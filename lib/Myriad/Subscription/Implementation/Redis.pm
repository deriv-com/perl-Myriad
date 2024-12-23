package Myriad::Subscription::Implementation::Redis;

use Myriad::Class ':v2', extends => qw(IO::Async::Notifier), does => [
    'Myriad::Role::Subscription'
];

# VERSION
# AUTHORITY

use Myriad::Util::UUID;
use Compress::Zstd ();

use constant MAX_ALLOWED_STREAM_LENGTH => 10_000;

use constant USE_OPENTELEMETRY => $ENV{USE_OPENTELEMETRY};

BEGIN {
    if(USE_OPENTELEMETRY) {
        require OpenTelemetry::Context;
        require OpenTelemetry::Trace;
        require OpenTelemetry::Constants;
        OpenTelemetry::Constants->import(qw( SPAN_STATUS_ERROR SPAN_STATUS_OK ));
    }
}

field $redis;

field $client_id;

# A list of all sources that emits events to Redis
# will need to keep track of them to block them when
# the stream size is more than what we think it should be
field @emitters;

# A list of all receivers that we should read items for
field @receivers;

field $should_shutdown;

BUILD {
    $client_id = Myriad::Util::UUID::uuid();
}

method configure (%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $self->next::method(%args);
}

async method create_from_source (%args) {
    my $src = delete $args{source} or die 'need a source';
    my $service = delete $args{service} or die 'need a service';

    my $stream = "service.subscriptions.$service/$args{channel}";

    $log->tracef('Adding subscription source %s to handler', $stream);
    push @emitters, {
        stream  => $stream,
        source  => $src,
        max_len => $args{max_len} // MAX_ALLOWED_STREAM_LENGTH
    } unless defined $args{subchannel_key};
    await Future->wait_all(
        $redis->zadd(
            "subscription.channels",
            $self->loop->time,
            encode_utf8($service . '/' . $args{channel}),
        ),
        $redis->sadd(
            "subscription.service",
            map { encode_utf8($_) } $service
        ),
        $redis->sadd(
            "subscription.service{$service}.channels",
            map { encode_utf8($_) } $args{channel}
        )
    );
    my %seen_channel;
    $self->adopt_future(
        $src->unblocked->then($self->$curry::weak(async method {
            # The streams will be checked later by "check_for_overflow" to avoid unblocking the source by mistake
            # we will make "check_for_overflow" aware about this stream after the service has started
            await $src->map($self->$curry::weak(async method ($event) {
                my $target_stream = $stream;
                if(defined($args{subchannel_key})) {
                    my $k = delete($event->{$args{subchannel_key}});
                    $target_stream .= "{$k}";
                    if(!exists $seen_channel{$k}) {
                        push @emitters, {
                            stream  => $target_stream,
                            source  => $src,
                            max_len => $args{max_len} // MAX_ALLOWED_STREAM_LENGTH
                        };
                        $seen_channel{$k} = 1;
                        await $redis->hset(
                            "subscription.subchannel.{$service}",
                            map { encode_utf8($_) } $args{channel}, $k
                        );
                    }
                }
                $log->tracef('Subscription source %s adding an event: %s', $target_stream, $event);
                my $data = encode_json_utf8($event);
                return await $redis->xadd(
                    encode_utf8($target_stream) => '*',
                    ($args{compress} || (defined $args{compress_threshold} and length($data) > $args{compress_threshold}))
                    ? (zstd => Compress::Zstd::compress($data))
                    : (data => $data)
                );
            }))->ordered_futures(
                low => 100,
                high => 5000,
            )->completed
             ->on_fail($self->$curry::weak(method {
                $log->warnf("Redis XADD command failed for stream %s", $stream);
                $should_shutdown->fail(
                    "Failed to publish subscription data for $stream - " . shift
                ) unless $should_shutdown->is_ready;
            }));
            return;
        }))
    );
    return;
}

async method create_from_sink (%args) {
    my $sink = delete $args{sink}
        or die 'need a sink';
    my $remote_service = $args{from} || $args{service};
    my $stream = "service.subscriptions.$remote_service/$args{channel}";
    $log->tracef('Adding subscription sink %s to handler', $stream);
    push @receivers, {
        key        => $stream,
        sink       => $sink,
        group_name => $args{service},
        group      => 0,
    };
}

async method start {
    $should_shutdown //= $self->loop->new_future(label => 'subscription::redis::shutdown');
    $log->tracef('Starting subscription handler client_id: %s', $client_id);
    await $self->create_streams;
    await Future->wait_any(
        $self->receive_items,
        $self->check_for_overflow,
        also => $should_shutdown,
    );
}

async method stop {
    $should_shutdown->done unless $should_shutdown->is_ready;
    return;
}


async method create_group($receiver) {
    unless ($receiver->{group}) {
        await $redis->create_group(
            $receiver->{key},
            $receiver->{group_name}
        );
        # Record mapping for services and groups - we can also retrieve this information
        # from $redis->xinfo_group, but having the entire list in a hash is more convenient
        # for larger deployments.
        await $redis->hset(
            'subscription.group',
            $receiver->{key},
            $receiver->{group_name}
        );
        $receiver->{group} = 1;
    }
    return;
}

async method receive_items {
    $log->tracef('Start receiving from (%d) subscription sinks', scalar(@receivers));
    while (@receivers == 0) {
        $log->tracef('No receivers, waiting for a few seconds');
        await $self->loop->delay_future(after => 5);
    }

    await &fmap_void($self->$curry::curry(async method ($rcv) {
        my $stream     = $rcv->{key};
        my $sink       = $rcv->{sink};
        my $group_name = $rcv->{group_name};

        try {
            my @pending;
            while (1) {
                try {
                    await $self->create_group($rcv);
                } catch ($e) {
                    $log->warnf('skipped subscription on stream %s because: %s will try again', $stream, $e);
                    await $self->loop->delay_future(after => 5);
                    next;
                }
                my @ack;
                while(@pending) {
                    # IDs are quite short, so we can stuff a fair few into each command - there's a bit of
                    # overhead so the more we combine here the better
                    push @ack, $redis->ack(
                        $stream,
                        $group_name,
                        splice(
                            @pending, 0, min(0+@pending, 200)
                        )
                    );
                }

                await $sink->unblocked;
                my @events = await $redis->read_from_stream(
                    stream => $stream,
                    group  => $group_name,
                    client => $client_id
                );

                # Let any pending ACK requests finish off before we start processing new ones - we do this check
                # here after the xreadgroup, rather than after the event loop, because that gives us a better
                # chance that all the ACKs have already been received, thus minimising wait time
                await Future->wait_all(@ack) if @ack;

                for my $event (@events) {
                    my $span;
                    if(USE_OPENTELEMETRY) {
                        $span = $tracer->create_span(
                            parent => OpenTelemetry::Context->current,
                            name   => $stream,
                            attributes => {
                                args => $event->{data}
                            },
                        );
                    }
                    try {
                        if(USE_OPENTELEMETRY) {
                            my $context = OpenTelemetry::Trace->context_with_span($span);
                            dynamically OpenTelemetry::Context->current = $context;
                            my $event_data = decode_json_utf8($event->{data});
                            $log->tracef('Passing event: %s | from stream: %s to subscription sink: %s', $event_data, $stream, $sink->label);
                            $sink->source->emit({
                                data => $event_data
                            });
                            push @pending, $event->{id};
                            $span->set_status(
                                SPAN_STATUS_OK
                            );
                        } else {
                            my $event_data = decode_json_utf8($event->{data});
                            $log->tracef('Passing event: %s | from stream: %s to subscription sink: %s', $event_data, $stream, $sink->label);
                            $sink->source->emit({
                                data => $event_data
                            });
                            push @pending, $event->{id};
                        }
                    } catch($e) {
                        $e = Myriad::Exception::InternalError->new(
                            reason => $e
                        ) unless blessed($e) and $e->DOES('Myriad::Exception');
                        $log->errorf(
                            'An error happened while decoding event data for stream %s message: %s, error: %s',
                            $stream,
                            $event->{data},
                            $e
                        );
                        if(USE_OPENTELEMETRY) {
                            $span->record_exception($e);
                            $span->set_status(
                                SPAN_STATUS_ERROR, $e
                            );
                        }
                    }
                }
            }
        } catch ($e) {
            $log->errorf(
                'Unable to read items from stream [%s] group [%s], unexpected error: %s',
                $stream,
                $group_name,
                $e
            );
            die $e;
        }
    }), foreach => [@receivers], concurrent => scalar @receivers);
}

async method check_for_overflow () {
    $log->tracef('Start checking overflow for (%d) subscription sources', 0 + @emitters);
    while (1) {
        if(@emitters) {
            my $emitter = shift @emitters;
            push @emitters, $emitter;
            try {
                my $len = await $redis->stream_length($emitter->{stream});
                if ($len >= 0.75 * $emitter->{max_len}) {
                    # Try a regular cleanup if we're getting close to the limit
                    await $redis->cleanup(
                        stream => $emitter->{stream},
                        limit  => $emitter->{max_len}
                    );
                    $len = await $redis->stream_length($emitter->{stream});
                }

                if ($len >= $emitter->{max_len}) {
                    unless ($emitter->{source}->is_paused) {
                        $emitter->{source}->pause;
                        $log->infof('Paused subscription source on %s, length is %s, max allowed %s', $emitter->{stream}, $len, $emitter->{max_len});
                    }
                } elsif ($emitter->{source}->is_paused) {
                    $emitter->{source}->resume;
                    $log->infof('Resumed subscription source on %s, length is %s', $emitter->{stream}, $len);
                }
            } catch ($e) {
                $log->warnf('An error ocurred while trying to check on stream %s status - %s', $emitter->{stream}, $e);
            }
        }

        # No need to run vigorously
        await $self->loop->delay_future(after => 5 + rand)
    }
}

async method create_streams() {
    await Future->needs_all(map { $redis->create_stream($_->{stream}) } @emitters);
}

1;

__END__

1;


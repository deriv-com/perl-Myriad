package Myriad::Subscription::Implementation::Memory;

use Myriad::Class ':v2', extends => qw(IO::Async::Notifier), does => [
    'Myriad::Role::Subscription',
    'Myriad::Util::Defer'
];

use constant USE_OPENTELEMETRY => $ENV{USE_OPENTELEMETRY};

BEGIN {
    if(USE_OPENTELEMETRY) {
        require OpenTelemetry::Context;
        require OpenTelemetry::Trace;
        require OpenTelemetry::Constants;
        OpenTelemetry::Constants->import(qw( SPAN_STATUS_ERROR SPAN_STATUS_OK ));
    }
}

# VERSION
# AUTHORITY

field $transport;

field $receivers;

field $should_shutdown = 0;
field $stopped;

BUILD {
    $receivers = [];
}

method receivers () { $receivers }

method _add_to_loop ($loop) {
    $stopped = $loop->new_future(label => 'subscription::redis::stopped');
}

method configure (%args) {
    $transport = delete $args{transport} if $args{transport};
    $self->next::method(%args);
}

async method create_from_source (%args) {
    my $src          = delete $args{source} or die 'need a source';
    my $service      = delete $args{service} or die 'need a service';
    my $channel_name = $service . '.' . $args{channel};
    await $transport->create_stream($channel_name);

    $self->adopt_future(
        $src->map(async sub {
            my $message = shift;
            await $transport->add_to_stream(
                $channel_name,
                $message->%*
            );
        })->resolve->completed
    );
    return;
}

async method create_from_sink (%args) {
    my $sink = delete $args{sink} or die 'need a sink';
    my $remote_service = $args{from} || $args{service};
    my $service_name = $args{service};
    my $channel_name = $remote_service . '.' . $args{channel};

    push $receivers->@*, {
        channel    => $channel_name,
        sink       => $sink,
        group_name => $service_name,
        group      => 0
    };
    return;
}

async method create_group ($subscription) {
    return if $subscription->{group};
    await $transport->create_consumer_group($subscription->{channel}, $subscription->{group_name}, 0, 0);
    $subscription->{group} = 1;
}

async method start {
    while (1) {
        await &fmap_void($self->$curry::curry(async method ($subscription) {
            await $self->create_group($subscription);
            try {
                $log->tracef('Sink blocked state: %s', $subscription->{sink}->unblocked->state);
                await Future->wait_any(
                    $self->loop->timeout_future(after => 0.5),
                    $subscription->{sink}->unblocked,
                );
            } catch {
                $log->tracef("skipped stream %s because sink is blocked", $subscription->{channel});
                return;
            }

            my $messages = await $transport->read_from_stream_by_consumer(
                $subscription->{channel},
                $subscription->{group_name},
                'consumer'
            );
            if(USE_OPENTELEMETRY) {
                for my $event_id (sort keys $messages->%*) {
                    my $span = $tracer->create_span(
                        parent => OpenTelemetry::Context->current,
                        name   => $subscription->{channel},
                        attributes => {
                            group => $subscription->{group_name},
                        },
                    );
                    try {
                        my $context = OpenTelemetry::Trace->context_with_span($span);
                        dynamically OpenTelemetry::Context->current = $context;

                        $subscription->{sink}->emit($messages->{$event_id});
                        await $transport->ack_message(
                            $subscription->{channel},
                            $subscription->{group_name},
                            $event_id
                        );

                        $span->set_status(
                            SPAN_STATUS_OK
                        );
                    } catch ($e) {
                        $e = Myriad::Exception::InternalError->new(
                            reason => $e
                        ) unless blessed($e) and $e->DOES('Myriad::Exception');
                        $log->errorf('Failed to process event %s - %s', $event_id, $e);
                        $span->record_exception($e);
                        $span->set_status(
                            SPAN_STATUS_ERROR, $e
                        );
                    }
                }
            } else {
                for my $event_id (sort keys $messages->%*) {
                    try {
                        $subscription->{sink}->emit($messages->{$event_id});
                        await $transport->ack_message(
                            $subscription->{channel},
                            $subscription->{group_name},
                            $event_id
                        );
                    } catch ($e) {
                        $e = Myriad::Exception::InternalError->new(
                            reason => $e
                        ) unless blessed($e) and $e->DOES('Myriad::Exception');
                        $log->errorf('Failed to process event %s - %s', $event_id, $e);
                    }
                }
            }

            if($should_shutdown) {
                $stopped->done;
                last;
            }
        }), foreach => [ $receivers->@* ], concurrent => 8);
        await $self->loop->delay_future(after => 0.1);
    }
}

async method stop {
    $should_shutdown = 1;
    await $stopped;
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


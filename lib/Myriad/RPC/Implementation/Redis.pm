package Myriad::RPC::Implementation::Redis;

use Myriad::Class extends => qw(IO::Async::Notifier);

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::RPC::Implementation::Redis - microservice RPC Redis implementation.

=head1 DESCRIPTION

=cut

use Role::Tiny::With;

use Future::Utils qw(fmap0);
use Sys::Hostname qw(hostname);
use Scalar::Util qw(blessed);

use Myriad::Exception::InternalError;
use Myriad::RPC::Message;

use constant RPC_SUFFIX => 'rpc';
use constant RPC_PREFIX => 'service';
use constant MAX_ALLOWED_STREAM_LENGTH => 10_000;

use Exporter qw(import export_to_level);

with 'Myriad::Role::RPC';

our @EXPORT_OK = qw(stream_name_from_service);

field $redis:reader;
field $group_name:reader;
field $whoami:reader;
field $rpc_list:reader;

field $running;
field $processing;

sub stream_name_from_service ($service, $method) {
    return RPC_PREFIX . ".{$service}.". RPC_SUFFIX . "/$method"
}

sub service_from_stream_name ($stream_name) {
    my ($service, $method) = $stream_name =~ m{\Q@{[RPC_PREFIX()]}\E\.\{([^\}]+)\}\.\Q@{[RPC_SUFFIX]}\E/(.*)};
    return ($service, $method);
}

method configure (%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $whoami = hostname();
    $group_name = 'processors';
    $rpc_list //= [];
    $processing //= {};

    $self->next::method(%args);
}

async method start () {
    $self->listen;
    await $running;
}

method create_from_sink (%args) {
    my $sink   = $args{sink} // die 'need a sink';
    my $method = $args{method} // die 'need a method name';
    my $service = $args{service} // die 'need a service name';

    push $rpc_list->@*, {
        stream => stream_name_from_service($service, $method),
        sink   => $sink,
        group  => 0
    };
}

async method stop () {
    $running->done unless $running->is_ready;
}

async method create_group ($rpc) {
    return if $rpc->{group};

    await $self->redis->create_group(
        $rpc->{stream},
        $self->group_name,
        '0',
        1
    );
    my ($service, $method) = service_from_stream_name($rpc->{stream});
    await $self->redis->hset(
        "rpc.group.{$service}",
        $method,
        $self->group_name,
    );
    $rpc->{group} = 1;
    await $self->check_pending($rpc);
    return;
}

async method check_pending ($rpc) {
    my $done = 0;
    until ( $done ) {
        my @items = await $self->redis->pending(
            stream => $rpc->{stream},
            group  => $self->group_name,
            client => $self->whoami
        );
        $done = 1 unless @items;
        $log->tracef('Pending messages in stream: %s | Done: %s', \@items, $done);

        await $self->stream_items_messages($rpc, @items);
    }
}

async method stream_items_messages ($rpc, @items) {
    ITEM:
    for my $item (@items) {
        next ITEM unless $item->{args} || exists $processing->{$item->{id}};
        my $data = {
            $item->{extra}->%*,
            data         => $item->{data},
            transport_id => $item->{id},
        };
        $processing->{$rpc->{stream}}->{$item->{id}} = $self->loop->new_future(
            label => "rpc::response::$rpc->{stream}::$item->{id}"
        );
        try {
            my $message = Myriad::RPC::Message::from_hash($data->%*);
            $log->tracef('Passing message: %s to: %s', $message, $rpc->{sink}->label);
            if ($message->passed_deadline) {
                $log->tracef('Skipping message %s because deadline is due - deadline: %s now: %s',
                    $message->transport_id, $message->deadline, time);
                await $self->drop($rpc->{stream}, $item->{id});
                next ITEM;
            }
            $rpc->{sink}->emit($message);
        } catch ($error) {
            $log->tracef("error while parsing the incoming messages: %s", $error->message);
            await $self->drop($rpc->{stream}, $item->{id});
        }
    }
    await Future->needs_all(values $processing->{$rpc->{stream}}->%*);
    $processing->{$rpc->{stream}} = {};
}

method listen () {
    return $running //= (async sub {
        $log->tracef('Start listening to (%d) RPC stream(s)', scalar($self->rpc_list->@*));
        await &fmap_void($self->$curry::weak(async method ($rpc) {
            try {
                await $self->create_group($rpc);

                while (1) {
                    my $f = $self->redis->when_key_changed($rpc->{stream});
                    while(my @items = await $self->redis->read_from_stream(
                        stream => $rpc->{stream},
                        group  => $self->group_name,
                        client => $self->whoami
                    )) {
                        await $self->stream_items_messages($rpc, @items);
                        await $self->redis->cleanup(
                            stream => $rpc->{stream},
                            limit  => MAX_ALLOWED_STREAM_LENGTH,
                        );
                    }
                    $log->tracef('Wait for key change notification on [%s]', $rpc->{stream});
                    await $f;
                    $log->tracef('Key [%s] changed, poll again', $rpc->{stream});
                }
            } catch ($e) {
                $log->errorf('Failed on RPC listen - %s', $e);
                die $e;
            }
        }), foreach => [$self->rpc_list->@*], concurrent => 0 + $self->rpc_list->@*);
    })->();
}

async method reply ($service, $message) {
    my $stream = stream_name_from_service($service, $message->rpc);
    try {
        $log->tracef('Reply to [%s] with %s', $message->who, $message->as_json);
        await $self->redis->publish($message->who, $message->as_json);
        await $self->redis->ack($stream, $self->group_name, $message->transport_id);
        $processing->{$stream}->{$message->transport_id}->done('published');
    } catch ($e) {
        $log->warnf("Failed to reply to client due: %s", $e);
        return;
    }
}

async method reply_success ($service, $message, $response) {
    $message->response = { response => $response };
    await $self->reply($service, $message);
}

async method reply_error ($service, $message, $error) {
    $message->response = { error => { category => $error->category, message => $error->message, reason => $error->reason } };
    await $self->reply($service, $message);
}

async method drop ($stream, $id) {
    $log->tracef("Going to drop message ID: %s on stream: %s", $id, $stream);
    await $self->redis->ack($stream, $self->group_name, $id);
    $processing->{$stream}->{$id}->done('published');
    return;
}

async method has_pending_requests ($service) {
    my $stream = stream_name_from_service($service);
    my $stream_info = await $self->redis->pending_messages_info($stream, $self->group_name);
    if($stream_info->[0]) {
        for my $consumer ($stream_info->[3]->@*) {
            return $consumer->[1] if $consumer->[0] eq $self->whoami;
        }
    }

    return 0;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


package Myriad::RPC::Implementation::Redis;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Role::Tiny::With;
with 'Myriad::Role::RPC';

use Myriad::Class extends => qw(IO::Async::Notifier);

=head1 NAME

Myriad::RPC::Implementation::Redis - microservice RPC Redis implementation.

=head1 DESCRIPTION

=cut

use Sys::Hostname qw(hostname);
use Scalar::Util qw(blessed);

use Myriad::Exception::InternalError;
use Myriad::RPC::Message;

has $redis;
method redis { $redis }

has $service;
method service { $service }

has $stream;
method stream { $stream //= $service . '/rpc'}

has $group_name;
method group_name { $group_name }

has $whoami;
method whoami { $whoami }

has $rpc_methods;

method configure (%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $service = delete $args{service} if exists $args{service};
    $whoami = hostname();
    $group_name = 'processors';
}

async method start () {
    await $self->redis->create_group(
        $self->stream,
        $self->group_name
    );
    await $self->listener;
}

method create_from_sink (%args) {
    my $sink   = $args{sink} // die 'need a sink';
    my $method = $args{method} // die 'need a method name';

    $rpc_methods->{$method} = $sink;
}


async method stop () {
    $self->listener->cancel;
    return;
}

async method listener () {
    my %stream_config = (
        stream => $self->stream,
        group  => $self->group_name,
        client => $self->whoami
    );
    my $pending_requests = $self->redis->pending(%stream_config);
    my $incoming_request = $self->redis->iterate(%stream_config);
    try {
        await $incoming_request->merge($pending_requests)
            ->map(sub {
                my $data = $_;
                try {
                    { message => Myriad::RPC::Message->new(@$data) };
                } catch ($error) {
                    $error = Myriad::Exception::InternalError->new($error) unless blessed($error) and $error->isa('Myriad::Exception');
                    return { error => $error, id => $data->{message_id} }
                }
            })->map(async sub {
                if(my $error = $_->{error}) {
                    $log->warnf("error while parsing the incoming messages: %s", $error->message);
                    await $self->drop($_->{id});
                } else {
                    my $message = $_->{message};
                    if (my $sink = $rpc_methods->{$message->rpc}) {
                        $sink->emit($message);
                    } else {
                        my $error = Myriad::Exception::RPC::MethodNotFound->new(reason => "No such method: " . $message->rpc);
                        await $self->reply_error($message, $error);
                    }
                }
            })->resolve->completed;
    } catch ($e) {
        warn $e;
        $log->errorf("RPC listener stopped due to: %s", $e);
    }
}

async method reply ($message) {
    try {
        await $self->redis->publish($message->who, $message->encode);
        await $self->redis->ack($self->stream, $self->group_name, $message->id);
    } catch ($e) {
        $log->warnf("Failed to reply to client due: %s", $e);
        return;
    }
}

async method reply_success ($message, $response) {
    $message->response = { response => $response };
    await $self->reply($message);
}

async method reply_error ($message, $error) {
    $message->response = { error => { category => $error->category, message => $error->message, reason => $error->reason } };
    await $self->reply($message);
}

async method drop ($id) {
    $log->debugf("Going to drop message: %s", $id);
    await $self->redis->ack($self->stream, $self->group_name, $id);
}

async method has_pending_requests () {
    my $stream_info = await $self->redis->pending_messages_info($self->stream, $self->group_name);
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

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


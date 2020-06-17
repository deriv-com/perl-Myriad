package Myriad::RPC::Implementation::Redis;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;
use Object::Pad;

class Myriad::RPC::Implementation::Redis extends Myriad::Notifier;

use experimental qw(signatures);

use Future::AsyncAwait;
use Syntax::Keyword::Try;
use Role::Tiny::With;

use Log::Any qw($log);
use Sys::Hostname;

with 'Myriad::RPC';

has $redis;
has $group_name;
has $whoami;
has $service;
has $rpc_map;
method rpc_map :lvalue { $rpc_map }

method BUILD(%args) {
    $whoami = hostname;
    $group_name = 'processors';
}

method configure(%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $service = delete $args{service} if exists $args{service};
}

method _add_to_loop($loop) {
    $self->listen()->retain();
}

async method listen() {
    await $redis->create_group($service, $group_name);
    my $stream_config = { stream => $service, group => $group_name, client => $whoami };
    my $pending_requests = $redis->pending(%$stream_config);
    my $incoming_request = $redis->iterate(%$stream_config);

    try {
        await $incoming_request->merge($pending_requests)->map(sub {
            # Redis response is array ref we need a hashref
            my %args = @$_;
            return \%args;
        })->map(sub {
            my ($data) = @_;
            try {
                { message => Myriad::RPC::Message->new($data->%*) };
            } catch {
                my $error = $@;
                if (!$@->isa('Myriad::Exception')) {
                    $error = Myriad::Exception::InternalError->new();
                }
                return { error => $error, id => $data->{message_id} }
            }
        })->each(sub {
            if (my $error = $_->{error}) {
                $log->warnf("error while parsing the incoming messages: %s", $error->message);
                $rpc_map->{__DEAD_MSG}->[0]->emit($_->{id});
            } else {
                my $message = $_->{message};
                if (my $method = $rpc_map->{$message->rpc}) {
                    $method->[0]->emit($message);
                } else {
                    my $error = Myriad::Exception::RPCMethodNotFound->new(method => $method);
                    $rpc_map->{'__ERROR'}->[0]->emit({message => $message, error => $error});
                }
            }
        })->completed;
    } catch {
        $log->fatalf("RPC listener stopped due: %s", $@);
    }
}

async method _reply($message) {
    try {
        await $redis->publish($message->who, $message->encode);
        await $redis->ack($service, $group_name, $message->id);
    } catch {
        $log->warnf("Failed to reply to client due: %s", $@);
        return;
    }
}

async method reply_success($message, $response) {
    $message->response = { response => $response };
    await $self->_reply($message);
}

async method reply_error($message, $error) {
    $message->response = { error => { code => $error->category, message => $error->message } };
    await $self->_reply($message);
}

async method drop($id) {
    $log->debugf("Going to drop message: %s", $id);
    await $redis->ack($service, $group_name, $id);
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


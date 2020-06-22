package Myriad::RPC::Implementation::Redis;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

use parent qw(IO::Async::Notifier);

use experimental qw(signatures);

use Future::AsyncAwait;
use Syntax::Keyword::Try;
use Sys::Hostname qw(hostname);
use Role::Tiny::With;
use Scalar::Util qw(blessed);

use Log::Any qw($log);

with 'Myriad::RPC';

sub rpc_map { shift->rpc_map }

sub configure ($self, %args) {
    for my $k (qw(whoami group_name redis service)) {
        $self->{$k} = delete $args{$k} if exists $args{$k};
    }
    $self->{whoami} //= hostname();
    $self->{group_name} //= 'processors';
}

sub _add_to_loop ($self, $loop) {
    $self->listen->retain;
}

async sub listen ($self) {
    await $self->redis->create_group(
        $self->service,
        $self->group_name
    );
    my %stream_config = (
        stream => $self->service,
        group  => $self->group_name,
        client => $self->whoami
    );
    my $pending_requests = $self->redis->pending(%stream_config);
    my $incoming_request = $self->redis->iterate(%stream_config);

    try {
        await $incoming_request->merge($pending_requests)
            ->map(sub {
                my ($data) = @_;
                try {
                    { message => Myriad::RPC::Message->new(@$data) };
                } catch {
                    my $error = $@;
                    $error = Myriad::Exception::InternalError->new($@) unless blessed($error) and $error->isa('Myriad::Exception');
                    return { error => $error, id => $data->{message_id} }
                }
            })->each(sub {
                if (my $error = $_->{error}) {
                    $log->warnf("error while parsing the incoming messages: %s", $error->message);
                    $self->rpc_map->{__DEAD_MSG}->[0]->emit($_->{id});
                } else {
                    my $message = $_->{message};
                    if (my $sub = $self->rpc_map->{$message->rpc}) {
                        $sub->[0]->emit($message);
                    } else {
                        my $error = Myriad::Exception::RPCMethodNotFound->new(sub => $sub);
                        $self->rpc_map->{'__ERROR'}->[0]->emit({message => $message, error => $error});
                    }
                }
            })->completed;
    } catch {
        $log->fatalf("RPC listener stopped due: %s", $@);
    }
}

async sub _reply ($self, $message) {
    try {
        await $self->redis->publish($message->who, $message->encode);
        await $self->redis->ack($self->service, $self->group_name, $message->id);
    } catch {
        $log->warnf("Failed to reply to client due: %s", $@);
        return;
    }
}

async sub reply_success ($self, $message, $response) {
    $message->response = { response => $response };
    await $self->_reply($message);
}

async sub reply_error ($self, $message, $error) {
    $message->response = { error => { code => $error->category, message => $error->message } };
    await $self->_reply($message);
}

async sub drop ($self, $id) {
    $log->debugf("Going to drop message: %s", $id);
    await $self->redis->ack($self->service, $self->group_name, $id);
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


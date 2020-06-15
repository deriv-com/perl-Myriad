package Myriad::RPC;

use strict;
use warnings;

# VERSION

use Future::AsyncAwait;
use Myriad::RPC::Message;
use Object::Pad;

class Myriad::RPC extends Myriad::Notifier;

use experimental qw(signatures);

use utf8;

use Syntax::Keyword::Try;

=encoding utf8;

=head1 SYNOPSIS

=head1 DESCRIPTION

Myriad RPC implementation to serve the requests of the service clients.

=cut

has $redis;
has $service;

has $stream_name;
has $group_name;

has $ryu;
has $rpc_map;

method ryu {$ryu}
method rpc_map :lvalue {$rpc_map}

method configure(%args) {
    $redis = delete $args{redis} // die 'Redis Transport is required';
    $service = delete $args{service} // die 'Service name is required';

    $stream_name = $service;
    $group_name = 'processors';
}

method _add_to_loop($loop) {
    $self->add_child(
        $ryu = Ryu::Async->new
    );

    $self->listen->retain();
}

async method listen {
    my $stream_config = { stream => $stream_name, group => $group_name, client => "me" };
    my $incoming_request = $redis->iterate(%$stream_config);
    my $pending_requests = $redis->pending(%$stream_config);

    await $incoming_request->merge($pending_requests)->map(sub {
        my %args = @$_;
        return \%args;
    })->map(sub {
        my ($data) = @_;
        Myriad::RPC::Message->new($data->%*);
    })->each(sub {
        if (my $method = $rpc_map->{$_->rpc}) {
            $method->[0]->emit($_)
        }
        else {
            $rpc_map->{'__NOTFOUND'}->[0]->emit($method);
        }
    })->completed;
}

async method reply($message) {
    await $redis->publish($message->who, $message->encode);
    await $redis->ack($stream_name, 'me', $message->id);
}

1;
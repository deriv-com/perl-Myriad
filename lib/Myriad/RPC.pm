package Myriad::RPC;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Future::AsyncAwait;
use Object::Pad;
use Syntax::Keyword::Try;
use Myriad::RPC::Message;
use Sys::Hostname;

use Log::Any qw($log);
class Myriad::RPC extends Myriad::Notifier;

use experimental qw(signatures);

=encoding utf8

=head1 NAME

Myriad::RPC - microservice RPC abstraction

=head1 SYNOPSIS

 my $rpc = $myriad->rpc;

=head1 DESCRIPTION

=head1 Implementation

Note that this is defined as a rôle, so it does not provide
a concrete implementation - instead, see classes such as:

=over 4

=item * L<Myriad::RPC::Implementation::Redis>

=item * L<Myriad::RPC::Implementation::Perl>

=back

=cut

use Role::Tiny;


has $redis;
has $service;

has $group_name;

has $ryu;
has $rpc_map;
has $whoami;

method ryu {$ryu}
method rpc_map :lvalue {$rpc_map}

method configure(%args) {
    $redis = delete $args{redis} // die 'Redis Transport is required';
    $service = delete $args{service} // die 'Service name is required';

    $whoami = hostname;
    $group_name = 'processors';
}

method _add_to_loop($loop) {
    $self->add_child(
        $ryu = Ryu::Async->new
    );

    $self->listen->retain();
}

async method listen {
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
            Myriad::RPC::Message->new($data->%*);
        })->each(sub {
            if ($_->isa('Myriad::Exception')) {
                warn "internal";
                # $rpc_map->{'__ERRORS'}->[0]->emit($_);
            }
            else {
                if (my $method = $rpc_map->{$_->rpc}) {
                    $method->[0]->emit($_)
                }
                else {
                    $rpc_map->{'__NOTFOUND'}->[0]->emit($method);
                }
            }
        })->completed;
    } catch {
        $log->fatalf("RPC listener stopped due: %s", $@);
    }
}

async method reply($message) {
    await $redis->publish($message->who, $message->encode);
    await $redis->ack($service, $group_name, $message->id);
}

1;

__END__

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


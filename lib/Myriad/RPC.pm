package Myriad::RPC;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Future::AsyncAwait;
use Object::Pad;

use Myriad::RPC::Message;
use Myriad::Exception::RPCMethodNotFound;

class Myriad::RPC;

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

requires 'rpc_map';

requires 'listen';

requires 'reply_success';

requires 'reply_error';

requires 'drop';

1;

__END__

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


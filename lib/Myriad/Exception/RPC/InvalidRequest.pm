package Myriad::Exception::RPC::InvalidRequest;

use strict;
use warnings;

# VERSION
# AUTHORITY

use parent qw(Ryu::Exception);

no indirect qw(fatal);

use Role::Tiny::With;

with 'Myriad::Exception';

sub category { 'rpc' }

sub message { 'invalid request' }

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


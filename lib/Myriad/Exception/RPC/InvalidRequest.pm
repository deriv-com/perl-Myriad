package Myriad::Exception::RPC::InvalidRequest;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);

use Myriad::Exception::Builder;

sub reason { shift->{reason} }

sub category { 'rpc' }
sub message { $_[0]->{message} //= 'invalid request due to: ' . $_[0]->reason }

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


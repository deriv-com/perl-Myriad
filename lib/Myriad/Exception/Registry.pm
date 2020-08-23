package Myriad::Exception::Registry;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);

use utf8;

=encoding utf8

=head1 NAME

Myriad::Exception::Base - common class for all exceptions

=head1 DESCRIPTION

See L<Myriad::Exception> for the rôle that defines the exception API.

=cut

use Myriad::Exception::Builder;

sub category { 'registry' }
sub reason { shift->{reason} //= 'unknown' }
sub message { $_[0]->{message} //= 'Internal error: ' . $_[0]->reason }

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


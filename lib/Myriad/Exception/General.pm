package Myriad::Exception::General;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

=encoding utf8

=head1 NAME

Myriad::Exception::Base - common class for all exceptions

=head1 DESCRIPTION

See L<Myriad::Exception> for the rôle that defines the exception API.

=cut

no indirect qw(fatal);

use Myriad::Exception::Builder;

sub category { 'myriad' }

sub message { shift->{message} //= 'unknown exception' }

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2023. Licensed under the same terms as Perl itself.


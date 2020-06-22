package Myriad::Subscription;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);
use Future::AsyncAwait;

use experimental qw(signatures);

=encoding utf8

=head1 NAME

Myriad::Subscription - microservice subscription abstraction

=head1 SYNOPSIS

 my $storage = $myriad->subscription;

=head1 DESCRIPTION

=head1 Implementation

Note that this is defined as a rôle, so it does not provide
a concrete implementation - instead, see classes such as:

=over 4

=item * L<Myriad::Subscription::Implementation::Redis>

=item * L<Myriad::Subscription::Implementation::Perl>

=back

=cut

use Role::Tiny;

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


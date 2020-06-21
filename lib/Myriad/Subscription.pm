package Myriad::Subscription;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Future::AsyncAwait;
use Object::Pad;

class Myriad::Subscription;

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

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


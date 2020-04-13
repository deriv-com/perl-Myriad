package Myriad::Exception;

use strict;
use warnings;

# VERSION

# Note that we aren't using Object::Pad here because Future::Exception
# is arrayref-based, so Object::Pad does not have anywhere to store slots.
use parent qw(Future::Exception);

no indirect;

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


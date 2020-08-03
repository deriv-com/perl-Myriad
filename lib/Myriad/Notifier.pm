package Myriad::Notifier;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);
use Object::Pad;

{
    package Myriad::Notifier::Empty;
    sub new {
        my ($class, %args) = @_;
        bless \%args, $class
    }
}
class Myriad::Notifier extends Myriad::Notifier::Empty;

use parent qw(IO::Async::Notifier);

=head1 NAME

Myriad::Notifier

=head1 DESCRIPTION

Provides a shim for L<Object::Pad> classes which want to inherit
from L<IO::Async::Notifier>, due to RTx this fails due to the
existing L<IO::Async::Notifier/new> method trying to call subclass
methods before the instance pads have been set up.

=cut

BUILD (%args) {
    $self->_init(\%args);
    $self->configure(%args);
    $self
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


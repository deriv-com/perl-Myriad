package Myriad::Notifier;

use strict;
use warnings;

no indirect;
use Object::Pad;

class Myriad::Notifier;

use parent qw(IO::Async::Notifier);

=head1 NAME

Myriad::Notifier

=head1 DESCRIPTION

Provides a shim for L<Object::Pad> classes which want to inherit
from L<IO::Async::Notifier>, due to RTx this fails due to the
existing L<IO::Async::Notifier/new> method trying to call subclass
methods before the instance pads have been set up.

=cut

has $ryu;

method BUILD (%args) {
    $self->_init(\%args);
    $self->configure(%args);
    $self
}

=head2 ryu

Provides a common L<Ryu::Async> instance.

=cut

method ryu { $ryu }

method _add_to_loop {
    $self->add_child(
        $ryu = Ryu::Async->new
    );
    $self->next::method;
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.

package Myriad::Exception::BadMessage;

use strict;
use warnings;

# VERSION

use parent qw(Myriad::Exception);

no indirect;

sub throw {
    my ($self, $details) = @_;
    $self->SUPER::throw("Internal error!", "INTERNAL", $details);
}

1;

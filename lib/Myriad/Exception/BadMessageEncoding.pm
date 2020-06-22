package Myriad::Exception::BadMessageEncoding;

use strict;
use warnings;

# VERSION

use parent qw(Myriad::Exception);

no indirect qw(fatal);

sub throw {
    my ($self) = @_;
    $self->SUPER::throw("Bad message encoding!", "BAD_MESSAGE");
}

1;

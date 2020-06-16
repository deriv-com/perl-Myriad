package Myriad::Exception::BadMessage;

use strict;
use warnings;

# VERSION

use parent qw(Myriad::Exception);

no indirect;

sub throw {
    my ($self, $field) = @_;
    $self->SUPER::throw("Bad RPC Message field: $field is required!", "BAD_MESSAGE");
}

1;

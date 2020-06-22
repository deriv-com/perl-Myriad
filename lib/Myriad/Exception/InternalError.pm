package Myriad::Exception::InternalError;

use strict;
use warnings;

# VERSION

use parent qw(Myriad::Exception);

no indirect;

use mro;

sub throw {
    my ($self, $details) = @_;
    $self->next::method("Internal error!", "INTERNAL", $details);
}

1;

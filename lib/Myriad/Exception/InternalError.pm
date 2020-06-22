package Myriad::Exception::InternalError;

use strict;
use warnings;

# VERSION

use parent qw(Myriad::Exception);

no indirect qw(fatal);

use mro;

sub throw {
    my ($self, $details) = @_;
    $self->next::method("Internal error!", "INTERNAL", $details);
}

1;

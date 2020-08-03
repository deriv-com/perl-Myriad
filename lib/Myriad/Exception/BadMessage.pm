package Myriad::Exception::BadMessage;

use strict;
use warnings;

# VERSION

no indirect qw(fatal);
use utf8;

use parent qw(Myriad::Exception);

sub throw {
    my ($self, $field) = @_;
    $self->next::method("Bad RPC Message field: $field is required!", "BAD_MESSAGE");
}

1;

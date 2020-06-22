package Myriad::Exception::RPCMethodNotFound;

use strict;
use warnings;

# VERSION

use parent qw(Myriad::Exception);

no indirect qw(fatal);

sub new {
    my ($class, $method) = @_;
    bless [
        "No such method: $method",
        'METHOD_NOT_FOUND'
    ], $class
}

1;

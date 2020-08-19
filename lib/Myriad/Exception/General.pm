package Myriad::Exception::General;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);

use Role::Tiny::With;

with 'Myriad::Exception';

sub new {
    my ($class, $method) = @_;
    bless { method => $method }, $class
}

1;


package Myriad::Exception::InternalError;

use strict;
use warnings;

# VERSION

no indirect qw(fatal);

use Myriad::Exception::Builder;

sub category { 'internal' }
sub message { shift->{message} //= 'Internal error' }

1;


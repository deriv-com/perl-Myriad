package Myriad::Exception::General;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);

use Myriad::Exception::Builder;

sub category { 'myriad' }
sub message { shift->{message} //= 'unknown exception' }

1;


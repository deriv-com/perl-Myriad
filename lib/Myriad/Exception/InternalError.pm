package Myriad::Exception::InternalError;

use strict;
use warnings;

# VERSION

no indirect qw(fatal);

use Role::Tiny::With;

with 'Myriad::Exception';

sub category { 'MYRIAD_INTERNAL_ERROR' }

sub message { 'Internal error' }

1;


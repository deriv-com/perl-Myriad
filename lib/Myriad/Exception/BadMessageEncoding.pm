package Myriad::Exception::BadMessageEncoding;

use strict;
use warnings;

# VERSION

no indirect qw(fatal);

use Role::Tiny::With;
with 'Myriad::Exception';

sub category { 'BAD_MESSAGE' }

sub message { 'Bad message encoding!' }

1;


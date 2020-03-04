use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Log::Any::Adapter qw(TAP);
use Myriad::Config;

is(exception {
    Myriad::Config->new
}, undef, '->new without parameters succeeds');

done_testing;


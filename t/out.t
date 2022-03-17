use strict;
use warnings;

use Test::More;
use Path::Tiny;
path('output.txt')->spew_utf8(explain \%ENV);
ok(1);

done_testing;



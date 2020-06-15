use strict;
use warnings;

use Myriad::Exception;
use Test::More;
use Test::Fatal;

my $ex = Myriad::Exception->new('a failure message here');
isa_ok($ex, 'Myriad::Exception', '$ex from ->new');

my $caught = exception { Myriad::Exception->throw('another exception') };
isa_ok($caught, 'Myriad::Exception', '$caught exception');

done_testing;

use strict;
use warnings;

use Myriad;
use Test::More;
use Test::Fatal;

use Scalar::Util qw(refaddr);

my $myriad = new_ok('Myriad');
isa_ok(my $f = $myriad->shutdown_future, 'Future');
is(refaddr($f), refaddr($myriad->shutdown_future), 'same Future on multiple calls');
is(exception {
    $myriad->shutdown->get
}, undef, 'can shut down without exceptions arising');
is($f->state, 'done', 'shutdown future marked as done');

done_testing;


use strict;
use warnings;

use Test::More;
use Myriad::Notifier;

my $notifier = new_ok('Myriad::Notifier');
can_ok($notifier, qw(ryu));

done_testing;

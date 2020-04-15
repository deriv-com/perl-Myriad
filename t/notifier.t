use strict;
use warnings;

use Test::More;
use Myriad::Notifier;

my $notifier = new_ok('Myriad::Notifier');
can_ok($notifier, qw(_add_to_loop));

done_testing;

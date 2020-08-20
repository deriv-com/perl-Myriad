use strict;
use warnings;

BEGIN { $ENV{MYRIAD_RANDOM_DELAY} = 0.005 }

use Test::More;
use Test::Deep;

use Object::Pad;
use Future::AsyncAwait;
use IO::Async::Loop;

class Example extends IO::Async::Notifier {
    use parent qw(Myriad::Util::Defer);
    use Log::Any qw($log);

    async method run : Defer (%args) {
        $log->tracef("in async method run");
        await $self->loop->delay_future(after => 0.002);
        $log->tracef("after async method resumed");
        return \%args;
    }
}
my $loop = IO::Async::Loop->new;
$loop->add(my $example = Example->new);
is_deeply($example->run(x => 123)->get, { x => 123}, 'deferred code executed correctly');

done_testing;



use strict;
use warnings;

use Log::Any::Adapter qw(TAP);

# Enforce some level of delay
BEGIN { $ENV{MYRIAD_RANDOM_DELAY} = 0.005 }

use Test::More;
use Test::Deep;

use Object::Pad;
use Future::AsyncAwait;
use IO::Async::Loop;

class Example :isa(IO::Async::Notifier) {
    use Myriad::Util::Defer;
    use Log::Any qw($log);

    async method run : Defer (%args) {
        $log->tracef("in async method run");
        await $self->loop->delay_future(after => 0.002);
        $log->tracef("after async method resumed");
        return \%args;
    }

    async method immediate {
        return 1;
    }

    async method immediate_deferred : Defer {
        $log->tracef('in immediate_deferred');
        return 1;
    }
}

my $loop = IO::Async::Loop->new;
$loop->add(my $example = Example->new);
is_deeply(
    $example->run(x => 123)->get,
    { x => 123},
    'deferred code executed correctly'
);

ok($example->immediate->is_done, 'immediate method marked as done immediately after call');
ok(!(my $ret = $example->immediate_deferred)->is_done, '... but with the :Defer attribute, still pending');
note explain $ret->state;
await Future->needs_any(
    $ret,
    $loop->timeout_future(after => 1)
);
ok($ret->is_done, '... resolving correctly after some time has passed');

done_testing;

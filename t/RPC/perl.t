use strict;
use warnings;

use Ryu::Async;
use IO::Async::Loop;
use Future::AsyncAwait;

use Test::More;
use Test::MemoryGrowth;

use Syntax::Keyword::Try;
use Log::Any qw($log);
use Log::Any::Adapter qw(Stderr), log_level => 'info';

use Myriad::RPC::Implementation::Perl;

my $loop = IO::Async::Loop->new;

my $message_args = {
    rpc        => 'test',
    message_id => 1,
    who        => 'client',
    deadline   => time,
    args       => '{}',
    stash      => '{}',
    trace      => '{}'
};

$loop->add(my $ryu = Ryu::Async->new);
$loop->add(my $rpc = Myriad::RPC::Implementation::Perl->new());

isa_ok($rpc, 'IO::Async::Notifier');

my $sink = $ryu->sink(label=> 'rpc::test');

$rpc->create_from_sink(method => 'test', sink => $sink);
$rpc->start()->retain;

subtest 'it should return method not found' => sub {
    (async sub {

    my $response = $loop->new_future;
    $message_args->{rpc} = 'not_found';
    $rpc->request($message_args, $response);

    try {
        await $response;
    } catch ($e) {
        like($e, qr{Method not found}, '');
    }


    })->()->get();

};


subtest 'it should propagate the message correctly' => sub {
    (async sub {
        my $response = $loop->new_future;

        $message_args->{rpc} = 'test';
        $rpc->request($message_args, $response);

        $sink->source->take(1)->each(sub {
            my $message = shift;
            $rpc->reply_success($message, {success => 1});
        })->completed->retain();

        my $reply = await $response;
        ok($reply, 'request should be propagated to the sink');
    })->()->get;
};


subtest 'it should shutdown cleanly' => sub {
    (async sub {
        my $f = await $rpc->stop;
        ok($f, 'it should stop');
    })->()->get();
};

done_testing;


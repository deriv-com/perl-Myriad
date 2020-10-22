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

(async sub {

    my $sink = $ryu->sink(label=> 'rpc::test');

    $rpc->create_from_sink(method => 'test', sink => $sink);
    $rpc->start()->retain;

    my $response = $loop->new_future;
    $message_args->{rpc} = 'not_found';
    $rpc->request($message_args, $response);

    try {
        await $response;
    } catch ($e) {
        like($e, qr{Method not found}, '');
    }

    $rpc->stop();

})->()->get();

done_testing;


use strict;
use warnings;

use Test::More;

use IO::Async::Loop;
use Myriad::Redis::Pending;
use Myriad::RPC;
use Myriad::Transport::Redis;
use Myriad::RPC::Implementation::Redis qw(stream_name_from_service);
use IO::Async::Timer::Periodic;
#use Myriad::RPC::Implementation::Redis;
use Ryu::Async;
use Time::Moment;
 use Log::Any::Adapter qw(Stderr), log_level => 'debug';

subtest 'pending instance' => sub {
    my $redis = do {
        package Placeholder::Redis;
        sub loop { IO::Async::Loop->new }
        bless {}, __PACKAGE__;
    };
    my $pending = new_ok('Myriad::Redis::Pending', [
        redis => $redis,
        stream => 'the-stream',
        group => 'the-group',
        id => 1234
    ]);
    isa_ok($pending->finished, qw(Future));
};

subtest 'redis xgroupread wait time' => sub {
 my $loop = IO::Async::Loop->new;
 my $redis = Myriad::Transport::Redis->new(
	 redis_uri              => 'redis://redis6:6379',
         cluster                =>  0,
         client_side_cache_size =>  0,
 );
 $loop->add($redis);
 $redis->start->get;
 my $ryu = Ryu::Async->new;
 $loop->add($ryu);

 my $rpc = Myriad::RPC::Implementation::Redis->new(redis => $redis);
 $loop->add($rpc);
 my $sink = $ryu->sink(label => "Testing:channel");
 my $sink2 = $ryu->sink(label => "Testing:channel2");

 my $method = 'test_method';
 my $service = 'testing_service';
 $rpc->create_from_sink(sink => $sink, method => $method, service => $service);


 my $method2 = 'test_method2';
 my $service2 = 'testing_service2';
 $rpc->create_from_sink(sink => $sink2, method => $method2, service => $service2);

 my $request = Myriad::RPC::Message->new(
	 rpc        => $method,
	 who        => 'me',
	 deadline   => 10,
	 message_id => 1,
	 args => {data => {test => 'HI'}},

 );

 my $stream_name = stream_name_from_service($service, $method);


 my $request2 = Myriad::RPC::Message->new(
	 rpc        => $method2,
	 who        => 'me',
	 deadline   => 10,
	 message_id => 1,
	 args => {data => {test => 'HI'}},

 );

 my $stream_name2 = stream_name_from_service($service2, $method2);

 my $count = 0;

 my $timer = IO::Async::Timer::Periodic->new(
   interval => 1,

   on_tick => sub {
      print "You've 5 seconds\n";
       $redis->xadd($stream_name => '*', $request->as_hash->%*)->get if $count % 2 == 0;
 $redis->xadd($stream_name2 => '*', $request2->as_hash->%*)->get unless $count % 2 == 0;
 $count++;
   },
);
$loop->add( $timer );
$timer->start;

 $sink->source->each(sub { my $s = shift; warn "TEST SINK 1 " . $s; $rpc->drop($stream_name, $s->{id})->get; })->completed;
 $sink2->source->each(sub { my $s = shift; warn "TEST SINK 2 " . $s; })->completed;

 $rpc->start->get;

 #Future->wait_any($rpc->start, $ryu->source->each(sub {warn "FFFFFFFFF " . $_;}));

 $redis->publish('test', 'hi')->get;


 pass "passing";

};
done_testing;


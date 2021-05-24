use strict;
use warnings;

use Test::More;

use IO::Async::Loop;
use Myriad::Redis::Pending;
use Myriad::RPC;
use Myriad::Transport::Redis;
use Myriad::RPC::Implementation::Redis qw(stream_name_from_service);
use IO::Async::Timer::Periodic;

use Ryu::Async;
use Time::Moment;

plan skip_all => 'set TESTING_REDIS_URI env var to test' unless exists $ENV{TESTING_REDIS_URI};

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

subtest 'redis multi xgroupread wait time' => sub {
    my $loop = IO::Async::Loop->new;
    my $redis = Myriad::Transport::Redis->new(
         redis_uri              => $ENV{TESTING_REDIS_URI},
         cluster                =>  0,
         client_side_cache_size =>  0,
    );
    $loop->add($redis);
    $redis->start->get;

    my $ryu = Ryu::Async->new;
    $loop->add($ryu);

    my $rpc = Myriad::RPC::Implementation::Redis->new(redis => $redis);
    $loop->add($rpc);

    my @params;

    for my $c (1..2) {
        print "Adding RPC $c\n";
        my %param = (sink => $ryu->sink(label => "Testing:channel$c"), method => "test_method_$c", service => "testing_service_$c");
        $rpc->create_from_sink(%param);

        $param{stream_name} = stream_name_from_service($param{service}, $param{method});

        $param{sink}->source->each(sub {
            my $e = shift;
            my $msg = $e->as_hash;
            my $now = Time::Moment->now;

            is Myriad::RPC::Message::is_valid($msg), '', 'Getting a valid message';

            Myriad::RPC::Message::apply_decoding($msg, 'utf8');
            is $now->epoch - $msg->{args}{data}{current_time} , 0, 'Got request same time it was sent';

            $rpc->drop($param{stream_name}, $e->message_id)->get;
        })->completed;
        
        push @params, \%param;
    }


    # continuously request one of the confiugred RPCs
    my $timer = IO::Async::Timer::Periodic->new(
        interval => 1,
        on_tick => sub {
            my $param = pop @params;
            print "Requesting only one method: $param->{method}\n";

            my $now = Time::Moment->now;
            my $request = Myriad::RPC::Message->new(
                rpc        => $param->{method},
                who        => 'me',
                deadline   => 10,
                message_id => 1,
                args => {data => {test => 'HI', current_time => $now->epoch }},
            );

            $redis->xadd($param->{stream_name} => '*', $request->as_hash->%*)->get;

            # keep it at the end so we pick the same one on next pop
            push @params, $param;
        },
    );

    $loop->add( $timer );
    $timer->start;


    # Stop running after 16 seconds as redis blocking limit is 15 seconds.
    Future->wait_any($rpc->start, $loop->delay_future(after => 16))->get;
};

done_testing;


use strict;
use warnings;


use IO::Async::Loop;
use Future::AsyncAwait;
use Myriad;

use Test::More;
plan skip_all => 'set TESTING_REDIS_URI env var to test' unless exists $ENV{TESTING_REDIS_URI};

my $loop = IO::Async::Loop->new;
my $calls_count = 0;
my $run_future = $loop->new_future(label => 'test_run');

{
    package Test::Service::TwoRPC;

    use Myriad::Service;

    async method rpc_test1 : RPC (%args) {
        return { called => 'rpc_test1' } ;
    }
    async method rpc_test2 : RPC (%args) {
        return { called => 'rpc_test2' } ;
    }
}


{
    package Test::Service::Caller;

    use Myriad::Service;
    use IO::Async::Timer::Periodic;
    use Time::Moment;
    use Test::More;

    async method startup () {
        await $self->keep_calling_timer();
    }

    async method keep_calling_timer() {
        my $timer = IO::Async::Timer::Periodic->new(
            interval => 1,
            on_tick  => sub {
                $log->info('Calling Test::Service::TwoRPC::rpc_test1');
                my $remote_service = $api->service_by_name('test.service.tworpc');

                my $time = Time::Moment->now;
                my $r = $remote_service->call_rpc('rpc_test1')->get; 
                my $wait_time = $time->delta_seconds(Time::Moment->now);

                is $r->{response}{called}, 'rpc_test1', 'Got the right response';
                cmp_ok $wait_time, '<=', 1, 'Took us one second or less to get response.';

                $calls_count++;
                # Run it for four times.
                $run_future->done('finished') if $calls_count == 4;
            },
        );
        $self->add_child($timer);
        $timer->start;
    }

}


my $myriad = Myriad->new;

my @arg = ("--transport_redis", $ENV{TESTING_REDIS_URI}, "Test::Service::TwoRPC,Test::Service::Caller");
await $myriad->configure_from_argv(@arg);
await Future->wait_any($myriad->run, $run_future);
#await $myriad->run;


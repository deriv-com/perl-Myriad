use strict;
use warnings;

use Test::More;

use Future;
use Future::AsyncAwait;
use Future::Utils qw(fmap);

use Myriad;

package Service::RPC {
    use Myriad::Service;

    async method echo : RPC (%args) {
        return \%args;
    }

    async method ping : RPC (%args) {
        return {time => time}
    }

    async method reverse : RPC (%args) {
        return {reverse => 'esrever'};
    }
};


subtest 'RPCs should not block each others in the same service'  => sub {
    (async sub {
        my $myriad = new_ok('Myriad');

        await $myriad->configure_from_argv('--transport', $ENV{MYRIAD_TRANSPORT} // 'memory', '--transport_cluster', $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0);
        await $myriad->add_service('Service::RPC');

        # Run the service
        $myriad->run->retain->on_fail(sub {
            die shift;
        });
        await $myriad->loop->delay_future(after => 0.25);
        my $start_time = time;

        # if one RPC doesn't have messages it should not block the others
        for my $i (0..10) {
            await (fmap {
                my $rpc = shift;
                $myriad->rpc_client->call_rpc('service.rpc', $rpc)->catch(sub {warn shift});
            } foreach => ['echo', 'ping'], concurrent => 3);
        }
        my $done_time = time;

        is($done_time - $start_time <= 1, 1, 'RPCs are not blocking each others');
    })->()->get();
};

subtest 'RPCs should not block each others in different services, same Myriad instance'  => sub {
    (async sub {

        package Another::RPC {
            use Myriad::Service;

            async method zero : RPC (%args) {
                return 0;
            }

            async method five : RPC (%args) {
                return 5;
            }

            async method twenty_five : RPC (%args) {
                return 25;
            }
        };

        my $myriad = new_ok('Myriad');

        await $myriad->configure_from_argv('--transport', $ENV{MYRIAD_TRANSPORT} // 'memory', '--transport_cluster', $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0);
        await $myriad->add_service('Service::RPC');
        await $myriad->add_service('Another::RPC');

        # Run the service
        $myriad->run->retain->on_fail(sub {
            die shift;
        });
        await $myriad->loop->delay_future(after => 0.25);

        my $start_time = time;
        # if one service's RPC doesn't have messages it should not block the others

        for my $i (0..10) {
            await (fmap {
                my ($service, $rpc) = shift->%*;
                $myriad->rpc_client->call_rpc($service, $rpc);
            } foreach => [
                {'service.rpc' => 'echo'}, {'service.rpc' => 'ping'},
                {'another.rpc' => 'zero'}, {'another.rpc' => 'five'},
            ], concurrent => 6);
        }
        my $done_time = time;

        is($done_time - $start_time <= 1, 1, 'RPCs are not blocking each others');
    })->()->get();
};

done_testing();

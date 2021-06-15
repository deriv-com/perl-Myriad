use strict;
use warnings;

use Test::More;

use Future;
use Future::AsyncAwait;
use Future::Utils qw(fmap_void);

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
        return {reversed => scalar reverse("$args{v}")};
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
            await fmap_void(async sub {
                my $rpc = shift;
                my $response = await Future->needs_any(
                    $myriad->rpc_client->call_rpc('service.rpc', $rpc)->catch(sub {warn shift}),
                    # There is a timeout in place inside call_rpc, there is no need for this in real implementation.
                    $myriad->loop->timeout_future(after => 1)
                );
                if ( $rpc eq 'ping' ) {
                    cmp_ok $response->{response}{time}, '==', time, 'Ping Matching Time';
                } elsif ( $rpc eq 'echo' ) {
                    like $response->{response}, qr//, 'Got echo response';
                }
            }, foreach => ['echo', 'ping'], concurrent => 3);
        }
        my $done_time = time;

        cmp_ok $done_time - $start_time, '<=', 1, 'RPCs are not blocking each others';
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

            async method double : RPC (%args) {
                return $args{v} * 2;
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
            await fmap_void(async sub {
                my ($service, $rpc, $args, $res) = shift->@*;
                my $response = await Future->needs_any(
                    $myriad->rpc_client->call_rpc($service, $rpc, %$args),
                    $myriad->loop->timeout_future(after => 1)
                );
                is_deeply $response, $res, "Matching response $service:$rpc";
            }, foreach => [
                ['service.rpc' => 'echo'   , { hi => 'echo' }    , { response => { hi => 'echo' } } ],
                ['service.rpc' => 'reverse', { v => 'reverseme' }, { response => { reversed => 'emesrever' } } ],
                ['another.rpc' => 'double' , { v => 4 }          , { response => 8 } ],
                ['another.rpc' => 'five'   , {}                  , { response => 5 } ],
            ], concurrent => 6);
            # Calling ping RPC here where it return time is inefficient as we might go to the next second.
        }
        my $done_time = time;

        # This will cause it to fail sometimes, as it may need more than 1 second to finish.
        # so to be more realistic, make it no more than 2
        cmp_ok $done_time - $start_time, '<=', 2, 'RPCs are not blocking each others';
    })->()->get();
};

done_testing();

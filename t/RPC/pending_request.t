use strict;
use warnings;

use Test::More;
use Test::MockModule;

use Future;
use Future::AsyncAwait;
use Future::Utils qw(fmap_void);
use IO::Async::Loop;


use Myriad;

package Service::RPC {
    use Myriad::Service;
    # seems that it cuase some race-condition
    # Startup tasks failed - Can't call method "get" on an undefined value at /usr/local/lib/perl5/site_perl/5.26.3/Myriad/Transport/Redis.pm line 600
    #config 'fail_rpc', default => 1;
    
    # Another thing would be that incrementing/counting
    # number of processed RPC calls by setting a slot like this
    # won't work (usnig build, or setting it as instance
    has $count = 0;
    BUILD (%args) {
        $count =  0;
    }

    async method startup () {
        # Zero our counter on startup
        await $api->storage->set('count', 0);
    }

    async method controlled_rpc : RPC (%args) {
        #my $flag = $api->config('fail_rpc_1')->as_string;
        my $flag = defined $ENV{'fail_rpc_1'} ? $ENV{'fail_rpc_1'} : 1;

        # Mimick a failure, only when flag is set;
        die if $flag eq '1';

        # This is used to overcome, the incorrect increment
        # mentione above
        my $count = await $api->storage->get('count');
        ++$count;
        await $api->storage->set('count', $count);
        
        $args{internal_count} = $count;
        $log->tracef('DOING %s', \%args);
        return \%args;
    }
};

package Service::Caller {
    use Myriad::Service;
    has $count_req = 0;
    has $count_res = 0;

    async method keep_calling : Batch () {
        my $service = $api->service_by_name('service.rpc');
        $count_req++;
        $log->tracef('Calling %s', $count_req);
        my $res = await $service->call_rpc('controlled_rpc', timeout => 4, count => $count_req);
        $count_res = $res->{internal_count};
        return [ { res => $res } ];
    }

    async method current_count : RPC (%args) {
        return { count_req => $count_req, count_res => $count_res };
    }
};


subtest 'RPCs on start should check and process pending messages on start'  => sub {
    (async sub {
        my $loop = IO::Async::Loop->new;
        my $f_rpc_m = new_ok('Myriad');  # Failing RPC Service Myriad.
        my $caller_m = new_ok('Myriad'); # Calling Service Myriad.
        my $p_rpc_m = new_ok('Myriad');  # Passing RPC Service Myriad.
        my @main_args = ('--transport', $ENV{MYRIAD_TRANSPORT} // 'memory', '--transport_cluster', $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0);
        # Need to Mock, in fact this is reassuring as this case only happens in dire situation.
        # i.e when service is forcefully stopped or got intruppted halfway through a request.
        my $redis_module = Test::MockModule->new('Myriad::RPC::Implementation::Redis');
        my $drop_is_called = [];
        $redis_module->mock('reply_error', async sub {
            my ($self, $service, $message, $error) = @_;
            push @$drop_is_called, { service => $service, error => $error, message => $message };
        });
        # Run the services
        # Failing RPC service
        await $f_rpc_m->configure_from_argv(@main_args, 'Service::RPC');
        $f_rpc_m->run->retain->on_fail(sub {
            die shift;
        });

        # Caller service
        await $caller_m->configure_from_argv(@main_args, 'Service::Caller');
        $caller_m->run->retain->on_fail(sub {
            die shift;
        });

        # Let the first call happen.
        await $loop->delay_future(after => 0.2);
        my $response = await $caller_m->rpc_client->call_rpc('service.caller', 'current_count')->catch(sub {warn shift});
        note time . " | RES: " . $response->{count_res} . " | REQ: " . $response->{count_req};
        is $response->{count_req}, 1, 'We only sent one request';
        is $response->{count_res} + 1, $response->{count_req}, 'We yet to  get a response for it.';
        
        note 'Shutting down Failing RPC Service and Starting a new one with a passing RPC (mimicking restart)';
        await $f_rpc_m->shutdown;
        $ENV{'fail_rpc_1'} = 0;
        await $p_rpc_m->configure_from_argv(@main_args, 'Service::RPC');
        $p_rpc_m->run->retain->on_fail(sub {
            die shift;
        });

        
        await $loop->delay_future(after => 0.5);
        $response = await $caller_m->rpc_client->call_rpc('service.caller', 'current_count')->catch(sub {warn shift});
        note time . " | RES2: " . $response->{count_res} . " | REQ: " . $response->{count_req};
        cmp_ok $response->{count_req}, '>', 1, "We sent more requests $response->{count_req}";
        is $response->{count_res}, $response->{count_req}, 'We got responses for all of our requests and nothing timedout';
        await $caller_m->shutdown;
        await $p_rpc_m->shutdown;
        $loop->stop;
=c
=d
            $loop->delay_future(after => 2)->then(async sub {
                my $response = await $caller_m->rpc_client->call_rpc('service.caller', 'current_count')->catch(sub {warn shift});
                note time . " | RES: " . $response->{count_res} . " | REQ: " . $response->{count_req};
                # should be zero as all are timedout
                note 'turning off';
                $f_rpc_m->shutdown->await;
                await $p_rpc_m->configure_from_argv(@main_args, '--services.test.service.tworpc.configs.fail_rpc_1','0', 'Service::RPC');
                $p_rpc_m->run->retain->on_fail(sub {
                    die shift;
                });
=c
                $f_rpc_m->configure_from_argv(@main_args, '--services.test.service.tworpc.configs.fail_rpc_1', '0', 'Service::RPC')->then(async sub {
                    $f_rpc_m->run;
                });
                note "re-ran with passing option";
            }),
        #await $myriad->configure_from_argv('--transport', $ENV{MYRIAD_TRANSPORT} // 'memory', '--transport_cluster', $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0, 'Service::RPC,Service::Caller');

        # Run the service
        $myriad->run->retain->on_fail(sub {
            die shift;
        });
        await $myriad->loop->delay_future(after => 0.25);

        # if one RPC doesn't have messages it should not block the others
        while ( 1 ) {
            await Future->wait_any(
                fmap_void(async sub {
                    my $rpc = shift;
                    my $response = await $myriad->rpc_client->call_rpc('service.caller', $rpc)->catch(sub {warn shift});
                    note "RES: " . $response->{count};
                }, foreach => ['current_count'], concurrent => 3),
                $myriad->loop->timeout_future(after => 4)
            );
        }
=cut
    })->()->get();
};


done_testing();

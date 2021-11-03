use strict;
use warnings;

use Test::More;
use Test::MockModule;

use Future;
use Future::AsyncAwait;
use Future::Utils qw(fmap_void);
use IO::Async::Loop;
use Myriad::Transport::Memory;
use Myriad::Storage::Implementation::Memory;

use Myriad;

package Service::Test {
    use Myriad::Service;
}

package Service::RPC {
    use Myriad::Service;
    # Another thing would be that incrementing/counting
    # number of processed RPC calls by setting a slot like this
    # won't work (usnig build, or setting it as instance
    has $count;
    has $key = 'count';
    BUILD {
        $count =  0;
    }

    async method startup () {
        # Zero our counter on startup
        my $c = await $api->storage->get($key);
        unless ( defined $c && $c < 2 ) {
            await $api->storage->set($key, $count);
        }
    }

    async method controlled_rpc : RPC (%args) {
        my $flag = defined $ENV{'fail_rpc_1'} ? $ENV{'fail_rpc_1'} : 1;

        # Mimick a failure, only when flag is set;
        die if $flag eq '1';

        # This is used to overcome, the incorrect increment
        # mentione above
        my $count = await $api->storage->get($key);
        ++$count;
        await $api->storage->set($key, $count);
        
        $args{internal_count} = $count;
        $log->tracef('DOING %s', \%args);
        return \%args;
    }
};

my $loop = IO::Async::Loop->new;
# Only used for in memory tests
my $transport = Myriad::Transport::Memory->new;
my $storage =  Myriad::Storage::Implementation::Memory->new();

my $added = 0;
async sub myriad_instance {
    my $service = shift // '';

    my $myriad = new_ok('Myriad');

    # Only in case of memory transport, we want to share the same transport instance.
    if (!$ENV{MYRIAD_TRANSPORT} || $ENV{MYRIAD_TRANSPORT} eq 'memory' ) {
        unless ($added) {
            $loop->add($transport);
            $loop->add($storage);
            $added = 1;
        }
        my $metaclass = Object::Pad::MOP::Class->for_class('Myriad');
        $metaclass->get_slot('$memory_transport')->value($myriad) = $transport;
        $metaclass->get_slot('$storage')->value($myriad) = $storage;
    }

    my @config = ('--transport', $ENV{MYRIAD_TRANSPORT} // 'memory', '--transport_cluster', $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0, '-l', 'debug');
    await $myriad->configure_from_argv(@config, $service);
    $myriad->run->retain->on_fail(sub { die shift; });

    return $myriad;

}

subtest 'RPCs on start should check and process pending messages on start'  => sub {
    (async sub {

        # Need to Mock, in fact this is reassuring as this case only happens in dire situation.
        # i.e when service is forcefully stopped or got intruppted halfway through a request.
        my $transport_module = (!$ENV{MYRIAD_TRANSPORT} || $ENV{MYRIAD_TRANSPORT} eq 'memory') ? Test::MockModule->new('Myriad::RPC::Implementation::Memory') : Test::MockModule->new('Myriad::RPC::Implementation::Redis');
        my $drop_is_called = [];
        $transport_module->mock('reply_error', async sub {
            my ($self, $service, $message, $error) = @_;
            push @$drop_is_called, { service => $service, error => $error, message => $message };
        });

        $ENV{'fail_rpc_1'} = 1;
        
        my $rpc_myriad = await myriad_instance('Service::RPC');
        my $myriad = await myriad_instance('Service::Test');

        # Do not fully wait for it right now.
        my $req = $myriad->rpc_client->call_rpc('service.rpc', 'controlled_rpc', fail => 1);
        await $loop->delay_future(after => 0.1);

        await $rpc_myriad->shutdown;
        undef $rpc_myriad;
        $ENV{'fail_rpc_1'} = 0;
        #await $loop->delay_future(after => 0.2);
        $rpc_myriad = await myriad_instance('Service::RPC');
        
        # check request now
        my $first_req = await $req;
        my $second_req = await $rpc_myriad->rpc_client->call_rpc('service.rpc', 'controlled_rpc', fail => 0);
        
        is scalar @$drop_is_called, 1, 'Drop is only called once';
        is_deeply $first_req, {fail => 1, internal_count => 1}, 'Correct first request response'; 
        is_deeply $second_req, {fail => 0, internal_count => 2}, 'Correct second request response'; 

        # This is needed to ensure complete operation after publishing response.
        my $finish = $loop->delay_future(after => 0.1)->on_done(sub {$rpc_myriad->shutdown->get; $myriad->shutdown->get;});
        await Future->needs_all($finish, $rpc_myriad->shutdown_future, $myriad->shutdown_future);


    })->()->get();
};


done_testing();

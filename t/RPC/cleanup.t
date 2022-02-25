use strict;
use warnings;

use Test::More;
use Test::MockModule;

use Future;
use Future::AsyncAwait;
use Future::Utils qw(fmap_void);
use IO::Async::Loop;
use Myriad::Transport::Memory;
use Myriad::Transport::Redis;
use Myriad::RPC::Message;
use Sys::Hostname qw(hostname);
use Test::MockModule;

use Myriad;

my $processed = 0;

package Service::RPC {
    use Myriad::Service;
    has $count;

    async method startup () {
        # Zero our counter on startup
        $count = 0;
    }

    async method test_rpc : RPC (%args) {
        ++$count;

        $args{internal_count} = $count;
        $log->tracef('DOING %s', \%args);
        $processed++;
        return \%args;
    }
};

my $loop = IO::Async::Loop->new;
# Only used for in memory tests
my $transport;
my $rpc_impl = Test::MockModule->new('Myriad::RPC::Implementation::Redis');
async sub myriad_instance {
    my $service = shift // '';

    my $myriad = new_ok('Myriad');

    # Only in case of memory transport, we want to share the same transport instance.
    if (!$ENV{MYRIAD_TRANSPORT} || $ENV{MYRIAD_TRANSPORT} eq 'memory' ) {
        $transport = Myriad::Transport::Memory->new;
        $loop->add($transport);
        my $metaclass = Object::Pad::MOP::Class->for_class('Myriad');
        $metaclass->get_field('$memory_transport')->value($myriad) = $transport;
    } else {
        $rpc_impl->mock('cleanup_delay', sub { return 0.1; });
    }

    my @config = ('--transport', $ENV{MYRIAD_TRANSPORT} // 'memory', '--transport_cluster', $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0, '-l', 'debug');
    await $myriad->configure_from_argv(@config, $service);
    $myriad->run->retain->on_fail(sub { die shift; });

    return $myriad;

}

my $whoami = Myriad::Util::UUID::uuid();
sub generate_requests {
    my ($rpc, $count, $expiry) = @_;
    my $id = 1;
    my @req;
    for (1..$count) {
        push @req, Myriad::RPC::Message->new(
            rpc => $rpc,
            who => $whoami,
            deadline => time + $expiry,
            message_id => $id,
            args => {test => $id++, who => $whoami }
        );
    }
    return @req;
}

subtest 'RPCs to cleanup their streams'  => sub {
    (async sub {

        note "starting service";
        my $rpc_myriad = await myriad_instance('Service::RPC');
        my $transport_instance;
        if (!$ENV{MYRIAD_TRANSPORT} || $ENV{MYRIAD_TRANSPORT} eq 'memory' ) {
            $transport_instance = $transport;
        } else {
            $loop->add( my $redis = Myriad::Transport::Redis->new(
                redis_uri => $ENV{MYRIAD_TRANSPORT},
                cluster => $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0,
            ));
            await $redis->start;
            $transport_instance = $redis;
        }

        my $message_count = 20;
        my @requests = generate_requests('test_rpc', $message_count, 1000);
        my $stream_name = 'service.service.rpc.rpc/test_rpc';
        foreach my $req (@requests) {
            await $transport_instance->xadd($stream_name => '*', $req->as_hash->%*);
        }
        await $loop->delay_future(after => 0.4);

        is $processed, $message_count, 'Have processed all messages';
        my $stream_length = await $transport_instance->stream_length($stream_name);
        is $stream_length, 1, 'Stream has been cleaned up after processing';

        # Test for another cycle
        my $message_count2 = $message_count + 44;
        @requests = generate_requests('test_rpc', $message_count2, 1000);
        foreach my $req (@requests) {
            await $transport_instance->xadd($stream_name => '*', $req->as_hash->%*);
        }
        await $loop->delay_future(after => 0.4);

        is $processed, $message_count + $message_count2, 'Have processed all messages';
        my $stream_length = await $transport_instance->stream_length($stream_name);
        is $stream_length, 1, 'Stream has been cleaned up after processing';

    })->()->get();
};

done_testing();

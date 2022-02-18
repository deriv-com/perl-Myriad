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
        $log->warnf('DOING %s', \%args);
        $processed++;
        return \%args;
    }
};

my $loop = IO::Async::Loop->new;
# Only used for in memory tests
my $transport;
async sub myriad_instance {
    my $service = shift // '';

    my $myriad = new_ok('Myriad');

    # Only in case of memory transport, we want to share the same transport instance.
    if (!$ENV{MYRIAD_TRANSPORT} || $ENV{MYRIAD_TRANSPORT} eq 'memory' ) {
        my $metaclass = Object::Pad::MOP::Class->for_class('Myriad');
        $metaclass->get_field('$memory_transport')->value($myriad) = $transport;
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

subtest 'RPCs on start should check and process pending messages on start'  => sub {
    (async sub {

        note "starting service";
        my $rpc_myriad = await myriad_instance('Service::RPC');

        my $message_count = 20;
        my @requests = generate_requests('test_rpc', $message_count, 1000);
        my $stream_name = 'service.service.rpc.rpc/test_rpc';

        # Add messages to stream then read them without acknowleging to make them go into pending state
        if (!$ENV{MYRIAD_TRANSPORT} || $ENV{MYRIAD_TRANSPORT} eq 'memory' ) {
            $transport = Myriad::Transport::Memory->new;
            $loop->add($transport);
            foreach my $req (@requests) {
                await $transport->add_to_stream($stream_name, $req->as_hash->%*);
            }
            await $loop->delay_future(after => 0.4);
            is $processed, $message_count, 'Have processed all messages';

            my $stream_length = $transport->stream_length($stream_name);
            is $stream_length, 0, 'Stream has been cleaned up after processing';
        } else {
            $loop->add( my $redis = Myriad::Transport::Redis->new(
                redis_uri => $ENV{MYRIAD_TRANSPORT},
                cluster => $ENV{MYRIAD_TRANSPORT_CLUSTER} // 0,
            ));
            await $redis->start;
            foreach my $req (@requests) {
                await $redis->xadd($stream_name => '*', $req->as_hash->%*);
            }
            await $loop->delay_future(after => 0.4);
            is $processed, $message_count, 'Have processed all messages';
            my $stream_length = await $redis->stream_length($stream_name);
            is $stream_length, 0, 'Stream has been cleaned up after processing';
        }

    })->()->get();
};


done_testing();

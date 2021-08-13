use strict;
use warnings;

use Future::AsyncAwait;
use Test::More;
use Log::Any::Adapter qw(TAP);
use Myriad;

package Example::Sender {
    use Myriad::Service;

    async method fast_e : Emitter() ($sink) {
        my $count = 1;
        while (1) {
            await $self->loop->delay_future(after => 0.2);
            $sink->emit({event => $count++});
        }
    }

    async method med_e : Emitter() ($sink) {
        my $count = 1;
        while (1) {
            await $self->loop->delay_future(after => 0.5);
            $sink->emit({event => $count++});
        }
    }
    
    async method slow_e : Emitter() ($sink) {
        my $count = 1;
        while (1) {
            await $self->loop->delay_future(after => 1);
            $sink->emit({event => $count++});
        }
    }
    
    async method fast_e2 : Emitter() ($sink) {
        my $count = 1;
        while (1) {
            await $self->loop->delay_future(after => 0.2);
            $sink->emit({event => $count++});
        }
    }
}

my %received;

package Example::Receiver {
    use Myriad::Service;
    async method receiver_from_emitter : Receiver(
        service => 'Example::Sender',
        channel => 'fast_e'
    ) ($src) {
        return $src->map(sub {
            push @{$received{fast_e}}, shift
        });
    }
    
    async method receiver_from_emitter2 : Receiver(
        service => 'Example::Sender',
        channel => 'med_e'
    ) ($src) {
        return $src->map(sub {
            push @{$received{med_e}}, shift
        });
    }

    async method receiver_from_emitter3 : Receiver(
        service => 'Example::Sender',
        channel => 'slow_e'
    ) ($src) {
        return $src->map(sub {
            push @{$received{slow_e}}, shift
        });
    }

    async method receiver_from_emitter4 : Receiver(
        service => 'Example::Sender',
        channel => 'fast_e2'
    ) ($src) {
        return $src->map(sub {
            push @{$received{fast_e2}}, shift
        });
    }
}

my $myriad = new_ok('Myriad');
await $myriad->configure_from_argv(
    qw(--transport redis://redis-node-0:6379 --transport_cluster 1 --log_level warn service)
    #qw(--transport memory --log_level warn service)
);

await $myriad->add_service('Example::Receiver');
await $myriad->add_service('Example::Sender');

$myriad->run->retain;

ok($myriad->subscription, 'subscription is initiated');

my $loop = IO::Async::Loop->new;
await $loop->delay_future(after => 1.1);

use Data::Dumper;
note Dumper(\%received);
is scalar $received{fast_e}->@*, 5, 'Got the right number of events from fast_emitter';
is scalar $received{med_e}->@*, 2, 'Got the right number of events from medium_emitter';
is scalar $received{slow_e}->@*, 1, 'Got the right number of events from slow_emitter';
is scalar $received{fast_e2}->@*, 5, 'Got the right number of events from fast_emitter2';


done_testing;


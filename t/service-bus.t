use Myriad::Class;

use Test::More;
use Test::Deep qw(bag cmp_deeply);
use Test::Fatal;
use Test::Myriad;
use Log::Any::Adapter qw(TAP);

use Future;
use Future::AsyncAwait;
use Object::Pad;

package Test::Sender {
    use Myriad::Service;

    field $bus;

    async method startup {
        $log->debugf('Startup first');
        $bus = $api->service_by_name('test.receiver')->bus;
        $log->debugf('Startup complete');
    }

    async method send:RPC (%args) {
        $log->debugf('Calling send with %s', \%args);
        try {
            $log->debugf('Send to remote bus');
            $bus->events->emit($args{data});
            return;
        } catch ($e) {
            $log->errorf('Failed to send - %s', $e);
        }
    }
}

package Test::Receiver {
   use Myriad::Service;

   field $events = [ ];

   async method startup {
       $api->bus->events->each(sub ($ev) {
           $log->debugf('Have event: %s', $ev);
           push $events->@*, $ev;
       });
   }
   async method events:RPC {
       return $events;
   }
}
my $sender;
my $receiver;

BEGIN {
    $receiver = Test::Myriad->add_service(service => 'Test::Receiver');
    $sender = Test::Myriad->add_service(service => 'Test::Sender');
}

try {
    await Test::Myriad->ready();
    note 'call RPC';
    await $sender->call_rpc('send', data => 'test data');
    note 'check results';
    my $srv = $Myriad::REGISTRY->service_by_name('test.receiver');
    my $ev = await $srv->events;
    note explain $ev;
    cmp_deeply($ev, bag('test data'), 'have events after sending');
} catch ($e) {
    note explain $e;
    die $e;
}
done_testing;


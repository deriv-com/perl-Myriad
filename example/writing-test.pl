use strict;
use warnings;

use Future::AsyncAwait;

use Test::More;
use Test::Myriad qw(add_service);

my ($mocked_service, $developer_service);

package Test::Service::Real {
    use Myriad::Service;
    use Test::More;

    async method get_event : Receiver(service => 'Test::Service::Mocked', channel => 'weekends') ($source) {
        await $source->each(sub {
            my $event = shift;
            like($event->{name}, qr{Saturday|Sunday},'We are getting data correctly');
        })->completed();
    }
}

BEGIN {
    $mocked_service = Test::Myriad->add_service(name => "Test::Service::Mocked")
                        ->add_rpc('say_hi', hello => 'other service!')
                        ->add_subscription('weekends', array => [{ name => 'Saturday' }, {name => 'Sunday' }]);

    $developer_service = Test::Myriad->add_service(service => 'Test::Service::Real');
}


subtest 'it should respond to RPC' => sub {
    (async sub {
        my $response = await $mocked_service->call_rpc('say_hi');
        ok($response->{response}->{hello}, 'rpc message has been received');
    })->()->get();
}; 

done_testing();


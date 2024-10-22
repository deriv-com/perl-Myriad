use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Fatal;
use Test::Myriad;
use Log::Any::Adapter qw(TAP);

use Future;
use Future::AsyncAwait;
use Object::Pad;

my ($ping_service, $pong_service);

package Test::Ping {
    use Myriad::Service;
    async method ping : RPC (%args) {
        return await $api->service_by_name('Test::Pong')->call_rpc('pong');
    }
    async method throws_error : RPC (%args) {
        die 'some error here';
    }
}

package Test::Pong {
   use Myriad::Service;
   async method pong : RPC (%args) {
        return {pong => 1};
   }
}

BEGIN {
   $ping_service = Test::Myriad->add_service(service => 'Test::Ping');
   $pong_service = Test::Myriad->add_service(service => 'Test::Pong');
}


await Test::Myriad->ready();

subtest 'RPC should return a response to caller' => sub {
    my $response = $pong_service->call_rpc('pong')->get;
    cmp_deeply($response, {pong => 1});
    done_testing;
};

subtest 'RPC client should receive a response' => sub {
    my $response = $ping_service->call_rpc('ping')->get();
    cmp_deeply($response, {pong => 1});
    done_testing;
};

subtest 'Methods which throw errors should raise an exception in the caller too' => sub {
    my $ex = exception {
        my $response = $ping_service->call_rpc('throws_error')->get();
        note explain $response;
    };
    isa_ok($ex, 'Myriad::Exception::InternalError');
    like($ex->reason->{reason}, qr/some error here/, 'exception had original message');
    done_testing;
};

done_testing;


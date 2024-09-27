use strict;
use warnings;

use Test::More;
use Test::Deep;
use Test::Fatal;
use Test::Myriad;

use Future;
use Future::AsyncAwait;
use Object::Pad qw(:experimental);
use Myriad::Exception::InternalError;

my ($broken_services);

# Example of some broken behavior that implementations can have
package Test::BrokenServices {
    use Myriad::Service;
    async method normal : RPC (%args) {
        return {pong => 1};
    }
    async method normal_dead : RPC (%args) {
        die "I am died";
    }
    async method hash_dead : RPC (%args) {
        die {reason => "I am died"};
    }
    async method blessed_dead : RPC (%args) {
        die bless {reason => "I am died"}, "Test::Exceptions";
    }
    async method bubbled_dead : RPC (%args) {
        # Fake it as something is wrong with Myriad itself
        Myriad::Exception::InternalError->throw();
    }
}

BEGIN {
    $broken_services = Test::Myriad->add_service(service => 'Test::BrokenServices');
}


await Test::Myriad->ready();

subtest 'Normal RPC calls must succeeded as usual' => sub {
    my $resposne = $broken_services->call_rpc('normal')->get;
    cmp_deeply($resposne, {pong => 1});
};

subtest 'Dead RPC calls must have its exceptions bubbled up to caller' => sub {
    my $failure = exception {
        $broken_services->call_rpc('normal_dead')->get;
    };
    is(ref $failure, "Myriad::Exception::RPC::RemoteException", "Correct error received by caller");
    like($failure->reason, qr/reason=I am died/, "Correct error message");
};

subtest 'HASHREFs must not cross RPC boundary!' => sub {
    my $failure = exception {
        $broken_services->call_rpc('hash_dead')->get;
    };
    is(ref $failure, "Myriad::Exception::RPC::RemoteException", "Correct error received by caller");
    like($failure->reason, qr/reason=HASH\(0x[a-zA-Z0-9]+\)/, "Correct error message");
};

subtest 'blessed HASHREFs must not cross RPC boundary!' => sub {
    my $failure = exception {
        $broken_services->call_rpc('blessed_dead')->get;
    };
    is(ref $failure, "Myriad::Exception::RPC::RemoteException", "Correct error received by caller");
    like($failure->reason, qr/reason=Test::Exceptions=HASH\(0x[a-zA-Z0-9]+\)/, "Correct error message");
};

subtest 'Internal Myriad errors on remote must not appear as local Myriad error!' => sub {
    my $failure = exception {
        $broken_services->call_rpc('bubbled_dead')->get;
    };
    is(ref $failure, "Myriad::Exception::RPC::RemoteException", "Correct error received by caller");
    is($failure->reason, 'Remote exception is thrown: Internal error (category=internal)', "Correct error message");
};

done_testing();


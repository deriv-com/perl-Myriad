use strict;
use warnings;

use Test::More;

use IO::Async::Test;
use IO::Async::Loop;

use Future::AsyncAwait;
use Object::Pad;

use Myriad::RPC::Implementation::Perl;

class TestService extends Myriad::Service {
    async method sum : RPC (%args) {
        return { ok => 1, result => $args{x} + $args{y} };
    }
}

my $loop = IO::Async::Loop->new;
testing_loop( $loop );

$loop->add(my $service = new_ok('TestService',
    [rpc => my $rpc = Myriad::RPC::Implementation::Perl->new])
);

my $result = $rpc->call(sum => {x => 12, y => 34})->get;
is_deeply($result, {ok => 1, result => 46}, 'result of RPC call');

done_testing;

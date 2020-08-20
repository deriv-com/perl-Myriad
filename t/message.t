use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Test::MemoryGrowth;

use Storable qw(dclone);
use Myriad::RPC::Message;

my $message_args = {
    rpc        => 'test',
    message_id => 1,
    who        => 'client',
    deadline   => time,
    args       => '{}',
    stash      => '{}',
    trace      => '{}'
};

is(exception {
    Myriad::RPC::Message->new(%$message_args)
}, undef, "->new with correct params should succeed");

for my $key (qw/rpc message_id who deadline args/) {
    like(exception {
        my $args = dclone $message_args;
        delete $args->{$key};
        Myriad::RPC::Message->new(%$args);
    }, qr/^invalid request/, "->new without $key should not succeed");
}

my $message = Myriad::RPC::Message->new(%$message_args);
is(exception {
    $message->encode
}, undef, '->encode should succeed');

no_growth {
    my $message = Myriad::RPC::Message->new(%$message_args);
    $message->encode;
} 'no memory leak detected';

done_testing;

use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Log::Any::Adapter qw(TAP);

use Myriad::Config;

is(exception {
    Myriad::Config->new
}, undef, '->new without parameters succeeds');

my $cfg = Myriad::Config->new;
is($cfg->key('subscription_transport'), 'redis', 'have the right default transport for subscriptions');
is($cfg->key('storage_transport'), 'redis', 'have the right default transport for storage');
is($cfg->key('rpc_transport'), 'redis', 'have the right default transport for RPC');
done_testing;


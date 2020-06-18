use strict;
use warnings;

BEGIN {
    # Enforce deferred operation for in-process Perl module
    $ENV{MYRIAD_RANDOM_DELAY} = 0.001;
}
use Future;
use Future::AsyncAwait;
use Test::More;
use Test::MemoryGrowth;
use Test::Metrics::Any;
use Myriad::Storage::Perl;

use IO::Async::Test;
use IO::Async::Loop;

my $loop = IO::Async::Loop->new;
testing_loop( $loop );

for my $class (qw(Myriad::Storage::Perl)) {
    subtest $class => sub {
        $loop->add(
            my $storage = new_ok($class)
        );
        is_metrics_from sub {
            (async sub {
                await $storage->set(some_key => 'value');
                is(await $storage->get('some_key'), 'value', 'can read our value back');
                await $storage->hash_set(some_hash => key => 'hash value');
                is(await $storage->hash_get('some_hash', 'key'), 'hash value', 'can read our hash value back');
                is(await $storage->hash_add('some_hash', 'numeric', 3), 3, 'can increment a hash value');
                is(await $storage->hash_add('some_hash', 'numeric', 2), 5, 'can increment a hash value again');
                is(await $storage->hash_get('some_hash', 'key'), 'hash value', 'can read our original hash value back');
            })->()->get; },
            {
                "myriad_storage_call_elapsed_count method:get status:success" => 1,
                "myriad_storage_call_elapsed_total method:get status:success" => Test::Metrics::Any::positive(),
                "myriad_storage_call_elapsed_count method:set status:success" => 1,
                "myriad_storage_call_elapsed_total method:set status:success" => Test::Metrics::Any::positive(),
                # If those two methods work, we'll just presume the others all
                #   do as they use the same mechanism
            },
            'storage methods reported metrics' or
                diag "Metrics are:\n" . Metrics::Any::Adapter::Test->metrics;

        # Cut-down version of the tests for a few
        # methods, just make sure that we don't go
        # crazy with our memory usage
        note 'Memory test, this may take a while';
        no_growth {
            Future->wait_all(
                $storage->set('some_key', 'some_value'),
                $storage->hash_set('some_hash_key', 'key', 'a hash value'),
            )->get;
            Future->wait_all(
                $storage->get('some_key'),
                $storage->hash_get('some_hash_key', 'key'),
            )->get;
            ()
        } calls => 1_000,
          'ensure basic storage operations do not leak memory';

        done_testing;
    };
}

done_testing;


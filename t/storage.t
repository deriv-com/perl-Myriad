use strict;
use warnings;

use Future::AsyncAwait;
use Test::More;
use Myriad::Storage::Perl;

use IO::Async::Test;
use IO::Async::Loop;
my $loop = IO::Async::Loop->new;
testing_loop( $loop );

$loop->add(
    my $storage = new_ok('Myriad::Storage::Perl')
);
(async sub {
    await $storage->set(some_key => 'value');
    is(await $storage->get('some_key'), 'value', 'can read our value back');
    await $storage->hash_set(some_hash => key => 'hash value');
    is(await $storage->hash_get('some_hash', 'key'), 'hash value', 'can read our hash value back');
    is(await $storage->hash_add('some_hash', 'numeric', 3), 3, 'can increment a hash value');
    is(await $storage->hash_add('some_hash', 'numeric', 2), 5, 'can increment a hash value again');
    is(await $storage->hash_get('some_hash', 'key'), 'hash value', 'can read our original hash value back');
})->()->get;

done_testing;


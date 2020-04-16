package Myriad::Storage;

use strict;
use warnings;

# VERSION

use Future::AsyncAwait;
use Object::Pad;

class Myriad::Storage;

use experimental qw(signatures);

=encoding utf8

=head1 NAME

Myriad::Storage - microservice storage abstraction

=head1 SYNOPSIS

 my $storage = $myriad->storage;
 await $storage->get('some_key');
 await $storage->hash_add('some_key', 'hash_key', 13);

=head1 DESCRIPTION

Provides an abstraction over the Redis-based data model used by L<Myriad> services.

For more information, please see the official L<Redis commands list|https://redis.io/commands>.

=cut

use Role::Tiny;

requires qw(
    get
    set
    observe
    push
    unshift
    pop
    shift
    hash_set
    hash_get
    hash_add
    hash_keys
    hash_values
    hash_exists
    hash_count
    hash_as_list
);

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


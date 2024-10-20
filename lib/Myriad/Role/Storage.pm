package Myriad::Role::Storage;

use Myriad::Class type => 'role';

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Role::Storage - microservice storage abstraction

=head1 SYNOPSIS

 my $storage = $myriad->storage;
 await $storage->get('some_key');
 await $storage->hash_add('some_key', 'hash_key', 13);

=head1 DESCRIPTION

Provides an abstraction over the Redis-based data model used by L<Myriad> services.

For more information on the API design, please see the official
L<Redis commands list|https://redis.io/commands>. This model was
used as the basis for the methods even when non-Redis backend
storage systems are used.

=head1 Implementation

Note that this is defined as a rôle, so it does not provide
a concrete implementation - instead, see classes such as:

=over 4

=item * L<Myriad::Storage::Implementation::Redis>

=item * L<Myriad::Storage::Implementation::Memory>

=back

=cut

=head1 METHODS - Write

=cut

our @WRITE_METHODS = qw(
    del
    expire
    getdel
    getset
    hash_add
    hash_expire
    hash_remove
    hash_set
    incr
    orderedset_add
    orderedset_remove_byscore
    orderedset_remove_member
    pop
    push
    set
    set_unless_exists
    shift
    unlink
    unorderedset_add
    unorderedset_remove
    unorderedset_replace
    unshift
);

=head2 expire

Apply expiry to a value.

Takes the following parameters:

=over 4

=item * C<< $k >>   - the relative key in storage

=item * C<< $ttl >> - the TTL of a key, Set this to C<undef> to mark it as permanent key.

=back

=cut

method expire;

=head2 hash_expire

Apply expiry to a value in a hash.

Takes the following parameters:

=over 4

=item * C<< $k >>   - the relative key in storage

=item * C<< $hash_key >>   - the hash key

=item * C<< $ttl >> - the TTL to apply, set this to C<undef> to mark it as permanent key.

=back

=cut

method hash_expire;

=head2 set

Takes the following parameters:

=over 4

=item * C<< $k >>   - the relative key in storage

=item * C<< $v >>   - the scalar value to set

=item * C<< $ttl >> - the TTL of a key, Set this to C<undef> to mark it as permanent key.

=back

Note that references are currently B<not> supported - attempts to write an arrayref, hashref
or object will fail.

Returns a L<Future> which will resolve on completion.

=cut

method set;

=head2 getset

Performs the same operation as L</set>, but additionally returns the original key value, if any.

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $v >> - the scalar value to set

=back

Note that references are currently B<not> supported - attempts to write an arrayref, hashref
or object will fail.

Returns a L<Future> which will resolve on completion to the original value, or C<undef> if none.

=cut

method getset;

=head2 getdel

Performs the same operation as L</get>, but additionally remove the key from the storage atomically.

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future> which will resolve on completion to the original value, or C<undef> if none.

=cut

method getdel;

=head2 push

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $v >> - the scalar value to set

=back

Returns a L<Future>.

=cut

method push;

=head2 unshift

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future>.

=cut

method unshift;

=head2 pop

Returns a L<Future> which will resolve to the item removed from the list,
or C<undef> if none available.

=cut

method pop;

=head2 shift

Returns a L<Future> which will resolve to the item removed from the list,
or C<undef> if none available.

=cut

method shift;

=head2 hash_remove

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

method hash_remove;

=head2 hash_set

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

method hash_set;

=head2 hash_add

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> indicating success or failure.

=cut

method hash_add;

=head2 orderedset_add

Adds a member to an orderedset structure
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $s >> - the scalar value of the score attached to member

=item * C<< $m >> - the scalar value of member

=back

Returns a L<Future>.

=cut

method orderedset_add;

=head2 orderedset_remove_member

Removes a member from an orderedset structure
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $m >> - the scalar value of member

=back

Returns a L<Future>.

=cut

method orderedset_remove_member;

=head2 orderedset_remove_byscore

Removes members that have scores within the range passed from an orderedset structure
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $min >> - the value of minimum score

=item * C<< $max >> - the value of maximum score

=back

Returns a L<Future>.

=cut

method orderedset_remove_byscore;

=head2 unorderedset_add

Adds members to a set.
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $members >> - an arrayref holding zero or more members to add

=back

Returns a L<Future>.

=cut

method unorderedset_add;

=head2 unorderedset_remove

Removes members from a set.
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $members >> - an arrayref holding zero or more members to remove

=back

Returns a L<Future>.

=cut

method unorderedset_remove;

=head2 unorderedset_replace

Atomically replace all members in a set.
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $members >> - an arrayref holding zero or more members to form the new set

=back

Returns a L<Future>.

=cut

method unorderedset_replace;

method del;
method unlink;
method set_unless_exists;

=head1 METHODS - Read

=cut

our @READ_METHODS = qw(
    get
    observe
    watch_keyspace
    hash_get
    hash_keys
    hash_values
    hash_exists
    hash_count
    hash_as_list
    list_count
    list_range
    orderedset_member_count
    orderedset_members
    unorderedset_is_member
    unorderedset_member_count
    unorderedset_members
    when_key_changed
);

=head2 get

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future> which will resolve to the corresponding value, or C<undef> if none.

=cut

method get;

=head2 observe

Observe a specific key.

Returns a L<Ryu::Observable> which will emit the current and all subsequent values.

=cut

method observe;

=head2 hash_get

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the scalar value for this key.

=cut

method hash_get;

=head2 hash_keys

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the keys in no defined order.

=cut

method hash_keys;

=head2 hash_values

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the values in no defined order.

=cut

method hash_values;

=head2 hash_exists

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to true if the key exists in this hash.

=cut

method hash_exists;

=head2 hash_count

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the count of the keys in this hash.

=cut

method hash_count;

=head2 hash_as_list

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of key/value pairs,
suitable for assigning to a hash.

=cut

method hash_as_list;

=head2 list_count

Takes the following parameters:

=over 4

=item * key

=back

Returns a L<Future> which will resolve to the integer count of values currently in the list.

=cut

method list_count;

=head2 list_range

Takes the following parameters:

=over 4

=item * key

=item * start index (from 0), use negative values to indicate distance from end of list (-1 being the last element)

=item * end index (from 0), as above

=back

Returns a L<Future> which will resolve to a list of values from the list.

=cut

method list_range;

=head2 orderedset_member_count

Returns the count of members that have scores within the range passed from an orderedset structure
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $min >> - the value of minimum score

=item * C<< $max >> - the value of maximum score

=back

Returns a L<Future>.

=cut

method orderedset_member_count;

=head2 orderedset_members

Returns the members that have scores within the range passed from an orderedset structure
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $min >> - the value of minimum score

=item * C<< $max >> - the value of maximum score

=back

Returns a L<Future>.

=cut

method orderedset_members;

=head2 unorderedset_is_member

Returns true if the given key is a member in the set.
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $value >> - the value to check for presence in the set

=back

Returns a L<Future>.

=cut

method unorderedset_is_member;

=head2 unorderedset_member_count

Returns the count of all members.

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future>.

=cut

method unorderedset_member_count;

=head2 unorderedset_members

Returns a list of all members in the set.
Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future>.

=cut

method unorderedset_members;

method when_key_changed;

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


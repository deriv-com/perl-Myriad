use strict;
use warnings;

use Future::AsyncAwait;
use Object::Pad;

class Myriad::Storage::Perl extends Myriad::Notifier;

use experimental qw(signatures);

=encoding utf8

=head1 NAME

Myriad::Storage::Perl - microservice storage abstraction

=head1 SYNOPSIS

=cut

use Attribute::Handlers;
use Class::Method::Modifiers;

sub Defer : ATTR(CODE) {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    my $name = *{$symbol}{NAME} or die 'need a symbol name';
    $log->tracef('will defer handler for %s::%s', $package, $name);
    around join('::', $package, $name) => async sub {
        my ($code, $self, @args) = @_;

        # effectively $loop->later
        await $self->loop->delay_future(after => 0);

        $log->tracef('deferred call to %s::%s', $package, $name);

        return await $self->$code(
            @args
        );
    }
}

=head2 get

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future> which will resolve to the corresponding value, or C<undef> if none.

=cut

async method get : Defer ($k) {
    return $data{$k};
}

=head2 set

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $v >> - the scalar value to set

=back

Note that references are currently B<not> supported - attempts to write an arrayref, hashref
or object will fail.

Returns a L<Future> which will resolve on completion.

=cut

async method set : Defer ($k, $v) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($v) if ref $v;
    return $data{$k} = $v;
}

=head2 observe

Observe a specific key.

Returns a L<Ryu::Source> which will emit the current and all subsequent values.

=cut

method observe ($k) {
    die 'no observation';
}

=head2 push

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $v >> - the scalar value to set

=back

Returns a L<Future> which will resolve to .

=cut

async method push : method ($k, @v) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($_) for grep { ref } @v;
    await $redis_action->rpush($k, @v);
}

=head2 unshift

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method unshift : method ($k, @v) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($_) for grep { ref } @v;
    await $redis_action->lpush($k, @v);
}

=head2 pop

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method pop : method ($k) {
    await $redis_action->rpop($k);
}

=head2 shift

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method shift : method ($k) {
    await $redis_action->lpop($k);
}

=head2 hash_set

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method hash_set ($k, $hash_key, $v) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($v) if ref $v;
    await $redis_action->hset($k, $hash_key, $v);
}

=head2 hash_get

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the scalar value for this key.

=cut

async method hash_get ($k, $hash_key) {
    await $redis_action->hget($k, $hash_key);
}

=head2 hash_add

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> indicating success or failure.

=cut

async method hash_add ($k, $hash_key, $v) {
    $v //= 1;
    die 'value cannot be a reference for ' . $k . ' - ' . ref($v) if ref $v;
}

=head2 hash_keys

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the keys in no defined order.

=cut

async method hash_keys ($k) {
}

=head2 hash_values

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the values in no defined order.

=cut

async method hash_values ($k) {
}

=head2 hash_exists

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to true if the key exists in this hash.

=cut

async method hash_exists ($k, $hash_key) {
}

=head2 hash_count

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the count of the keys in this hash.

=cut

async method hash_count ($k) {
}

=head2 hash_as_list

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of key/value pairs,
suitable for assigning to a hash.

=cut

async method hash_as_list ($k) {
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


package Myriad::Storage::Perl;

use strict;
use warnings;

# VERSION

use Future::AsyncAwait;
use Object::Pad;

class Myriad::Storage::Perl extends Myriad::Notifier;

use experimental qw(signatures);

=encoding utf8

=head1 NAME

Myriad::Storage::Perl - microservice storage abstraction

=head1 SYNOPSIS

=head1 DESCRIPTION

This is intended for use in tests and standalone local services.
There is no persistence, and no shared data across multiple
processes, but the full L<Myriad::Storage> API should be exposed
correctly.

=cut

use Role::Tiny::With;

use Attribute::Handlers;
use Class::Method::Modifiers;

use Log::Any qw($log);

with 'Myriad::Storage';

use constant RANDOM_DELAY => $ENV{MYRIAD_RANDOM_DELAY} || 0;

# Helper method that allows us to return a not-quite-immediate
# Future from some inherently non-async code.
sub Defer : ATTR(CODE) {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    my $name = *{$symbol}{NAME} or die 'need a symbol name';
    $log->tracef('will defer handler for %s::%s', $package, $name);
    around join('::', $package, $name) => async sub {
        my ($code, $self, @args) = @_;

        # effectively $loop->later, but in an await-compatible way:
        # either zero (default behaviour) or if we have a random
        # delay assigned, use that to drive a uniform rand() call
        await $self->loop->delay_future(
            after => RANDOM_DELAY && rand(RANDOM_DELAY)
        );

        $log->tracef('deferred call to %s::%s', $package, $name);

        return await $self->$code(
            @args
        );
    }
}

# Common datastore
my %data;

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

async method push : Defer ($k, @v) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($_) for grep { ref } @v;
    push $data{$k}->@*, @v;
    return 0+$data{$k}->@*;
}

=head2 unshift

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method unshift : Defer ($k, @v) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($_) for grep { ref } @v;
    unshift $data{$k}->@*, @v;
    return 0+$data{$k}->@*;
}

=head2 pop

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method pop : Defer ($k) {
    return pop $data{$k}->@*;
}

=head2 shift

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method shift : Defer ($k) {
    return shift $data{$k}->@*;
}

=head2 hash_set

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method hash_set : Defer ($k, %args) {
    for my $hash_key (sort keys %args) {
        my $v = $args{$hash_key};
        die 'value cannot be a reference for ' . $k . ' hash key ' . $hash_key . ' - ' . ref($v) if ref $v;
    }
    @{$data{$k}}{keys %args} = values %args;
    return 0 + keys %args;
}

=head2 hash_get

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the scalar value for this key.

=cut

async method hash_get : Defer ($k, $hash_key) {
    return $data{$k}{$hash_key};
}

=head2 hash_add

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> indicating success or failure.

=cut

async method hash_add : Defer ($k, $hash_key, $v) {
    $v //= 1;
    die 'value cannot be a reference for ' . $k . ' - ' . ref($v) if ref $v;
    return $data{$k}{$hash_key} += $v;
}

=head2 hash_keys

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the keys in no defined order.

=cut

async method hash_keys : Defer ($k) {
    return keys $data{$k}->%*;
}

=head2 hash_values

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the values in no defined order.

=cut

async method hash_values : Defer ($k) {
    return values $data{$k}->%*;
}

=head2 hash_exists

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to true if the key exists in this hash.

=cut

async method hash_exists : Defer ($k, $hash_key) {
    return exists $data{$k}{$hash_key};
}

=head2 hash_count

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the count of the keys in this hash.

=cut

async method hash_count : Defer ($k) {
    return 0 + keys $data{$k}->%*;
}

=head2 hash_as_list

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of key/value pairs,
suitable for assigning to a hash.

=cut

async method hash_as_list : Defer ($k) {
    return $data{$k}->%*;
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


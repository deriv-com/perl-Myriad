package Myriad::Storage::Implementation::Memory;

use Myriad::Class extends => 'IO::Async::Notifier', does => [
    'Myriad::Role::Storage',
];

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Storage::Implementation::Memory - microservice storage abstraction

=head1 SYNOPSIS

=head1 DESCRIPTION

This is intended for use in tests and standalone local services.
There is no persistence, and no shared data across multiple
processes, but the full L<Myriad::Storage> API should be exposed
correctly.

=cut

use Myriad::Util::Defer;

# Common datastore
field %data;

field $key_change { +{ } }

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

async method expire : Defer ($k) {
    return undef;
}

async method hash_expire : Defer ($k) {
    return undef;
}

=head2 set

Takes the following parameters:

=over 4

=item * C<< $k >>   - the relative key in storage

=item * C<< $v >>   - the scalar value to set

=item * C<< $ttl >> - the TTL value for the key. (Ignored)

=back

Note that references are currently B<not> supported - attempts to write an arrayref, hashref
or object will fail.

Returns a L<Future> which will resolve on completion.

=cut

async method set : Defer ($k, $v, $ttl = undef) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($v) if ref $v;
    $data{$k} = $v;
    $key_change->{$k}->done if $key_change->{$k};
    return $v;
}

async method set_unless_exists : Defer ($k, $v, $ttl = undef) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($v) if ref $v;
    my $old = $data{$k};
    return $data{$k} if exists $data{$k};
    $data{$k} = $v;
    $key_change->{$k}->done if $key_change->{$k};
    return $old;
}

method when_key_changed ($k) {
    return +(
        $key_change->{$k} //= $self->loop->new_future->on_ready($self->$curry::weak(method {
            delete $key_change->{$k}
        }))
    )->without_cancel;
}

=head2 getset

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $v >> - the scalar value to set

=back

Note that references are currently B<not> supported - attempts to write an arrayref, hashref
or object will fail.

Returns a L<Future> which will resolve on completion.

=cut

async method getset : Defer ($k, $v) {
    die 'value cannot be a reference for ' . $k . ' - ' . ref($v) if ref $v;
    my $original = delete $data{$k};
    $data{$k} = $v;
    return $original;
}

=head2 getdel

Performs the same operation as L</get>, but additionally remove the key from the storage atomically.

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future> which will resolve on completion to the original value, or C<undef> if none.

=cut

async method getdel : Defer ($k) {
    return delete $data{$k};
}

=head2 incr

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future> which will resolve to the corresponding incremented value, or C<undef> if none.

=cut

async method incr : Defer ($k) {
    return ++$data{$k};
}

=head2 observe

Observe a specific key.

Returns a L<Ryu::Source> which will emit the current and all subsequent values.

=cut

method observe ($k) {
    die 'no observation';
}


=head2 watch_keyspace

Returns update about keyspace

=cut

async method watch_keyspace {
    die 'no watch_keyspace';
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

=head2 hash_remove

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method hash_remove : Defer ($k, $hash_key) {
    if(ref $hash_key eq 'ARRAY') {
        return 0 + delete $data{$k}->@{$hash_key->@*};
    } else {
        die 'value cannot be a reference for ' . $k if ref $hash_key;
        delete $data{$k}->{$hash_key};
        return 1;
    }
}

=head2 hash_set

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

async method hash_set : Defer ($k, $hash_key, $v = undef) {
    if(ref $hash_key eq 'HASH') {
        @{$data{$k}}{keys $hash_key->%*} = values $hash_key->%*;
        return 0 + keys $hash_key->%*;
    } else {
        die 'value cannot be a reference for ' . $k . ' hash key ' . $hash_key . ' - ' . ref($v) if ref $v;
        $data{$k}{$hash_key} = $v;
        return 1;
    }
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

async method list_count : Defer ($k) {
    return 0 + $data{$k}->@*;
}

async method list_range : Defer ($k, $start = 0, $end = -1) {
    my $len = 0 + $data{$k}->@*
        or return [ ];
    # Handle negative values as offset from end (-1 being last element)
    $start = $len - $start if $start < 0;
    $end = $len - $end if $end < 0;
    return [ $data{$k}->@[$start .. $end] ];
}

=head2 orderedset_add

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $s >> - the scalar score value

=item * C<< $m >> - the scalar member value

=back

Note that references are currently B<not> supported - attempts to write an arrayref, hashref
or object will fail.

Returns a L<Future> which will resolve on completion.

=cut

async method orderedset_add : Defer ($k, $s, $m) {
    die 'score & member values cannot be a reference for ' . $k . ' - ' . ref($s) . ref($m) if (ref $s or ref $m);
    $data{$k} = {} unless defined $data{$k};
    return $data{$k}->{$s} = $m;
}

=head2 orderedset_remove_member

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $m >> - the scalar member value

=back

Returns a L<Future> which will resolve on completion.

=cut

async method orderedset_remove_member : Defer ($k, $m) {
    my @keys_before  = keys $data{$k}->%*;
    $data{$k} = { map { $data{$k}->{$_} !~ /$m/ ? ($_ => $data{$k}->{$_}) : ()  } keys $data{$k}->%* };
    my @keys_after = keys $data{$k}->%*;
    return 0 + @keys_before - @keys_after;
}

=head2 orderedset_remove_byscore

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $min >> - the minimum score to remove

=item * C<< $max >> - the maximum score to remove

=back

Returns a L<Future> which will resolve on completion.

=cut

async method orderedset_remove_byscore : Defer ($k, $min, $max) {
    $min = -100000 if $min =~ /-inf/;
    $max = 100000 if $max =~ /\+inf/;
    my @keys_before  = keys $data{$k}->%*;
    $data{$k} = { map { ($_ >= $min and $_ <= $max ) ? () : ($_ => $data{$k}->{$_})  } keys $data{$k}->%* };
    my @keys_after = keys $data{$k}->%*;
    return 0 + @keys_before - @keys_after;
}

=head2 unorderedset_add

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $m >> - the scalar member value

=back

Note that references are currently B<not> supported - attempts to write an arrayref, hashref
or object will fail.

Returns a L<Future> which will resolve on completion.

=cut

async method unorderedset_add : Defer ($k, $m) {
    $m = [ $m ] unless ref($m) eq 'ARRAY';
    die 'set member values cannot be a reference for key:' . $k . ' - ' . ref($_) for grep { ref } $m->@*;
    $data{$k} = {} unless defined $data{$k};
    return @{$data{$k}}{$m->@*} = ();
}

=head2 unorderedset_remove

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $m >> - the scalar member value

=back

Returns a L<Future> which will resolve on completion.

=cut

async method unorderedset_remove : Defer ($k, $m) {
    $m = [ $m ] unless ref($m) eq 'ARRAY';
    my $keys_before = 0 + keys $data{$k}->%*;
    delete @{$data{$k}}{$m->@*};
    return $keys_before - keys $data{$k}->%*;
}

async method unorderedset_replace : Defer ($k, $m) {
    $m = [ $m ] unless ref($m) eq 'ARRAY';
    delete @{$data{$k}}{keys $data{$k}->%*};
    @{$data{$k}}{$m->@*} = ();
    return 0 + keys $data{$k}->%*;
}

async method unlink : Defer (@keys) {
    delete @data{@keys};
    $key_change->{$_}->done for grep { $key_change->{$_} } @keys;
    return $self;
}

async method del : Defer (@keys) {
    delete @data{@keys};
    $key_change->{$_}->done for grep { $key_change->{$_} } @keys;
    return $self;
}

=head2 orderedset_member_count

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $min >> - minimum score for selection

=item * C<< $max >> - maximum score for selection

=back

Returns a L<Future> which will resolve on completion.

=cut

async method orderedset_member_count : Defer ($k, $min, $max) {
    $min = -100000 if $min =~ /-inf/;
    $max = 100000 if $max =~ /\+inf/;
    return scalar map { ($_ >= $min and $_ <= $max) ? (1) : ()  } keys $data{$k}->%*;
}

=head2 orderedset_members

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $min >> - minimum score for selection

=item * C<< $max >> - maximum score for selection

=back

Returns a L<Future> which will resolve on completion.

=cut

async method orderedset_members : Defer ($k, $min = '-inf', $max = '+inf', $with_score = 0) {
    $min = -100000 if $min =~ /-inf/;
    $max = 100000 if $max =~ /\+inf/;
    return [ map { ($_ >= $min and $_ <= $max ) ? $with_score ? ($data{$k}->{$_}, $_) : ($data{$k}->{$_}) : ()  } sort keys $data{$k}->%* ];
}

=head2 unorderedset_member_count

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future> which will resolve on completion.

=cut

async method unorderedset_member_count : Defer ($k) {
    return 0 + keys $data{$k}->%*;
}

=head2 unorderedset_members

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $min >> - minimum score for selection

=item * C<< $max >> - maximum score for selection

=back

Returns a L<Future> which will resolve on completion.

=cut

async method unorderedset_members : Defer ($k) {
    return [ keys $data{$k}->%* ];
}

async method unorderedset_is_member : Defer ($k, $m) {
    return exists $data{$k}{$m};
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


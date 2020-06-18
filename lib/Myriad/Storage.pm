package Myriad::Storage;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Future::AsyncAwait;
use Object::Pad;

class Myriad::Storage;

use Role::Tiny;

use experimental qw(signatures);

use Metrics::Any qw($metrics);
use Time::HiRes ();

=encoding utf8

=head1 NAME

Myriad::Storage - microservice storage abstraction

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

=item * L<Myriad::Storage::Implementation::Perl>

=back

=cut

$metrics->make_timer( elapsed =>
    name        => [qw( myriad storage call elapsed )],
    description => "Elapsed time spent processing storage requests",
    # TODO: A shared category/service across the whole process?
    labels      => [qw( method status )],
);

sub _make_wrapped_method_for_metrics ($method, $inner) {
    my $code = sub ($self, @args) {
        my $start = [Time::HiRes::gettimeofday()];
        return $self->$inner(@args)
            ->then_with_f( sub {
                my ($f) = @_;
                $metrics->report_timer( elapsed => Time::HiRes::tv_interval($start),
                    { method => $method, status => "success" } );
                $f;
            })
            ->else_with_f( sub {
                my ($f) = @_;
                $metrics->report_timer( elapsed => Time::HiRes::tv_interval($start),
                    { method => $method, status => "failure" } );
                $f;
            });
    };

    # TODO: An implementation based on Object::Pad would likely use
    # __PACKAGE__->META->add_method( ... );
    no strict 'refs';
    *$method = $code;
}

=head2 get

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=back

Returns a L<Future> which will resolve to the corresponding value, or C<undef> if none.

=cut

requires '_get';
_make_wrapped_method_for_metrics get => '_get';

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

requires '_set';
_make_wrapped_method_for_metrics set => '_set';

=head2 observe

Observe a specific key.

Returns a L<Ryu::Source> which will emit the current and all subsequent values.

=cut

requires 'observe';

=head2 push

Takes the following parameters:

=over 4

=item * C<< $k >> - the relative key in storage

=item * C<< $v >> - the scalar value to set

=back

Returns a L<Future> which will resolve to .

=cut

requires '_push';
_make_wrapped_method_for_metrics push => '_push';

=head2 unshift

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

requires '_unshift';
_make_wrapped_method_for_metrics unshift => '_unshift';

=head2 pop

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

requires '_pop';
_make_wrapped_method_for_metrics pop => '_pop';

=head2 shift

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

requires '_shift';
_make_wrapped_method_for_metrics shift => '_shift';

=head2 hash_set

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to .

=cut

requires '_hash_set';
_make_wrapped_method_for_metrics hash_set => '_hash_set';

=head2 hash_get

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the scalar value for this key.

=cut

requires '_hash_get';
_make_wrapped_method_for_metrics hash_get => '_hash_get';

=head2 hash_add

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> indicating success or failure.

=cut

requires '_hash_add';
_make_wrapped_method_for_metrics hash_add => '_hash_add';

=head2 hash_keys

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the keys in no defined order.

=cut

requires '_hash_keys';
_make_wrapped_method_for_metrics hash_keys => '_hash_keys';

=head2 hash_values

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of the values in no defined order.

=cut

requires '_hash_values';
_make_wrapped_method_for_metrics hash_values => '_hash_values';

=head2 hash_exists

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to true if the key exists in this hash.

=cut

requires '_hash_exists';
_make_wrapped_method_for_metrics hash_exists => '_hash_exists';

=head2 hash_count

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to the count of the keys in this hash.

=cut

requires '_hash_count';
_make_wrapped_method_for_metrics hash_count => '_hash_count';

=head2 hash_as_list

Takes the following parameters:

=over 4

=item *

=back

Returns a L<Future> which will resolve to a list of key/value pairs,
suitable for assigning to a hash.

=cut

requires '_hash_as_list';
_make_wrapped_method_for_metrics hash_as_list => '_hash_as_list';

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


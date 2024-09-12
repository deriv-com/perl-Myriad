package Myriad::Service::Attributes;

use Myriad::Class class => '';

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Service::Attributes - microservice coördination

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

=head1 Attributes

Each of these is an attribute that can be applied to a method.

Note that this class is just a simple passthrough to L<Myriad::Registry>,
which does all the real work.

=cut

use Attribute::Storage qw(get_subattr);

use Myriad::Registry;

use List::Util qw(pairmap);
use Sub::Util ();

our %KNOWN_ATTRIBUTES = map {;
    my ($sym) = /[A-Za-z0-9_]+/g;
    $sym => $sym
} pairmap {
    my $attr = get_subattr($b->reference, 'ATTR');
    ($attr && $attr->{code})
    ? $a
    : ()
} meta::get_this_package()->list_symbols(sigils => '&');

=head1 METHODS

=head2 apply_attributes

Due to L<Attribute::Handlers> limitations at runtime, we need to pick
up attributes ourselves.

=cut

=head2 RPC

Mark this async method as a callable RPC method.

 async method example_rpc : RPC (%args) {
  return \%args;
 }

This will cause the method to be registered in L<Myriad::Registry/add_rpc>.

=cut

sub RPC:ATTR(CODE,NAME) ($class, $method_name, @args) {
    require Myriad;
    my $code = $class->can($method_name);
    $Myriad::REGISTRY->add_rpc(
        $class,
        $method_name,
        $code,
        +{ @args }
    );
}

=head2 Batch

Mark this as an async method which should be called repeatedly to generate
arrayref batches of data.

Takes the following parameters as a hashref:

=over 4

=item * C<compress> - compress all data, regardless of size

=item * C<compress_threshold> - compress any data which would be larger than the given size after encoding, in bytes

=back

 field $id = 0;
 async method example_batch : Batch {
  return [ ++$id ];
 }

=cut

sub Batch:ATTR(CODE,NAME) ($class, $method_name, @args) {
    require Myriad;
    my $code = $class->can($method_name);
    $Myriad::REGISTRY->add_batch(
        $class,
        $method_name,
        $code,
        +{ @args }
    );
}

=head2 Emitter

Indicates a method which should be called on startup, which given a
L<Ryu::Sink> will emit events to that sink until it's done.

Takes the following parameters as a hashref:

=over 4

=item * C<compress> - compress all data, regardless of size

=item * C<compress_threshold> - compress any data which would be larger than the given size after encoding, in bytes

=item * C<subchannel_key> - emit to zero or more separate streams defined by this key in the emitted items

=back

=cut

sub Emitter:ATTR(CODE,NAME) ($class, $method_name, @args) {
    require Myriad;
    my $code = $class->can($method_name);
    $Myriad::REGISTRY->add_emitter(
        $class,
        $method_name,
        $code,
        +{ @args }
    );
}

=head2 Receiver

Indicates a method which should be called on startup and passed a
L<Ryu::Source>. Events will be emitted to that source until termination.

=cut

sub Receiver:ATTR(CODE,NAME) ($class, $method_name, @args) {
    require Myriad;
    my $code = $class->can($method_name);
    $Myriad::REGISTRY->add_receiver(
        $class,
        $method_name,
        $code,
        +{ @args }
    );
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


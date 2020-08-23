package Myriad::Service::Attributes;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

=encoding utf8

=head1 NAME

Myriad::Service::Attributes - microservice coördination

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

=head1 Attributes

Each of these is an attribute that can be applied to a method.

=cut

use Myriad::Registry;

use Log::Any qw($log);
use Exporter qw(import export_to_level);

use Sub::Util ();

my %known_attributes = (
    RPC => 'rpc',
    Stream => 'stream',
    Sink => 'sink',
    Batch => 'batch'
);

=head2 MODIFY_CODE_ATTRIBUTES

Due to L<Attribute::Handlers> limitations at runtime, we need to pick
up attributes ourselves.

=cut

sub apply_attributes {
    my ($class, %args) = @_;
    my $pkg = $args{class};
    my ($method) = Sub::Util::subname($args{code}) =~ /::([^:]+)$/;
    for my $attr ($args{attributes}->@*) {
        my ($type, $args) = $attr =~ m{^([a-z]+)(.*$)}si;
        # Nasty, but functional for now - this will likely be replaced by
        # an m//gc parser later with a restricted set of options.
        $args = +{ eval "$args" } if length $args;

        $log->infof('Attrbute %s (%s) applying to %s', $type, $args, $pkg);
        die 'unknown attribute ' . $type unless my $handler = $known_attributes{$type};
        $class->$handler(
            $pkg,
            $method,
            $args{code},
            $args
        );
    }
    return;
}

=head2 RPC

Mark this async method as a callable RPC method.

 async method example_rpc : RPC (%args) {
  return \%args;
 }

This will cause the method to be registered in L<Myriad::Registry/add_rpc>.

=cut

sub rpc {
    my ($class, $pkg, $method, $code, $args) = @_;
    Myriad::Registry->add_rpc(
        $pkg,
        $method,
        $code,
        $args
    );
}

=head2 Stream

Mark this as an async method which expects to be called with a L<Ryu::Sink>,
and is responsible for streaming data into that sink until cancelled.

 has $src;
 async method example_stream : Stream ($sink) {
  $src //= $self->ryu->source;
  $sink->from($src);
  my $idx = 0;
  while(1) {
   await $self->loop->delay_future(after => 0.1);
   $src->emit(++$idx);
  }
 }

=cut

sub stream {
    my ($class, $pkg, $method, $code, $args) = @_;
    Myriad::Registry->add_stream(
        $pkg,
        $method,
        $code,
        $args,
    );
}

=head2 Batch

Mark this as an async method which should be called repeatedly to generate
arrayref batches of data.

 has $id = 0;
 async method example_batch : Batch {
  return [ ++$id ];
 }

=cut

sub batch {
    my ($class, $pkg, $method, $code, $args) = @_;
    Myriad::Registry->add_batch(
        $pkg,
        $method,
        $code,
        $args,
    );
}

=head2 Sink

Mark this as an async method which should be called repeatedly to generate
arrayref batches of data.

 has $id = 0;
 async method example_batch : Batch {
  return [ ++$id ];
 }

=cut

sub sink {
    my ($class, $pkg, $method, $code, $args) = @_;
    Myriad::Registry->add_sink(
        $pkg,
        $method,
        $code,
        $args,
    );
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


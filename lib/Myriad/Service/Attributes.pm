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

use Attribute::Handlers;

use Myriad::Registry;

use Log::Any qw($log);

use Exporter qw(import export_to_level);

our @IMPORT = our @IMPORT_OK = qw(RPC);

=head2 RPC

Mark this async method as a callable RPC method.

 async method example_rpc : RPC (%args) {
  return \%args;
 }

=cut

sub RPC : ATTR {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    die 'Invalid attribute - should be applied to a coderef' unless ref($referent) eq 'CODE';
    $log->tracef(
        'Marking %s::%s as an RPC method (%s) via %s at %s:%d',
        $package,
        *{$symbol}{NAME},
        $data,
        $phase,
        $filename,
        $linenum
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

sub Stream : ATTR {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    die 'Invalid attribute - should be applied to a coderef' unless ref($referent) eq 'CODE';
    $log->tracef(
        'Marking %s::%s as a Stream method (%s) via %s at %s:%d',
        $package,
        *{$symbol}{NAME},
        $data,
        $phase,
        $filename,
        $linenum
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

sub Batch : ATTR {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    die 'Invalid attribute - should be applied to a coderef' unless ref($referent) eq 'CODE';
    my $method = *{$symbol}{NAME};
    $log->tracef(
        'Marking %s::%s as a Batch method (%s) via %s at %s:%d',
        $package,
        $method,
        $data,
        $phase,
        $filename,
        $linenum
    );
    Myriad::Registry->add_batch(
        $package,
        $method,
        $referent
    );
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


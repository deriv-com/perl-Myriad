package Myriad::Registry;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

=encoding utf8

=head1 NAME

Myriad::Registry - track available methods and subscriptions

=head1 SYNOPSIS

=head1 DESCRIPTION

Used internally within L<Myriad> for keeping track of what services
are available, and what they can do.

=cut

use Future::AsyncAwait;

use Myriad::Exception;
use Myriad::Exception::Registry;

our %RPC;
our %STREAM;
our %BATCH;
our %SINK;

=head2 add_rpc

Registers a new RPC method for the given class.

=cut

sub add_rpc {
    my ($class, $pkg, $method, $code) = @_;
    $RPC{$pkg}{$method} = $code;
}

=head2 rpc_for

Returns a hashref of RPC definitions for the given class.

=cut

sub rpc_for {
    my ($class, $pkg) = @_;
    return $RPC{$pkg} // Myriad::Exception::Registry->throw(reason => 'unknown package ' . $pkg);
}

=head2 add_stream

Registers a new stream method for the given class.

=cut

sub add_stream {
    my ($class, $pkg, $method, $code) = @_;
    $STREAM{$pkg}{$method} = $code;
}

=head2 streams_for

Returns a hashref of stream methods for the given class.

=cut

sub streams_for {
    my ($class, $pkg) = @_;
    return $STREAM{$pkg} // Myriad::Exception::Registry->throw('unknown package ' . $pkg);
}

=head2 add_batch

Registers a new batch method for the given class.

=cut

sub add_batch {
    my ($class, $pkg, $method, $code) = @_;
    $BATCH{$pkg}{$method} = $code;
}

=head2 batches_for

Returns a hashref of batch methods for the given class.

=cut

sub batches_for {
    my ($class, $pkg) = @_;
    return $BATCH{$pkg};
}

=head2 add_sink

Registers a new sink method for the given class.

=cut

sub add_sink {
    my ($class, $pkg, $method, $code) = @_;
    $SINK{$pkg}{$method} = $code;
}

=head2 sinkes_for

Returns a hashref of sink methods for the given class.

=cut

sub sinkes_for {
    my ($class, $pkg) = @_;
    return $SINK{$pkg} ;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


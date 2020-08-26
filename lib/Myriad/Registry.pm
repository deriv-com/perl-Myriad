package Myriad::Registry;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Object::Pad;

class Myriad::Registry;

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
use Scalar::Util qw(blessed);

use Log::Any qw($log);
has $myriad;

has $rpc = {};
has $service_by_name = {};
has $batch = {};
has $sink = {};
has $stream = {};

BUILD (%args) {
    Scalar::Util::weaken($myriad = $args{myriad});
}

=head2 add_service

Instantiates and adds a new service to the L</loop>.

Returns the service instance.

=cut

async method add_service ($srv, %args) {
    $srv = $srv->new(
        redis => $self->redis
    ) unless blessed($srv) and $srv->isa('Myriad::Service');

    my $name = $args{name} || $srv->service_name;
    $log->infof('Add service [%s]', $name);
    $self->loop->add(
        $srv
    );
    my $k = Scalar::Util::refaddr($srv);
    Scalar::Util::weaken($self->{service_by_name}{$name} = $srv);
    $self->{services}{$k} = $srv;

    await $srv->startup;
    return;
}

=head2 service_by_name

Looks up the given service, returning the instance if it exists.

Will throw an exception if the service cannot be found.

=cut

method service_by_name ($k) {
    return $service_by_name->{$k} // Myriad::Exception::Registry->throw(
        reason => 'service ' . $k . ' not found'
    );
}

=head2 add_rpc

Registers a new RPC method for the given class.

=cut

method add_rpc ($pkg, $method, $code, $args) {
    $rpc->{$pkg}{$method} = $code;
}

=head2 rpc_for

Returns a hashref of RPC definitions for the given class.

=cut

method rpc_for ($pkg) {
    return $rpc->{$pkg} // Myriad::Exception::Registry->throw(
        reason => 'unknown package ' . $pkg
    );
}

=head2 add_stream

Registers a new stream method for the given class.

=cut

method add_stream ($pkg, $method, $code, $args) {
    $stream->{$pkg}{$method} = $code;
}

=head2 streams_for

Returns a hashref of stream methods for the given class.

=cut

method streams_for ($pkg) {
    return $stream->{$pkg} // Myriad::Exception::Registry->throw('unknown package ' . $pkg);
}

=head2 add_batch

Registers a new batch method for the given class.

=cut

method add_batch ($pkg, $method, $code) {
    $batch->{$pkg}{$method} = $code;
}

=head2 batches_for

Returns a hashref of batch methods for the given class.

=cut

method batches_for ($pkg) {
    return $batch->{$pkg};
}

=head2 add_sink

Registers a new sink method for the given class.

=cut

method add_sink ($pkg, $method, $code) {
    $sink->{$pkg}{$method} = $code;
}

=head2 sinks_for

Returns a hashref of sink methods for the given class.

=cut

method sinks_for ($pkg) {
    return $sink->{$pkg};
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


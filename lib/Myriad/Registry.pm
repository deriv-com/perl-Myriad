package Myriad::Registry;

use Myriad::Class extends => 'IO::Async::Notifier';

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Registry - track available methods and subscriptions

=head1 SYNOPSIS

=head1 DESCRIPTION

Used internally within L<Myriad> for keeping track of what services
are available, and what they can do.

=cut

use Myriad::Exception::Builder category => 'registry';

declare_exception ServiceNotFound => (
    message => 'Unable to locate the given service',
);
declare_exception UnknownClass => (
    message => 'Unable to locate the given class for component lookup',
);

use Myriad::API;

has $myriad;

has $rpc = {};
has $service_by_name = {};
has $batch = {};
has $sink = {};
has $stream = {};
has $emitter = {};
has $receiver = {};

BUILD (%args) {
    weaken($myriad = $args{myriad});
}

=head2 add_service

Instantiates and adds a new service to the L</loop>.

Returns the service instance.

=cut

async method add_service (%args) {
    my $srv = delete $args{service};
    my $storage = delete $args{storage};

    $srv = $srv->new(
        %args
    ) unless blessed($srv) and $srv->isa('Myriad::Service');

    my $pkg = ref $srv;

    # Inject an `$api` instance so that this service can talk
    # to storage and the outside world
    $Myriad::Service::SLOT{$pkg}{api}->value($srv) = Myriad::API->new(
        myriad => $myriad,
        storage => $storage,
    );

    my $name = $args{name} || $srv->service_name;
    $rpc->{$pkg} ||= {};
    $stream->{$pkg} ||= {};
    $batch->{$pkg} ||= {};
    $sink->{$pkg} ||= {};
    $emitter->{$pkg} ||= {};
    $receiver->{$pkg} ||= {};
    $log->tracef('Going to add service %s', $name);
    $self->loop->add(
        $srv
    );
    my $k = refaddr($srv);
    weaken($service_by_name->{$name} = $srv);
    $self->{services}{$k} = $srv;

    try {
        await $srv->start;
        $log->infof('Added service [%s]', $name);
    } catch ($e) {
        $log->errorf('Failed to add service [%s] due: %s', $name, $e);
    }
    return;
}

=head2 service_by_name

Looks up the given service, returning the instance if it exists.

Will throw an exception if the service cannot be found.

=cut

method service_by_name ($k) {
    return $service_by_name->{$k} // Myriad::Exception::Registry::ServiceNotFound->throw(
        reason => 'service ' . $k . ' not found'
    );
}

=head2 add_rpc

Registers a new RPC method for the given class.

=cut

method add_rpc ($pkg, $method, $code, $args) {
    $rpc->{$pkg}{$method} = {
        code => $code,
        args => $args,
    };
}

=head2 rpc_for

Returns a hashref of RPC definitions for the given class.

=cut

method rpc_for ($pkg) {
    return $rpc->{$pkg} // Myriad::Exception::Registry::UnknownClass->throw(
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
    return $stream->{$pkg} // Myriad::Exception::Registry::UnknownPackage->throw(reason => 'unknown package ' . $pkg);
}

=head2 add_batch

Registers a new batch method for the given class.

=cut

method add_batch ($pkg, $method, $code, $args) {
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

method add_sink ($pkg, $method, $code, $args) {
    $sink->{$pkg}{$method} = $code;
}

=head2 sinks_for

Returns a hashref of sink methods for the given class.

=cut

method sinks_for ($pkg) {
    return $sink->{$pkg};
}

=head2 add_emitter

Registers a new emitter method for the given class.

=cut

method add_emitter ($pkg, $method, $code, $args) {
    $args->{channel} //= $method;
    $emitter->{$pkg}{$method} = {
        code => $code,
        args => $args,
    };
}

=head2 emitters_for

Returns a hashref of emitter methods for the given class.

=cut

method emitters_for ($pkg) {
    return $emitter->{$pkg};
}

=head2 add_receiver

Registers a new receiver method for the given class.

=cut

method add_receiver ($pkg, $method, $code, $args) {
    $args->{channel} //= $method;
    $receiver->{$pkg}{$method} = {
        code => $code,
        args => $args,
    };
}

=head2 receivers_for

Returns a hashref of receiver methods for the given class.

=cut

method receivers_for ($pkg) {
    return $receiver->{$pkg};
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


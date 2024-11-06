package Myriad::API;

use Myriad::Class;

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::API - provides an API for Myriad services

=head1 SYNOPSIS

=head1 DESCRIPTION

Used internally within L<Myriad> services for providing access to
storage, subscription and RPC behaviour.

=cut

use List::UtilsBy qw(extract_by);
use Myriad::Config;
use Myriad::Mutex;
use Myriad::Service::Remote;
use Myriad::Service::Storage;
use Myriad::Service::Bus;

=head1 METHODS - Accessors

=cut

field $myriad;
field $service;

=head2 service_name

Returns the name of this service (as a plain string).

=cut

field $service_name : reader;

=head2 storage

Returns a L<Myriad::Role::Storage>-compatible instance for interacting with storage.

=cut

field $storage : reader;
field $config;
field $bus;

=head1 METHODS - Other

=cut

BUILD (%args) {
    weaken($myriad = delete $args{myriad});
    weaken($service = delete $args{service});
    $service_name = delete $args{service_name} // die 'need a service name';
    $config = delete $args{config} // {};
    $storage = Myriad::Service::Storage->new(
        prefix => $service_name,
        storage => $myriad->storage
    );
}

=head2 service_by_name

Returns a service proxy instance for the given service name.

This can be used to call RPC methods and act on subscriptions.

=cut

method service_by_name ($name) {
    return Myriad::Service::Remote->new(
        myriad             => $myriad,
        service_name       => $myriad->registry->make_service_name($name),
        local_service_name => $service_name
    );
}


=head2 config

Returns a L<Ryu::Observable> that holds the value of the given
configuration key.

=cut

method config ($key) {
    my $pkg = caller;
    if($Myriad::Config::SERVICES_CONFIG{$pkg}->{$key}) {
        return $config->{$key};
    }
    Myriad::Exception::Config::UnregisteredConfig->throw(
        reason => "$key is not registered by service $service_name"
    );
}

=head2 mutex

=cut

async method mutex (@args) {
    my ($code) = extract_by { ref($_) eq 'CODE' } @args;
    # `name` is used for a shared mutex across services
    my $name = @args % 2 ? shift(@args) : $service_name;
    my %args = @args;
    # `key` is used for a suffix for a specific service
    my $suffix = delete($args{key}) // '';
    my $mutex = Myriad::Mutex->new(
        %args,
        loop    => $service->loop,
        key     => $name . (length($suffix) ? "[$suffix]" : ''),
        storage => $storage,
        id      => $service->uuid,
    );
    if($code) {
        try {
            await $mutex->acquire;
            my $f = $code->();
            await $f if blessed($f) and $f->isa('Future');
            await $mutex->release;
        } catch($e) {
            $log->errorf('Failed while processing mutex-protected code: %s', $e);
            await $mutex->release;
            die $e;
        }
        return undef;
    } else {
        return await $mutex->acquire;
    }
}

method bus {
    unless($bus) {
        $bus = Myriad::Service::Bus->new(
            service   => $service_name,
            myriad    => $myriad,
        );
        $bus->setup->retain;
    }
    return $bus;
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


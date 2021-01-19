package Myriad::API;

use Myriad::Service::Remote;
use Myriad::Service::Storage;

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

has $myriad;
has $service_name;
has $storage;

BUILD (%args) {
    weaken($myriad = delete $args{myriad});
    $service_name = delete $args{service_name} // die 'need a service name';
    $storage = Myriad::Service::Storage->new(prefix => $service_name, storage => $myriad->storage);
}

=head2 storage

Returns a L<Myriad::Role::Storage>-compatible instance for interacting with storage.

=cut

method storage { $storage }

=head2 service_by_name

Returns a service proxy instance for the given service name.

This can be used to call RPC methods and act on subscriptions.

=cut

method service_by_name ($name) {
    return Myriad::Service::Remote->new(service_name => $myriad->registry->make_service_name($name), myriad => $myriad);
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


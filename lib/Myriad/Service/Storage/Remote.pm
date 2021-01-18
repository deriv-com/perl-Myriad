package Myriad::Service::Storage::Remote;

use Myriad::Class;

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Service::Storage::Remote - abstraction to access other services storage.

=head1 SYNOPSIS

 my $storage = $api->service_by_name('service')->storage;
 await $storage->get('some_key');

=head1 DESCRIPTION

=cut

use Myriad::Role::Storage;

BEGIN {
    my $meta = Myriad::Service::Storage::Remote->META;

    for my $method (@Myriad::Role::Storage::READ_METHODS) {
        $meta->add_method($method, sub {
            my ($self, $key, @rest) = @_;
            return $self->storage->$method($self->apply_prefix($key), @rest);
        });
    }
}


has $prefix;
has $storage;
method storage { $storage };

BUILD (%args) {
    $prefix = delete $args{prefix} // die 'need a prefix';
    $storage = delete $args{storage} // die 'need a storage instance';
}

=head2 apply_prefix

Maps the requested key into the service's keyspace
so we can pass it over to the generic storage layer.

Takes the following parameters:

=over 4

=item * C<$k> - the key

=back

Returns the modified key.

=cut

method apply_prefix ($k) {
    return $prefix . '.' . $k;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.



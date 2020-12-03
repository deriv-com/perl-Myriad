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

method rpc {
    ...
}

method subscription {
    ...
}

method storage {
    ...
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


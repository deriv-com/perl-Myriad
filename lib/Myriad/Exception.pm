package Myriad::Exception;

use Myriad::Class type => 'role';

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Exception - standard exception rôle for all L<Myriad> code

=head1 DESCRIPTION

This is a rôle used for all exceptions throughout the framework.

=cut

requires category;
requires message;

=head2 throw

Instantiates a new exception and throws it (by calling L<perlfunc/die>).

=cut

method throw (@args) {
    $self = $self->new(@args) unless blessed($self);
    die $self;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


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

method category;
method message;

=head2 throw

Instantiates a new exception and throws it (by calling L<perlfunc/die>).

=cut

sub throw ($class, @args) {
    my $self = blessed($class) ? $class : $class->new(@args);
    die $self;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2023. Licensed under the same terms as Perl itself.


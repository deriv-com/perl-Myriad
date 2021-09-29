package Myriad::Exception;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

=encoding utf8

=head1 NAME

Myriad::Exception - standard exception rôle for all L<Myriad> code

=head1 DESCRIPTION

This is a rôle used for all exceptions throughout the framework.

=cut

no indirect qw(fatal);

use Scalar::Util;
use Role::Tiny;

requires qw(category message);

=head2 throw

Instantiates a new exception and throws it (by calling L<perlfunc/die>).

=cut

sub throw {
    my $self = shift;
    $self = $self->new(@_) unless Scalar::Util::blessed($self);
    die $self;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


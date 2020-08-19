package Myriad::Exception;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);

use utf8;

=encoding utf8

=head1 NAME

Myriad::Exception

=head1 DESCRIPTION

This is a rôle used for all exceptions throughout the framework.

=cut

use Scalar::Util;
use Role::Tiny;

requires qw(category message);

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

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


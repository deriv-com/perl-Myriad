package Myriad::Exception::Builder;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

=encoding utf8

=head1 NAME

Myriad::Exception::Builder - applies L<Myriad::Exception::Base> to an exception class

=head1 DESCRIPTION

See L<Myriad::Exception> for the rôle that defines the exception API.

=cut

use Check::UnitCheck;
use Myriad::Exception;
use Myriad::Exception::Base;

require Myriad::Class;

sub import {
    my ($class, %args) = @_;
    for my $k (sort keys %args) {
        my $pkg = 'Myriad::Exception::' . $k;
        # my $pkg = caller;
        Myriad::Class->import(
            target  => $pkg,
            extends => qw(Myriad::Exception::Base)
        );
        {
            no strict 'refs';
            my $data = $args{$k};
            warn "keys = " . join ',', sort keys %$data;
            *{$pkg . '::' . $_} = $data->{$_} for keys %$data;
        }
        die 'cannot' unless $pkg->can('reason');
        die 'cannot' unless $pkg->can('category');
        Role::Tiny->apply_roles_to_package(
            $pkg => 'Myriad::Exception'
        )
    }
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


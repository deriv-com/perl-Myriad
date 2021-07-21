package Myriad::Role;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

=encoding utf8

=head1 NAME

Myriad::Role - common pragmata for L<Myriad> rôles

=cut

require Myriad::Class;

sub import {
    my $called_on = shift;

    # Unused, but we'll support it for now.
    my $version = 1;
    if(@_ and $_[0] =~ /^:v([0-9]+)/) {
        $version = $1;
        shift;
    }
    my %args = (
        version => $version,
        @_
    );

    my $class = __PACKAGE__;
    $args{target} //= caller(0);
    return Myriad::Class->import(%args);
}

1;


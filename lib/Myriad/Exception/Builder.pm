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

sub import {
    my ($class, @args) = @_;
    my $pkg = caller;
    { no strict 'refs'; push @{$pkg . '::ISA'}, qw(Myriad::Exception::Base); }
    my $code = sub {
        Role::Tiny->apply_roles_to_package(
            $pkg => 'Myriad::Exception'
        )
    };
    # Allow Myriad::Exception::Base->import from unit tests
    return $code->() if grep { /:immediate/ } @args;

    # ... but most of the time, we're a standalone .pm with
    # a `use Myriad::Exception::Base;` line
    Check::UnitCheck::unitcheckify($code);
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


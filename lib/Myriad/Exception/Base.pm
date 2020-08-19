package Myriad::Exception::Base;

use strict;
use warnings;

use Check::UnitCheck;
use Myriad::Exception;

use overload '""' => sub { shift->as_string }, bool => sub { 1 }, fallback => 1;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class
}

sub as_string { shift->message }

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
    return $code->() if ${^GLOBAL_PHASE} eq 'RUN';
    # ... but most of the time, we're a standalone .pm with
    # a `use Myriad::Exception::Base;` line
    Check::UnitCheck::unitcheckify($code);
}

1;


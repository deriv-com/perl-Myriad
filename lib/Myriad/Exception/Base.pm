package Myriad::Exception::Base;

use strict;
use warnings;

use Myriad::Exception;

use overload '""' => sub { shift->as_string }, bool => sub { 1 }, fallback => 1;

sub new {
    my ($class, %args) = @_;
    bless \%args, $class
}

sub as_string { shift->message }

1;


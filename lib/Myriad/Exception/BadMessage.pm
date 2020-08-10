package Myriad::Exception::BadMessage;

use strict;
use warnings;

# VERSION

no indirect qw(fatal);
use utf8;

use Role::Tiny::With;

with 'Myriad::Exception';

sub new { 
    my ($class, $field_name) = @_;
    return bless { field => $field_name}, $class;
}

sub category { 'BAD_MESSAGE' }

sub field { shift->{field} }

sub message { 
    my $self = shift;
    return "Bad RPC Message field: " . $self->field . " is required!" 
}

1;


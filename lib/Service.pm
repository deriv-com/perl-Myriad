package Myriad::Service;

use strict;
use warnings;

use parent qw(IO::Async::Notifier);

=head1 NAME

Myriad::Service - base class for L<Myriad>-based services

=head1 SYNOPSIS

=cut

sub diagnostics { Future->done }

1;



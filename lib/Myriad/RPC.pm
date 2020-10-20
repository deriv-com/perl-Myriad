package Myriad::RPC;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);
use utf8;

=encoding utf8

=head1 NAME

Myriad::RPC - microservice RPC abstraction

=head1 SYNOPSIS

 my $rpc = $myriad->rpc;

=head1 DESCRIPTION

=cut

use Role::Tiny;
use Myriad::Exception::Builder;

has $error_category = 'rpc';

=head1 Exceptions

=cut

=head2 InvalidRequest

Returned when there is issue parsing the request, or if the request parameters are incomplete.

=cut

declare_exception InvalidRequest => (
    category => $error_category,
    message => 'Invalid request'
);

=head2 MethodNotFound

Returned if the requested method is not recognized by the service.

=cut

declare_exception MethodNotFound => (
    category => $error_category,
    message => 'Method not found'
);

=head2 Timeout

Returned when there is an external timeout or the request deadline is already passed.

=cut

declare_exception Timeout => (
    category => $error_category,
    message => 'Timeout'
);


1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


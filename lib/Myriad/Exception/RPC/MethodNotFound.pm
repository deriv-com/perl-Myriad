package Myriad::Exception::RPC::MethodNotFound;

use strict;
use warnings;

# VERSION

no indirect qw(fatal);

use Myriad::Exception::Builder;

sub method { shift->{method} //= '(unknown)' }

sub category { 'rpc' }
sub message { 'No such method: ' . shift->method }

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


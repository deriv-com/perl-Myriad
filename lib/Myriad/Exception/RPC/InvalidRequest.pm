package Myriad::Exception::RPC::InvalidRequest;

use Myriad::Class;

# VERSION
# AUTHORITY

use Myriad::Exception::Builder;

has $message;

method category { 'rpc' }
method message { $_[0]->{message} //= 'invalid request due to: ' . $_[0]->reason }

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


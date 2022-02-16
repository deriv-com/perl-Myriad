package Myriad::Transport::PostgreSQL;

use Myriad::Class extends => 'IO::Async::Notifier';

# VERSION
# AUTHORITY

use Database::Async;
use Database::Async::Engine::PostgreSQL;

has $dbh;

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


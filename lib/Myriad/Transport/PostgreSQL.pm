package Myriad::Transport::PostgreSQL;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;
use Object::Pad;

class Myriad::Transport::PostgreSQL extends Myriad::Notifier;

use Future::AsyncAwait;
use Syntax::Keyword::Try;

use Database::Async;
use Database::Async::Engine::PostgreSQL;

use Log::Any qw($log);

has $dbh;

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


package Myriad::RPC::Implementation::Perl;

use strict;
use warnings;

# VERSION
# AUTHORITY

use parent qw(IO::Async::Notifier);

no indirect qw(fatal);

use utf8;

=encoding utf8

=head1 NAME

Myriad::RPC::Implementation::Perl - microservice RPC abstraction

=head1 DESCRIPTION

=cut

use experimental qw(signatures);

use Future::AsyncAwait;
use Syntax::Keyword::Try;
use Role::Tiny::With;
use Scalar::Util qw(blessed);

use Log::Any qw($log);

with 'Myriad::RPC';

async sub start ($self) {
    $self->{queue} = Future::Queue->new;

}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


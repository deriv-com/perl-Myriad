package Myriad::Transport::HTTP;

use strict;
use warnings;

class Myriad::Transport::HTTP extends Myriad::Notifier;

use curry;

use Net::Async::HTTP;
use Net::Async::HTTP::Server;

has $client;
has $server;
has $listener;
has $requests;

method configure (%args) {

}

method on_request ($srv, $req) {
    $requests->emit($req);
}

method listen_port { 80 }

method _add_to_loop {
    $self->next::method;
    $requests = $self->ryu->source;

    $self->add_child(
        $client = Net::Async::HTTP->new(
        )
    );
    $self->add_child(
        $server = Net::Async::HTTP::Server->new(
            on_request => $self->curry::weak::on_request,
        )
    );
    $listener = $server->listen(
        addr => {
            family => 'inet',
            socktype => 'stream',
            port => $self->listen_port,
        }
    );
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


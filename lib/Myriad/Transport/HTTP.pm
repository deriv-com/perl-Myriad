package Myriad::Transport::HTTP;

use Myriad::Class extends => 'IO::Async::Notifier';

# VERSION
# AUTHORITY

use Net::Async::HTTP;
use Net::Async::HTTP::Server;

field $client;
field $server;
field $listener;
field $requests;
field $ryu;

method configure (%args) {

}

method on_request ($srv, $req) {
    $requests->emit($req);
    $log->infof('HTTP request - %s', $req->path);
    my $txt = '';
    my $response = HTTP::Response->new(200);
    $response->add_content($txt);
    $response->content_type("text/plain");
    $response->content_length(length $txt);
    $req->respond($response);
}

method listen_port () { 2000 }

method _add_to_loop ($) {
    $self->next::method;

    $self->add_child(
        $ryu = Ryu::Async->new
    );
    $requests = $ryu->source;

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

Deriv Group Services Ltd. C<< DERIV@cpan.org >>

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


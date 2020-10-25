package Myriad::RPC::Implementation::Perl;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Syntax::Keyword::Try qw( try :experimental(typed) );

use Role::Tiny::With;
with 'Myriad::Role::RPC';

use Future::Queue;

use Myriad::Exception::General;
use Myriad::RPC::Message;
use Myriad::Class extends => qw(IO::Async::Notifier);

=head1 NAME

Myriad::RPC::Implementation::Perl - microservice RPC in-memory implementation.

=head1 DESCRIPTION

=cut

has $service;
has $should_shutdown;
has $requests_queue = Future::Queue->new;
has $rpc_methods = {};
has @pending_requests;

method configure(%args) {
    $service = delete $args{service} if exists $args{service};

    $self->next::method(%args);
}

=head1 METHODS

=head2 start

Start waiting for new requests to fill in the internal requests queue.

=cut

async method start () {
    $should_shutdown //= $self->loop->new_future(label => 'rpc::perl::shutdown_future')->without_cancel;
    my $id = 0;
    my $message;
    while (my $request = await $requests_queue->shift) {
        try {
            $id++;
            $message = Myriad::RPC::Message->new($request->%*);
            if (my $sink = $rpc_methods->{$message->rpc}) {
                $sink->source->emit($message);
            } else {
                Myriad::Exception::RPC::MethodNotFound->throw(reason => $message->rpc);
            }
        } catch ($e isa Myriad::Exception::RPC::BadEncoding) {
            $log->warnf('Recived a dead message that we cannot parse, going to drop it.');
            $log->tracef("message was: %s", $request);
            await $self->drop($id);
        } catch ($e) {
            await $self->reply_error($message, $e);
        }

        $message = undef;
        await Future::wait_any($should_shutdown, $self->loop->delay_future(after => 0.01));
    }
}

=head2 create_from_sink

Register and RPC call and save a reference to its L<RYU::Sink>.

=cut

method create_from_sink (%args) {
    my $sink   = $args{sink} // die 'need a sink';
    my $method = $args{method} // die 'need a method name';

    $rpc_methods->{$method} = $sink;
}

=head2 stop

Gracefully stop the RPC processing.

=cut

async method stop () {
    $should_shutdown->done();
}

=head2 reply_success

Reply to the requester with a success message.

In this implementation it's done by resolving the L<Future> calling C<done>.

=cut

async method reply_success ($message, $response) {
    my $future = shift @pending_requests;
    $message->response = { response => $response };
    $future->done($message->encode);
}

=head2 reply_error

Reply to the requester with a failure message.

In this implementation it's done by resolving the L<Future> calling C<fail>.

=cut

async method reply_error ($message, $error) {
    my $future = shift @pending_requests;
    $message->response = { error => { category => $error->category, message => $error->message, reason => $error->reason } };
    $future->fail($message->encode);
}

=head2 drop

Drop the request because we can't reply to the requester.

=cut

async method drop ($id) {
    shift @pending_requests;
}

=head2 request

Create a new request.

=over 4

=item * C<message> - A string that typically should contain JSON encoded message.

=item * C<reply_future> - A L<Future> that is going to be resolved once the request is processed.

=back

=cut

method request ($message, $reply_future) {
    push @pending_requests, $reply_future;
    $requests_queue->push($message);
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


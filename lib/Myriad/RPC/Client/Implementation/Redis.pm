package Myriad::RPC::Client::Implementation::Redis;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Myriad::Class extends => qw(IO::Async::Notifier);

use Myriad::Util::UUID;
use Myriad::RPC::Implementation::Redis qw(stream_name_from_service);
use Myriad::RPC::Message;

has $redis;
has $pending_requests;
has $whoami;
has $current_id;

BUILD {
    $pending_requests = {};
    $whoami = Myriad::Util::UUID::uuid();
    $current_id = 0;
}

method configure (%args) {
    $redis = delete $args{redis} if $args{redis};
}

method _add_to_loop ($loop) {
    $self->start->retain();
}

async method start() {
    my $sub = await $redis->subscribe($whoami);
    $sub->events->map('payload')->map(sub{
        try {
            my $message = Myriad::RPC::Message::from_json($_);
            if(my $pending = delete $pending_requests->{$message->message_id}) {
                $pending->done($message);
            }
        } catch ($e) {
            $log->warnf("failed to parse rpc response due %s", $e);
        }
    })->completed;
}

async method call_rpc($service, $method, %args) {
    my $pending = $self->loop->new_future(label => "rpc::request::${service}::${method}");
    my $message_id = $self->next_id;

    my $request = Myriad::RPC::Message->new(
        rpc        => $method,
        who        => $whoami,
        deadline   => 30,
        message_id => $message_id,
        args       => \%args,
    );
    try {
        await $redis->xadd(stream_name_from_service($service) => '*', $request->as_hash->%*);
        $pending_requests->{$message_id} = $pending;
        my $message = await Future->wait_any($self->loop->timeout_future(after => 3), $pending);
        return $message->response;
    } catch ($e) {
    warn $e;
        $pending->fail($e);
        delete $pending_requests->{$message_id};
    }
}

method next_id {
    return $current_id++;
}

1;


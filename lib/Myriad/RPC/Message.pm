package Myriad::RPC::Message;

use strict;
use warnings;

# VERSION

use Object::Pad;
use Syntax::Keyword::Try;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);

use Myriad::Exception::BadMessageEncoding;
use Myriad::Exception::BadMessage;

class Myriad::RPC::Message;

has $rpc;
has $id;
has $who;
has $deadline;

has $args;
has $stash;
has $response;
has $trace;

method id {$id};
method rpc {$rpc};
method args {$args};
method who {$who};
method response :lvalue {$response}

method BUILD(%raw_message) {
    $rpc = $raw_message{rpc} // Myriad::Exception::BadMessage->throw('rpc');
    $id = $raw_message{message_id} // Myriad::Exception::BadMessage->throw('id');
    $who = $raw_message{who} // Myriad::Exception::BadMessage->throw('who');
    $deadline = $raw_message{deadline} // Myriad::Exception::BadMessage->throw('deadline');
    try {
        $args = $raw_message{args} ? decode_json_utf8($raw_message{args}) : Myriad::Exception::BadMessage->throw('args');
        $stash = $raw_message{stash} ? decode_json_utf8($raw_message{stash}) : {};
        $trace = $raw_message{trace} ? decode_json_utf8($raw_message{trace}) : {};
        $response = {};
    }
    catch {
        Myriad::Exception::BadMessageEncoding->throw();
    }
}

method encode {
    try {
        return encode_json_utf8({
            rpc        => $rpc,
            message_id => $id,
            who        => $who,
            deadline   => $deadline,
            args       => encode_json_utf8($args),
            stash      => encode_json_utf8($stash),
            response   => encode_json_utf8($response),
            trace      => encode_json_utf8($trace),
        });
    }
    catch {
        Myriad::Exception::BadMessageEncoding->throw();
    }
}

1;
package Myriad::RPC::Message;

use strict;
use warnings;

# VERSION

use Object::Pad;
use Syntax::Keyword::Try;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8);

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
    $rpc = $raw_message{rpc} // die 'need the RPC name';
    $id = $raw_message{message_id} // die 'need the message id';
    $who = $raw_message{who} // die 'need the sender identifier "who"';
    $deadline = $raw_message{deadline} // die 'need a deadline';
    try {
        $args = decode_json_utf8($raw_message{args});
        $stash = decode_json_utf8($raw_message{stash});
        $response = {};
        # $trace = $raw_message{trace} ? {} : decode_json_utf8($raw_message{trace});
    }
    catch {
        # Usually decode_json errors are ugly
        die 'Failed to decode one the message JSON fields.';
    }
}

method encode {
    try {
        return encode_json_utf8({
            rpc      => $rpc,
            id       => $id,
            who      => $who,
            deadline => $deadline,
            args     => encode_json_utf8($args),
            stash    => encode_json_utf8($stash),
            response => encode_json_utf8($response),
            # trace    => encode_json_utf8($trace),
        });
    }
    catch {
        die 'Failed to encode the message into JSON string'
    }
}

1;
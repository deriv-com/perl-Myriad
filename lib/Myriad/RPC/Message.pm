package Myriad::RPC::Message;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Object::Pad;
class Myriad::RPC::Message;

use utf8;

=encoding utf8

=head1 NAME

Myriad::RPC::Message - RPC message implementation

=head1 SYNOPSIS

 Myriad::RPC::Message->new();

=head1 DESCRIPTION

This class is to handle the decoding/encoding and verification of the RPC messages received
from the transport layer. It will throw an exception when the message is invalid or doesn't
match the structure.

=cut

use Scalar::Util qw(blessed);
use Syntax::Keyword::Try;
use JSON::MaybeUTF8 qw(:v1);

has $rpc;
has $id;
has $who;
has $deadline;

has $args;
has $stash;
has $response;
has $trace;

method id { $id }
method rpc { $rpc }
method args { $args }
method who { $who }
method response :lvalue { $response }

=head2 BUILD

as per the RPC specifications this requires:

=over 4

=item * C<rpc> - The name of the procedure we are going to execute.

=item * C<message_id> - The ID of this message given by the transport.

=item * C<who> - A string that should identify the sender of the message for the transport.

=item * C<deadline> - An epoch that represents when the timeout of the message.

=item * C<args> - A JSON encoded string contains the argument of the procedure.

=item * C<stash> - A JSON encoded string contains "request" related information.

=item * C<trace> - Tracing information.

=back

Returns a L<Myriad::RPC::Message> or throw and exception.

=cut

BUILD(%request) {
    $rpc = $request{rpc} // Myriad::Exception::RPC::InvalidRequest->throw(reason => 'rpc is required');
    $id = $request{message_id} // Myriad::Exception::RPC::InvalidRequest->throw(reason => 'message_id is required');
    $who = $request{who} // Myriad::Exception::RPC::InvalidRequest->throw(reason => 'who is required');
    $deadline = $request{deadline} // Myriad::Exception::RPC::InvalidRequest->throw(reason => 'deadline is required');
    $args = $request{args} // Myriad::Exception::RPC::InvalidRequest->throw(reason => 'args is required');

    try {
        $args  = decode_json_text($args);
        $stash = $request{stash} ? decode_json_text($request{stash}) : {};
        $trace = $request{trace} ? decode_json_text($request{trace}) : {};
        $response = {};
    } catch ($e) {
        $e = Myriad::Exception::RPC::BadEncoding->new(reason => $e);
    }
}

=head2 encode

Encode the message into a JSON string

It'll throw an exception if the message can't be encoded.

=cut

method encode {
    try {
        return encode_json_utf8({
            rpc        => $rpc,
            message_id => $id,
            who        => $who,
            deadline   => $deadline,
            args       => encode_json_text($args),
            stash      => encode_json_text($stash),
            response   => encode_json_text($response),
            trace      => encode_json_text($trace),
        });
    } catch ($e) {
        Myriad::Exception::RPC::BadEncoding->throw(reason => $e);
    }
}

1;


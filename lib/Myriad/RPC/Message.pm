package Myriad::RPC::Message;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Object::Pad;
use Syntax::Keyword::Try;
use JSON::MaybeUTF8 qw(decode_json_utf8 encode_json_utf8 encode_json_text);

use Myriad::Exception::BadMessageEncoding;
use Myriad::Exception::BadMessage;

=encoding utf8

=head1 NAME

Myriad::RPC::Message - RPC message implementation

=head1 SYNOPSIS

Myriad::RPC::Message->new();

=head1 DESCRIPTION

This class is to handle the decoding/encoding and verification of the RPC messages received from the transport layer
It will throw an exception when the message is bad or doesn't match the structure.

=cut

class Myriad::RPC::Message;

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
    } catch {
        Myriad::Exception::BadMessageEncoding->throw();
    }
}

=head2 encode

Encode the message into a JSON string

It'll throw an exception if the it could not encode the message.

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
    } catch {
        Myriad::Exception::BadMessageEncoding->throw();
    }
}

1;
package Myriad::RPC::Message;

use Myriad::Class;

# VERSION
# AUTHORITY

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
has $message_id;
has $transport_id;
has $who;
has $deadline;

has $args;
has $stash;
has $response;
has $trace;

=head2 message_id

The ID of the message given by the requester.

=cut

method message_id { $message_id }

=head2 transport_id

The ID of the message given by Redis, to be used in xack later.

=cut

method transport_id { $transport_id };

=head2 rpc

The name of the procedure we are going to execute.

=cut

method rpc { $rpc }

=head2 who

A string that should identify the sender of the message for the transport.

=cut

method who { $who }

=head2 deadline

An epoch that represents when the timeout of the message.

=cut

method deadline { $deadline }

=head2 args

A JSON encoded string contains the argument of the procedure.

=cut

method args { $args }

=head2 resposne

The response to this message.

=cut

method response { $response }

method set_response ($v) { $response = $v }

=head2 stash

information related to the request should be returned back to the requester.

=cut

method stash { $stash }

=head2 trace

Tracing information.

=cut

method trace { $trace }

=head2 BUILD

Build a new message.

=cut

BUILD(%message) {
    $rpc          = $message{rpc};
    $who          = $message{who};
    $message_id   = $message{message_id};
    $transport_id = $message{transport_id};
    $deadline     = $message{deadline} || time + 30;
    $args         = $message{args} || {};
    $response     = $message{response} || {};
    $stash        = $message{stash} || {};
    $trace        = $message{trace} || {};
}


=head2 as_hash

Return a simple hash with the message data, it mustn't return nested hashes
so it will convert them to JSON encoded strings.

=cut

method as_hash () {
    my $data =  {
        rpc => $rpc,
        who => $who,
        message_id => $message_id,
        deadline => $deadline,
    };

    $self->transcode_message($data, 'encode');

    return $data;

}

=head2 from_hash

A class method which tries to parse a hash and return a L<Myriad::RPC::Message>.

The hash should comply with the format returned by C<as_hash>.

=cut

sub from_hash ($class, %hash) {
    $class->check_valid(\%hash);

    return $class->new(
        $class->transcode_message(\%hash, 'decode')->%*
    );
}

=head2 as_json

returns the message data as a JSON string.

=cut

method as_json () {
    my $data = {
        rpc        => $rpc,
        message_id => $message_id,
        who        => $who,
        deadline   => $deadline,
    };

    return encode_json_text($self->transcode_message($data, 'encode'));
}

=head2 from_json

a static method that tries to parse a JSON string
and return a L<Myriad::RPC::Message>.

=cut

sub from_json ($class, $json) {
    my $raw_message = decode_json_text($json);
    $class->check_valid($raw_message);

    return $class->new(
        $class->transcode_message($raw_message, 'decode')->%*
    );
}

=head2 check_valid

A static method used in the C<from_*> methods family to make
sure that we have the needed information.

=cut

sub check_valid ($class, $message) {
    for my $field (qw(rpc message_id who deadline args)) {
        Myriad::Exception::RPC::InvalidRequest->throw(reason => "$field is required") unless exists $message->{$field};
    }
}

my %keys_to_encode = map { $_ => 1 } qw(args response stash trace);

=head2 transcode_message

A class method to decode some field from JSON string into Perl hashes.

=cut

sub transcode_message ($class, $data, $direction) {
    my $decode = $direction eq 'encode'
    ? \&encode_json_text
    : $direction eq 'decode'
    ? \&decode_json_text
    : die 'invalid ->transcode_message direction, expecting "encode" or "decode"';

    try {
        return +{
            map {
                $_ => exists $keys_to_encode{$_}
                ? $decode->($data->{$_})
                : $_
            } keys $data->%*
        };
    } catch ($e) {
        Myriad::Exception::RPC::BadEncoding->throw(reason => $e);
    }
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


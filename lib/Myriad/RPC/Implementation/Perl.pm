package Myriad::RPC::Implementation::Perl;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Future::AsyncAwait;
use Object::Pad;

class Myriad::RPC::Implementation::Perl extends Myriad::Notifier;

=encoding utf8

=head1 NAME

Myriad::RPC::Implementation::Perl - microservice RPC server abstraction

=head1 SYNOPSIS

=head1 DESCRIPTION

This is intended for use in tests and standalone local services.

=cut

use Role::Tiny::With;
with 'Myriad::RPC';

use JSON::MaybeUTF8 qw(encode_json_utf8);

has $rpc_map;
method rpc_map :lvalue { $rpc_map }

async method listen () {}

has %pending;

=head2 call

    $resultf = $rpc->call($method, \%args)

    $result = $resultf->get

Invokes the named RPC call, passing in the given arguments given by the hash
reference. Returns a future which will eventually yield the result.

=cut

async method call ($method, $args) {
    my $resultf = Future->new;
    my $id = "$resultf";
    $pending{$id} = $resultf;

    my $msg = Myriad::RPC::Message->new(
        rpc        => $method,
        message_id => $id,
        who        => __FILE__,
        deadline   => 60,
        args       => encode_json_utf8($args),
    );

    $rpc_map->{$method}->[0]->emit($msg);

    return await $resultf;
}

async method reply_success ($message, $response) {
    my $resultf = delete $pending{$message->id} or
        return warn "Did not have a pending result future";
    $resultf->done($response);
}

async method reply_error ($message, $error) {
    my $resultf = delete $pending{$message->id} or
        return warn "Did not have a pending result future";
    $resultf->fail($error, RPC => $message);
}

async method drop ($id) {}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.

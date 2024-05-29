package Myriad::Service::Remote::RPC;

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Service::Remote::RPC - abstraction to access other services over the network.

=head1 SYNOPSIS


=head1 DESCRIPTION

=cut

use Myriad::Class;

field $myriad : param;
field $service : param;

method DESTROY { }

method AUTOLOAD (%args) {
    my ($method) = our $AUTOLOAD =~ m{^.*::([^:]+)$};
    return $myriad->rpc_client->call_rpc(
        $service,
        $method => %args
    );
}

1;


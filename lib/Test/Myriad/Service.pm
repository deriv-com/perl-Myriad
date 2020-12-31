package Test::Myriad::Service;

use strict;
use warnings;

use Scalar::Util qw(weaken);
use Sub::Util;

use Myriad::Service::Implementation;
use Myriad::Class;
use Myriad::Service::Attributes;

has $name;
has $pkg;
has $meta_service;
has $myriad;

has $default_rpc;
has $mocked_rpc;

BUILD (%args) { 
    $meta_service = delete $args{meta};
    $pkg = delete $args{pkg};
    weaken($myriad = delete $args{myriad});

    $default_rpc = {};
    $mocked_rpc = {};

    # Replace the RPC subs with a mockable
    # version if the class already exists
    try {
        if (my $methods = $myriad->registry->rpc_for($pkg)) {
            for my $method (keys $methods->%*) {
                $default_rpc->{$method} = $methods->{$method}->{code};
                $methods->{$method}->{code} = async sub {
                    if ($mocked_rpc->{$method}) {
                        return delete $mocked_rpc->{$method};
                    }
                    await $default_rpc->{$method};
                };
                $meta_service->add_method($method, async sub {'dummy'});
            }
        }
    } catch ($e) {
        $log->tracef('Myriad::Registry error while checking %s, %s', $pkg, $e);
    }
}

method add_rpc ($name, %response) {
    my $faker = async sub {
        if ($mocked_rpc->{$name}) { 
            return delete $mocked_rpc->{$name};
        } elsif (my %default_response = $default_rpc->{$name}) {
            return \%default_response;
        }
    };

    # Don't prefix the RPC name it's used in messages delivery.

    Myriad::Service::Attributes->apply_attributes(
        class => $meta_service->name,
        code => Sub::Util::set_subname($name, $faker),
        attributes => ['RPC'],
    );

    $default_rpc->{$name} = %response;
    $meta_service->add_method($name, $faker);

    $self;
}

method mock_rpc ($name, %response) {
     die 'You should define rpc methdos using "add_rpc" first' unless $default_rpc->{$name};
     die 'You cannot mock RPC call twice' if $mocked_rpc->{$name};
     $mocked_rpc->{$name} = \%response;

     $self;
}

async method call_rpc ($method, %args) {
    await $myriad->rpc_client->call_rpc($pkg, $method, %args);
}

method add_subscription ($channel, @data) {
    my $batch = async sub { 
        while (my @next = splice(@data, 0, 5)) {
            return \@next;
        }
    };

    Myriad::Service::Attributes->apply_attributes(
        class => $meta_service->name,
        code => Sub::Util::set_subname($channel, $batch),
        attributes => ['Batch'],
    );

    $meta_service->add_method("batch_$channel", $batch);

    $self
}

method add_receiver ($from, $channel, $handler) {
    my $receiver = async sub {
        my ($self, $src) = @_;
        await $src->each($handler)->completed;
    };

    Myriad::Service::Attributes->apply_attributes(
        class => $meta_service->name,
        code => Sub::Util::set_subname("receiver_$channel", $receiver),
        attributes => ["Receiver(from => '$from', channel => '$channel')"]
    );

    $meta_service->add_method("receiver_$channel", $receiver);

    $self;
}

1;


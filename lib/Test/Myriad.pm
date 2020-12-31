package Test::Myriad;

use strict;
use warnings;

use Scalar::Util qw(blessed);
use Future::AsyncAwait;
use Check::UnitCheck;

use Myriad;
use Myriad::Service::Implementation;
use Test::Myriad::Service;

our @REGISTERED_SERVICES;

my $myriad = Myriad->new();

sub import {

    sub add_service {
        my ($self, %args) = @_;
        my ($pkg, $meta);
        if (my $service = delete $args{service}) {
            $pkg = $service;
            $meta = $service->META;
        } elsif ($service = delete $args{name}) {
            $pkg  = "Test::Service::$service";
            $meta = Object::Pad->begin_class($pkg, extends => 'Myriad::Service::Implementation');

            {
                no strict 'refs';
                push @{$pkg . '::ISA' }, 'Myriad::Service';
                $Myriad::Service::SLOT{$pkg} = {
                    map { $_ => $meta->add_slot('$' . $_) } qw(api)
                };
            }
        }

        push @REGISTERED_SERVICES, $pkg;

        return Test::Myriad::Service->new(meta => $meta, pkg => $pkg, myriad => $myriad);
    }

    Check::UnitCheck::unitcheckify(sub {
        $myriad->configure_from_argv("--redis", "redis://redis");
        for my $service (@REGISTERED_SERVICES) {
            $myriad->add_service($service)->get();
        }
        $myriad->run->retain();
    });

}

1;


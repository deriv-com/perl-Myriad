package Myriad::Service::Config;

use strict;
use warnings;

our $CONFIG_REGISTRY;

use Future::AsyncAwait;
use Future::Utils qw(fmap0);

use Ryu::Observable;
use Log::Any qw($log);

use Myriad::Exception::Builder category => 'config';

sub config {
    my ($varname, %args) = @_;

    $varname = $1 if $varname =~ m/^\$(.*)$/ or die 'config name should start with $';
    my $caller = caller;

    my $observable = Ryu::Observable->new("");    
    my $default = delete $args{default};

    if ($default) {
        $observable->set_value($default);
    }

    $CONFIG_REGISTRY->{$caller}->{$varname} = {
        required => defined $default,
        holder => $observable,
    };

    {
        no strict 'refs';
        *{"${caller}::${varname}"} = \$observable;
    }
}

sub import_into {
    my ($pkg, $caller) = @_;
    {
        no strict 'refs';
        *{"${caller}::config"} = $pkg->can('config');
    }
}

async sub resolve_config {
    my ($pkg, $service_name) = @_;
    
    my @config_keys = keys $CONFIG_REGISTRY->{$pkg}->%*; 
    
    if (my $storage = $Myriad::Storage::STORAGE) {
        await fmap0(async sub {
            my $key = shift;
            my $config;
            if(
                ($config = await $storage->get('myriad.config' . $service_name . '/' . $key)) ||
                ($config = await $storage->get('myriad.config'. $pkg . '/' . $key))
            ) {
                $CONFIG_REGISTRY->{$pkg}->{$key}->{holder}->set_string($config);
            }
        }, foreach => [\@config_keys], concurrent => 8);
    }
}

1;


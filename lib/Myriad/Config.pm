package Myriad::Config;

use Myriad::Class;

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Config

=head1 DESCRIPTION

Configuration support.

=cut

use feature qw(current_sub);

use Getopt::Long qw(GetOptionsFromArray);
use Pod::Usage;
use Config::Any;
use YAML::XS;
use List::Util qw(pairmap);
use Ryu::Observable;
use Myriad::Storage;

use Myriad::Exception::Builder category => 'config';

declare_exception 'ConfigRequired' => (
    message => 'A required configueration key was not set'
);

declare_exception 'UnregisteredConfig' => (
    message => 'Config should be registered by calling "config" before usage'
);

=head1 PACKAGE VARIABLES

=head2 DEFAULTS

The C<< %DEFAULTS >> hash provides base values that will be used if no other
configuration file, external storage or environment variable provides an
alternative.

=cut

# Default values

our %DEFAULTS = (
    config_path            => 'config.yml',
    transport_redis        => 'redis://localhost:6379',
    transport_cluster      => 0,
    log_level              => 'info',
    library_path           => '',
    opentracing_host       => 'localhost',
    opentracing_port       => 6832,
    subscription_transport => undef,
    rpc_transport          => undef,
    storage_transport      => undef,
    transport              => 'redis',
    service_name           => '',
);

=head2 SHORTCUTS_FOR

The C<< %SHORTCUTS_FOR >> hash allows commandline shortcuts for common parameters.

=cut

our %SHORTCUTS_FOR = (
    c   => 'config_path',
    l   => 'log_level',
    lib => 'library_path',
    t   => 'transport',
    s   => 'service_name',
);


=head2 SERVICES_CONFIG

A registry of configs defined by the services using the C<< config  >> helper.

=cut

our %SERVICES_CONFIG;

# Our configuration so far. Populated via L</BUILD>,
# can be updated by other mechanisms later.
has $config;

BUILD (%args) {
    $config //= {};
    $config->{services} //= {};
    # Parameter order in decreasing order of preference:
    # - commandline parameter
    # - environment
    # - config file
    # - defaults

    $self->from_args($args{commandline});

    $log->tracef('Defaults %s, shortcuts %s, args %s', \%DEFAULTS, \%SHORTCUTS_FOR, \%args);
    $self->from_env();

    $config->{config_path} //= $DEFAULTS{config_path};
    $self->from_file();

    $config->{$_} //= $DEFAULTS{$_} for keys %DEFAULTS;

    # Populate transports with the default transport if they are not already
    # configured by the developer

    $config->{$_} //= $config->{transport} for qw(rpc_transport subscription_transport storage_transport);

    push @INC, split /,:/, $config->{library_path} if $config->{library_path};

    $config->{$_} = Ryu::Observable->new($config->{$_}) for grep { not ref $_ } keys %$config;

    $log->debugf("Config is %s", $config);
}

method key ($key) { return $config->{$key} // die 'unknown config key ' . $key }

method define ($key, $v) {
    die 'already exists - ' . $key if exists $config->{$key} or exists $DEFAULTS{$key};
    $config->{$key} = $DEFAULTS{$key} = Ryu::Observable->new($v);
}

method parse_subargs ($subarg, $root, $value) {
    $subarg =~ s/(.*)[_|\.](configs?|instances?)(.*)/$2$3/;
    die 'invalid service name' unless $2;

    my $service_name = $1;
    $service_name =~ s/_/\./g;
    $root = $root->{$service_name} //= {};

    my @sublist = split /_|\./, $subarg;
    die 'config key is not formated correctly' unless @sublist;
    while (@sublist > 1) {
        my $level = shift @sublist;
        $root->{$level} //= {};
        $root= $root->{$level};
    }
    $root->{$sublist[0]} = $value;
}

method from_args ($commandline) {
    return unless $commandline;
    my $error;

    while (1) {
        last unless $commandline->@* && ($commandline->[0] =~ /--?./);

        my $arg = shift $commandline->@*;
        $arg =~ s/--?//;
        ($arg, my $value) = split '=', $arg;

        # First match arg with expected keys
        my $key = exists $DEFAULTS{$arg} ? $arg : $SHORTCUTS_FOR{$arg};
        if ($key) {
            $value = shift $commandline->@* unless $value;
            $config->{$key} = $value;
        } elsif ($arg =~ s/services?[_|\.]//) { # are we doing service config
            $value = shift $commandline->@* unless $value;
            try {
                $self->parse_subargs($arg, $config->{services}, $value);
            } catch {
                $error = "looks like $arg format is wrong can't parse it!";
                last;
            }
        } else {
            $error = "don't know how to deal with option $arg";
            last
        }
    }

    if ($error) {
        $log->error($error);
        die pod2usage(1);
    }
}

method from_env () {
    $config->{$_} //= delete $ENV{'MYRIAD_' . uc($_)} for grep { exists $ENV{'MYRIAD_' . uc($_)} } keys %DEFAULTS;
    map {
        $_ =~ s/(MYRIAD_SERVICES?_)//;
        $self->parse_subargs(lc($_), $config->{services}, $ENV{$1 . $_});
    } (grep {$_ =~ /MYRIAD_SERVICES?_/} keys %ENV);
}

method from_file () {
    if(-r $config->{config_path}) {
        my ($override) = Config::Any->load_files({
            files   => [ $config->{config_path} ],
            use_ext => 1
        })->@*;

        $log->debugf('override is %s', $override);

        my %expanded = pairmap {
                ref($b) ? $b->%* : ($a => $b)
        } $override->%*;

        $config->{$_} //= $expanded{$_} for sort keys %expanded;

        # Merge the services config
        $config->{services}  = {
            $expanded{services}->%*,
            $config->{services}->%*,
        } if $expanded{services};
    }
}

async method service_config ($pkg, $service_name) {
    my $service_config = {};
    $service_name =~ s/\[(.*)\]$//;
    my $instance = $1;
    my $available_config = $config->{services}->value->{$service_name}->{configs};

    my $instance_overrides = {};
    $instance_overrides =
        $config->{services}->value->{$service_name}->{instances}->{$instance}->{configs} if $instance;
    if(my $declared_config = $SERVICES_CONFIG{$pkg}) {
        for my $key (keys $declared_config->%*) {
            my $value = await $self->from_storage($service_name, $instance, $key);
            $value //= $instance_overrides->{$key} ||
                       $available_config->{$key} ||
                       $declared_config->{$key}->{default} ||
                       Myriad::Exception::Config::ConfigRequired->throw(reason => $key);
            $value = Myriad::Utils::Secure->new($value) if $declared_config->{$key}->{secure};
            $service_config->{$key} = Ryu::Observable->new($value);
        }
    }

    return $service_config;
}

async method from_storage ($service_name, $instance, $key) {
    my $storage = $Myriad::Storage::STORAGE;
    if ($storage) {
        $service_name .= "[$instance]" if $instance;
        # Todo: Once we enable root namespace we should change this
        await $storage->get("myriad.config.service.$service_name.$key");
    }
}

method DESTROY { }

method AUTOLOAD () {
    my ($k) = our $AUTOLOAD =~ m{^.*::([^:]+)$};
    die 'unknown config key ' . $k unless blessed $config->{$k} && $config->{$k}->isa('Ryu::Observable');
    my $code = method () { return $self->key($k); };
    { no strict 'refs'; *$k = $code; }
    return $self->$code();
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


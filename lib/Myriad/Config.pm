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

=head1 PACKAGE VARIABLES

=head2 DEFAULTS

The C<< %DEFAULTS >> hash provides base values that will be used if no other
configuration file, external storage or environment variable provides an
alternative.

=cut

# Default values

our %DEFAULTS = (
    config_path            => 'config.yml',
    redis_uri              => 'redis://localhost:6379',
    log_level              => 'info',
    library_path           => '',
    opentracing_host       => 'localhost',
    opentracing_port       => 6832,
    subscription_transport => undef,
    rpc_transport          => undef,
    storage_transport      => undef,
    transport_default      => 'perl',
    service_name           => '',
);

=head2 SHORTCUTS_FOR

The C<< %SHORTCUTS_FOR >> hash allows commandline shortcuts for common parameters.

=cut

our %SHORTCUTS_FOR = (
    config_path       => [qw(c)],
    log_level         => [qw(l)],
    library_path      => [qw(lib)],
    transport_default => [qw(t)],
    service_name      => [qw(s)],
);

# Our configuration so far. Populated via L</BUILD>,
# can be updated by other mechanisms later.
has $config;

BUILD (%args) {
    $config //= {};

    # Parameter order in decreasing order of preference:
    # - commandline parameter
    # - environment
    # - config file
    # - defaults
    $log->tracef('Defaults %s, shortcuts %s, args %s', \%DEFAULTS, \%SHORTCUTS_FOR, \%args);
    if($args{commandline}) {
        GetOptionsFromArray(
            $args{commandline},
            $config,
            map {
                join('|', $_, ($SHORTCUTS_FOR{$_} || [])->@*) . '=s',
            } sort keys %DEFAULTS,
        ) or die pod2usage(1);
    }

    $config->{$_} //= $ENV{'MYRIAD_' . uc($_)} for grep { exists $ENV{'MYRIAD_' . uc($_)} } keys %DEFAULTS;

    $config->{config_path} //= $DEFAULTS{config_path};
    if(defined $config->{config_path} and -r $config->{config_path}) {
        my ($override) = Config::Any->load_files({
            files   => [ $config->{config_path} ],
            use_ext => 1
        })->@*;
        $log->debugf('override is %s', $override);
        my %expanded = (sub {
            my ($item, $prefix) = @_;
            my $code = __SUB__;
            $log->tracef('Checking %s with prefix %s', $item, $prefix);
            # Recursive expansion for any nested data
            return pairmap {
                ref($b)
                ? $code->(
                    $b,
                    join('_', $prefix // (), $a),
                )
                : ($a => $b)
            } %$item
        })->($override);
        $config->{$_} //= $expanded{$_} for sort keys %expanded;
    }

    $config->{$_} //= $DEFAULTS{$_} for keys %DEFAULTS;

    # Populate transports with the default transport if they are not already
    # configured by the developer

    $config->{$_} //= $config->{transport_default} for qw(rpc_transport subscription_transport storage_transport);

    push @INC, split /,:/, $config->{library_path} if $config->{library_path};
    $config->{$_} = Ryu::Observable->new($config->{$_}) for keys %$config;
    $log->debugf("Config is %s", $config);
}

method key ($key) { return $config->{$key} // die 'unknown config key ' . $key }

method define ($key, $v) {
    die 'already exists - ' . $key if exists $config->{$key} or exists $DEFAULTS{$key};
    $config->{$key} = $DEFAULTS{$key} = Ryu::Observable->new($v);
}

method DESTROY { }

method AUTOLOAD () {
    my ($k) = our $AUTOLOAD =~ m{^.*::([^:]+)$};
    # We enforce `_` because everything should be namespaced
    die 'unknown k ' . $k unless $k =~ /_/;
    die 'unknown config key ' . $k unless exists $config->{$k};
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


package Myriad::Config;

use strict;
use warnings;

use Object::Pad;

class Myriad::Config;

no indirect;

=head1 NAME

Myriad::Config

=head1 DESCRIPTION

Configuration support.

=cut

use Getopt::Long qw(GetOptionsFromArray);
use Config::Any;
use YAML::XS;
use List::Util qw(pairmap);
use Log::Any qw($log);
use feature qw(current_sub);

=head1 PACKAGE VARIABLES

=head2 DEFAULTS

The C<< %DEFAULTS >> hash provides base values that will be used if no other
configuration file, external storage or environment variable provides an
alternative.

=cut

# Default values

our %DEFAULTS = (
    config_path => 'config.yml',
    redis_host  => 'localhost',
    redis_port  => '6379',
);

=head2 SHORTCUTS_FOR

The C<< %SHORTCUTS_FOR >> hash allows commandline shortcuts for common parameters.

=cut

our %SHORTCUTS_FOR = (
    config_path => [qw(c)],
    redis_host  => [qw(h)],
    redis_port  => [qw(p)],
);

has $config;

method BUILD (@args) {
    $config //= {};
    # Parameter order in decreasing order of preference:
    # - commandline parameter
    # - environment
    # - config file
    # - defaults
    $log->tracef('Defaults %s, shortcuts %s, args %s', \%DEFAULTS, \%SHORTCUTS_FOR, \@args);
    GetOptionsFromArray(
        \@args,
        $config,
        map {
            join('|', $_, ($SHORTCUTS_FOR{$_} || [])->@*) . '=s',
        } sort keys %DEFAULTS,
    ) or die pod2usage(1);

    $config->{$_} //= $ENV{'MYRIAD_' . uc($_)} for grep { exists $ENV{'MYRIAD_' . uc($_)} } keys %DEFAULTS;

    $config->{config_path} //= $DEFAULTS{config_path};
    if(defined $config->{config_path} and -r $config->{config_path}) {
        my ($override) = Config::Any->load_files({
            files => [ $config->{config_path} ],
            use_ext => 1
        })->@*;
        $log->debugf('override is %s', $override);
        my %expanded = (sub {
            my ($item, $prefix) = @_;
            my $code = __SUB__;
            $log->tracef('Checking %s with prefix %s', $item, $prefix);
            pairmap {
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

    $log->debugf("Config is %s", $config);
    return @args;
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


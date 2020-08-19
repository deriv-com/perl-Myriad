#!perl
use strict;
use warnings;

=head1 NAME

myriad.pl

=head1 DESCRIPTION

=cut

use Myriad;
use Time::Moment;
use Sys::Hostname qw(hostname);

use Log::Any::Adapter qw(Stderr), log_level => 'info';
use Log::Any qw($log);

use Myriad::UI::Readline;

my $hostname = hostname();
$log->infof('Starting Myriad on %s pid %d at %s', $hostname, $$, Time::Moment->now->to_string);
my $myriad = Myriad->new(
    hostname => hostname(),
    pid      => $$,
);
$myriad->configure_from_argv(@ARGV)->get;
$myriad->run;

package Myriad::Service::Attributes;

use strict;
use warnings;

# VERSION

=head1 Attributes

Each of these is an attribute that can be applied to a method.

=cut

use Attribute::Handlers;

use Log::Any qw($log);

use Exporter qw(import export_to_level);

our @IMPORT = our @IMPORT_OK = qw(RPC);

=head2 RPC

Mark this method as a callable RPC method.

=cut

sub RPC:ATTR {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    die 'Invalid attribute - should be applied to a coderef' unless ref($referent) eq 'CODE';
    $log->debugf(
        'Marking %s::%s as an RPC method (%s) via %s at %s:%d',
        $package,
        *{$symbol}{NAME},
        $data,
        $phase,
        $filename,
        $linenum
    );
}

sub Stream:ATTR {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    die 'Invalid attribute - should be applied to a coderef' unless ref($referent) eq 'CODE';
    $log->debugf(
        'Marking %s::%s as a Stream method (%s) via %s at %s:%d',
        $package,
        *{$symbol}{NAME},
        $data,
        $phase,
        $filename,
        $linenum
    );
}

1;


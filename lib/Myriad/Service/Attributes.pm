package Myriad::Service::Attributes;

use strict;
use warnings;

use Attribute::Handlers;

use Log::Any qw($log);
 
=head1 Attributes

Each of these is an attribute that can be applied to a method.

=head2 RPC

Mark this method as 

=cut

use Exporter qw(import export_to_level);

our @IMPORT = our @IMPORT_OK = qw(RPC);

sub RPC:ATTR {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    $log->debugf(
        'Marking %s::%s as an RPC method (%s) via %s at %s:%d',
        ref($referent),
        *{$symbol}{NAME},
        $data,
        $phase,
        $filename,
        $linenum
    );
}

1;


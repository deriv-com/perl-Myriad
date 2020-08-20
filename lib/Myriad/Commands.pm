package Myriad::Commands;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Object::Pad;

class Myriad::Commands;

no indirect qw(fatal);

=head1 NAME

Myriad::Commands

=head1 DESCRIPTION

Provides top-level commands, such as loading a service or making an RPC call.

=cut

use Future::AsyncAwait;
use Syntax::Keyword::Try;

use Module::Runtime qw(require_module);

use Log::Any qw($log);

has $myriad;

BUILD (%args) {
    Scalar::Util::weaken($myriad = $args{myriad} // die 'needs a Myriad parent object');
}

async method service (@args) {
    my @modules;
    while(my $entry = shift @args) {
        if($entry =~ /^[a-z0-9_:]+$/i) {
            push @modules, $entry;
        } else {
            die 'unsupported module format ' . $entry;
        }
    }
    my $loop = IO::Async::Loop->new;
    for my $module (@modules) {
        $log->infof('Loading %s', $module);
        require_module($module);
        $loop->add(
            my $srv = $module->new(
                redis => $myriad->redis,
                myriad => $myriad,
            )
        );
        await $srv->startup;
        await $srv->diagnostics(1);
    }
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


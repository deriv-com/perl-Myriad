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
use Future::Utils qw(fmap0);

use Module::Runtime qw(require_module);

use Log::Any qw($log);

has $myriad;

BUILD (%args) {
    Scalar::Util::weaken($myriad = $args{myriad} // die 'needs a Myriad parent object');
}

=head2 service

Attempts to load and start one or more services.

=cut

async method service (@args) {
    my @modules;
    while(my $entry = shift @args) {
        if($entry =~ /,/) {
            unshift @args, split /,/, $entry;
        } elsif(my ($base) = $entry =~ m{^([a-z0-9_:]+)::$}i) {
            require Module::Pluggable::Object;
            my $search = Module::Pluggable::Object->new(
                search_path => [ $base ]
            );
            push @modules, $search->plugins;
        } elsif($entry =~ /^[a-z0-9_:]+[a-z0-9_]$/i) {
            push @modules, $entry;
        } else {
            die 'unsupported ' . $entry;
        }
    }

    await fmap0(async sub {
        my ($module) = @_;
        $log->debugf('Loading %s', $module);
        require_module($module);
        await $myriad->add_service($module);
    }, foreach => \@modules, concurrent => 4);
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


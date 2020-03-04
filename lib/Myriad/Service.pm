package Myriad::Service;

use strict;
use warnings;

use Object::Pad;
use Future::AsyncAwait;

class Myriad::Service extends Myriad::Notifier;
use parent qw(
    Myriad::Service::Attributes
);

use utf8;

=encoding utf8

=head1 NAME

Myriad::Service - microservice coördination

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Myriad::Service::Attributes;

# Member variables

has $redis;
has $service_name;

=head1 METHODS

=head2 diagnostics

Runs any internal diagnostics.

=cut

async method diagnostics {
    return;
}

=head2 configure

Populate internal configuration.

=cut

method configure(%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $service_name = delete $args{name} if exists $args{name};
    $self->next::method(%args);
}

method redis { $redis }
method service_name { $service_name //= lc(ref($self) =~ s{::}{_}gr) }

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 CONTRIBUTORS

=over 4

=item * Tom Molesworth C<< TEAM@cpan.org >>

=item * Paul Evans C<< PEVANS@cpan.org >>

=back

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


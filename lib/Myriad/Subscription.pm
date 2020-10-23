package Myriad::Subscription;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);
use utf8;

=encoding utf8

=head1 NAME

Myriad::Subscription - microservice Subscription abstraction

=head1 SYNOPSIS

 my $sub = Myriad::Subscription->new();

=head1 DESCRIPTION

=cut

use Myriad::Subscription::Implementation::Redis;
use Myriad::Subscription::Implementation::Perl;

sub new {
    my ($class, %args) = @_;
    my $transport = delete $args{transport};

    if ($transport eq 'redis') {
        return Myriad::Subscription::Implementation::Redis->new(%args);
    } else {
        return Myriad::Subscription::Implementation::Perl->new(%args);
    }
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


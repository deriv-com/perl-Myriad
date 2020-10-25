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

    # Passing args individually looks tedious but this is to avoid
    # L<IO::Async::Notifier> exception when it doesn't recognize the key.

    if ($transport eq 'redis') {
        return Myriad::Subscription::Implementation::Redis->new(
            redis   => $args{redis},
            ryu     => $args{ryu},
            service => $args{service},
        );
    } else {
        return Myriad::Subscription::Implementation::Perl->new(
            service => $args{service},
        );
    }
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


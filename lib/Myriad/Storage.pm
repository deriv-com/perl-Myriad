package Myriad::Storage;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);
use utf8;

=encoding utf8

=head1 NAME

Myriad::Storage - microservice Storage abstraction

=head1 SYNOPSIS

 my $storage = Myriad::Storage->new();

=head1 DESCRIPTION

=cut

use Myriad::Role::Storage;

use Myriad::Storage::Implementation::Redis;
use Myriad::Storage::Implementation::Perl;

sub new {
    my ($class, %args) = @_;
    my $transport = delete $args{transport};

    # Passing args individually looks tedious but this is to avoid
    # L<IO::Async::Notifier> exception when it doesn't recognize the key.

    if ($transport eq 'redis') {
        return Myriad::Storage::Implementation::Redis->new(
            redis   => $args{redis},
        );
    } else {
        return Myriad::Storage::Implementation::Perl->new();
    }
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


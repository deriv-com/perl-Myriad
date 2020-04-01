package Myriad;

use strict;
use warnings;

use utf8;

=encoding utf8

=head1 NAME

Myriad - microservice coördination

=head1 SYNOPSIS

 use Myriad;
 Myriad->new(@ARGV)->run;

=head1 DESCRIPTION

=cut

use Myriad::Transport::Redis;
use Myriad::Transport::HTTP;

use Scalar::Util qw(blessed weaken);
use Log::Any qw($log);
use Log::Any::Adapter qw(Stderr), log_level => 'trace';

=head2 loop

Returns the main L<IO::Async::Loop> instance for this process.

=cut

sub loop { shift->{loop} //= IO::Async::Loop->new }

=head2 new

Instantiates.

Currently takes no useful parameters.

=cut

sub new {
    my $class = shift;
    bless { @_ }, $class
}

=head2 redis

The L<Net::Async::Redis> (or compatible) instance used for service coördination.

=cut

sub redis {
    my ($self, %args) = @_;
    $self->{redis} //= do {
        $self->loop->add(
            my $redis = Myriad::Transport::Redis->new
        );
        $redis
    };
}

=head2 add_service

Instantiates and adds a new service to the L</loop>.

Returns the service instance.

=cut

sub add_service {
    my ($self, $srv, %args) = @_;
    $srv = $srv->new(
        redis => $self->redis
    ) unless blessed($srv) and $srv->isa('Myriad::Service');
    my $name = $args{name} || $srv->service_name;
    $log->infof('Add service [%s]', $name);
    $self->loop->add(
        $srv
    );
    my $k = Scalar::Util::refaddr($srv);
    Scalar::Util::weaken($self->{services_by_name}{$name} = $srv);
    $self->{services}{$k} = $srv;
}
    
sub service_by_name {
    my ($self, $k) = @_;
    $self->{services_by_name}{$k} // die 'service ' . $k . ' not found';
}

=head2 run

Starts the main loop.

=cut

sub run {
    my ($self) = @_;
    $self->loop->attach_signal(TERM => sub {
        $log->infof('TERM received, exit');
        $self->loop->stop;
    });
    $self->loop->attach_signal(QUIT => sub {
        $log->infof('QUIT received, exit');
        $self->loop->stop;
    });
    $self->loop->run;
}

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


package Myriad;

use strict;
use warnings;

use utf8;

our $VERSION = '0.001';

=encoding utf8

=head1 NAME

Myriad - microservice coördination

=head1 SYNOPSIS

 use Myriad;
 Myriad->new(@ARGV)->run;

=head1 DESCRIPTION

Myriad provides a framework for dealing with asynchronous, microservice-based code.
It is intended for use in an environment such as Kubernetes to support horizontal
scaling for larger systems.

=head2 Do you need this?

If you expect to be dealing with more traffic than a single server can handle,
or you have a development team larger than 30-50 or so, this might be of interest.

For a smaller system with a handful of users, it's I<probably> overkill!

=head1 METHODS

=cut

use Myriad::Exception;

use Myriad::Transport::Redis;
use Myriad::Transport::HTTP;

use Scalar::Util qw(blessed weaken);
use Log::Any qw($log);
use Log::Any::Adapter qw(Stderr), log_level => 'info';

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

=head2 http

The L<Net::Async::HTTP::Server> (or compatible) instance used for health checks
and metrics.

=cut

sub http {
    my ($self, %args) = @_;
    $self->{http} //= do {
        $self->loop->add(
            my $http = Myriad::Transport::HTTP->new
        );
        $http
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

=head2 service_by_name

Looks up the given service, returning the instance if it exists.

Will throw an exception if the service cannot be found.

=cut

sub service_by_name {
    my ($self, $k) = @_;
    return $self->{services_by_name}{$k} // Myriad::Exception->throw('service ' . $k . ' not found');
}

=head2 shutdown

Requests shutdown.

=cut

sub shutdown {
    my ($self) = @_;
    my $f = $self->{shutdown}
        or die 'attempting to shut down before we have started, this will not end well';
    $f->done unless $f->is_ready;
    $f
}

=head2 shutdown_future

Returns a copy of the shutdown L<Future>.

This would resolve once the process is about to shut down,
triggered by a fault or a Unix signal.

=cut

sub shutdown_future {
    my ($self) = @_;

    return $self->{shutdown_without_cancel} //= (
        $self->{shutdown} //= $self->loop->new_future->set_label('shutdown')
    )->without_cancel;
}

=head2 run

Starts the main loop.

Applies signal handlers for TERM and QUIT, then starts the loop.

=cut

sub run {
    my ($self) = @_;
    $self->loop->attach_signal(TERM => sub {
        $log->infof('TERM received, exit');
        $self->shutdown
    });
    $self->loop->attach_signal(QUIT => sub {
        $log->infof('QUIT received, exit');
        $self->shutdown
    });
    $self->shutdown_future->await;
}

1;

__END__

=head1 SEE ALSO

=head2 Perl

Microservices are hardly a new concept, and there's a lot of prior art out there.
Here are a list of the Perl implementations that we're aware of:

=head2 Java

As the textbook "enterprise-scale platform", Java naturally fits a microservice theme.

=over 4

=item * L<Spring Boot|https://spring.io/guides/gs/spring-boot/> - One of the frameworks that integrate well 
with the traditional Java ecosystem depends on HTTP as a transport, there is no unified storage layer the developer can import DB connector of his choice.

=item * L<Micronaut|https://micronaut.io/> - This framework has many integrations with industry-standard solutions like (SQL, MongoDB, Kafka, Redis, gRPC)
they have integration guides with cloud-native solutions (AWS, GCP ...etc).

=item * L<DropWizard|https://www.dropwizard.io/en/stable/> - A minimal framework that provides a RESTful interface and storage layer using Hibernate.

=item * L<Helidon|https://helidon.io/> - Oracle's open source attempt, provides support for two types of transport and SQL access layer using standard Java's packages,
 built with cloud-native deployment in mind.

=back

=head2 Python

Most of Python's frameworks provide tools to facilitate building logic blocks behind APIs (Flask, Django ..etc)
for work distribution L<Celery|https://docs.celeryproject.org/en/stable/> is used as a task queue abstraction.

=head2 Rust

=head2 JS

JS has many frameworks that help to implement the microservice architecture, some are:

=over 4

=item * L<Moleculer|https://moleculer.services/>

=item * L<Seneca|https://senecajs.org/>

=back

Cloud platforms also have some degree of microservice support:

=over 4

=item * L<AWS Lambda|https://aws.amazon.com/lambda> - trigger small containers based on logic, typically combined
with other AWS services for data storage, message sending and other actions

=item * L<Google App Engine> - Google's own attempt

=item * L<Heroku|https://www.heroku.com/> - Allow developers to build a microservices architecture based on the services they provide
like the example they mentioned in this L<blog|https://devcenter.heroku.com/articles/event-driven-microservices-with-apache-kafka>

=back

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 CONTRIBUTORS

=over 4

=item * Tom Molesworth C<< TEAM@cpan.org >>

=item * Paul Evans C<< PEVANS@cpan.org >>

=back

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


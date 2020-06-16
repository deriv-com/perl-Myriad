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

=head1 Modules and code layout

=over 4

=item * L<Myriad::Storage> - abstraction layer for storage, available as C<< $self->storage >> within services

=item * L<Myriad::RPC> - the RPC abstraction layer, in C<< $self->rpc >>

=item * L<Myriad::Subscription> - the subscription handling layer, in C<< $self->subscription >>

=back

Each of the three abstractions has various implementations, you'd set one on startup
and that would provide functionality through the top-level abstraction layer.

=head2 Storage

The L<Myriad::Storage> abstract API is a good starting point here.

For storage, we have:

=over 4

=item * L<Myriad::Storage::Redis>

=item * L<Myriad::Storage::PostgreSQL>

=item * L<Myriad::Storage::Perl>

=back

=head2 RPC

Simple request/response patterns are handled with the L<Myriad::RPC> layer ("remote procedure call").

Details on the request are in L<Myriad::RPC::Request> and the response to be sent back is in L<Myriad::RPC::Response>.

=over 4

=item * L<Myriad::RPC::Redis>

=item * L<Myriad::RPC::PostgreSQL>

=item * L<Myriad::RPC::Perl>

=item * L<Myriad::RPC::AMQP>

=back

and subscriptions:

=over 4

=item * L<Myriad::Subscription::Redis>

=item * L<Myriad::Subscription::PostgreSQL>

=item * L<Myriad::Subscription::Perl>

=item * L<Myriad::Subscription::AMQP>

=back

Note that I<some layers don't have implementations for all transports> - MQ for example does not really provide a concept of "storage".

Each of these implementations is supposed to separate out the logic from the actual transport calls, so there's a separate ::Transport set of classes here:

=over 4

=item * L<Myriad::Transport::Redis>

=item * L<Myriad::Transport::PostgreSQL>

=item * L<Myriad::Transport::Perl>

=item * L<Myriad::Transport::AMQP>

=back

which deal with the lower-level interaction with the protocol, connection management and so on. More details on that
can be found in L<Myriad::Transport> - but it's typically only useful for people working on the L<Myriad> implementation itself.

Other classes of note:

=over 4

=item * L<Myriad::Exception> - generic errors, provides L<Myriad::Exception/throw> and we recommend that all errors inherit from this

=item * L<Myriad::Plugin> - adds specific functionality to services

=item * L<Myriad::Bootstrap> - startup used in C<myriad.pl> for providing autorestart and other functionality

=item * L<Myriad::Service> - base class for a service

=item * L<Myriad::Registry> - support for registering services and methods within the current process

=item * L<Myriad::Config> - general config support, commandline/file/storage

=item * L<Myriad::Notifier> - L<IO::Async::Notifier> layer, probably due for removal

=back

=head1 METHODS

=cut

use Myriad::Exception;

use Myriad::Transport::Redis;
use Myriad::Transport::HTTP;

use Scalar::Util qw(blessed weaken);
use Log::Any qw($log);
use Log::Any::Adapter;

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

=head2 setup_logging

Prepare for logging.

=cut

sub setup_logging {
    my ($self) = @_;
    Log::Any::Adapter->import(
        qw(Stderr),
        log_level => 'info'
    );
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

Microservices are hardly a new concept, and there's a lot of prior art out there.

Key features that we attempt to provide:

=over 4

=item * B<atomic storage> - being able to record something in storage as part of the same transaction as acknowledging a message

=item * B<flexible backends> - support for various storage, RPC and subscription implementations, allowing for mix+match

=item * B<zero transport option> - for testing and smaller deployments, you might want to run everything in a single process

=item * B<language-agnostic> - implementations should be possible in languages other than Perl

=item * B<first-class Kubernetes support> - k8s is not required, but when available we should play to its strengths

=item * B<minimal boilerplate> - with an emphasis on rapid prototyping

=back


=head2 Perl

Here are a list of the Perl microservice implementations that we're aware of:

=over 4

=item * L<https://github.com/jmico/beekeeper> - MQ-based (via STOMP), using L<AnyEvent>

=item * L<https://mojolicious.org> - more of a web framework, but a popular one

=back

=head2 Java

Although this is the textbook "enterprise-scale platform", Java naturally fits a microservice theme.

=over 4

=item * L<Spring Boot|https://spring.io/guides/gs/spring-boot/> - One of the frameworks that integrates well
with the traditional Java ecosystem, depends on HTTP as a transport. Although there is no unified storage layer,
database access is available through connectors.

=item * L<Micronaut|https://micronaut.io/> - This framework has many integrations with industry-standard solutions - SQL, MongoDB, Kafka, Redis, gRPC - and they have integration guides for cloud-native solutions such as AWS or GCP.

=item * L<DropWizard|https://www.dropwizard.io/en/stable/> - A minimal framework that provides a RESTful interface and storage layer using Hibernate.

=item * L<Helidon|https://helidon.io/> - Oracle's open source attempt, provides support for two types of transport and SQL access layer using standard Java's packages,
 built with cloud-native deployment in mind.

=back

=head2 Python

Most of Python's frameworks provide tools to facilitate building logic blocks behind APIs (Flask, Django ..etc).

For work distribution, L<Celery|https://docs.celeryproject.org/en/stable/> is commonly used as a task queue abstraction.

=head2 Rust

=over 4

=item * L<https://rocket.rs/> - although this is a web framework, rather than a complete microservice system,
it's reasonably popular for the request/response part of the equation

=item * L<https://actix.rs/> - another web framework, this time with a focus on the actor pattern

=back

=head2 JS

JS has many frameworks that help to implement the microservice architecture, some are:

=over 4

=item * L<Moleculer|https://moleculer.services/>

=item * L<Seneca|https://senecajs.org/>

=back

=head2 Cloud providers

Microservice support at the provider level:

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

=item * Eyad Arnabeh

=back

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


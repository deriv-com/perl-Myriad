# NAME

Myriad - microservice coördination

[![Coverage status](https://coveralls.io/repos/github/binary-com/perl-Myriad/badge.svg?branch=master)](https://coveralls.io/github/binary-com/perl-Myriad?branch=master)
[![Test status](https://circleci.com/gh/binary-com/perl-Myriad.svg?style=shield&circle-token=55b191c6582ef5932e57b142fb29d8e13ae19598)](https://app.circleci.com/pipelines/github/binary-com/perl-Myriad)
[![Docker](https://img.shields.io/docker/pulls/deriv/myriad.svg)](https://hub.docker.com/r/deriv/myriad)

# SYNOPSIS

    use Myriad;
    Myriad->new->run;

# DESCRIPTION

Myriad provides a framework for dealing with asynchronous, microservice-based code.
It is intended for use in an environment such as Kubernetes to support horizontal
scaling for larger systems.

Overall this framework encourages - but does not enforce - single-responsibility
in each microservice: each service should integrate with at most one external system,
and integration should be kept in separate services from business logic or aggregation.
This is at odds with common microservice frameworks, so perhaps it would be more accurate
to say that this framework is aimed at developing "nanoservices" instead.

## Do you need this?

If you expect to be dealing with more traffic than a single server can handle,
or you have a development team larger than 30-50 or so, this might be of interest.

For a smaller system with a handful of users, it's _probably_ overkill!

# Modules and code layout

- [Myriad::Service](https://metacpan.org/pod/Myriad%3A%3AService) - load this in your own code to turn it into a microservice
- [Myriad::RPC](https://metacpan.org/pod/Myriad%3A%3ARPC) - the RPC abstraction layer, in `$self->rpc`
- [Myriad::Storage](https://metacpan.org/pod/Myriad%3A%3AStorage) - abstraction layer for storage, available as `$self->storage` within services
- [Myriad::Subscription](https://metacpan.org/pod/Myriad%3A%3ASubscription) - the subscription handling layer, in `$self->subscription`

Each of the three abstractions has various implementations. You'd set one on startup
and that would provide functionality through the top-level abstraction layer. Service code
generally shouldn't need to care which implementation is applied. There may however be cases
where transactional behaviour differs between implementations, so there is some basic
functionality planned for checking whether RPC/storage/subscription use the same underlying
mechanism for transactional safety.

## Storage

The [Myriad::Storage](https://metacpan.org/pod/Myriad%3A%3AStorage) abstract API is a good starting point here.

For storage implementations, we have:

- [Myriad::Storage::Redis](https://metacpan.org/pod/Myriad%3A%3AStorage%3A%3ARedis)
- [Myriad::Storage::PostgreSQL](https://metacpan.org/pod/Myriad%3A%3AStorage%3A%3APostgreSQL)
- [Myriad::Storage::Memory](https://metacpan.org/pod/Myriad%3A%3AStorage%3A%3AMemory)

Additional transport mechanisms may be available, see CPAN for details.

## RPC

Simple request/response patterns are handled with the [Myriad::RPC](https://metacpan.org/pod/Myriad%3A%3ARPC) layer ("remote procedure call").

Details on the request are in [Myriad::RPC::Request](https://metacpan.org/pod/Myriad%3A%3ARPC%3A%3ARequest) and the response to be sent back is in [Myriad::RPC::Response](https://metacpan.org/pod/Myriad%3A%3ARPC%3A%3AResponse).

- [Myriad::RPC::Redis](https://metacpan.org/pod/Myriad%3A%3ARPC%3A%3ARedis)
- [Myriad::RPC::PostgreSQL](https://metacpan.org/pod/Myriad%3A%3ARPC%3A%3APostgreSQL)
- [Myriad::RPC::Memory](https://metacpan.org/pod/Myriad%3A%3ARPC%3A%3AMemory)

Additional transport mechanisms may be available, see CPAN for details.

## Subscriptions

The [Myriad::Subscription](https://metacpan.org/pod/Myriad%3A%3ASubscription) abstraction layer defines the available API here.

Subscription implementations include:

- [Myriad::Subscription::Redis](https://metacpan.org/pod/Myriad%3A%3ASubscription%3A%3ARedis)
- [Myriad::Subscription::PostgreSQL](https://metacpan.org/pod/Myriad%3A%3ASubscription%3A%3APostgreSQL)
- [Myriad::Subscription::Memory](https://metacpan.org/pod/Myriad%3A%3ASubscription%3A%3AMemory)

Additional transport mechanisms may be available, see CPAN for details.

## Transports

Note that _some layers don't have implementations for all transports_ - MQ for example does not really provide a concept of "storage".

Each of these implementations is supposed to separate out the logic from the actual transport calls, so there's a separate ::Transport set of classes here:

- [Myriad::Transport::Redis](https://metacpan.org/pod/Myriad%3A%3ATransport%3A%3ARedis)
- [Myriad::Transport::PostgreSQL](https://metacpan.org/pod/Myriad%3A%3ATransport%3A%3APostgreSQL)
- [Myriad::Transport::Memory](https://metacpan.org/pod/Myriad%3A%3ATransport%3A%3AMemory)

which deal with the lower-level interaction with the protocol, connection management and so on. More details on that
can be found in [Myriad::Transport](https://metacpan.org/pod/Myriad%3A%3ATransport) - but it's typically only useful for people working on the [Myriad](https://metacpan.org/pod/Myriad) implementation itself.

## Other classes

Documentation for these classes may also be of use:

- [Myriad::Exception](https://metacpan.org/pod/Myriad%3A%3AException) - generic errors, provides ["throw" in Myriad::Exception](https://metacpan.org/pod/Myriad%3A%3AException#throw) and we recommend that all service errors implement this rôle
- [Myriad::Plugin](https://metacpan.org/pod/Myriad%3A%3APlugin) - adds specific functionality to services
- [Myriad::Bootstrap](https://metacpan.org/pod/Myriad%3A%3ABootstrap) - startup used in `myriad.pl` for providing autorestart and other functionality
- [Myriad::Service](https://metacpan.org/pod/Myriad%3A%3AService) - base class for a service
- [Myriad::Registry](https://metacpan.org/pod/Myriad%3A%3ARegistry) - support for registering services and methods within the current process
- [Myriad::Config](https://metacpan.org/pod/Myriad%3A%3AConfig) - general config support, commandline/file/storage

# METHODS

## loop

Returns the main [IO::Async::Loop](https://metacpan.org/pod/IO%3A%3AAsync%3A%3ALoop) instance for this process.

## services

Hashref of services that have been added to this instance,
as `name` => `Myriad::Service` pairs.

## configure\_from\_argv

Applies configuration from commandline parameters.

Expects a list of parameters and applies the following logic for each one:

- if it contains `::` and a wildcard `*`, it's treated as a service module base name, and all
modules under that immediate namespace will be loaded
- if it contains `::`, it's treated as a comma-separated list of service module names to load
- a `-` prefix is a standard getopt parameter

## redis

The [Net::Async::Redis](https://metacpan.org/pod/Net%3A%3AAsync%3A%3ARedis) (or compatible) instance used for service coördination.

## memory\_transport

The [Myriad::Transport::Memory](https://metacpan.org/pod/Myriad%3A%3ATransport%3A%3AMemory) instance.

## rpc

The [Myriad::RPC](https://metacpan.org/pod/Myriad%3A%3ARPC) instance to serve RPC requests.

## rpc\_client

The [Myriad::RPC::Client](https://metacpan.org/pod/Myriad%3A%3ARPC%3A%3AClient) instance to request other services RPC.

## http

The [Net::Async::HTTP::Server](https://metacpan.org/pod/Net%3A%3AAsync%3A%3AHTTP%3A%3AServer) (or compatible) instance used for health checks
and metrics.

## subscription

The [Myriad::Subscription](https://metacpan.org/pod/Myriad%3A%3ASubscription) instance to manage events.

## storage

The [Myriad::Storage](https://metacpan.org/pod/Myriad%3A%3AStorage) instance to manage data.

## registry

Returns the common [Myriad::Registry](https://metacpan.org/pod/Myriad%3A%3ARegistry) representing the current service state.

## add\_service

Instantiates and adds a new service to the ["loop"](#loop).

Returns the service instance.

## service\_by\_name

Looks up the given service, returning the instance if it exists.

Will throw an exception if the service cannot be found.

## ryu

a source to corresponde to any high level events.

## shutdown

Requests shutdown.

## on\_start

Registers a coderef to be called during startup.
The coderef is expected to return a [Future](https://metacpan.org/pod/Future).

## on\_shutdown

Registers a coderef to be called during shutdown.

The coderef is expected to return a [Future](https://metacpan.org/pod/Future) indicating completion.

## shutdown\_future

Returns a copy of the shutdown [Future](https://metacpan.org/pod/Future).

This would resolve once the process is about to shut down,
triggered by a fault or a Unix signal.

## setup\_logging

Prepare for logging.

## setup\_tracing

Prepare [OpenTracing](https://metacpan.org/pod/OpenTracing) collection.

## run

Starts the main loop.

Applies signal handlers for TERM and QUIT, then starts the loop.

# SEE ALSO

Microservices are hardly a new concept, and there's a lot of prior art out there.

Key features that we attempt to provide:

- **reliable handling** - requests and actions should be reliable by default
- **atomic storage** - being able to record something in storage as part of the same transaction as acknowledging a message
- **flexible backends** - support for various storage, RPC and subscription implementations, allowing for mix+match
- **zero transport option** - for testing and smaller deployments, you might want to run everything in a single process
- **language-agnostic** - implementations should be possible in languages other than Perl
- **first-class Kubernetes support** - k8s is not required, but when available we should play to its strengths
- **minimal boilerplate** - with an emphasis on rapid prototyping

These points tend to be incompatible with typical HTTP-based microservices frameworks, although this is
offered as one of the transport mechanisms (with some limitations).

## Perl

Here are a list of the Perl microservice implementations that we're aware of:

- [https://github.com/jmico/beekeeper](https://github.com/jmico/beekeeper) - MQ-based (via STOMP), using [AnyEvent](https://metacpan.org/pod/AnyEvent)
- [https://mojolicious.org](https://mojolicious.org) - more of a web framework, but a popular one
- [Async::Microservice](https://metacpan.org/pod/Async%3A%3AMicroservice) - [AnyEvent](https://metacpan.org/pod/AnyEvent)-based, using HTTP as a protocol, currently a minimal wrapper intended to be used with OpenAPI services

## Java

Although this is the textbook "enterprise-scale platform", Java naturally fits a microservice theme.

- [Spring Boot](https://spring.io/guides/gs/spring-boot/) - One of the frameworks that integrates well
with the traditional Java ecosystem, depends on HTTP as a transport. Although there is no unified storage layer,
database access is available through connectors.
- [Micronaut](https://micronaut.io/) - This framework has many integrations with industry-standard
solutions - SQL, MongoDB, Kafka, Redis, gRPC - and they have integration guides for cloud-native solutions
such as AWS or GCP.
- [DropWizard](https://www.dropwizard.io/en/stable/) - A minimal framework that provides a RESTful
interface and storage layer using Hibernate.
- [Helidon](https://helidon.io/) - Oracle's open source attempt, provides support for two types of
transport and SQL access layer using standard Java's packages, built with cloud-native deployment in mind.

## Python

Most of Python's frameworks provide tools to facilitate building logic blocks behind APIs (Flask, Django ..etc).

For work distribution, [Celery](https://docs.celeryproject.org/en/stable/) is commonly used as a task queue abstraction.

## Rust

- [https://rocket.rs/](https://rocket.rs/) - although this is a web framework, rather than a complete microservice system,
it's reasonably popular for the request/response part of the equation
- [https://actix.rs/](https://actix.rs/) - another web framework, this time with a focus on the actor pattern

## JS

JS has many frameworks that help to implement the microservice architecture, some are:

- [Moleculer](https://moleculer.services/) - generally a full-featured, well-designed microservices framework, highly recommended
- [Seneca](https://senecajs.org/)

## PHP

- [Swoft](http://en.swoft.org/) - async support via Swoole's coroutines, HTTP/websockets based with additional support for Redis/database connection pooling and ORM

## Cloud providers

Microservice support at the provider level:

- [AWS Lambda](https://aws.amazon.com/lambda) - trigger small containers based on logic, typically combined
with other AWS services for data storage, message sending and other actions
- ["Google App Engine"](#google-app-engine) - Google's own attempt
- [Heroku](https://www.heroku.com/) - Allow developers to build a microservices architecture based on the services they provide
like the example they mentioned in this [blog](https://devcenter.heroku.com/articles/event-driven-microservices-with-apache-kafka)

# AUTHOR

Deriv Group Services Ltd. `DERIV@cpan.org`

# CONTRIBUTORS

- Tom Molesworth `TEAM@cpan.org`
- Paul Evans `PEVANS@cpan.org`
- Eyad Arnabeh
- Nael Alolwani

# LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.

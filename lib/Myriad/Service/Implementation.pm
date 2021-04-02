package Myriad::Service::Implementation;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Object::Pad;
use Future;
use Future::AsyncAwait;
use Syntax::Keyword::Try;

use Myriad::Storage::Implementation::Redis;
use Myriad::Subscription;

use Myriad::Exception;

class Myriad::Service::Implementation extends IO::Async::Notifier;

use utf8;

=encoding utf8

=head1 NAME

Myriad::Service - microservice coördination

=head1 SYNOPSIS

=head1 DESCRIPTION

=cut

use Log::Any qw($log);
use Metrics::Any qw($metrics);
use List::Util qw(min);
use Scalar::Util qw(blessed);
use Myriad::Service::Attributes;

# Only defer up to this many seconds between batch iterations
use constant MAX_EXPONENTIAL_BACKOFF => 2;

sub MODIFY_CODE_ATTRIBUTES {
    my ($class, $code, @attrs) = @_;
    Myriad::Service::Attributes->apply_attributes(
        class      => $class,
        code       => $code,
        attributes => \@attrs
    );
}

has $ryu;
has $storage;
has $myriad;
has $service_name;
has $rpc;
has $subscription;
has %active_batch;

=head1 ATTRIBUTES

These methods return instance variables.

=head2 ryu

Provides a common L<Ryu::Async> instance.

=cut

method ryu () { $ryu }

=head2 myriad

The L<Myriad> instance which owns this service. Stored internally as a weak reference.

=cut

method myriad () { $myriad }

=head2 service_name

The name of the service, defaults to the package name.

=cut

method service_name () { $service_name }


=head1 METRICS

General metrics that any service is assumed to have

=head2 myriad.service.rpc

Timing information about RPC calls tagged by service, status and method name

=cut


$metrics->make_timer( rpc_timing =>
   name => [ qw(myriad service rpc) ],
   description => "Time taken to perocess the RPC request",
   labels => [qw(method status service)]
);

=head2 myriad.service.batch

Timing information about the batch subscriptions tagged by service, status and method name

=cut

$metrics->make_timer( batch_timing =>
   name => [ qw(myriad service batch) ],
   description => "Time taken to perocess the RPC request",
   labels => [qw(method status service)]
);

=head2 myriad.service.receiver

Timing information about events receivers tagged by service, status and method name

=cut

$metrics->make_timer( receiver_timing =>
   name => [ qw(myriad service receiver) ],
   description => "Time taken to perocess the received events",
   labels => [qw(method status service)]
);

=head2 myriad.service.emitter

A counter for the events emitted by emitters tagged by service and method name

=cut

$metrics->make_counter( emitters_count =>
    name => [qw(myriad service emitter)],
    description => "Counter for the events emitted by the emitters",
    labels => [qw(method service)],
);

=head1 METHODS

=head2 configure

Populate internal configuration.

=cut

method configure (%args) {
    $service_name //= (delete $args{name} || die 'need a service name');
    Scalar::Util::weaken($myriad = delete $args{myriad}) if exists $args{myriad};
    $rpc = delete $args{rpc} if exists $args{rpc};
    $subscription = delete $args{subscription} if exists $args{subscription};
    $self->next::method(%args);
}

=head2 _add_to_loop

Apply this service to the current event loop.

This will trigger a number of actions:

=over 4

=item * initial startup

=item * first diagnostics check

=item * if successful, batch and subscription registration will occur

=back

=cut

method _add_to_loop($loop) {
    $log->tracef('Adding %s to loop', ref $self);
    $self->add_child(
        $ryu = Ryu::Async->new
    );

    $self->next::method($loop);
}

=head1 ASYNC METHODS

=cut

async method process_batch($k, $code, $src) {
    my $backoff;
    $log->tracef('Start batch processing for %s', $k);
    while (1) {
        await $src->unblocked;
        my $data = [];
        try {
            $data = await $self->$code()->on_ready(sub {
                my $f = shift;
                $metrics->report_timer(batch_timing => $f->elapsed, {method => $k, status => $f->state, service => $service_name});
            });
        } catch ($e) {
            $log->warnf("Batch iteration for %s failed - %s", $k, $e);
        }
        if ($data->@*) {
            $backoff = 0;
            $src->emit($_) for $data->@*;
            # Defer next processing, give other events a chance
            await $self->loop->delay_future(after => 0);
        }
        else {
            $backoff = min(MAX_EXPONENTIAL_BACKOFF, ($backoff || 0.02) * 2);
            $log->tracef('Batch for %s returned no results, delaying for %dms before retry', $k, $backoff * 1000.0);
            await $self->loop->delay_future(
                after => $backoff
            );
        }
    }
}

=head2 start

Perform the diagnostics check and start the service components (RPC, Batches, Subscriptions ..etc).

=cut

async method start {
    my $registry = $Myriad::REGISTRY;

    await $self->startup;
    my @pending;

    my $diag = await Future->wait_any(
        $self->loop->timeout_future(after => 30),
        $self->diagnostics(1),
    );

    die "diagnostics for $service_name failed" unless $diag eq 'ok';

    if(my $emitters = $registry->emitters_for(ref($self))) {
        for my $method (sort keys $emitters->%*) {
            $log->tracef('Found emitter %s as %s', $method, $emitters->{$method});
            my $spec = $emitters->{$method};
            my $chan = $spec->{args}{channel} // die 'expected a channel, but there was none to be found';
            my $sink = $ryu->sink(
                label => "emitter:$chan",
            );
            await $subscription->create_from_source(
                source  => $sink->source->map(sub {
                    $metrics->inc_counter('emitters_count', {method => $method, service => $service_name});
                    return $_;
                }),
                channel => $chan,
                service => $service_name,
            );
            my $code = $spec->{code};
            push @pending, $spec->{current} = $self->$code(
                $sink,
            )->on_fail(sub {
                $log->fatalf('Emitter for %s failed - %s', $method, shift);
            })->retain;
        }
    }

    if(my $receivers = $registry->receivers_for(ref($self))) {
        for my $method (sort keys $receivers->%*) {
            $log->tracef('Found receiver %s as %s', $method, $receivers->{$method});
            my $spec = $receivers->{$method};
            my $chan = $spec->{args}{channel} // die 'expected a channel, but there was none to be found';
            my $sink = $ryu->sink(
                label => "receiver:$chan",
            );
            await $subscription->create_from_sink(
                sink    => $sink,
                channel => $chan,
                client  => $service_name . '/' . $method,
                from    => $spec->{args}{service},
                service => $service_name,
            );
            my $code = $spec->{code};
            my $current = await $self->$code($sink->source);

            die "Receivers method: $method should return a Ryu::Source"
                unless blessed $current && $current->isa('Ryu::Source');

            $current->map(sub {
                my $f = Future->wrap(shift);
                $metrics->report_timer(receiver_timing => ($f->elapsed // 0), {method => $method, status => $f->state, service => $service_name});
                return $f;
            })->resolve->completed->retain;

            push @pending, $spec->{current} = $current->completed->retain;
        }
    }

    if (my $batches = $registry->batches_for(ref($self))) {
        for my $method (sort keys $batches->%*) {
            $log->tracef('Starting batch process %s for %s', $method, ref($self));
            my $code = $batches->{$method}{code};
            my $sink = $ryu->sink(label => 'batch:' . $method);
            await $subscription->create_from_source(
                source  => $sink->source,
                channel => $method,
                service => $service_name,
            );
            $active_batch{$method} = [
                $sink,
                $self->process_batch($method, $code, $sink)
            ];
        }
    }

    if (my $rpc_calls = $registry->rpc_for(ref($self))) {
        for my $method (sort keys $rpc_calls->%*) {
            my $spec = $rpc_calls->{$method};
            my $sink = $ryu->sink(label => "rpc:$service_name:$method");
            $rpc->create_from_sink(service => $service_name, method => $method, sink => $sink);

            my $code = $spec->{code};
            $spec->{current} = $sink->source->map(async sub {
                my $message = shift;
                try {
                    my $response = await $self->$code($message->args->%*)->on_ready(sub {
                        my $f = shift;
                        $metrics->report_timer(rpc_timing => $f->elapsed, {method => $method, status => $f->state, service => $service_name});
                    });
                    await $rpc->reply_success($service_name, $message, $response);
                } catch ($e) {
                    await $rpc->reply_error($service_name, $message, $e);
                }
            })->resolve->completed;
        }
    }
    $log->infof('Wait for %d startup tasks to complete', 0 + @pending);
    # await Future->needs_all(@pending);
    $log->infof('Done');

};

=head2 startup

Initialize the service internal status it will be called when the service is added to the L<IO::Async::Loop>.

The method here is just a placeholder it should be reimplemented by the service code.

=cut

async method startup {
    return;
}

=head2 diagnostics

Runs any internal diagnostics.

The method here is just a placeholder it should be reimplemented by the service code.

=cut

async method diagnostics($level) {
    return 'ok';
}

=head2 shutdown

Gracefully shut down the service by

- stop accepting more requests

- finish the pending requests

=cut

async method shutdown {}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


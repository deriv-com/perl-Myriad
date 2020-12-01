package Myriad::Service::Implementation;

use strict;
use warnings;

# VERSION
# AUTHORITY

use Object::Pad;
use Future;
use Future::AsyncAwait;
use Syntax::Keyword::Try;

use Myriad::RPC::Implementation::Redis;
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
use List::Util qw(min);
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
has $redis;
has $storage;
has $myriad;
has $service_name;
has $rpc;
has $rpc_transport;
has %active_batch;
has $subscription_transport;

has $sub;

=head1 ATTRIBUTES

These methods return instance variables.

=head2 ryu

Provides a common L<Ryu::Async> instance.

=cut

method ryu () { $ryu }

=head2 redis

The L<Myriad::Transport::Redis> instance.

=cut

method redis () { $redis }

=head2 storage

The L<Myriad::Storage> instance.

=cut

method storage () {
    $storage //= Myriad::Storage::Implementation::Redis->new(
        redis_action => $redis,
        redis_subscription => $redis
    );
}

=head2 myriad

The L<Myriad> instance which owns this service. Stored internally as a weak reference.

=cut

method myriad () { $myriad }

=head2 service_name

The name of the service, defaults to the package name.

=cut

method service_name () { $service_name //= lc(ref($self) =~ s{::}{.}gr) }

=head2 subscription_transport

The type of the Subscription transport e.g: redis or perl.

=cut

method subscription_transport () { $subscription_transport }

=head2 rpc_transport

The type of the RPC transport e.g: redis or perl.

=cut

method rpc_transport () { $rpc_transport }

=head1 METHODS

=head2 configure

Populate internal configuration.

=cut

method configure (%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $service_name = delete $args{name} if exists $args{name};
    $rpc_transport = delete $args{rpc_transport} if exists $args{rpc_transport};
    Scalar::Util::weaken($myriad = delete $args{myriad}) if exists $args{myriad};
    $subscription_transport = delete $args{subscription_transport} if exists $args{subscription_transport};
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

    $self->add_child(
        $sub = Myriad::Subscription->new(
            transport => $self->subscription_transport,
            redis     => $redis,
            service   => $self->service_name,
            ryu       => $ryu
        )
    );

    $self->add_child(
        $rpc = Myriad::RPC->new(
            transport => $self->rpc_transport,
            redis   => $redis,
            service => $self->service_name,
        )
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
        my $data = await $self->$code;
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
    try {
        my $diagnostics_ok = await Future->wait_any(
            $self->loop->timeout_future(after => 10),
            $self->diagnostics(1),
        );

        if ($diagnostics_ok) {
            if(my $emitters = $registry->emitters_for(ref($self))) {
                for my $method (sort keys $emitters->%*) {
                    $log->tracef('Found emitter %s as %s', $method, $emitters->{$method});
                    my $spec = $emitters->{$method};
                    my $chan = $spec->{args}{channel} // die 'expected a channel, but there was none to be found';
                    my $sink = $ryu->sink(
                        label => "emitter:$chan",
                    );
                    $sub->create_from_source(
                        source => $sink->source,
                        channel => $chan,
                    );
                    my $code = $spec->{code};
                    $spec->{current} = $self->$code(
                        $sink,
                        $self,
                    )->retain;
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
                    $sub->create_from_sink(
                        sink => $sink,
                        channel => $chan,
                        client => ref($self) . '/' . $method,
                        service => $spec->{args}{service},
                    );
                    my $code = $spec->{code};
                    $spec->{current} = $self->$code(
                        $sink->source,
                        $self,
                    )->retain;
                }
            }
            if (my $batches = $registry->batches_for(ref($self))) {
                for my $method (sort keys $batches->%*) {
                    $log->tracef('Starting batch process %s for %s', $method, ref($self));
                    my $code = $batches->{$method};
                    my $sink = $ryu->sink(label => 'batch:' . $method);
                    $sub->create_from_source(
                        source => $sink->source,
                        channel => $method,
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
                    my $sink = $ryu->sink(label => "rpc:$method");
                    $rpc->create_from_sink(method => $method, sink => $sink);

                    my $code = $spec->{code};
                    $spec->{current} = $sink->source->map(async sub {
                        my $message = shift;
                        try {
                            my $response = await $self->$code($message->args->%*);
                            await $rpc->reply_success($message, $response);
                        } catch ($e) {
                            await $rpc->reply_error($message, $e);
                        }
                    })->resolve->completed;
                }


            }
        } else {
            $log->errorf("can't start %s diagnostics failed", $self->service_name);
            return;
        }

        my $wait_sub = $sub->start->on_fail(sub { $log->errorf('failed on sub run - %s', [ @_ ]) });
        my $wait_rpc = $rpc ? $rpc->start : Future->done;

        Future->wait_all($wait_sub, $wait_rpc)->retain;

    } catch ($e) {
        $log->errorf('Could not finish diagnostics for service %s in time.', $self->service_name);
        die $e;
    }

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

async method shutdown {
    if($rpc) {
        try {
            await Future->wait_any($self->loop->timeout_future(after => 30), $rpc->stop);
        } catch ($error) {
            $log->warnf("Failed to stop accepting requests we might end up with unfinished requests due: %s", $error);
        }

        try {
            await Future->wait_any($self->loop->timeout_future(after => 60 * 3), (async sub {
                while ( await $rpc->has_pending_requests ) {
                    await $self->loop->delay_future(after => 30);
                }
            })->());
        } catch ($error) {
            $log->warnf("Failed to wait for all requests to finish due: %s, unclean shutdown", $error);
        }
    }

    if($sub) {
        try {
            await Future->wait_any($self->loop->timeout_future(after => 60 * 3), $sub->stop);
        } catch ($error) {
            $log->warnf("Failed to wait for the subscription to end gracefully due: %s", $error);
        }
    }
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


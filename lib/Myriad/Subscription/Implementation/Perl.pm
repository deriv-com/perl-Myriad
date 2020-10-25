package Myriad::Subscription::Implementation::Perl;

# VERSION
# AUTHORITY

use Myriad::Class extends => qw(IO::Async::Notifier);

use Role::Tiny::With;

with 'Myriad::Role::Subscription';

has $service;

has $channels = {};
has $receivers = {};

has $should_shutdown = 0;
has $stopped;

method _add_to_loop ($loop) {
    $stopped = $loop->new_future(label => 'subscription::redis::stopped');
}

method configure (%args) {
    $service = delete $args{service} if exists $args{service};
    $self->next::method(%args);
}

method create_from_source (%args) {
    my $src          = delete $args{source} or die 'need a source';
    my $channel_name = $service . '.' . $args{channel};
    $channels->{$channel_name} = [];

    $src->each(sub {
        my $message = shift;
        push $channels->{$channel_name}->@*, $message;
    })->retain;
}

method create_from_sink (%args) {
    my $sink = delete $args{sink} or die 'need a sink';
    my $channel_name = $service . '.' . $args{channel};
    $receivers->{$channel_name} = [] unless exists $receivers->{$channel_name};

    push $receivers->{$channel_name}->@*, $sink;
}

async method start {
    while (1) {
        for my $channel (keys $channels->%*) {
            my $clients = $receivers->{$channel};
            if($clients->@*) {
                while (my $message = shift $channels->{channel}->@*) {
                    for my $receiver ($clients->@*) {
                        $receiver->emit($message);
                    }
                }
            }
            # Give other things a space
            await $self->loop->delay_future(after => 0.3);
        }
        if($should_shutdown) {
            $stopped->done;
            last;
        }
    }
}

async method stop {
    $should_shutdown = 1;
    await $stopped;
}

1;


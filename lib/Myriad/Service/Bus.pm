package Myriad::Service::Bus;

use Myriad::Class;

field $events : reader;
field $transport;
field $service_name;

BUILD (%args) {
    $service_name = $args{service};
    $events = $args{myriad}->ryu->source;
    $transport = $args{myriad}->transport('storage');
}

async method setup {
    # We currently pass through the events to the main source, and
    # don't support backpressure - for small volumes this works, but
    # the longer-term intention is to decant heavy subscription streams
    # onto their own connection so we can pause reading without affecting
    # other functionality.
    my $sub = await $transport->subscribe('event.{' . $service_name . '}');
    $sub->each(sub {
        $events->emit($_);
    })->retain;
    return $sub;
}

1;

#!/usr/bin/env perl 
use strict;
use warnings;

use Myriad;

{
package Example::Service::Holder;

# Simple batch method example.

use Myriad::Service;
use Ryu::Source;

has $count = 0;
has $value = Ryu::Source->new;

async method current : RPC {
    return { value => $value, count => $count};
}

async method update_v : RPC (%args) {

    $value->emit($args{new_value});
    return 1;

}

async method call_counter : Emitter() ($sink, $api, %args){
    $value->each(sub {
        my $v = shift;
        my $e = {name => "EMITTER-Holder serv", value => $v, count => ++$count};
        $sink->emit($e);
    });
}

}

{
package Example::Service::Consumer;

# Simple batch method example.

use Myriad::Service;

has $count = 0;

async method call_counter :Receiver(service => 'example.service.holder') ($sink, $api, %args) {
    $log->warnf('Receiver Called | %s | %s | %s');

    while(1) {
        use Data::Dumper;
        await $sink->map(sub {my $t = shift; $log->warnf('fff %s', Dumper($t)); $count = $t;})->completed;
    }

}
async method current_s : RPC {
    return $count;
}


}
no indirect;

use Syntax::Keyword::Try;
use Future::AsyncAwait;
use Log::Any qw($log);
use Test::More;

(async sub {
    my $myriad = Myriad->new;
=s
    $myriad->add_service(
        'Example::Service::Emitter',
        name => 'example_service_emitter',
    );
    $myriad->add_service(
        'Example::Service::Test',
        name => 'example',
    );
=cut
    my @arg = ("-l","debug","--redis_uri","redis://redis6:6379","Example::Service::Holder,Example::Service::Consumer");
    $myriad->configure_from_argv(@arg)->get;
    $log->warnf('done configuring');
    $myriad->run;
    {
        my $srv = $myriad->service_by_name('example.service.emitter');
        my $tst_srv = $myriad->service_by_name('example');
        is(await $srv->current, 1, '1 because it has been already called');
        is(await $tst_srv->current_s, 0, '0 00000000');
        # Defer one iteration on the event loop
        await $myriad->loop->delay_future(after => 1);
        use Data::Dumper;
        note "ssssss " . Dumper($tst_srv->current_s);
        is(await $srv->current, 10, 'and now we should have 10');
    }
})->()->get;

done_testing();

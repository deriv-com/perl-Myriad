package Coffee::Drinker::Judge;

use Myriad::Service;

has $current_users;
has $current_machines;
has $current_coffee;

async method startup () {
    $current_users = [];
    $current_machines = [];
    $current_coffee = [];
}

async method drinking_tracker : Receiver(service => 'coffee.drinker.heavy', channel => 'drink') ($sink) {
    return $sink->map(sub {
        my $ids = shift;
        $log->warnf('GOT COFFEE %s', $ids);
        push @$current_coffee, $ids;
    });
}

async method drinkers_tracker : Receiver(service => 'coffee.drinker.heavy', channel => 'new_drinker') ($sink) {
    return $sink->map(sub {
        my $ids = shift;
        $log->warnf('GOT new Drinker %s', $ids);
        push @$current_users, $ids;
    });
}

async method machine_tracker : Receiver(service => 'coffee.drinker.heavy', channel => 'new_machine') ($sink) {
    return $sink->map(sub {
        my $ids = shift;
        $log->warnf('GOT new MACHINE %s', $ids);
        push @$current_machines, $ids;
    });
}
1;

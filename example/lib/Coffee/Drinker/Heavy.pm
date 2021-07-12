package Coffee::Drinker::Heavy;

use Myriad::Service;

use JSON::MaybeUTF8 qw(:v1);
use String::Random;
use Future::Utils qw( fmap_concat fmap_void );

has $rng = String::Random->new;
has $latest_user_id;
has $latest_machine_id;

async method startup () {
    my $user_storage    = $api->service_by_name('coffee.manager.user')->storage;
    my $machine_storage = $api->service_by_name('coffee.manager.machine')->storage;

    $latest_user_id    = await $user_storage->get('id');
    $latest_machine_id = await $machine_storage->get('id');

}

async method drink : Batch () {
    my $coffee_service = $api->service_by_name('coffee.manager.coffee');
    my @got_coffees;
    my $concurrent = int(rand(51));
    $log->warnf('CALL');
    my $get_coffee_params = sub { return { int(rand($latest_user_id))  => int(rand($latest_machine_id)) } };
    $log->warnf('Bought Coffee User: %d | Machine: %d | entry_id: %d', $get_coffee_params->());
    await &fmap_void( $self->$curry::curry(async method ($params) {
            my $r = await $coffee_service->call_rpc('buy', 
                type => 'PUT',
                params => $params
            );
            $log->warnf('Bought Coffee User: %d | Machine: %d | entry_id: %d', $params->%*, $r->{id});
            push @got_coffees,  $r;
        }), foreach => [($get_coffee_params->()) x $concurrent], concurrent => $concurrent);

    return  [ @got_coffees ];

}

=d
async method new_driker : Batch () {
    my $user_service = $api->service_by_name('coffee.manager.user');
    my @added_users;
    my $concurrent = int(rand(51));
    my $new_user_hash = sub { return {login => $rng->randpattern("CccccCcCC"), password => 'pass', email => $rng->randpattern("CCCccccccc")} };
    await &fmap_void( $self->$curry::curry(async method ($user_hash) {
            my $r = await $user_service->call_rpc('request', 
                type => 'PUT',
                body => $user_hash
            );
            $log->warnf('Added User: %s', $r);
            $latest_user_id = $r->{id};
            push @added_users, $r;
        }), foreach => [($new_user_hash->()) x $concurrent], concurrent => $concurrent);

    return  [ @added_users ];

}

async method new_machine : Batch () {
    my $machine_service = $api->service_by_name('coffee.manager.machine');
    my @added_machines;
    my $concurrent = int(rand(51));
    my $new_machine_hash = sub { return {name => $rng->randpattern("Ccccccccc"), caffeine => $rng->randpattern("n")} };
    await &fmap_void( $self->$curry::curry(async method ($machine_hash) {
            my $r = await $machine_service->call_rpc('request', 
                type => 'PUT',
                body => $machine_hash
            );
            $log->warnf('Added Machine %s', $r);
            $latest_machine_id = $r->{id};
            push @added_machines, $r;
        }), foreach => [($new_machine_hash->()) x $concurrent], concurrent => $concurrent);

    return  [ @added_machines ];
}
=cut
1;

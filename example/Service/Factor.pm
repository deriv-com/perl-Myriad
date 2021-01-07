package example::Service::Factor;

use Myriad::Service;
use JSON::MaybeUTF8 qw(:v1);

has $factor = 0;
has $players_id = {};

async method diagnostics ($level) {
    return 1;
}

async method secret_checks :Receiver(service => 'example.service.secret') ($sink) {
    while(1) {
        await $sink->map(
            sub {
                my $e = shift;
                my %info = ($e->@*);
                $log->tracef('INFO %s', \%info);
                my $data = decode_json_utf8($info{'data'});
                my $secret_service = $api->service_by_name('example.service.secret');
                my $secret_storage = $secret_service->storage;

                # If pass reset the game, with new value.
                if($data->{pass}) {
                    $factor = 0;
                    $players_id = {};
                    $secret_service->call_rpc('reset_game', secret => int(rand(100)))->retain;
                    $log->info('Called RESET');
                } else {
                    # We will:
                    # Double the factor on every new player joining
                    # increment factor by number of player trials on every check.
                    my $player_id = $data->{id};
                    my $trials = $secret_storage->hash_get('current_players',$player_id)->get;

                    # since there is no hash_conut implemented yet.
                    $players_id->{$player_id} = 1;

                    $log->trace('TRIALS: %s, MILT: %s', $trials, scalar keys %$players_id);
                    $factor += $trials;
                    $factor *= 2 for keys %$players_id;

                }
                    $log->infof('Setting factor %d', $factor);
                    $api->storage->set('factor', $factor)->retain;
            })->completed;
    }

}

1;



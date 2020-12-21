package Myriad::Service::Remote;

use Myriad::Class;
use Myriad::Service::Storage::Remote;

has $myriad;
has $service_name;
has $storage;

BUILD(%args) {
    weaken($myriad = delete $args{myriad});
    $service_name = delete $args{service_name} // die 'need a service name';
    $storage = Myriad::Service::Storage::Remote->new(prefix => $service_name, storage => $myriad->storage);
}

method storage { $storage }

async method call_rpc ($rpc, %args) {
    await $myriad->rpc_client->call_rpc($service_name, $rpc, %args);
}

async method subscribe ($channel) {

}

1;

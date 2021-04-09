# perl-Myriad

[![Coverage Status](https://coveralls.io/repos/github/binary-com/perl-Myriad/badge.svg?branch=master)](https://coveralls.io/github/binary-com/perl-Myriad?branch=master)

Myriad provides a framework for dealing with asynchronous, microservice-based code.
It is intended for use in an environment such as Kubernetes to support horizontal
scaling for larger systems.

## Features

- Naturally asynchronous 
- Multiple inter-services communication patterns
- Different options for communication and storage backends

for more details check [myriad.pm](https://github.com/binary-com/perl-Myriad/blob/master/lib/Myriad.pm) and the examples folder

## Quick Start

```
package Service::Demo;

use Myriad::Service;

config "how_long", default => 5;

async method delayed_echo : RPC (%args) {
    await $self->loop->delay_future(after => $api->config('how_long')->as_number);
	return \%args
}

async method listen_for_events : Receiver(from => 'other.service.name', channel => 'channel name') ($src) {
	return $src->map(...); #do awsome things
}

async method publish_events : Emitter() ($sink) { 
    # collect events and emit them
    $sink->emit({....});
}

1;
```

then run the service 

```
docker run deriv/myriad Service::Demo
```

Start with development mode (Auto reload on file changes):

```
docker run -e MYRIAD_DEV=1 deriv/myriad Service::Demo
```

## Command line options

### To run a service

```
myriad.pl Service::Package
```

### To send an RPC request

```
myriad.pl --service_name <Target::Service> rpc <rpc name> [rpc args as key value]
```

### To subscribe to an event stream

```
myriad.pl --service_name <Target::Service> subscription <channel_name>
```

### To inspect storage value

```
myriad.pl --service_name <Target::Service> storage <operation> <key>
```

### To set the transport URL

```
myriad.pl --transport_redis <redis://...> [reset of the commands]
```


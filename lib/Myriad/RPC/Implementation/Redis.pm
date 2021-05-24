package Myriad::RPC::Implementation::Redis;

use Myriad::Class extends => qw(IO::Async::Notifier);

our $VERSION = '0.006'; # VERSION
our $AUTHORITY = 'cpan:DERIV'; # AUTHORITY

=encoding utf8

=head1 NAME

Myriad::RPC::Implementation::Redis - microservice RPC Redis implementation.

=head1 DESCRIPTION

=cut

use Role::Tiny::With;

use Future::Utils qw(fmap0);
use Sys::Hostname qw(hostname);
use Scalar::Util qw(blessed);

use Myriad::Exception::InternalError;
use Myriad::RPC::Message;

use constant RPC_SUFFIX => 'rpc';
use constant RPC_PREFIX => 'service';

use Exporter qw(import export_to_level);

with 'Myriad::Role::RPC';

our @EXPORT_OK = qw(stream_name_from_service);

has $redis;
method redis { $redis }

has $group_name;
method group_name { $group_name }

has $whoami;
method whoami { $whoami }

has $rpc_list;
method rpc_list { $rpc_list }

has $ryu;
method ryu { $ryu }

has $running;


sub stream_name_from_service ($service, $method) {
    return RPC_PREFIX . ".$service.". RPC_SUFFIX . "/$method"
}

method configure (%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $whoami = hostname();
    $group_name = 'processors';
    $rpc_list //= [];

    $self->next::method(%args);
}

method _add_to_loop($loop) {
    $self->add_child(
        $ryu = Ryu::Async->new
    );
    $self->next::method($loop);
}

async method start () {
    $self->listen;
    await $running;
}

method create_from_sink (%args) {
    my $sink   = $args{sink} // die 'need a sink';
    my $method = $args{method} // die 'need a method name';
    my $service = $args{service} // die 'need a service name';

    push $rpc_list->@*, {
        stream => stream_name_from_service($service, $method),
        sink   => $sink,
        group  => 0
    };
}

async method stop () {
    $running->done unless $running->is_ready;
}

async method create_group ($rpc) {
    unless ($rpc->{group}) {
        await $self->redis->create_group($rpc->{stream}, $self->group_name);
        $rpc->{group} = 1;
    }
}

async method listening_source ($rpc) {
	my $source = $ryu->source(label => "rpc_source:listening:$rpc->{stream}");
	$source->map($self->$curry::weak(async method ($item) {
                    push $item->{data}->@*, ('transport_id', $item->{id});
                    try {
                        my $message = Myriad::RPC::Message::from_hash($item->{data}->@*);
			return $message;
                    } catch ($error) {
                        $log->tracef("error while parsing the incoming messages: %s", $error->message);
                        await $self->drop($rpc->{stream}, $item->{id});
                    }

			}))->resolve->retain;
                        $rpc->{sink}->from($source);
	return $source;

}

async method listen () {
    return $running //= (async sub {
		    #        while (1) {
             my @rpcs = await &fmap_concat($self->$curry::curry(async method ($rpc) {
                await $self->create_group($rpc);

        # check for pending
	#my @pending_items = await $self->redis->pending(stream => $rpc->{stream}, group => $self->group_name, client => $self->whoami);
	#	use Data::Dumper;
	#	$log->warnf('PPPPPPpending %s', Dumper(\@pending_items) );
	#	$log->warnf('AFTER');

	my $s =  await $self->listening_source($rpc);
              await $self->redis->read_from_stream(
                    stream => $rpc->{stream},
                    group => $self->group_name,
                    client => $self->whoami,
		    source   => $s,
                );
		#$log->warnf('AFTER  HIIIIIIIII');
		#await $s;

		#	my @items = (@pending_items, @new_items);
		#$log->warnf('NEW %s', Dumper(\@new_items) );
		#for my $item (@items) {
		#}
                }), foreach => [$self->rpc_list->@*], concurrent => 4);
          return Future->wait_all(@rpcs);
	    #await $self->loop->delay_future(after => 0.001);
	    # }
    })->();
}

async method reply ($service, $message) {
    my $stream = stream_name_from_service($service, $message->rpc);
    try {
        await $self->redis->publish($message->who, $message->as_json);
        await $self->redis->ack($stream, $self->group_name, $message->transport_id);
    } catch ($e) {
        $log->warnf("Failed to reply to client due: %s", $e);
        return;
    }
}

async method reply_success ($service, $message, $response) {
    $message->response = { response => $response };
    await $self->reply($service, $message);
}

async method reply_error ($service, $message, $error) {
    $message->response = { error => { category => $error->category, message => $error->message, reason => $error->reason } };
    await $self->reply($service, $message);
}

async method drop ($stream, $id) {
    $log->tracef("Going to drop message: %s", $id);
    await $self->redis->ack($stream, $self->group_name, $id);
}

async method has_pending_requests ($stream) {
	#my $stream = stream_name_from_service($service);
    my $stream_info = await $self->redis->pending_messages_info($stream, $self->group_name);
    if($stream_info->[0]) {
        for my $consumer ($stream_info->[3]->@*) {
            return $consumer->[1] if $consumer->[0] eq $self->whoami;
        }
    }

    return 0;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


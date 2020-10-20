package Myriad::Subscription::Implementation::Redis;

# VERSION
# AUTHORITY

use Myriad::Class extends => qw(IO::Async::Notifier);

use JSON::MaybeUTF8 qw(:v1);
use Unicode::UTF8 qw(decode_utf8 encode_utf8);
use Myriad::Util::UUID;

has $redis;
has $ryu;
has $service;

has $uuid;

# Group mapping
has $group = { };

has $queues = [ ];

BUILD {
    $uuid = Myriad::Util::UUID::uuid();
}
method configure (%args) {
    $redis = delete $args{redis} if exists $args{redis};
    $ryu = delete $args{ryu} if exists $args{ryu};
    $service = delete $args{service} if exists $args{service};
    $self->next::method(%args);
}

method create_from_source (%args) {
    my $src = delete $args{source} or die 'need a source';
    my $stream = 'some.service.' . $args{channel};
    $src->each(sub {
        $log->infof('sub has an event! %s', $_);
        $redis->xadd(
            encode_utf8($stream) => '*',
            data => encode_json_utf8($_),
        )->retain;
    });
}

method create_from_sink (%args) {
    my $sink = delete $args{sink} or die 'need a sink';
    my $stream = 'some.service.' . $args{channel};
    $log->infof('created sub thing from sink');
    push $queues->@*, {
        key => $stream,
        client => $args{client},
        sink => $sink
    };
#    $sisrc->each(sub {
#        $log->infof('sub has an event! %s', $_);
#        $redis->xadd(
#            encode_utf8($stream) => '*',
#            data => encode_json_utf8($_),
#        );
#    });
}

async method run {
    while (1) {
        # await $src->unblocked;
        if($queues->@*) {
            my $item = shift $queues->@*;
            push $queues->@*, $item;
            $log->infof('Will readgroup on %s', $item);
            my $stream = $item->{key};
            my $sink = $item->{sink};
            unless(exists $group->{$stream}{$item->{client}}) {
                try {
                    $log->infof('Creating new group for stream %s client %s', $stream, $item->{client});
                    await $redis->xgroup(create => $stream, $item->{client}, '0');
                } catch {
                    die $@ unless $@ =~ /^BUSYGROUP/;
                }
                $group->{$stream}{$item->{client}} = 1;
            }
            my ($streams) = await $redis->xreadgroup(
                BLOCK   => 2500,
                GROUP   => $item->{client}, $uuid,
                COUNT   => 10, # $self->batch_count,
                STREAMS => (
                    $stream, '>'
                )
            );
            $log->infof('Read group %s', $streams);
            for my $stream (sort keys %$streams) {
                my $data = $streams->{$stream};
                for my $item ($data->@*) {
                    my ($id, $args) = $item->@*;
                    $log->tracef(
                        'Item from stream %s is ID %s and args %s',
                        $stream,
                        $id,
                        $args
                    );
                    if($args) {
                        push @$args, ("message_id", $id);
                        $sink->source->emit($args);
                    }
                }
            }
        } else {
            await $self->loop->delay_future(after => 1);
        }
    }
}

1;

__END__

1;

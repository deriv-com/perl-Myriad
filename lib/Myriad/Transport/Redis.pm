package Myriad::Transport::Redis;

use Myriad::Class extends => qw(IO::Async::Notifier);

# VERSION
# AUTHORITY

=pod

We expect to expose:

=over 4

=item * stream handling functionality, including claiming/pending

=item * get/set and observables

=item * sorted sets

=item * hyperloglog existence

=item * simple queues via lists

=item * pub/sub

=back

This module is responsible for namespacing, connection handling and clustering.
It should also cover retry for stateless calls.

=cut

use Class::Method::Modifiers qw(:all);
use Compress::Zstd ();
use Sub::Util qw(subname);

use Myriad::Redis::Pending;

use Net::Async::Redis;
use Net::Async::Redis::Cluster;

use List::Util qw(pairmap);

my $redis_class;
my $cluster_class;
BEGIN {
    $redis_class = 'Net::Async::Redis';
    $cluster_class = 'Net::Async::Redis::Cluster';
    # Only enable XS mode on request
    if($ENV{PERL_REDIS_XS}) {
        eval {
            require Net::Async::Redis::XS;
            require Net::Async::Redis::Cluster::XS;
            1;
        } and do {
            $redis_class = 'Net::Async::Redis::XS';
            $cluster_class = 'Net::Async::Redis::Cluster::XS';
        }
    }
}

use Myriad::Exception::Builder category => 'transport_redis';

declare_exception 'NoSuchStream' => (
    message => 'There is no such stream, is the other service running?',
);

field $use_cluster;
field $use_trim_exact;
field $redis_uri;
field $redis;
field $redis_pool;
field $waiting_redis_pool;
field $pending_redis_count = 0;
field $wait_time;
field $batch_count = 500;
field $max_pool_count;
field $clientside_cache_size;
field $prefix;
field $ryu;
field $starting;

field $cache_events;

BUILD {
    $redis_pool = [];
    $waiting_redis_pool = [];
}

method configure (%args) {
    if(exists $args{redis_uri}) {
        my $uri = delete $args{redis_uri};
        $redis_uri = ref($uri) ? $uri : URI->new($uri);
    }
    if(exists $args{cluster}) {
        $use_cluster = delete $args{cluster};
    }
    $max_pool_count = exists $args{max_pool_count} ? delete $args{max_pool_count} : 10;
    $prefix //= exists $args{prefix} ? delete $args{prefix} : 'myriad';
    $clientside_cache_size = delete $args{client_side_cache_size} if exists $args{client_side_cache_size};
    $wait_time = exists $args{wait_time} ? delete $args{wait_time} : 15_000;
    # limit minimum wait time to 100ms
    $wait_time = 100 if $wait_time < 100;
    $use_trim_exact = delete $args{use_trim_exact} // 0;
    return $self->next::method(%args);
}

method ryu { $ryu }

=head2 wait_time

Time to wait for items, in milliseconds.

=cut

method wait_time () { $wait_time }

=head2 batch_count

Number of items to allow per batch (pending / readgroup calls).

=cut

method batch_count () { $batch_count }

async method start {
    await $starting if $starting;
    return if $starting or $redis;

    $redis = await $starting = $self->redis->on_ready(sub { undef $starting });
    return;
}


=head2 apply_prefix

=cut

method apply_prefix($key) {
    return "$prefix.$key";
}

=head2 remove_prefix

=cut

method remove_prefix($key) {
    return $key =~ s/^\Q$prefix\E\.//r;
}

=head2 oldest_processed_id

Check the last id that has been processed
by B<all> the consumer groups in the given stream.

=cut

async method oldest_processed_id($stream) {
    $stream = $self->apply_prefix($stream);
    my ($groups) = await $redis->xinfo(GROUPS => $stream);
    my $oldest;

    for my $group ($groups->@*) {
        # Use snake_case instead of kebab-case so that we can map cleanly to Perl conventions
        my %info = pairmap {
            (
                ($a =~ tr/-/_/r),
                $b
            )
        } @$group;
        $log->tracef('Group info: %s', \%info);

        my $group_name = $info{name};

        $log->tracef('Pending check where oldest was %s and last delivered %s', $oldest, $info{last_delivered_id});
        $oldest //= $info{last_delivered_id};
        $oldest = $info{last_delivered_id}
            if $info{last_delivered_id}
            and $self->compare_id(
                $oldest, $info{last_delivered_id}
            ) > 0;

        # Pending list might have items older than "last_delivered_id"
        # If the get deleted we can't claim them back and they are lost forever.
        my ($pending_info) = await $redis->xpending($stream, $group_name);
        my ($count, $first_id, $last_id, $consumers) = $pending_info->@*;
        $log->tracef('Pending info %s', $pending_info);
        $log->tracef('Pending from %s', $first_id);
        $log->tracef('Pending check where oldest was %s and first %s', $oldest, $first_id);
        $oldest //= $first_id;
        $oldest = $first_id if defined($first_id) and $self->compare_id($oldest, $first_id) > 0;
    }

    return $oldest;
}

=head2 compare_id

Given two IDs, compare them as if doing a C<< <=> >> numeric
comparison.

=cut

method compare_id($x, $y) {
    $x //= '0-0';
    $y //= '0-0';
    # Do they match?
    return 0 if $x eq $y;
    my @first = split /-/, $x, 2;
    my @second = split /-/, $y, 2;

    return $first[0] <=> $second[0]
        || $first[1] <=> $second[1];
}

=head2 next_id

Given a stream ID, returns the next ID after it.
This is managed by the simple expedient of incrementing
the right-hand part of the identifier.

=cut

method next_id($id) {
    my ($left, $right) = split /-/, $id, 2;
    ++$right;
    $left . '-' . $right
}

method _add_to_loop(@) {
    $self->add_child(
        $ryu = Ryu::Async->new
    )
}

method source (@args) {
    $self->ryu->source(@args)
}

=head2 iterate

Deal with incoming requests via a stream.

Returns a L<Ryu::Source> which emits L<Myriad::Redis::Pending> items.

=cut

async method read_from_stream (%args) {
    my $stream = $self->apply_prefix($args{stream});
    my $group = $args{group};
    my $client = $args{client};

    my $claimed = await $self->xautoclaim(
        $stream,
        $group,
        $client,
        30_000,
        '0-0',
        COUNT => $self->batch_count,
        'JUSTID',
    );
    my $claim_required = $claimed->[1]->@* ? 1 : 0;

    my ($delivery) = await $self->xreadgroup(
        BLOCK   => $self->wait_time,
        GROUP   => $group, $client,
        COUNT   => $self->batch_count,
        STREAMS => ($stream, ($claim_required ? '0' : '>')),
    );

    $log->tracef('Read group: %s as `%s` from %s in [%s]: %s', $group, $client, ($claim_required ? 'old pending items' : 'latest'), $stream, $delivery);

    # We are strictly reading for one stream
    my $batch = $delivery->[0];
    if ($batch) {
        my ($stream, $data) = $batch->@*;
        return map {
            my ($id, $kv_pairs) = $_->@*;
            my $args = { $kv_pairs->@* };
            my $data = exists $args->{zstd} ? Compress::Zstd::decompress(delete $args->{zstd}) : delete($args->{data});
            +{
                stream => $self->remove_prefix($stream),
                id     => $id,
                data   => $data,
                args   => $args->{args},
                extra  => $args,
            }
        } $data->@*;
    }

    return ();
}

async method stream_info ($stream) {
    my $v = await $redis->xinfo(
        STREAM => $self->apply_prefix($stream)
    );

    my %info = pairmap {
        (
            ($a =~ tr/-/_/r),
            $b
        )
    } @$v;
    $log->tracef('Currently %d groups, %d total length', $info{groups}, $info{length});
    $log->tracef('Full info %s', \%info);
    return \%info;
}

=head2 cleanup

Clear up old entries from a stream when it grows too large.

=cut

async method cleanup (%args) {
    my $stream = $args{stream} // die 'no stream passed';
    try {
        # Check on our status - can we clean up any old queue items?
        my ($info) = await $self->stream_info($stream);

        # Track how far back our active stream list goes - anything older than this is fair game
        my $oldest = await $self->oldest_processed_id($stream);
        $log->tracef('Attempting to clean up [%s] Size: %d | Earliest ID to care about: %s', $stream, $info->{length}, $oldest);
        if ($oldest and $oldest ne '0-0' and $self->compare_id($oldest, $info->{first_entry}[0]) > 0) {
            my $total = 0;
            my $count;
            do {
                ($count) = await $redis->xtrim(
                    $self->apply_prefix($stream),
                    MINID => ($use_trim_exact ? '=' : '~'),
                    $oldest,
                );
                $total += $count if $count;
                $log->tracef('Trimmed %d items from stream: %s', $count, $stream) if $count;
            } while $count;
            $log->tracef('Trimmed %d total items from stream: %s', $total, $stream);

            unless($total) {
                # At this point, we know we _can_ remove things, but the approximate attempt earlier didn't
                # make any progress - so we fall back to a full removal instead
                ($count) = await $redis->xtrim(
                    $self->apply_prefix($stream),
                    MINID => '=',
                    $oldest,
                );
                $log->debugf(
                    'Approximate trimming failed to remove any items, resorting to slower exact trim method for stream %s, removed %d items total',
                    $stream,
                    $count
                );
            }
        }
        else {
            $log->tracef('No point in trimming (%s) where: oldest is %s and this compares to %s', $stream, $oldest, $info->{first_entry}[0]);
        }
    } catch ($e) {
        return if $e =~ /no such key/; # can ignore these
        die $e;
    }
}

=head2 pending

Check for any pending items, claiming them for reprocessing as required.

Takes the following named parameters:

=over 4

=item * C<stream> - the stream name

=item * C<group> - which consumer group to check

=item * C<client> - the name of the client to check

=back

Returns the pending items in this stream.

=cut

async method pending (%args) {
    my $src = $self->source;
    my $stream = $self->apply_prefix($args{stream});
    my $group = $args{group};
    my $client = $args{client};
    my @res = ();

    my $instance = await $self->borrow_instance_from_pool;
    try {
        my ($pending) = await $instance->xpending(
            $stream,
            $group,
            '-', '+',
            $self->batch_count,
            $client,
        );
        @res = await &fmap_concat($self->$curry::weak(
            async method ($item) {
                my ($id, $consumer, $age, $delivery_count) = $item->@*;
                $log->tracef('Claiming pending message %s from %s, age %s, %d prior deliveries', $id, $consumer, $age, $delivery_count);
                my $claim = await $redis->xclaim(
                    $stream,
                    $group,
                    $client,
                    10,
                    $id
                );
                return unless $claim and $claim->@*;
                $log->tracef('Claim is %s', $claim);
                my $kv_pairs = $claim->[0]->[1] || [];

                my $args = { $kv_pairs->@* };
                my $data = exists $args->{zstd} ? Compress::Zstd::decompress(delete $args->{zstd}) : delete($args->{data});
                return {
                    stream => $self->remove_prefix($stream),
                    id     => $id,
                    data   => $data,
                    args   => $args->{args},
                    extra  => $args,
                };
            }),
            foreach => $pending,
            concurrent => 0 + @$pending
        );
    } catch ($e) {
        $log->warnf('Could not read pending messages on stream: %s | error: %s', $stream, $e);
    }
    $self->return_instance_to_pool($instance) if $instance;
    undef $instance;

    return @res;
}

=head2 create_stream

Creates a Redis stream.
Note that there is no straight way to do that in Redis
without creating a group or adding an event.
To overcome this it will create a group with MKSTREAM option
Then destroy that init consumer group.

=over 4

=item * C<stream> - name of the stream we want to create.

=back

=cut

async method create_stream ($stream) {
    await $self->create_group($stream, 'INIT', '$', 1);
    await $self->remove_group($stream, 'INIT');
    $log->tracef('created a Redis stream: %s', $stream);
}

=head2 create_group

Create a Redis consumer group if it does NOT exist.

It'll also send the MKSTREAM option to create the stream if it doesn't exist.

=over 4

=item * C<stream> - The name of the stream we want to attach the group to.

=item * C<group> - The group name.

=item * C<start_from> - The id of the message that is going to be considered the start of the stream for this group's point of view
by default it's C<0> which means the first available message.

=back

=cut

async method create_group ($stream, $group, $start_from = '0', $make_stream = 0) {
    try {
        my @args = ('CREATE', $self->apply_prefix($stream), $group, $start_from);
        push @args, 'MKSTREAM' if $make_stream;
        await $redis->xgroup(@args);
        $log->tracef('Created new consumer group: %s from stream: %s', $group, $stream);
    } catch ($e) {
        if($e =~ /BUSYGROUP/){
            $log->tracef('Already exists consumer group: %s from stream: %s', $group, $stream);
            return;
        } elsif ($e =~ /requires the key to exist/) {
            Myriad::Exception::Transport::Redis::NoSuchStream->throw(
                reason => "no such stream: $stream",
            );
        } else {
            die $e;
        }
    }
}

=head2 remove_group

Delete a Redis consumer group.

=over 4

=item * C<stream> - The name of the stream group belongs to.

=item * C<group> - The consumer group name.

=back

=cut

async method remove_group ($stream, $group) {
    try {
        my @args = ('DESTROY', $self->apply_prefix($stream), $group);
        await $redis->xgroup(@args);
        $log->tracef('Deleted consumergroup: %s from stream: %s', $group, $stream);
    } catch ($e) {
        if ($e =~ /requires the key to exist/) {
            $log->warnf('Trying to remove a consumergroup(%s) from stream: %s that does not exist', $group, $stream);
            Myriad::Exception::Transport::Redis::NoSuchStream->throw(
                reason => "no such stream: $stream",
            );
        } else {
            die $e;
        }
    }
}

=head2 pending_messages_info

Return information about the pending messages for a stream and a consumer group.

This currently just execute C<XPENDING> without any filtering.

=over 4

=item * C<stream> - The name of the stream we want to check.

=item * C<group> - The consumers group name that we want to check.

=back

=cut

async method pending_messages_info($stream, $group) {
    await $redis->xpending($self->apply_prefix($stream), $group);
}

=head2 stream_length

Return the length of a given stream

=cut

async method stream_length ($stream) {
    return await $redis->xlen($self->apply_prefix($stream));
}

=head2 borrow_instance_from_pool

Returns a Redis connection either from a pool of connection or a new one.
With the possibility of waiting to get one, if all connection were busy and we maxed out our limit.

=cut

async method borrow_instance_from_pool {
    $log->tracef('Available Redis pool count: %d', 0 + $redis_pool->@*);
    if (my $available_redis = shift $redis_pool->@*) {
        ++$pending_redis_count;
        return $available_redis;
    } elsif ($pending_redis_count < $max_pool_count) {
        ++$pending_redis_count;
        return await $self->redis;
    }
    push @$waiting_redis_pool, my $f = $self->loop->new_future;
    $log->debugf('All Redis instances are pending, added to waiting list. Current Redis count: %d/%d | Waiting count: %d', $pending_redis_count, $max_pool_count, 0 + $waiting_redis_pool->@*);
    return await $f;
}

=head2 return_instance_to_pool

This puts back a redis connection into Redis pool, so it can be used by other called.
It should be called at the end of every usage, as on_ready.

It should also be possible with a try/finally combination..
but that's currently failing with the $redis_pool slot not being defined.

Takes the following parameters:

=over 4

=item * C<$instance> - Redis connection to be returned.

=back

=cut

method return_instance_to_pool ($instance) {
    if( my $waiting_redis = shift $waiting_redis_pool->@*) {
        $waiting_redis->done($instance)
    } else {
        push $redis_pool->@*, $instance;
        $log->tracef('Returning instance to pool, Redis used/available now %d/%d', $pending_redis_count, 0 + $redis_pool->@*);
        $pending_redis_count--;
    }
    return;
}

=head2 redis

Resolves to a new L<Net::Async::Redis> or L<Net::Async::Redis::Cluster>
instance, depending on the setting of C<$use_cluster>.

=cut

async method redis () {
    my $instance;
    if($use_cluster) {
        $instance = $cluster_class->new(
            client_side_cache_size => $clientside_cache_size,
        );
        $self->add_child(
            $instance
        );
        await $instance->bootstrap(
            host => $redis_uri->host,
            port => $redis_uri->port,
        );
    } else {
        $instance = $redis_class->new(
            host => $redis_uri->host,
            port => $redis_uri->port,
            client_side_cache_size => $clientside_cache_size,
        );
        $self->add_child(
            $instance
        );
        $log->tracef('Added new Redis connection (%s) to pool', $redis_uri->as_string);
        await $instance->connect;
    }
    return $instance;
}

async method xreadgroup (@args) {
    my $instance = await $self->borrow_instance_from_pool;
    my ($batch) =  await $instance->xreadgroup(@args)->on_ready(sub {
        $self->return_instance_to_pool($instance);
    });
    return ($batch);
}

async method xautoclaim (@args) {
    my $instance = await $self->borrow_instance_from_pool;
    my ($batch) =  await $instance->xautoclaim(@args)->on_ready(sub {
        $self->return_instance_to_pool($instance);
    });
    return ($batch);
}

async method xadd ($stream, @args) {
    return await $redis->xadd($self->apply_prefix($stream), @args);
}

=head2 ack

Acknowledge a message from a Redis stream.

=over 4

=item * C<stream> - The stream name.

=item * C<group> - The group name.

=item * C<message_id> - The id of the message we want to acknowledge.

=back

=cut

async method ack ($stream, $group, @message_ids) {
    await $redis->xack($self->apply_prefix($stream), $group, @message_ids);
}

=head2 publish

Publish a message through a Redis channel (pub/sub system)

=over 4

=item * C<channel> - The channel name.

=item * C<message> - The message we want to publish (string).

=back

=cut

async method publish ($channel, $message) {
    await $redis->publish($self->apply_prefix($channel), "$message");
}

=head2 subscribe

Subscribe to a redis channel.

=cut

async method subscribe ($channel) {
    my $instance = await $self->borrow_instance_from_pool;
    await $instance->subscribe($self->apply_prefix($channel))->on_ready(sub {
        $self->return_instance_to_pool($instance);
    });
}

async method get($key) {
    await $redis->get($self->apply_prefix($key));
}

async method set ($key, $v, $ttl) {
    await $redis->set($self->apply_prefix($key), $v, defined $ttl ? ('EX', $ttl) : ());
}

async method unlink (@keys) {
    await $redis->unlink(map { $self->apply_prefix($_) } @keys);
}

async method del (@keys) {
    await $redis->del(map { $self->apply_prefix($_) } @keys);
}

async method set_unless_exists ($key, $v, $ttl) {
    $log->infof('Set [%s] to %s with TTL %s', $key, $v, $ttl);
    await $redis->set(
        $self->apply_prefix($key),
        $v,
        qw(NX GET),
        defined $ttl ? ('PX', $ttl * 1000.0) : ()
    );
}

async method getset($key, $v) {
    await $redis->getset($self->apply_prefix($key), $v);
}

async method getdel($key) {
    await $redis->getdel($self->apply_prefix($key));
}

async method incr ($key) {
    await $redis->incr($self->apply_prefix($key));
}

async method rpush($key, @v) {
    await $redis->rpush($self->apply_prefix($key), @v);
}

async method lpush($key, @v) {
    await $redis->lpush($self->apply_prefix($key), @v);
}

async method rpop($key) {
    await $redis->rpop($self->apply_prefix($key));
}

async method lpop($key) {
    await $redis->lpop($self->apply_prefix($key));
}

async method hset ($k, $hash_key, $v) {
    await $redis->hset($self->apply_prefix($k), $hash_key, $v);
}

async method hmset ($k, @kvs) {
    await $redis->hmset($self->apply_prefix($k), @kvs);
}

async method hget($k, $hash_key) {
    await $redis->hget($self->apply_prefix($k), $hash_key);
}

async method hgetall($k) {
    await $redis->hgetall($self->apply_prefix($k));
}

async method hkeys($k) {
    await $redis->hkeys($self->apply_prefix($k));
}

async method hvals($k) {
    await $redis->hvals($self->apply_prefix($k));
}

async method hlen($k) {
    await $redis->hlen($self->apply_prefix($k));
}

async method hexists($k, $hash_key) {
    await $redis->hexists($self->apply_prefix($k), $hash_key);
}

async method hincrby($k, $hash_key, $v) {
    await $redis->hincrby($self->apply_prefix($k), $hash_key, $v);
}

async method sadd ($key, @v) {
    await $redis->sadd($self->apply_prefix($key), @v);
}

async method sismember ($key, @v) {
    await $redis->sismember($self->apply_prefix($key), @v);
}

async method smembers ($key) {
    await $redis->smembers($self->apply_prefix($key));
}

async method scard ($key) {
    await $redis->scard($self->apply_prefix($key));
}

async method srem ($key, @v) {
    await $redis->srem($self->apply_prefix($key), @v);
}

async method zadd ($key, @v) {
    await $redis->zadd($self->apply_prefix($key), @v);
}

async method zrem ($k, $m) {
    await $redis->zrem($self->apply_prefix($k), $m);
}

async method zremrangebyscore ($k, $min, $max) {
    await $redis->zremrangebyscore($self->apply_prefix($k), $min => $max);
}

async method zcount ($k, $min, $max) {
    await $redis->zcount($self->apply_prefix($k), $min, $max);
}

async method zrange ($k, @v) {
    await $redis->zrange($self->apply_prefix($k), @v);
}

async method lrange ($k, @v) {
    await $redis->lrange($self->apply_prefix($k), @v);
}

async method llen ($k, @v) {
    await $redis->llen($self->apply_prefix($k), @v);
}

method clientside_cache_events {
    $cache_events ||= $redis->clientside_cache_events
        ->map($self->curry::weak::remove_prefix)
}

async method watch_keyspace ($pattern) {
    # Net::Async::Redis will handle the connection in this case
    if($clientside_cache_size) {
        return $redis->clientside_cache_events
            ->map($self->$curry::weak(method {
                $log->tracef('Have clientside cache event with [%s] and will remove prefix [%s.]', $_, $prefix);
                return $self->remove_prefix($_);
            }));
    }

    $log->tracef(
        'Falling back to keyspace notifications for %s due to client cache size = %d or unsupported',
        $pattern,
        $clientside_cache_size
    );

    # Keyspace notification is a psubscribe
    my $instance = await $self->borrow_instance_from_pool;
    my $sub = await $instance->watch_keyspace(
        $self->apply_prefix($pattern)
    );
    my $src = $sub->events;
    my $events = $src->map(sub {
        my $chan = $_->{channel} =~ s/__key.*:$prefix\.//r;
        return $chan;
    });
    $events->on_ready($self->$curry::weak(sub {
        shift->return_instance_to_pool($instance);
    }));
    return $events;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


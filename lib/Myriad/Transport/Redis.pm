use strict;
use warnings;

use utf8;
use Object::Pad;

class Myriad::Transport::Redis extends Myriad::Notifier;

=pod

We expect to expose:

- stream handling functionality, including claiming/pending
- get/set and observables
- sorted sets
- hyperloglog existence
- simple queues via lists
- pub/sub

This module is responsible for namespacing, connection handling and clustering.
It should also cover retry for stateless calls.

=cut

use Future::AsyncAwait;
use Syntax::Keyword::Try;

use Myriad::Redis::Pending;

use Log::Any qw($log);
use List::Util qw(pairmap);

has $redis;
has $wait_time = 15_000;
has $batch_count = 50;

=head2 wait_time

Time to wait for items, in milliseconds.

=cut

method wait_time { $wait_time }

=head2 batch_count

Number of items to allow per batch (pending / readgroup calls).

=cut

method batch_count { $batch_count } 

async method oldest_processed_id($stream) {
    my ($v) = await $redis->xinfo(GROUPS => $stream);
    my $oldest;
    for my $group (@$v) {
        # Use snake_case instead of kebab-case so that we can map cleanly to Perl conventions
        my %info = pairmap {
            (
                ($a =~ tr/-/_/r),
                $b
            )
        } @$group;
        $log->tracef('Group info: %s', \%info);

        my $group_name = $info{name};
        {
            my ($v) = await $redis->xinfo(CONSUMERS => $stream, $group_name);
            for my $consumer (@$v) {
                my %info = pairmap { $a =~ tr/-/_/; ($a, $b) } @$consumer;
                $log->tracef('Consumer info: %s', \%info);
            }
        }
        $log->tracef('Pending check where oldest was %s and last delivered %s', $oldest, $info{last_delivered_id});
        $oldest //= $info{last_delivered_id};
        $oldest = $info{last_delivered_id} if $info{last_delivered_id} and compare_id($oldest, $info{last_delivered_id}) > 0;
        {
            my ($v) = await $redis->xpending($stream, $group_name);
            my ($count, $first_id, $last_id, $consumers) = @$v;
            $log->tracef('Pending info %s', $v);
            $log->tracef('Pending from %s', $first_id);
            $log->tracef('Pending check where oldest was %s and first %s', $oldest, $first_id);
            $oldest //= $first_id;
            $oldest = $first_id if defined($first_id) and compare_id($oldest, $first_id) > 0;
        }
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

method _add_to_loop {
    $self->add_child(
        $redis = Net::Async::Redis->new
    );
}

method source(@args) {
    $self->ryu->source(@args)
}

=head2 iterate

Deal with incoming requests via a stream.

Returns a L<Ryu::Source> which emits L<Myriad::Redis::Pending> items.

=cut

method iterate(%args) {
    my $src = $self->source;
    my $stream = $args{stream};
    my $group = $args{group};
    my $client = $args{client};
    Future->wait_any(
        $src->completed,
        (async sub {
            while(1) {
                await $src->unblocked;
                my ($batch) = await $redis->xreadgroup(
                    BLOCK   => $self->wait_time,
                    GROUP   => $group, $client,
                    COUNT   => $self->pending_count,
                    STREAMS => (
                        $stream, '>'
                    )
                );
                $log->tracef('Read group %s', $batch);
                for my $delivery ($batch->@*) {
                    my ($stream, $data) = $delivery->@*;
                    for my $item ($data->@*) {
                        my ($id, $args) = $item->@*;
                        $log->tracef(
                            'Item from stream %s is ID %s and args %s',
                            $stream,
                            $id,
                            $args
                        );
                        my $msg = Myriad::Redis::Pending->new(
                            redis  => $self,
                            stream => $stream,
                            id     => $id,
                        );
                        $src->emit($msg);
                        await $redis->xack($stream, 'first_group', $id);
                    }
                }
            }
        })->()
    )->retain;
    $src;
}

async method stream_info($stream) {
    my ($v) = await $redis->xinfo(
        STREAM => $stream
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

async method cleanup(%args) {
    my $stream = $args{stream};
    # Check on our status - can we clean up any old queue items?
    my %info = await $self->stream_info($stream)->%*;
    return unless $info{length} > $args{limit};

    # Track how far back our active stream list goes - anything older than this is fair game
    my $oldest = await $self->oldest_processed_id($stream);
    $log->debugf('Earliest ID to care about: %s', $oldest);

    if($oldest and $oldest ne '0-0' and compare_id($oldest, $info{first_entry}[0]) > 0) {
        # At this point we know we have some older items that can go. We'll need to finesse
        # the direction to search: for now, take the naïve but workable assumption that we
        # have an even distribution of values. This means we go forwards from the start if
        # $oldest is closer to the first_delivery_id, or backwards from the end if it's
        # nearer to the end. We can use the timestamp (first half) rather than the full ID
        # for this comparison. If we get this wrong, we'll still end up with the right
        # count - it'll just be a bit less efficient.
        # This could likely be enhanced by taking a binary search (setting count to 1), although for the common case
        # of consistent/predictable stream population, having a few points that can be used for a good derivative
        # estimate means we could apply Newton-Raphson, Runge-Kutta or similar methods to converge faster.
        my $direction = do {
            no warnings 'numeric';
            ($oldest - $info{first_entry}[0]) > ($info{last_entry}[0] - $oldest)
            ? 'xrevrange'
            : 'xrange'
        };
        my $limit = 200;
        my $endpoint = $direction eq 'xrevrange' ? '+' : '-';
        my $total = 0;
        while(1) {
            # XRANGE / XREVRANGE conveniently have switched start/end parameters, so we don't need to swap $endpoint
            # and $oldest depending on type here.
            my ($v) = await $redis->$direction($stream, $endpoint, $oldest, COUNT => $limit);
            $log->tracef('%s returns %d/%d items between %s and %s', uc($direction), 0 + @$v, $limit, $endpoint, $oldest);
            $total += 0 + @$v;
            last unless 0 + @$v >= $limit;
            # Overlapping ranges, so the next ID will be included twice
            --$total;
            $endpoint = $v->[-1][0];
        }
        $total = $info{length} - $total if $direction eq 'xrange';

        $log->tracef('Would trim to %d items', $total);
        my ($before) = await $redis->memory_usage($stream);
        # my ($trim) = await $redis->xtrim($stream, MAXLEN => '~', $total);
        my ($trim) = await $redis->xtrim($stream, MAXLEN => $total);
        my ($after) = await $redis->memory_usage($stream);
        $log->tracef('Size changed from %d to %d after trim which removed %d items', $before, $after, $trim);
    } else {
        $log->tracef('No point in trimming: oldest is %s and this compares to %s', $oldest, $info{first_entry}[0]);
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

Returns a L<Ryu::Source> for the pending items in this stream.

=cut

method pending(%args) {
    my $src = $self->source;
    my $stream = $args{stream};
    my $group = $args{group};
    my $client = $args{client};
    Future->wait_any(
        $src->completed,
        (async sub {
            my $start = '-';
            while(1) {
                await $src->unblocked;
                my ($pending) = await $redis->xpending(
                    $stream,
                    $group,
                    $start, '+',
                    $self->pending_count,
                    $client,
                );
                for my $item ($pending->@*) {
                    my ($id, $consumer, $age, $delivery_count) = $item->@*;
                    $log->tracef('Claiming pending message %s from %s, age %s, %d prior deliveries', $id, $consumer, $age, $delivery_count);
                    my $claim = await $redis->xclaim($stream, 'first_group', 'first_client', 10, $id);
                    $log->tracef('Claim is %s', $claim);
                    $start = $id;
                    my $msg = Myriad::Redis::Pending->new(
                        redis  => $self,
                        stream => $stream,
                        id     => $id,
                    );
                    $src->emit($msg);
                }
                last unless @$pending >= $self->pending_count;
            }
        })->(),
    )->retain;
    $src;
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


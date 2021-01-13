package Myriad::Transport::Perl;

# VERSION
# AUTHORTIY

use strict;
use warnings;

use Ryu::Async;

use Myriad::Class extends => qw(IO::Async::Notifier);
use Myriad::Exception::Builder category => 'perl_transport';

has $ryu;
has $streams;
has $channels;
has $data;

declare_exception 'StreamNotFound' => (
    message => 'The given stream does not exist'
);

declare_exception 'StreamExists' => (
    message => 'Stream already exists you cannot re-create it'
);

declare_exception 'GroupExists' => (
    message => 'The given group name already exists'
);

declare_exception 'GroupNotFound' => (
    message => 'The given group does not exist'
);

BUILD {
    $streams = {};
    $channels = {};
    $data = {};
}

async method create_stream ($stream_name) {
    die Myriad::Exception::Transport::Perl::StreamExists->throw() if $streams->{$stream_name};
    $streams->{$stream_name} = {current_id => 0, data => {}};
}

async method add_to_stream ($stream_name, %data) {
    my ($id, $stream) = (0, undef);
    if ($stream = $streams->{$stream_name}) {
        $id = ++$stream->{current_id} if $stream->{data}->%*;
    } else {
        await $self->create_stream($stream_name);
    }

    $streams->{$stream_name}->{data}->{$id} = { data => \%data };
    return $id;
}

async method create_consumer_group ($stream_name, $group_name, $offset = 0, $make_stream = 0) {
    await $self->create_stream($stream_name) if $make_stream;
    my $stream = $streams->{$stream_name} // Myriad::Exception::Transport::Perl::StreamNotFound->throw(reason => 'Stream should exist before creating new consumer group');
    Myriad::Exception::Transport::Perl::GroupExists->throw() if exists $stream->{groups}{$group_name};
    $stream->{groups}->{$group_name} = {pendings => {}, cursor => $offset};
}

async method read_from_stream ($stream_name, $offset = 0 , $count = 10) {
    my $stream = $streams->{$stream_name} // return ();
    my %messages = map { $_ => $stream->{data}->{$_}->{data} } ($offset..$offset+$count - 1);
    return %messages;
}

async method read_from_stream_by_consumer ($stream_name, $group_name, $consumer_name, $offset = 0, $count = 10) {
    my ($stream, $group) = $self->get_stream_group($stream_name, $group_name);
    my $group_offset = $offset + $group->{cursor};
    my %messages;
    for my $i ($group_offset..$group_offset+$count - 1) {
        $messages{$i} =  $stream->{data}->{$i}->{data};
        $group->{pendings}->{$i} = {since => time, consumer => $consumer_name, delivery_count => 0};
    }

    $group->{cursor} += $group_offset + $count;

    return %messages;
}

async method ack_message ($stream_name, $group_name, $message_id) {
    my ($stream, $group) = $self->get_stream_group($stream_name, $group_name);
    delete $group->{pendings}->{$message_id};
}

async method claim_message ($stream_name, $group_name, $consumer_name, $message_id) {
    my ($stream, $group) = $self->get_stream_group($stream_name, $group_name);
    if (my $info = $group->{pendings}->{$message_id}) {
        $info = {since => time, consumer => $consumer_name, delivery_count => $info->{delivery_count}++};
        return $stream->{data}->{$message_id}->%*;
    } else {
        return ();
    }
}

async method publish ($channel_name, $message) {
    my $subscribers = $channels->{$channel_name};

    for my $subscriber ($subscribers->@*) {
        $subscriber->emit($message);
    }

    return length $subscribers;
}

async method subscribe ($channel_name) {
    $channels->{$channel_name} = [] unless exists $channels->{$channel_name};
    my $sink = $ryu->sink;
    push $channels->{$channel_name}->@*, $sink;
    return $sink->source;
}

async method set ($key, $value) {
    $data->{$key} = $value;
}

async method get ($key) {
    return $data->{$key};
}

method get_stream_group ($stream_name, $group_name) {
    my $stream = $streams->{$stream_name} // Myriad::Exception::Transport::Perl::StreamNotFound->throw();
    my $group = $stream->{groups}->{$group_name} // Myriad::Exception::Transport::Perl::GroupNotFound->throw();
    return ($stream, $group);
}

method _add_to_loop($loop) {
    $self->add_child($ryu = Ryu::Async->new());
    $self->next::method($loop);
}

1;


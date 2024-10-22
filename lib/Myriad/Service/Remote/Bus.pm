package Myriad::Service::Remote::Bus;
use Myriad::Class;

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Service::Remote::Bus - abstraction to access events from other services

=head1 SYNOPSIS


=head1 DESCRIPTION

=cut

field $myriad : param;
field $service : param;

field $events;

method events {
    unless($events) {
        $events = $myriad->ryu->source;
        my $transport = $myriad->transport('storage');
        my $uuid = $service;
        $events->map(async sub ($item, @) {
            try {
                $log->debugf('Post to service [%s] data [%s]', $uuid, $item);
                await $transport->publish(
                    'event.{' . $uuid . '}',
                    ref($item) ? encode_json_utf8($item) : encode_utf8($item)
                )
            } catch ($e) {
                $log->errorf('Failed to send event: %s', $e);
            }
        })->resolve(low => 10, high => 100)->retain;
    }
    $log->tracef('Returning source: %s', $events);
    return $events;
}

1;

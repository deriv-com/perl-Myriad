package Myriad::Mutex;
use Myriad::Class qw(:v2);

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Mutex - a basic mutual-exclusion primitive

=head1 SYNOPSIS

 my $mutex = await $api->mutex;

=head1 DESCRIPTION

=cut

use Math::Random::Secure;

field $key;
field $id;
field $storage;
field $ttl;
field $loop;

field $acquired;

BUILD (%args) {
    $id = delete $args{id};
    $key = delete $args{key};
    $storage = delete $args{storage};
    $ttl = delete $args{ttl} // 60;
    $loop = delete $args{loop} // IO::Async::Loop->new;
    die 'invalid remaining keys in %args - '. join ',', sort keys %args if %args;
}

async method removal_watch {
}

async method acquire {
    while(1) {
        if(
            my $res = await $storage->set_unless_exists(
                $key => $id,
                $ttl,
            )
        ) {
            $log->debugf('Mutex [%s] lost to [%s]', $key, $res);
            my $removed = $storage->when_key_changed($key);
            await Future->wait_any(
                $loop->delay_future(after => 3 + rand),
                $removed->without_cancel,
            ) if await $storage->get($key);
        } else {
            $log->debugf('Acquired mutex [%s]', $key);
            $acquired = 1;
            return $self;
        }

        # Slight delay between attempts
        await $loop->delay_future(after => 0.01 * rand);
    }
}

async method release {
    return undef unless $acquired;
    $log->debugf('Release mutex [%s]', $key);
    await $storage->del($key);
    $acquired = 0;
    return undef;
}

method DESTROY {
    if(${^GLOBAL_PHASE} eq 'DESTRUCT') {
        $log->warnf('Mutex [%s] still acquired at global destruction time', $key)
            if $acquired;
        return;
    }

    $self->release->retain;
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


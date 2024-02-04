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

field $acquired;

BUILD (%args) {
    $id = delete $args{id};
    $key = delete $args{key};
    $storage = delete $args{storage};
    die 'invalid remaining keys in %args - '. join ',', sort keys %args if %args;
}

async method removal_watch {
}

async method acquire {
    while(1) {
        if(
            my $res = await $storage->set_unless_exists(
                $key => $id,
                3.0,
            )
        ) {
            $log->debugf('Mutex [%s] lost to [%s]', $key, $res);
            my $removed = $storage->when_key_changed($key);
            await $removed if await $storage->get($key);
        } else {
            $log->debugf('Acquired mutex [%s]', $key);
            $acquired = 1;
            return $self;
        }
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
    $self->release->retain;
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


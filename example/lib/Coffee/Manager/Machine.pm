package Coffee::Manager::Machine;

use Myriad::Service;

use JSON::MaybeUTF8 qw(:v1);

has $fields;
has $id;

BUILD (%args) {
    $fields = {
        name => {
            mandatory => 1, # not required
            unique    => 1, # not required
        },
        caffeine => {
            mandatory => 1, # not required
        },
    };
}

async method startup () {
    $id = await $api->storage->get('id');
}

async method request : RPC (%args) {
    $log->warnf('GOT Request: %s', \%args);

    my $storage = $api->storage;
    # Only accept PUT request
    if ( $args{type} eq 'PUT' or $args{type} eq 'POST') {
        my %body = $args{body}->%*;
        return {error => {text => 'Missing Argument. Must supply login, password, email', code => 400 } }
            if grep { ! exists $body{$_} } keys $fields->%*;

        my %unique_values;
        # should be converted to fmap instead of for
        for my $unique_field (grep { exists $fields->{$_}{unique}} keys $fields->%*) {
            my $value = await $storage->hash_get(join('.', 'unique', $unique_field), $body{$unique_field});
            return {error => {text => 'User already exists', code => 400 } } if $value;
            $unique_values{$unique_field} = $body{$unique_field};

        }
        $log->debugf('Unique values %s', \%unique_values);

        # Need to add more validation
        my %cleaned_body;
        @cleaned_body{keys $fields->%*} = @body{keys $fields->%*};

        $id = await $storage->incr('id');

        await $storage->hash_set('machine', $id, encode_json_utf8(\%cleaned_body));
        await fmap_void(
            async sub {
                my $key = shift;
                await $storage->hash_set(join('.', 'unique', $key), $unique_values{$key}, 1);
            }, foreach => [keys %unique_values], concurrent => 4
        );
        return {id => $id, record => \%cleaned_body};
    } else {
        return {error => {text => 'Wrong request METHOD please use PUT for this resource', code => 400 } };
    }
}

1;

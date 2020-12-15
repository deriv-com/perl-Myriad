package Myriad::Commands;

use Myriad::Class;
use Unicode::UTF8 qw(decode_utf8);

# VERSION
# AUTHORITY

=head1 NAME

Myriad::Commands

=head1 DESCRIPTION

Provides top-level commands, such as loading a service or making an RPC call.

=cut

use Future::Utils qw(fmap0);

use Module::Runtime qw(require_module);

has $myriad;

BUILD (%args) {
    weaken(
        $myriad = $args{myriad} // die 'needs a Myriad parent object'
    );
}

=head2 service

Attempts to load and start one or more services.

=cut

async method service (@args) {
    my @modules;
    while(my $entry = shift @args) {
        if($entry =~ /,/) {
            unshift @args, split /,/, $entry;
        } elsif(my ($base) = $entry =~ m{^([a-z0-9_:]+)::$}i) {
            require Module::Pluggable::Object;
            my $search = Module::Pluggable::Object->new(
                search_path => [ $base ]
            );
            push @modules, $search->plugins;
        } elsif($entry =~ /^[a-z0-9_:]+[a-z0-9_]$/i) {
            push @modules, $entry;
        } else {
            die 'unsupported ' . $entry;
        }
    }

    await fmap0(async sub {
        my ($module) = @_;
        $log->debugf('Loading %s', $module);
        require_module($module);
        $log->errorf('loaded %s but it cannot ->new?', $module) unless $module->can('new');
        await $myriad->add_service($module);
    }, foreach => \@modules, concurrent => 4);
}

async method rpc ($rpc, @args) {
    try {
        my $response = await $myriad->rpc_client->call_rpc($myriad->config->service_name->as_string, $rpc, @args);
        $log->infof('RPC response is %s', $response);
    } catch ($e) {
        $log->warnf('RPC command failed due: %s', $e);
    }
}

async method subscription ($stream, @args) {
    my $service_name = $myriad->config->service_name->as_string;
    $log->infof('Subscribing to: %s | %s | %s', $service_name, $stream);
    my $sink = $myriad->ryu->sink(
        label => "receiver:$stream",
    );
    $myriad->subscription->create_from_sink(
        sink    => $sink,
        channel => $stream,
        client  => ref($self) . '/' . 'SUB_COMMAND',
        from    => $service_name,
    );

    $sink->source->each(sub {
        my $e = shift;
        my %info = ($e->@*);
        $log->infof('DATA: %s', decode_utf8($info{data}));
    })->completed->retain;
}

async method storage($command, $key) {
    # TODO use a method from the storage module to make the key name.
    my $response = await $myriad->storage->$command($myriad->config->service_name->as_string . '/' . $key);
    $log->infof('Storage resposne is: %s', $response);
}


1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


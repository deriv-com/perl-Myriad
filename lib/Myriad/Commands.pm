package Myriad::Commands;

use Myriad::Util::UUID;

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

use Myriad::Service::Remote;

has $myriad;
has $cmd;

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

    my $service_custom_name = $myriad->config->service_name->as_string;

    die 'You cannot pass a service name and load multiple modules' if @modules > 1 and length $service_custom_name;

    await fmap0(async sub {
        my ($module) = @_;
        $log->debugf('Loading %s', $module);
        require_module($module);
        $log->errorf('loaded %s but it cannot ->new?', $module) unless $module->can('new');
        if ($service_custom_name eq '') {
            await $myriad->add_service($module);
        } else {
            await $myriad->add_service($module, name => $service_custom_name);
        }
    }, foreach => \@modules, concurrent => 4);

    $cmd = {
        code => async sub {
            await fmap0 {
                my $service = shift;
                try {
                    $log->infof('Starting service [%s]', $service->service_name);
                    $service->start;
                } catch($e) {
                    $log->warnf('FAILED to start service %s | %s', $service->service_name, $e);
                }
            } foreach => [values $myriad->services->%*], concurrent => 4;

            $self->start_components();

        },
        params => {},
    };
}

method remote_service {
    return Myriad::Service::Remote->new(
        myriad       => $myriad,
        service_name => $myriad->registry->make_service_name(
            $myriad->config->service_name->as_string
        ) // die 'no service name found'
    );
}

async method rpc ($rpc, @args) {
    my $remote_service = $self->remote_service;
    $cmd = {
        code => async sub {
            my $params = shift;
            my ($remote_service, $command, $args) = map { $params->{$_} } qw(remote_service name args);

            $self->start_components(['rpc_client']);
            try {
                my $response = await $remote_service->call_rpc($command, @$args);
                $log->infof('RPC response is %s', $response);
            } catch ($e) {
                $log->warnf('RPC command failed due: %s', $e);
            }
            await $myriad->shutdown;
        },
        params => { name => $rpc, args => \@args, remote_service => $remote_service}
    };
}

async method subscription ($stream, @args) {
    my $remote_service = $self->remote_service;
    $cmd = {
        code => async sub {
            my $params = shift;
            my ($remote_service, $stream, $args) = map { $params->{$_} } qw(remote_service stream args);
            $self->start_components(['subscription']);

            $log->infof('Subscribing to: %s | %s', $remote_service->service_name, $stream);
            my $uuid = Myriad::Util::UUID::uuid();
            $remote_service->subscribe($stream, "$0/$uuid")->each(sub {
                my $e = shift;
                my %info = ($e->@*);
                use Data::Dumper;
                $log->infof('DATA: %s', decode_utf8(Dumper($info{data})));
            })->completed;
        },
        params => { stream => $stream, args => \@args, remote_service => $remote_service}
    };

}

async method storage ($action, $key, $extra = undef) {
    my $remote_service = Myriad::Service::Remote->new(myriad => $myriad, service_name => $myriad->registry->make_service_name($myriad->config->service_name->as_string));
    $cmd = {
        code => async sub {
            my $params = shift;
            my ($remote_service, $action, $key, $extra) = map { $params->{$_} } qw(remote_service action key extra);

            my $response = await $remote_service->storage->$action($key, defined $extra? $extra : () );
            $log->infof('Storage resposne is: %s', $response);
            await $myriad->shutdown;

        },
        params => { action => $action, key => $key, extra => $extra, remote_service => $remote_service} };
}

method start_components ($components = ['rpc', 'subscription', 'rpc_client']) {
    my @components_started = map {
        my $component = $_;
        # We need retain to make it persists and handle responses.
        $myriad->$component->start->retain->on_fail(sub {
            my $error = shift;
            $log->warnf("%s failed due %s", $component, $error);
            $myriad->shutdown_future->fail($error);

        });

        $log->debugf('Started Component: %s', $component);

    } @$components;
}

async method run_cmd () {
    await $cmd->{code}->($cmd->{params}) if exists $cmd->{code};
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


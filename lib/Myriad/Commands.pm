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
has $queued_commands;
has $remote_service;

BUILD (%args) {
    weaken(
        $myriad = $args{myriad} // die 'needs a Myriad parent object'
    );
    $queued_commands = [];
    $remote_service;
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

    die 'You cannot pass a service name and load multiple modules' if (scalar @modules > 1 && $service_custom_name ne '');

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
    push @$queued_commands, {cmd => 'service'};
}

async method rpc ($rpc, @args) {
    try {
        $remote_service = Myriad::Service::Remote->new(myriad => $myriad, service_name => $myriad->registry->make_service_name($myriad->config->service_name->as_string));
        push @$queued_commands, {cmd => 'rpc', name => $rpc, args => \@args};
        #my $response = await $service->call_rpc($rpc, @args);
        #$log->infof('RPC response is %s', $response);
    } catch ($e) {
        $log->warnf('RPC command failed due: %s', $e);
    }
}

async method subscription ($stream, @args) {
    $remote_service = Myriad::Service::Remote->new(myriad => $myriad, service_name => $myriad->registry->make_service_name($myriad->config->service_name->as_string));
    push @$queued_commands, {cmd => 'subscription', stream => $stream, args => \@args}; 

}

async method storage($action, $key) {
    $remote_service = Myriad::Service::Remote->new(myriad => $myriad, service_name => $myriad->registry->make_service_name($myriad->config->service_name->as_string));
    push @$queued_commands, {cmd => 'storage', action => $action, key => $key}; 
}

async method run_queued() {

    await fmap0(async sub {
        my ($command) = @_;
            if ($command->{cmd} eq 'rpc') {
                my $response = await $remote_service->call_rpc($command->{name}, $command->{args}->@*);
                $log->infof('RPC response is %s', $response);
                await $myriad->shutdown;
            } elsif ( $command->{cmd} eq 'service' ) {
                
                fmap0( async sub { await $_->start }, foreach => [values $myriad->services->%*], concurrent => 4);
                map {
                    my $component = $_;
                    $myriad->$component->start->on_fail(sub {
                        my $error = shift;
                        $log->warnf("%s failed due %s", $component, $error);
                        $myriad->shutdown_future->fail($error);
                    })->retain();
                } qw(rpc subscription rpc_client);

            } elsif ( $command->{cmd} eq 'subscription' ) {

                my $stream = $command->{stream};

                $log->infof('Subscribing to: %s | %s', $remote_service->service_name, $stream);
                my $uuid = Myriad::Util::UUID::uuid();
                $remote_service->subscribe($stream, "$0/$uuid")->each(sub {
                    my $e = shift;
                    my %info = ($e->@*);
                    $log->infof('DATA: %s', decode_utf8($info{data}));
                })->completed->retain;
            } elsif ( $command->{cmd} eq 'storage') {

                my $action = $command->{action};
                my $key = $command->{key};
                my $response = await $remote_service->storage->$action($key);
                $log->infof('Storage resposne is: %s', $response);

            }
    }, foreach => $queued_commands, concurrent => 4);

}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


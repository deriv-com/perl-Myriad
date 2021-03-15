use strict;
use warnings;

use Test::More;
use Test::MockModule;
use Test::MockObject;
use Test::Fatal;
use Test::Deep;

use Future::AsyncAwait;
use IO::Async::Loop;
use IO::Async::Test;

use Myriad;
use Myriad::Commands;
use Myriad::Config;
use Test::Myriad;

my $loop = IO::Async::Loop->new;
testing_loop($loop);



subtest "Service Command" => sub {

    # Myriad module is required for Command creation but only used in Service command
    my $myriad_module = Test::MockModule->new('Myriad');
    my ( @added_services_modules, @add_services_by_name );
    $myriad_module->mock('add_service', async sub{
        my ($self, $module, %args) = @_;
        # Calling of this sub means Service command has been executed succesfully
        push @added_services_modules, $module;
        push @add_services_by_name, $args{'name'} if exists $args{'name'};
    });

    # Fake existance of two sibling modules
    {
        package Ta::Sibling1;
    }
    {
        package Ta::Sibling2;
    }
    $INC{'Ta/Sibling1.pm'} = 1;
    $INC{'Ta/Sibling2.pm'} = 1;
    ######

    my $myriad = Myriad->new;
    my $command = new_ok('Myriad::Commands'=> ['myriad', $myriad]);
    $myriad->META->get_slot('$config')->value($myriad) = Myriad::Config->new();

    # Wrong Service(module) name
    like( exception { wait_for_future( $command->service('Ta-wrong') )->get } , qr/unsupported/, 'Died when passing wrong format name');
    like( exception { wait_for_future( $command->service('Ta_wrong') )->get } , qr/Can't locate/, 'Died when passing module that does not exist');

    # Running multiple services
    wait_for_future( $command->service('Ta::') )->get;
    cmp_deeply(\@added_services_modules, ['Ta::Sibling1', 'Ta::Sibling2'], 'Added both modules');
    # Clear it for next test.
    undef @added_services_modules;

    # Command to run multiple services should not be allowed when service_name option is set
    my $srv_run_name = 'service.test.one';
    $myriad->META->get_slot('$config')->value($myriad) = Myriad::Config->new( commandline => ['--service_name', $srv_run_name] );
    like (exception {wait_for_future( $command->service('Ta::') )->get}, qr/You cannot pass a service/, 'Not able to load multiple due to set service_name');
    # However allowed to run 1
    wait_for_future( $command->service('Ta::Sibling1') )->get;
    cmp_deeply(\@added_services_modules, ['Ta::Sibling1'], 'Added one service');
    cmp_deeply(\@add_services_by_name, [$srv_run_name], "Added $srv_run_name by name");
};

BEGIN {
    # if we want to fully test the command
    # we should be able to run mock service with a testing RPC
    # then call it with the command and test it.
    # This will be used in a different flow.t test
    Test::Myriad->add_service(name => "Test::Service::Mocked")->add_rpc('test_cmd', success => 1);
}

my $myriad_mod = Test::MockModule->new('Myriad');

# Mock shutdown behaviour
# As some commands  are expected to call shutdown on completion.
my $shutdown_count = 0;
$myriad_mod->mock('shutdown', async sub {
    my $self = shift;
    my $shutdown_f = $loop->new_future(label => 'shutdown future');
    $shutdown_count++;
    $shutdown_f->done('shutdown called');
});
my $rmt_svc_cmd_called;
my $test_cmd;
my %calls;
my %started_components;

sub mock_component {
    my ($component, $cmd, $test_name) = @_;

    $test_cmd = $test_name;
    undef %calls;
    $rmt_svc_cmd_called = {};
    undef %started_components;
    $myriad_mod->mock($component, sub {
        my ($self) = @_;
        my $mock = Test::MockObject->new();
        $mock->mock( $cmd, async sub {
            my ($self, $service_name, $rpc, %args) = @_;
            $rmt_svc_cmd_called->{$cmd} //= [];
            push @{$rmt_svc_cmd_called->{$cmd}}, {svc => $service_name, rpc => $rpc, args => \%args};
            $calls{$rpc}++;
            return {success => 1};
        });
        my $f;
        $mock->mock('start', async sub {
            my ($self) = @_;
            $f //= $loop->new_future;
            $started_components{$component} = 1;
            return $f;
        });
        $mock->mock('is_started', async sub {
            my ($self) = @_;
            my $started = $loop->new_future;
            return defined $f ? $started->done("$component started") : $started->fail('start not called');
        });

        $mock->mock('create_from_sink', async sub {});
        return $mock;
    });

}

subtest "rpc command" => sub {
    my $myriad = Myriad->new;
    my $svc_pkg_name = 'Test::Service::Mocked';
    $myriad->META->get_slot('$config')->value($myriad) = Myriad::Config->new( commandline => ['--service_name', $svc_pkg_name] );
    my $command = new_ok('Myriad::Commands'=> ['myriad', $myriad]);
    mock_component('rpc_client', 'call_rpc', 'rpc_client_test');
    ok wait_for_future( $command->rpc($test_cmd, value => 1) )->get, 'Command has been added';

    is $started_components{'rpc_client'}, undef, 'Component RPC not yet started';
    # Results will be printed as log.
    my $working_cmd = wait_for_future($command->run_cmd)->get;

    ok $started_components{'rpc_client'}, 'Component RPC started';
    is $calls{$test_cmd}, 1, 'called correct command ';
    # Check what service is called
    is ($_->{svc}, $myriad->registry->make_service_name($svc_pkg_name), "Correct service name passed") for $rmt_svc_cmd_called->{call_rpc}->@*;
    like ( $working_cmd->result, qr/shutdown called/, 'RPC command called shutdown' );


    ok wait_for_future( $command->rpc('not_an_rpc', value => 1) )->get, 'Wrond command has been added';
    my $fail_cmd = wait_for_future($command->run_cmd)->get;
    is $calls{'not_an_rpc'}, 1, 'called correct command ';
    like ( $working_cmd->result, qr/shutdown called/, 'RPC command called shutdown' );

    is $shutdown_count, 2, "Shutdown called 2 times because we passed 2 commands";
};

done_testing;

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
    Test::Myriad->add_service(name => "Test::Service::Mocked")->add_rpc('testing_rpc', success => 1);
}

my $myriad_mod = Test::MockModule->new('Myriad');
my $rmt_svc_cmd_called = {};
my $testing_rpc = 'testing_rpc';
$myriad_mod->mock('rpc_client', sub { 
        my ($self) = @_;
        my $mock = Test::MockObject->new();
        $mock->mock( 'call_rpc', async sub { 
                my ($self, $service_name, $rpc, %args) = @_;
                $rmt_svc_cmd_called->{rpc} //= [];
                push @{$rmt_svc_cmd_called->{rpc}}, {svc => $service_name, rpc => $rpc, args => \%args};
                die 'Unknown RPC' unless $rpc eq $testing_rpc;
                return {success => 1};
            } 
        );
        return $mock;
    }
);

subtest "rpc command" => sub {
    my $myriad = Myriad->new;
    my $svc_pkg_name = 'Test::Service::Mocked';
    $myriad->META->get_slot('$config')->value($myriad) = Myriad::Config->new( commandline => ['--service_name', $svc_pkg_name] );
    my $command = new_ok('Myriad::Commands'=> ['myriad', $myriad]);
    my $working_rpc = wait_for_future( $command->rpc($testing_rpc, value => 1) )->get;
    my $failed_rpc  = wait_for_future( $command->rpc('not_an_rpc', value => 1) )->get;

    # Checking response also confirms correct rpc name.
    like( $working_rpc, qr/RPC response is {success => 1}/, 'Successful RPC command response');
    like( $failed_rpc, qr/RPC command failed due: Unknown RPC/, 'Not an actual RPC');

    # Check what service is called
    is ($_->{svc}, $myriad->registry->make_service_name($svc_pkg_name), "Correct service name passed") for $rmt_svc_cmd_called->{rpc}->@*;
};

done_testing;

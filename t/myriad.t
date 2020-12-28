use strict;
use warnings;

use Myriad;
use Myriad::Commands;
use Test::More;
use Test::Fatal;
use Test::MockModule;
use Future::AsyncAwait;
use Scalar::Util qw(refaddr);

sub loop_notifiers {
    my $loop = shift;

    my @current_notifiers = $loop->notifiers;
    my %loaded_in_loop = map { ref($_)  => 1} @current_notifiers;
    return \%loaded_in_loop;
}

sub class_slot {
    my $class = shift;

    my %slots_classes = map { ref($_)  => 1} @$class;
    return \%slots_classes;
}
my $command_module = Test::MockModule->new('Myriad::Commands');
my $command = 'test';
my $command_is_called = 0;
$command_module->mock($command, async sub { my ($self, $param) = @_; $command_is_called = $param; });

my $myriad = new_ok('Myriad');
subtest "class methods and proper initialization" => sub {
    can_ok($myriad, $_) for qw(configure_from_argv loop registry redis rpc_client rpc http subscription storage add_service service_by_name ryu shutdown run);


    my $command_param = 'Testing';
    $myriad->configure_from_argv(('-l', 'debug', '--subscription_transport', 'perl', '--rpc_transport', 'perl', '--storage_transport', 'perl', $command, $command_param));

    my $myriad_slots = class_slot($myriad);
    # Check configure_from_argv init objects
    ok($myriad_slots->{'IO::Async::Loop::Poll'}, 'Loop is set');
    isa_ok($myriad->config, 'Myriad::Config', 'Config is set');

    # Logging setup
    is($myriad->config->log_level, 'debug', 'Log level matching');
    isa_ok(@{$myriad->config->log_level->{subscriptions}}[0], 'CODE', 'Logging has been setup');

    # Tracing setup
    ok($myriad_slots->{'Net::Async::OpenTracing'}, 'Tracing is set');
    #    isa_ok($myriad->[1]->[-1], 'CODE', 'Added to shutdown tasks');
    my $current_notifiers = loop_notifiers($myriad->loop);
    ok($current_notifiers->{'Net::Async::OpenTracing'}, 'Tracing is added to  loop');

    # Redis setup
    ok($myriad_slots->{'Myriad::Transport::Redis'}, 'Redis is set');
    ok($current_notifiers->{'Myriad::Transport::Redis'}, 'Redis is added to  loop');

    # Command
    ok($myriad_slots->{'Myriad::Commands'}, 'Command is set');
    like($command_is_called, qr/$command_param/, 'Test Command has been found and called');

};

subtest "Myriad attributes setting tests" => sub {

    # RPC
    my $rpc = $myriad->rpc;
    isa_ok($rpc, 'Myriad::RPC::Implementation::Perl', 'Myriad RPC is set');
    my $current_notifiers = loop_notifiers($myriad->loop);
    ok($current_notifiers->{'Myriad::RPC::Implementation::Perl'}, 'RPC is added to loop');

    # RPC Client
    TODO: {
        local $TODO = "Make perl implementation for RPC Client";
        #my $rpc_client = $myriad->rpc_client;
        #isa_ok($rpc_client, 'Myriad::RPC::Client::Implementation::Perl', 'Myriad RPC Client is set');
        # my $current_notifiers = loop_notifiers($myriad->loop);
        #ok($current_notifiers->{'Myriad::RPC::Client::Implementation::Perl'}, 'RPC Cleint is added to loop');
        ok(!1);
    }

    # HTTP
    my $http = $myriad->http;
    isa_ok($http, 'Myriad::Transport::HTTP', 'Myriad HTTP is set');
    my $current_notifiers = loop_notifiers($myriad->loop);
    ok($current_notifiers->{'Myriad::Transport::HTTP'}, 'HTTP is added to loop');

    # Subscription
    my $subscription = $myriad->subscription;
    isa_ok($subscription, 'Myriad::Subscription::Implementation::Perl', 'Myriad Subscription is set');
    my $current_notifiers = loop_notifiers($myriad->loop);
    ok($current_notifiers->{'Myriad::Subscription::Implementation::Perl'}, 'Subscription is added to loop');

    # Storage
    my $storage = $myriad->storage;
    isa_ok($storage, 'Myriad::Storage::Implementation::Perl', 'Myriad Storage is set');

    # Registry and ryu
    isa_ok($myriad->registry, 'Myriad::Registry', 'Myriad::Registry is set');
    my $ryu = $myriad->ryu;
    isa_ok($ryu, 'Ryu::Async', 'Myriad Ryu is set');
    my $current_notifiers = loop_notifiers($myriad->loop);
    ok($current_notifiers->{'Ryu::Async'}, 'Ryu is added to loop');

};

subtest  "Run and shutdown behaviour" => sub {

    like(exception {
        $myriad->shutdown->get
    }, qr/attempting to shut down before we have started,/, 'can not shutdown as nothing started yet.');
    isa_ok(my $f = $myriad->shutdown_future, 'Future');
    is(refaddr($f), refaddr($myriad->shutdown_future), 'same Future on multiple calls');
    is(exception {
        $myriad->shutdown->get
    }, undef, 'can shut down without exceptions arising');
    is($f->state, 'done', 'shutdown future marked as done');

};
done_testing;


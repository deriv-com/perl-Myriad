use strict;
use warnings;

use Test::More;
use Myriad;
plan skip_all => 'it is not useful and will fix it later';
my @received;

package Example::Service {
    use Myriad::Service;
    async method simple_emitter : Emitter(
        channel => 'example'
    ) ($sink, $api, $args) {
        $sink->from([1..10]);
    }
    async method simple_receiver : Receiver(
        channel => 'example'
    ) ($src, $api, $args) {
        $src->each(sub { push @received, $_ });
    }
}

my $myriad = new_ok('Myriad');
$myriad->add_service(
    'Example::Service',
    name    => 'example',
)->get;
isa_ok(my $srv = $myriad->service_by_name('example'), 'Myriad::Service');

done_testing;


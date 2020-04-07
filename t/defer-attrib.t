use strict;
use warnings;

use Test::More;
use Test::Deep;

use Object::Pad;
use Future::AsyncAwait;
use IO::Async::Loop;

class Example extends IO::Async::Notifier {

use Attribute::Handlers;
use Class::Method::Modifiers;
sub Defer : ATTR(CODE) {
    my ($package, $symbol, $referent, $attr, $data, $phase, $filename, $linenum) = @_;
    my $name = *{$symbol}{NAME} or die 'need a symbol name';
    warn "defer for $package->$name\n";
    around join('::', $package, $name) => async sub {
        my ($code, $self, @args) = @_;
        warn "Deferred thing starts for $name\n";
        await $self->loop->delay_future(after => 0);
        return await $self->$code(@args);
    }
}

use Data::Dumper;
async method run : Defer (%args) {
    warn "in async method run\n";
    await $self->loop->delay_future(after => 0.5);
    return \%args;
}
}
my $loop = IO::Async::Loop->new;
$loop->add(my $example = Example->new);
is_deeply($example->run(x => 123)->get, { x => 123}, 'RPC call returned correctly');

done_testing;



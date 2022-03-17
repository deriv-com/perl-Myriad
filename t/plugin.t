use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Log::Any::Adapter qw(TAP);

is(exception {
    eval <<'EOS' or die $@;
    package Example::Plugin;
    use Myriad::Plugin;
    register Magic => sub {
        warn "magic";
    };
    1
EOS
}, undef, 'can create a plugin');
isa_ok('Example::Plugin', 'Myriad::Plugin');

is(exception {
    eval <<'EOS' or die $@;
    package Example::Service;
    use Myriad::Service;
    use Myriad::Plugin qw(Example::Plugin);
    1
EOS
}, undef, 'can create a service using that plugin');

done_testing;

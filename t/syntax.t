use strict;
use warnings;

use Test::More;
use Test::Fatal;

use Log::Any::Adapter qw(TAP);
use Log::Any qw($log);

BEGIN {
    require Myriad;
    require Myriad::Service;
}

# Need to have the main functionality loaded so that Myriad::Registry
# can work as expected.
require Myriad;

$log->infof('starting');

# Assorted syntax helper checks. So much eval.

subtest 'enables strict' => sub {
    fail('eval should not succeed with global var') if eval(q{
        package local::strict::vars;
        use Myriad::Service;
        $x = 123;
    });
    like($@, qr/Global symbol \S+ requires explicit package/, 'strict vars enabled');
    fail('eval should not succeed with symbolic refs') if eval(q{
        package local::strict::refs;
        use Myriad::Service;
        my $var = 123;
        my $name = 'var';
        print $$var;
    });
    like($@, qr/as a SCALAR ref/, 'strict refs enabled');
    fail('eval should not succeed with poetry') if eval(q{
        package local::strict::subs;
        use Myriad::Service;
        MissingSub;
    });
    like($@, qr/Bareword \S+ not allowed/, 'strict subs enabled');
};

subtest 'disables indirect object syntax' => sub {
    fail('indirect call should be fatal') if eval(q{
        package local::indirect;
        use Myriad::Service;
        indirect { 'local::indirect' => 1 };
    });
    like($@, qr/Indirect call/, 'no indirect enabled');
};

subtest 'try/catch available' => sub {
    is(eval(q{
        package local::try;
        use Myriad::Service;
        try { die 'test' } catch { 'ok' }
    }), 'ok', 'try/catch supported') or diag $@;
};

subtest 'helper methods from Scalar::Util' => sub {
    is(eval(q{
        package local::HelperMethods;
        use Myriad::Service;
        blessed(bless {}, "Nothing") eq "Nothing" or die 'blessed not found';
        'ok'
    }), 'ok', 'try/catch supported') or diag $@;
};
subtest 'dynamically available' => sub {
    is(eval(q{
        package local::dynamically;
        use Myriad::Service;
        my $x = "ok";
        {
         dynamically $x = "fail";
        }
        $x
    }), 'ok', 'dynamically supported') or diag $@;
};

subtest 'async/await available' => sub {
    isa_ok(eval(q{
        package local::asyncawait;
        use Myriad::Service;
        async sub example {
         await Future->new;
        }
        example();
    }), 'Future') or diag $@;
};

subtest 'utf8 enabled' => sub {
    local $TODO = 'probably not a valid test, fixme';
    is(eval(qq{
        package local::unicode;
        use Myriad::Service;
        "\x{2084}"
    }), "\x{2084}", 'utf8 enabled') or diag $@;
};

subtest 'Log::Any imported' => sub {
    is(eval(q{
        package local::logging;
        use Myriad::Service;
        $log->tracef("test");
        1;
    }), 1, '$log is available') or diag $@;
};

subtest 'Object::Pad' => sub {
    isa_ok(eval(q{
        package local::pad;
        use Myriad::Service;
        method test { $self->can('test') ? 'ok' : 'not ok' }
        async method test_async { $self->can('test_async') ? 'ok' : 'not ok' }
        __PACKAGE__
    }), 'IO::Async::Notifier') or diag $@;
    isa_ok('local::pad', 'Myriad::Service::Implementation');
    my $obj = new_ok('local::pad' => [name => 'test']);
    can_ok($obj, 'test');
    is($obj->test, 'ok', 'we find our own methods');
    is(exception {
        $obj->diagnostics(0)
    }, undef, 'we are able to call the built-in ->diagnostics method without issues');
};

subtest 'attributes' => sub {
    isa_ok(eval(q{
        package local::attributes;
        use Myriad::Service;
        method test :RPC { $self->can('test') ? 'ok' : 'not ok' }
        __PACKAGE__
    }), 'IO::Async::Notifier') or diag $@;
    my $obj = new_ok('local::attributes' => [name => 'test_attributes']);
    can_ok($obj, 'test');
    is($obj->test, 'ok', 'we find our own methods');
};

subtest 'Myriad::Class :v2' => sub {
    is(eval(q{
        package local::v2;
        use Myriad::Class qw(:v2);
        field $suspended;
        field $resumed;
        method suspended { $suspended }
        method resumed { $resumed }
        async method example ($f) {
            suspend { ++$suspended }
            resume { ++$resumed }
            await $f;
            return;
        }
        extended method checked ($v : Checked(NumGE(5))) { 'ok' }
        __PACKAGE__
    }), 'local::v2') or diag $@;
    my $obj = local::v2->new;
    my $f = $obj->example(my $pending = Future->new);
    is($obj->suspended // 0, 1, 'have suspended once');
    is($obj->resumed // 0, 0, 'and not yet resumed');
    $pending->done;
    is($obj->suspended // 0, 1, 'have still suspended once');
    is($obj->resumed // 0, 1, 'and resumed once now');
    is(exception {
        $obj->checked(5)
    }, undef, 'can check numeric >= 5');
    like(exception {
        $obj->checked(-3)
    }, qr/\Qsatisfying NumGE(5)/, 'numeric check fails on number out of range');
    like(exception {
        $obj->checked('xx')
    }, qr/\Qsatisfying NumGE(5)/, 'numeric check fails on invalid number');

    {
        is(eval(q{
            package local::v2::of;
            use Myriad::Class qw(:v2);
            field $example:param;
            method diff ($obj) {
             $example - ($example of $obj)
            }
            __PACKAGE__
        }), 'local::v2::of', 'can compile using of') or diag $@;
        my $x = new_ok('local::v2::of' => [example => 7]);
        my $y = new_ok('local::v2::of' => [example => 3]);
        is($x->diff($y), 4, 'of operator');
    }
    {
        is(eval(q{
            package local::v2::lex;
            use Myriad::Class qw(:v2);

            field $f = 4;
            my method lex () { $f + 1 }
            method example () {
             2 * $self->&lex
            }
            __PACKAGE__
        }), 'local::v2::lex', 'can compile using lexical methods') or diag $@;
        my $x = new_ok('local::v2::lex');
        is($x->example, 10, 'lexical method calling');
    }
    done_testing;
};
done_testing;


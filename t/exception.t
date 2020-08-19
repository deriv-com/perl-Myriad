use strict;
use warnings;

use Test::More;
use Test::Fatal;

require Myriad::Exception::Base;

subtest 'needs category' => sub {
    like(exception {
        package Exception::Example::MissingCategory;
        Myriad::Exception::Base->import;
    }, qr/missing category/, 'refuses to compile an exception class without a category');
};

subtest 'stringifies okay' => sub {
    is(exception {
        package Exception::Example::Stringification;
        sub category { 'example' }
        sub message { 'example message' }
        Myriad::Exception::Base->import;
    }, undef, 'simple exception class can be defined');
    my $ex = new_ok('Exception::Example::Stringification');
    can_ok($ex, qw(new throw message category));
    is("$ex", 'example message', 'stringifies okay');
};

subtest 'can ->throw' => sub {
    is(exception {
        package Exception::Example::Throwable;
        sub category { 'example' }
        sub message { 'this was thrown' }
        Myriad::Exception::Base->import;
    }, undef, 'simple exception class can be defined');
    isa_ok(my $ex = exception {
        Exception::Example::Throwable->throw;
    }, qw(Exception::Example::Throwable));
    is("$ex", 'this was thrown', 'message survived');
};

done_testing;


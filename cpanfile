# Syntax
requires 'meta', '>= 0.004';
requires 'mro';
requires 'indirect';
requires 'multidimensional';
requires 'bareword::filehandles';
requires 'experimental', '>= 0.032';
requires 'XS::Parse::Keyword', '>= 0.44';
requires 'Syntax::Keyword::Dynamically', '>= 0.13';
requires 'Syntax::Keyword::Try', '>= 0.29';
requires 'Syntax::Keyword::Defer', '>= 0.10';
requires 'Syntax::Keyword::Match', '>= 0.15';
requires 'Syntax::Operator::Equ', '>= 0.10';
requires 'Future', '>= 0.50';
requires 'Future::Queue', '>= 0.52';
requires 'Future::AsyncAwait', '>= 0.66';
requires 'Future::AsyncAwait::Hooks', '>= 0.02';
requires 'Future::IO', '>= 0.15';
requires 'XS::Parse::Sublike', '>= 0.22';
requires 'Object::Pad', '>= 0.809';
requires 'Role::Tiny', '>= 2.002004';
requires 'Data::Checks', '>= 0.09';
requires 'Object::Pad::FieldAttr::Checked';
requires 'Sublike::Extended';
requires 'Signature::Attribute::Checked', '>= 0.06';
# Streams
requires 'Ryu', '>= 4.000';
requires 'Ryu::Async', '>= 0.020';
# IO::Async
requires 'Heap', '>= 0.80';
requires 'IO::Async', '>= 0.803';
requires 'IO::Async::Notifier', '>= 0.803';
requires 'IO::Async::Test', '>= 0.803';
requires 'IO::Async::SSL', '>= 0.25';
# Functionality
requires 'curry', '>= 2.000001';
requires 'Log::Any', '>= 1.717';
requires 'Log::Any::Adapter', '>= 1.717';
requires 'Config::Any', '>= 0.33';
requires 'YAML::XS', '>= 0.89';
requires 'Metrics::Any', '>= 0.10';
requires 'OpenTracing::Any', '>= 1.006';
requires 'OpenTelemetry', '>= 0.023';
requires 'OpenTelemetry::SDK', '>= 0.022';
requires 'OpenTelemetry::Exporter::OTLP', '>= 0.017';
# Older versions of the protobuf library get confused by perl 5.38 boolean values in the tests
requires 'Alien::ProtoBuf';
requires 'Alien::uPB::Core';
requires 'Google::ProtocolBuffers::Dynamic', '>= 0.43';
requires 'JSON::MaybeUTF8', '>= 2.000';
requires 'Unicode::UTF8';
requires 'Time::Moment', '>= 0.44';
requires 'Sys::Hostname';
requires 'Pod::Simple::Text';
requires 'Scope::Guard';
requires 'Check::UnitCheck';
requires 'Class::Method::Modifiers';
requires 'Module::Load';
requires 'Module::Runtime';
requires 'Module::Pluggable::Object';
requires 'Math::Random::Secure';
requires 'Getopt::Long';
requires 'Pod::Usage';
requires 'List::Util', '>= 1.63';
requires 'List::Keywords', '>= 0.11';
requires 'Compress::Zstd', '>= 0.20';
# Integration
requires 'Net::Async::OpenTracing', '>= 1.001';
requires 'Log::Any::Adapter::OpenTracing', '>= 0.001';
requires 'Metrics::Any::Adapter::Statsd', '>= 0.03';
# Transport
requires 'Net::Async::Redis', '>= 6.000';
recommends 'Net::Async::Redis::XS', '>= 1.001';
requires 'Net::Async::HTTP', '>= 0.49';
requires 'Net::Async::HTTP::Server', '>= 0.14';
# Introspection
requires 'Devel::MAT::Dumper';

# Things that may move out
recommends 'Term::ReadLine';
recommends 'Linux::Inotify2';

on 'test' => sub {
    requires 'Test::More', '>= 0.98';
    requires 'Test::Deep', '>= 1.130';
    requires 'Test::Fatal', '>= 0.014';
    requires 'Test::MemoryGrowth', '>= 0.03';
    requires 'Log::Any::Adapter::TAP';
    requires 'Log::Any::Test';
    requires 'Test::CheckDeps';
    requires 'Test::NoTabs';
    requires 'Test::MockModule';
    requires 'Test::MockObject';
};

on 'develop' => sub {
    requires 'Devel::Cover::Report::Coveralls', '>= 0.11';
    requires 'Devel::Cover';
};


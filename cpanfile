# Syntax
requires 'Syntax::Keyword::Dynamically', '>= 0.04';
requires 'Syntax::Keyword::Try', '>= 0.11';
requires 'Future', '>= 0.45';
requires 'Future::AsyncAwait', '>= 0.40';
requires 'Object::Pad', '>= 0.22';
requires 'Role::Tiny', '>= 2.000';
# Streams
requires 'Ryu', '>= 1.012';
requires 'Ryu::Async', '>= 0.016';
# IO::Async
requires 'Heap', '>= 0.80';
requires 'IO::Async::Notifier', '>= 0.75';
requires 'IO::Async::Test', '>= 0.75';
requires 'IO::Async::SSL', '>= 0.22';
# Functionality
requires 'Future', '>= 0.44';
requires 'Log::Any', '>= 1.708';
requires 'Log::Any::Adapter', '>= 1.708';
requires 'Config::Any';
requires 'YAML::XS', '>= 0.81';
requires 'OpenTracing::Any', '>= 0.004';
requires 'JSON::MaybeUTF8', '>= 1.002';
# Integration
requires 'Net::Async::HTTP';
requires 'Net::Async::HTTP::Server';
requires 'Net::Async::Redis', '>= 2.001';
requires 'Net::Async::OpenTracing', '>= 0.001';
# Introspection
requires 'Devel::MAT::Dumper';

on 'test' => sub {
    requires 'Test::More', '>= 0.98';
    requires 'Test::Deep', '>= 1.124';
    requires 'Test::Fatal', '>= 0.010';
    requires 'Test::MemoryGrowth', '>= 0.003';
    requires 'Log::Any::Adapter::TAP';
    requires 'Log::Any::Test';
};

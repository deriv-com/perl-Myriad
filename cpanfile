# Syntax
requires 'Syntax::Keyword::Dynamically', '>= 0.04';
requires 'Syntax::Keyword::Try', '>= 0.11';
requires 'Future::AsyncAwait', '>= 0.39';
requires 'Object::Pad', '>= 0.20';
requires 'Role::Tiny', '>= 2.000';
# Streams
requires 'Ryu', '>= 1.012';
requires 'Ryu::Async', '>= 0.016';
# IO::Async
requires 'Heap';
requires 'IO::Async::Notifier', '>= 0.75';
requires 'IO::Async::SSL', '>= 0.22';
# Functionality
requires 'Log::Any', '>= 1.708';
requires 'Log::Any::Adapter', '>= 1.708';
requires 'Config::Any';
requires 'YAML::XS', '>= 0.81';
# Integration
requires 'Net::Async::HTTP';
requires 'Net::Async::HTTP::Server';
requires 'Net::Async::Redis', '>= 2.002_001';
requires 'Net::Async::OpenTracing', '>= 0.001';

on 'test' => sub {
    requires 'Test::More', '>= 0.98';
    requires 'Test::Deep', '>= 1.124';
    requires 'Test::Fatal', '>= 0.010';
    requires 'Log::Any::Adapter::TAP';
    requires 'Log::Any::Test';
};

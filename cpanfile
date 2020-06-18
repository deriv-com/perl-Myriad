# Syntax
requires 'Syntax::Keyword::Dynamically', '>= 0.04';
requires 'Syntax::Keyword::Try', '>= 0.11';
requires 'Future', '>= 0.45';
requires 'Future::AsyncAwait', '>= 0.40';
requires 'Object::Pad', '>= 0.28';
requires 'Role::Tiny', '>= 2.000';
# Streams
requires 'Ryu', '>= 2.001';
requires 'Ryu::Async', '>= 0.016';
# IO::Async
requires 'Heap', '>= 0.80';
requires 'IO::Async::Notifier', '>= 0.77';
requires 'IO::Async::Test', '>= 0.77';
requires 'IO::Async::SSL', '>= 0.22';
# Functionality
requires 'Log::Any', '>= 1.708';
requires 'Log::Any::Adapter', '>= 1.708';
requires 'Config::Any', '>= 0.32';
requires 'YAML::XS', '>= 0.81';
requires 'Metrics::Any', '>= 0.05';
requires 'OpenTracing::Any', '>= 0.004';
requires 'Net::Async::OpenTracing', '>= 0.001';
# Transport
requires 'Net::Async::HTTP', '>= 0.47';
requires 'Net::Async::HTTP::Server', '>= 0.13';
requires 'Net::Async::Redis', '>= 2.004';
requires 'Net::Async::AMQP', '>= 2.000';
requires 'Net::Async::SMTP', '>= 0.002';
requires 'Database::Async', 0;
requires 'Database::Async::Engine::PostgreSQL', 0;
# Introspection
requires 'Devel::MAT::Dumper';

on 'test' => sub {
    requires 'Test::More', '>= 0.98';
    requires 'Test::Deep', '>= 1.130';
    requires 'Test::Fatal', '>= 0.014';
    requires 'Test::MemoryGrowth', '>= 0.03';
    requires 'Test::Metrics::Any', 0;
    requires 'Log::Any::Adapter::TAP';
    requires 'Log::Any::Test';
};

# Syntax
requires 'mro';
requires 'indirect';
requires 'multidimensional';
requires 'bareword::filehandles';
requires 'Syntax::Keyword::Dynamically', '>= 0.06';
requires 'Syntax::Keyword::Try', '>= 0.20';
requires 'Future', '>= 0.47';
requires 'Future::Queue';
requires 'Future::AsyncAwait', '>= 0.47';
requires 'Object::Pad', '>= 0.35';
requires 'Role::Tiny', '>= 2.002003';
# Streams
requires 'Ryu', '>= 2.004';
requires 'Ryu::Async', '>= 0.017';
# IO::Async
requires 'Heap', '>= 0.80';
requires 'IO::Async::Notifier', '>= 0.77';
requires 'IO::Async::Test', '>= 0.77';
requires 'IO::Async::SSL', '>= 0.22';
# Functionality
requires 'curry', '>= 1.001';
requires 'Log::Any', '>= 1.708';
requires 'Log::Any::Adapter', '>= 1.708';
requires 'Config::Any', '>= 0.32';
requires 'YAML::XS', '>= 0.82';
requires 'Metrics::Any', '>= 0.06';
requires 'OpenTracing::Any', '>= 1.003';
requires 'JSON::MaybeUTF8', '>= 1.002';
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
# Integration
requires 'Net::Async::OpenTracing', '>= 1.000';
requires 'Log::Any::Adapter::OpenTracing', '>= 0.001';
requires 'Log::Any::Adapter::Multiplexor', '>= 0.03';
# Transport
requires 'Net::Async::Redis', '>= 3.008';
requires 'Net::Async::HTTP', '>= 0.47';
requires 'Net::Async::HTTP::Server', '>= 0.13';
requires 'Net::Async::SMTP', '>= 0.002';
requires 'Database::Async', '>= 0.013';
requires 'Database::Async::Engine::PostgreSQL', '>= 0.010';
# Introspection
requires 'Devel::MAT::Dumper';

# Things that may move out
requires 'Term::ReadLine';

on 'test' => sub {
    requires 'Test::More', '>= 0.98';
    requires 'Test::Deep', '>= 1.130';
    requires 'Test::Fatal', '>= 0.014';
    requires 'Test::MemoryGrowth', '>= 0.03';
    requires 'Log::Any::Adapter::TAP';
    requires 'Log::Any::Test';
    requires 'Test::CheckDeps';
    requires 'Test::NoTabs';
};

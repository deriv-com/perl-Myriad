package Myriad::Exception::RPC;

# VERSION
# AUTHORITY

use Myriad::Exception::Builder;

declare_exception InvalidRequest => (
    package => 'Myriad::Exception::RPC',
    category => 'rpc',
    message => 'Invalid request'
);

declare_exception MethodNotFound => (
    package => 'Myriad::Exception::RPC',
    category => 'rpc',
    message => 'Method not found'
);

declare_exception Timeout => (
    package => 'Myriad::Exception::RPC',
    category => 'rpc',
    message => 'Timeout'
);

1;

__END__


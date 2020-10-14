package Myriad::Util::UUID;

use strict;
use warnings;

use Math::Random::Secure;

sub uuid {
    # UUIDv4 (random)
    return sprintf '%04x%04x-%04x-%04x-%02x%02x-%04x%04x%04x',
        (map { Math::Random::Secure::irand(2**16) } 1..3),
        (Math::Random::Secure::irand(2**16) & 0x0FFF) | 0x4000,
        (Math::Random::Secure::irand(2**8)) & 0xBF,
        (Math::Random::Secure::irand(2**8)),
        (map { Math::Random::Secure::irand(2**16) } 1..3)
}

1;


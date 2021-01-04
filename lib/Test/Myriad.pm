package Test::Myriad;

use strict;
use warnings;

# VERSION
# AUTHORITY

use IO::Async::Loop;
use Future::Utils qw(fmap0);
use Future::AsyncAwait;
use Check::UnitCheck;

use Myriad;
use Myriad::Service::Implementation;
use Test::Myriad::Service;

our @REGISTERED_SERVICES;

my $loop = IO::Async::Loop->new();
my $myriad = Myriad->new();

=head1 NAME

Myriad::Test - a collection of helpers to test microservices.

=head1 SYNOPSIS

 import Test::Myriad;

 my $mock_service = add_service(name => 'mocked_service');

=head1 DESCRIPTION

=cut

sub add_service {
    my ($self, %args) = @_;
    my ($pkg, $meta);
    if (my $service = delete $args{service}) {
        $pkg = $service;
        $meta = $service->META;
    } elsif ($service = delete $args{name}) {
        $pkg  = "Test::Service::$service";
        $meta = Object::Pad->begin_class($pkg, extends => 'Myriad::Service::Implementation');

        {
            no strict 'refs';
            push @{$pkg . '::ISA' }, 'Myriad::Service';
            $Myriad::Service::SLOT{$pkg} = {
                map { $_ => $meta->add_slot('$' . $_) } qw(api)
            };
        }
    }

    push @REGISTERED_SERVICES, $pkg;

    return Test::Myriad::Service->new(meta => $meta, pkg => $pkg, myriad => $myriad);
}

sub import {
    Check::UnitCheck::unitcheckify(sub {
        $loop->later(sub {
            $myriad->configure_from_argv("--redis", "redis://redis");
            (fmap0 {
                $myriad->add_service($_);
            } foreach => [@REGISTERED_SERVICES])->then(sub {
                $myriad->run
            })->retain;
        });
    });
}

1;

__END__

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


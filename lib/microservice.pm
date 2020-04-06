package microservice;

use strict;
use warnings;

=head1 NAME

microservice

=head1 SYNOPSIS

 package Example::Service;
 use microservice;

 sub startup {
  $log->infof('Starting %s', __PACKAGE__);
 }

 # Trivial RPC call, provides the `example` method
 async method example : RPC {
  my ($self) = @_;
  return { ok => 1 };
 }

 # Slightly more useful - return all the original parameters
 async sub echo : RPC {
  my ($self, %args) = @_;
  return \%args;
 }

 # Default internal diagnostics checks are performed automatically,
 # this method is called after the microservice status such as Redis
 # connections, exception status etc. are verified
 async sub diagnostics {
  my ($self, $level) = @_;
  return 'ok';
 }

 1;

=head1 DESCRIPTION

Since this is supposed to be a common standard across all our code, we get to enforce a few
language features:

=over 4

=item * L<strict>

=item * L<warnings>

=item * L<utf8>

=item * no L<indirect>

=item * L<Syntax::Keyword::Try>

=item * L<Future::AsyncAwait>

=back

This also makes available a L<Log::Any> instance in the C<$log> package variable.

=cut

no indirect;
use mro;
use Future::AsyncAwait;
use Syntax::Keyword::Try;
use Syntax::Keyword::Dynamically;
use Object::Pad;

use Heap;
use IO::Async::Notifier;
use IO::Async::SSL;
use Net::Async::HTTP;

use Myriad::Service;

use Log::Any qw($log);

sub import {
	my ($called_on) = @_;
	my $class = __PACKAGE__;
	my $pkg = caller(0);

    # Apply core syntax and rules
	strict->import;
	warnings->import;
	utf8->import;
	feature->import(':5.26');
	indirect->unimport(qw(fatal));
    # This one's needed for nested scope, e.g. { package XX; use microservice; method xxx (%args) ... }
    experimental->import('signatures');
    mro::set_mro($pkg => 'c3');

    # Some well-designed modules provide direct support for import target
    Syntax::Keyword::Try->import_into($pkg);
    Syntax::Keyword::Dynamically->import_into($pkg);
    Future::AsyncAwait->import_into($pkg);

    # So the eval isn't awesome, but it is nice and easy for injecting
    # the class - without this, we have to repeat the package name :/
    Object::Pad->import_into($pkg);
    eval "package $pkg; class $pkg extends Myriad::Service;";

    {
        no strict 'refs';
        # Essentially the same as importing Log::Any qw($log) for now,
        # but we may want to customise this with some additional attributes.
        # Note that we have to store a ref to the returned value, don't
        # drop that backslash...
        *{$pkg . '::log'} = \Log::Any->get_logger(
            category => $pkg
        );
    }
}

1;

=head1 AUTHOR

Binary Group Services Ltd. C<< BINARY@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Binary Group Services Ltd 2020. Licensed under the same terms as Perl itself.


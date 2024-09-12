package Myriad::Util::Defer;

use Myriad::Class type => 'role';

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Util::Defer - provide a deferred wrapper attribute

=head1 DESCRIPTION

This is used to make an async method delay processing until later.

It can be controlled by the C<MYRIAD_RANDOM_DELAY> environment variable,
and defaults to no delay.

=cut

use constant RANDOM_DELAY => $ENV{MYRIAD_RANDOM_DELAY} || 0;

use Sub::Util;
use Attribute::Storage;

# Attribute for code that wants to defer execution
sub Defer :ATTR(CODE,NAME) ($class, $method_name, @attrs) {
    my $defer = __PACKAGE__->can('defer_method');
    $defer->($class, $method_name);
    return 1;
}

sub import ($class, @) {
    my $pkg = caller;
    push meta::get_package($pkg)->get_or_add_symbol(q{@ISA})->reference->@*, __PACKAGE__;
    return;
}

# Helper method that allows us to return a not-quite-immediate
# Future from some inherently non-async code.
sub defer_method ($package, $name) {
    $log->tracef('will defer handler for %s::%s by %f', $package, $name, RANDOM_DELAY);
    my $code = $package->can($name);
    my $replacement = async sub ($self, @args) {
        # effectively $loop->later, but in an await-compatible way:
        # either zero (default behaviour) or if we have a random
        # delay assigned, use that to drive a uniform rand() call
        $log->tracef('call to %s::%s, deferring start', $package, $name);
        await RANDOM_DELAY ? $self->loop->delay_future(
            after => rand(RANDOM_DELAY)
        ) : $self->loop->later;

        $log->tracef('deferred call to %s::%s runs now', $package, $name);

        return await $self->$code(
            @args
        );
    };
    {
        no strict 'refs';
        no warnings 'redefine';
        *{join '::', $package, $name} = $replacement if RANDOM_DELAY;
    }
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


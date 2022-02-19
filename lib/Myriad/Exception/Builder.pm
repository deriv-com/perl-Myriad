package Myriad::Exception::Builder;

use Myriad::Class class => '';

# VERSION
# AUTHORITY

=encoding utf8

=head1 NAME

Myriad::Exception::Builder - applies L<Myriad::Exception::Base> to an exception class

=head1 DESCRIPTION

See L<Myriad::Exception> for the rôle that defines the exception API.

=cut

use Myriad::Exception;
use Myriad::Exception::Base;

# Not currently used, but nice as a hint
our @EXPORT = our @EXPORT_OK = qw(declare_exception);

# When importing, you can set the default category to avoid some
# repetition when there's a long list of exceptions to be defining
our %DEFAULT_CATEGORY_FOR_CLASS;

sub import {
    my ($class, %args) = @_;
    my $pkg = caller;
    no strict 'refs';
    $DEFAULT_CATEGORY_FOR_CLASS{$pkg} = delete $args{category} if exists $args{category};
    die 'unexpected parameters: ' . join ',', sort keys %args if %args;
    *{$pkg . '::declare_exception'} = $class->can('declare_exception');
}

=head2 declare_exception

Creates a new exception under the L<Myriad::Exception> namespace.

This will be a class formed from the caller's class:

=over 4

=item * called from C<Myriad::*>, would strip the C<Myriad::> prefix

=item * any other class will remain intact

=back

e.g.  L<Myriad::RPC> when calling this would end up with classes under L<Myriad::Exception::RPC>,
but C<SomeCompany::Service::Example> would get L<Myriad::Exception::SomeCompany::Service::Example>
as the exception base class.

Takes the following parameters:

=over 4

=item * C<$name> - the exception

=item * C<%args> - extra details

=back

Details can currently include:

=over 4

=item * C<category>

=item * C<message>

=back

Returns the generated classname.

=cut

our %EXCEPTIONS;
sub declare_exception {
    my ($name, %args) = @_;
    my $caller = caller;

    my $pkg = length($name) ? (join '::', (
        delete($args{package}) || ('Myriad::Exception::' . (caller =~ s{^Myriad::}{}r))
    ), $name) : $caller;
    my $category = delete $args{category} // $DEFAULT_CATEGORY_FOR_CLASS{$caller};
    die 'invalid category ' . $category unless $category =~ /^[0-9a-z_]+$/;
    my $message = delete $args{message} // 'unknown';

    warn "declare_exception must be called from a BEGIN { ... } block (current phase ${^GLOBAL_PHASE}) for $pkg (category $category)"
        unless ${^GLOBAL_PHASE} eq 'START';
    die 'already have exception ' . $pkg if exists $EXCEPTIONS{$pkg};

    $EXCEPTIONS{$pkg} = my $class = Myriad::Class->import(
        target  => $pkg,
        class   => $pkg,
        extends => 'Myriad::Exception::Base',
    );
    $class->add_role('Myriad::Exception');
    $class->add_method(
        category => sub ($self) { $category }
    );
    $class->add_method(
        message => sub ($self) {
            my $str = $message . ' (category=' . $self->category;
            if($self->reason) {
                $str .= ' , reason=' . $self->reason;
            }
            return $str . ')';
        }
    );
    return $class;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2022. Licensed under the same terms as Perl itself.


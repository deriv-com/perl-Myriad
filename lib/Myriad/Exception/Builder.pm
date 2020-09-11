package Myriad::Exception::Builder;

use strict;
use warnings;

# VERSION
# AUTHORITY

no indirect qw(fatal);
use utf8;

=encoding utf8

=head1 NAME

Myriad::Exception::Builder - applies L<Myriad::Exception::Base> to an exception class

=head1 DESCRIPTION

See L<Myriad::Exception> for the rôle that defines the exception API.

=cut

use Myriad::Exception;
use Myriad::Exception::Base;

use Exporter qw(import export_to_level);

our @EXPORT = our @EXPORT_OK = qw(declare_exception);

sub old_import {
    my ($class, %args) = @_;
    for my $k (sort keys %args) {
        my $pkg = 'Myriad::Exception::' . $k;
        # my $pkg = caller;
        Myriad::Class->import(
            target  => $pkg,
            extends => qw(Myriad::Exception::Base)
        );
        {
            no strict 'refs';
            my $data = $args{$k};
            warn "keys = " . join ',', sort keys %$data;
            *{$pkg . '::' . $_} = $data->{$_} for keys %$data;
        }
        die 'cannot' unless $pkg->can('reason');
        die 'cannot' unless $pkg->can('category');
        Role::Tiny->apply_roles_to_package(
            $pkg => 'Myriad::Exception'
        )
    }
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

You can override this by passing something else to L</import>.

Takes the following parameters:

=over 4

=item * C<$name> - the exception

=item * C<%args> - extra details

=back

Details can currently include:

=over 4

=item * C<category>

=back

Returns the generated classname.

=cut

sub declare_exception {
    my ($name, %args) = @_;

    my $pkg = join '::', (
        delete($args{package}) || ('Myriad::Exception::' . (caller =~ s{^Myriad::}{}r))
    ), $name;

    no strict 'refs';
    push @{$pkg . '::ISA'}, qw(Myriad::Exception::Base);
    my $category = delete $args{category} // 'unknown';
    die 'invalid category ' . $category unless $category =~ /^[0-9a-z_]+$/;
    *{$pkg . '::category'} = sub { $category };
    my $message = delete $args{message} // 'unknown';
    *{$pkg . '::message'} = sub { $message };
    Role::Tiny->apply_roles_to_package(
        $pkg => 'Myriad::Exception'
    )
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020. Licensed under the same terms as Perl itself.


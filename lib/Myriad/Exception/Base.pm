package Myriad::Exception::Base;

use strict;
use warnings;

# VERSION
# AUTHORITY

use utf8;

=encoding utf8

=head1 NAME

Myriad::Exception::Base - common class for all exceptions

=head1 DESCRIPTION

See L<Myriad::Exception> for the rôle which defines the exception API.

=cut

no indirect qw(fatal);
use Myriad::Exception;

use overload '""' => sub { shift->as_string }, bool => sub { 1 }, fallback => 1;

sub new {
    my ($class, %args) = @_;
    # Force the reason to be a valid string
    # or it would cause issue with strongly typed clients.
    # Moreover, attempt to use blessed object here would crash the listener
    if ($args{reason}) {
        my $reason = "$args{reason}";
        $reason =~ s/(\s+)$//;
        $args{reason} = $reason;
    }
    bless \%args, $class;
}

=head2 reason

The failure reason. Freeform text.

=cut

sub reason { shift->{reason} }

=head2 as_string

Returns the exception message as a string.

=cut

sub as_string { shift->message }

=head2 does

Check the role ownership of the objects, added here to maintain compatibility with Object::Pad exports.
This is needed as some part of Myriad code assume that the objects created by Myriad exceptions do exports does,
which in turn to be absent.

=cut

sub does {
    use Object::Pad::MOP::Class qw(:experimental);
    my ($self, $role) = @_;

    return 0 unless $role and ref $self;

    my $klass = ref $self;
    my $klass_ptr = Object::Pad::MOP::Class->try_for_class($klass);
    return 0 unless defined $klass_ptr;

    my %roles = map {($_->name) => 1} $klass_ptr->all_roles;
    return $roles{$role} // 0;
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


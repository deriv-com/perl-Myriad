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

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>.

See L<Myriad/CONTRIBUTORS> for full details.

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2024. Licensed under the same terms as Perl itself.


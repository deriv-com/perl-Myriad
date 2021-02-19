package Myriad::Bootstrap;

use strict;
use warnings;

use 5.010;

# VERSION
# AUTHORITY

=head1 NAME

Myriad::Bootstrap - starts up a Myriad child process ready for loading modules
for the main functionality

=head1 DESCRIPTION

Controller process for managing an application.

Provides a minimal parent process which starts up a child process for
running the real application code. A pipe is maintained between parent
and child for exchanging status information, with a secondary UNIX domain
socket for filedescriptor handover.

The parent process loads only two additional modules - strict and warnings
- with the rest of the app-specific modules being loaded in the child. This
is enforced: any other modules found in C<< %INC >> will cause the process to
exit immediately.

Signals:

=over 4

=item * C<HUP> - Request to recycle all child processes

=item * C<TERM> - Shut down all child processes gracefully

=item * C<KILL> - Immediate shutdown for all child processes

=back

The purpose of this class is to support development usage: it provides a
minimal base set of code that can load up the real modules in separate
forks, and tear them down again when dependencies or local files change.

We avoid even the standard CPAN modules because one of the changes we're
watching for is C<< cpanfile >> content changing, if there's a new module
or updated version we want to be very sure that it's properly loaded.

One thing we explicitly B<don't> try to do is handle Perl version or executable
changing from underneath us - so this is very much a fork-and-call approach,
rather than fork-and-exec.

=cut

our %ALLOWED_MODULES = map {
    $_ => 1
} qw(
        strict
        warnings
    ),
    __PACKAGE__;

our %constant;

=head1 METHODS - Class

=head2 allow_modules

Add modules to the whitelist.

Takes a list of module names in the same format as C<< %INC >> keys.

Don't ever use this.

=cut

sub allow_modules {
    my $class = shift;
    @ALLOWED_MODULES{@_} = (1) x @_;
}

sub open_pipe {
    # Establish comms channel for child process
    socketpair my $child_pipe, my $parent_pipe, $constant{AF_UNIX}, $constant{SOCK_STREAM}, $constant{PF_UNSPEC}
        or die $!;

    { # Unbuffered writes
        my $old = select($child_pipe);
        $| = 1; select($parent_pipe);
        $| = 1; select($old);
    }

    return ($parent_pipe, $child_pipe);
}

sub make_pipe_nonblocking {
    my $pipe = shift;
    my $flags = fcntl($pipe, $constant{F_GETFL}, 0)
        or die "Can't get flags for the socket: $!\n";

    $flags = fcntl($pipe, $constant{F_SETFL}, $flags | $constant{O_NONBLOCK})
        or die "Can't set flags for the socket: $!\n";
}

sub listen_to_pipe {
    my ($pipe, $on_read) = @_; 
    # See https://perldoc.perl.org/functions/select#select-RBITS,WBITS,EBITS,TIMEOUT
    # for a better understanding
    my $input = '';
    my $rin = my $win = '';
    vec($rin, fileno($pipe), 1) = 1;
    my $ein = $rin | $win;
    
    ACTIVE:
    while(1) {
        die $! unless defined(my $nfound = select my $rout = $rin, my $wout = $win, my $eout = $ein, 5);
        if($nfound) {
            my $rslt = sysread $pipe, my $buf, 4096;
            last ACTIVE unless $rslt;
            $input .= $buf;
            while($input =~ s/^[\r\n]*(.*)[\r\n]+//) {
                $on_read->($1);
            }
        }
    }
}

=head2 boot

Given a target coderef or classname, prepares the fork and communication
pipe, then starts the code.

=cut

sub boot {
    my ($class, $target) = @_;
    my $parent_pid = $$;
    # Most of the handling here involves catching things, and reporting
    # to the parent via STDOUT
    $SIG{HUP} = sub {
        say "$$ - HUP detected";
    };

    { # Read constants from various modules without loading them into the main process
        die $! unless defined(my $pid = open my $child, '-|');
        my %constant_map = (
            Socket => [qw(AF_UNIX SOCK_STREAM PF_UNSPEC)],
            Fcntl  => [qw(F_GETFL F_SETFL O_NONBLOCK)],
            POSIX  => [qw(WNOHANG)],
        );
        unless($pid) {
            # We've forked, so we're free to load any extra modules we'd like here
            require Module::Load;
            for my $pkg (sort keys %constant_map) {
                Module::Load::load($pkg);
                $pkg->import;
                {
                    no strict 'refs';
                    print "$_=" . *{join '::', $pkg, $_}->() . "\n" for @{$constant_map{$pkg}};
                }
            }
            exit 0;
        }
        {
            # A poor attempt at a data-exchange protocol indeed, but one with the advantage
            # of simplicity and readability for anyone investigating via `strace`
            my @constants = map @$_, values %constant_map;
            while(<$child>) {
                my ($k, $v) = /^([^=]+)=(.*)$/;
                $constant{$k} = $v;
            }
            close $child or die $!;
            die "Missing constant $_" for grep !exists $constant{$_}, @constants;
        }
    }
    

    my ($intoify_parent_pipe, $inotify_child_pipe) = open_pipe();

    {
        if(my $pid = fork // die "fork! $!") {
            close $inotify_parent_pipe;
            listen_to_pipe($inotify_child_pipe, sub {
                # TODO: kill the Myriad instance and reload
            });
            
            if(my $exit = waitpid $pid, 0) {
                say "$$ Exit was $exit";
            } else {
                say "$$ No exit code yet";
            }
            say "$$ - Done";
            exit 0;
        } else {
            require Module::Load;
            Module::Load::load('Linux::Inotify2');
            my $watcher = Linux::Inotify2->new();
            
            listen_to_pipe($parent_pipe, sub {
                $watcher->watch(shift, IN_MODIFY);
            });

            while (my $events = $watcher->read) {
                print $parent_pipe "reload"
            }
        }
    }

    my ($parent_pipe, $child_pipe) = open_pipe();

    my $active = 1;
    MAIN:
    while($active) {
        if(my $pid = fork // die "fork: $!") {
            say "$$ - Parent with $pid child";

            # The parent watches for events from the child...
            close $parent_pipe or die $!;

            make_pipe_nonblocking($child_pipe);

            # Note that we don't have object methods available yet, since that'd pull in IO::Handle
            print $child_pipe "Parent active\n";

            { # Make sure we didn't pull in anything unexpected
                my %found = map {
                    # Convert filename to package name
                    (s{/}{::}gr =~ s{\.pm$}{}r) => 1,
                } keys %INC;

                # Trim out anything that we arbitrarily decided would be fine
                delete @found{keys %ALLOWED_MODULES};

                my $loaded_modules = join ',', sort keys %found;
                die "excessive module loading detected: $loaded_modules" if $loaded_modules;
            }

            my $stop = 0;
            local $SIG{HUP} = sub {
                say "$$ - HUP detected in parent";
                kill 3, $pid;
            };

            listen_to_pipe($child_pipe, sub {say shift});
            
            if(my $exit = waitpid $pid, 0) {
                say "$$ Exit was $exit";
                last MAIN;
            } else {
                say "$$ No exit code yet";
            }
            say "$$ - Done";
            exit 0;
        } else {
            say "$$ - Child with parent " . $parent_pid;
            
            make_pipe_nonblocking($parent_pipe);

            # We'd expect to pass through some more details here as well
            my %args = (
                parent_pipe => $parent_pipe
            );

            # Support coderef or package name
            if(ref $target) {
                $target->(%args);
            } else {
                require Module::Load;
                Module::Load::load($target);
                $target->new->run(%args);
            }
            exit 0;
        }
    }
}

1;

=head1 AUTHOR

Deriv Group Services Ltd. C<< DERIV@cpan.org >>

=head1 LICENSE

Copyright Deriv Group Services Ltd 2020-2021. Licensed under the same terms as Perl itself.


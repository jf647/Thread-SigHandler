#
# $Id: SigHandler.pm,v 1.1 2003/12/29 00:40:18 james Exp $
#

=head1 NAME

Thread::SigHandler - start a dedicated thread to handle signals

=head1 SYNOPSIS

 use Thread::SigHandler;
 my $handler = Thread::SigHandler->new(
   TERM => \&foo,
 );

=cut

package Thread::SigHandler;

use strict;
use warnings;
use threads;

our $VERSION = '0.10';

use Carp        qw|croak|;
use Config;

# create a sighandler object
sub new
{
    
    my $self = shift;
    my $class = ref $self || $self;
    my %args = @_;
    
    # create mappings from signal name to number and back
    my $i = 0;
    my %signum;
    my @signame;
    defined $Config{sig_name} || die "No sigs?";
    foreach my $name (split(/\s+/, $Config{sig_name})) {
        $signum{$name} = $i;
        $signame[$i] = $name;
        $i++;
    }
    
    # create a hash of signal numbers to actions
    my %sigs2acts;
    while( my($sig, $action) = each %args ) {
        
        # make sure the action is a coderef
        unless( ref $action eq 'CODE' ) {
            croak("action for signal $sig is not a coderef");
        }
        
        # if it's a number, make sure it's valid
        if( $sig =~ m/^\d+$/ ) {
            unless( defined $signame[$sig] ) {
                croak("invalid signal number $sig");
            }
            $sigs2acts{$sig} = $action;
        }
        
        # otherwise try to get the number from the name
        elsif( defined $signum{$sig} ) {
            $sigs2acts{$signum{$sig}} = $action;
        }
        
        # otherwise it must be invalid
        else {
            croak("invalid signal $sig\n");
        }
        
    }
    
    # create the object
    $self = bless { actions => \%sigs2acts }, $class;
    
    # start the signal handling thread
    $self->start_sighandler;
    
    return $self;
    
}

# start the dedicated sighandler thread
sub start_sighandler
{
    
    my $self = shift;
    
    # block registered signals in the calling thread
    require POSIX;
    my $sigset = POSIX::SigSet->new( keys %{ $self->{actions} } );
    unless( defined POSIX::sigprocmask(&POSIX::SIG_BLOCK, $sigset) ) {
        croak("could not block registered signals in calling thread");
    }
    $self->{sigset} = $sigset;

    # start a dedicated signal handling thread
    my $thread = threads->create('sighandler', $self);
    
    # remember the thread object id
    $self->{handler_tid} = $thread->tid;
    
    return $self;
    
    
}

# the dedicated thread that receives signals
sub sighandler
{
    
    my $self = shift;
    
    # create sigactions for each registered signal
    while( my($sig, $action) = each %{ $self->{actions} } ) {
        my $sigaction = POSIX::SigAction->new($sig, $self->{sigset});
        unless( defined POSIX::sigaction($sig, $sigaction) ) {
            croak("could not register signal handler for sig $sig");
        }
    }
    
    # unblock the registered signals (we inherited the block)
    unless( defined POSIX::sigprocmask(&POSIX::SIG_UNBLOCK, $self->{sigset}) ) {
        croak("could not unblock registered signals in dedicated thread");
    }
    
    # wait for signals to come in
    while( 1 ) { # do forever
        select(undef, undef, undef, 5);
    }
    
}

# keep require happy
1;


__END__

=head1 DESCRIPTION

                  *** A note of CAUTION ***

 This module only functions on Perl version 5.8.0 and later.
 And then only when threads are enabled with -Dusethreads.  It
 is of no use with any version of Perl before 5.8.0 or without
 threads enabled.

                  *************************

Thread::SigHandler starts a dedicated signal handling thread. It provides a
similar functionality as Thread::Signal did with 5.005 threads.

Note that there is a Thread::Signal module on CPAN designed to work with
ithreads; this module performs a different task and is likely not to work on
the thread implementations that Thread::SigHandler is designed for (see
L<"COMPATIBILITY"> and L<"TODO"> below). For the remainder of this document
(save for L<"TODO">, references to Thread::Signal refer to the module that
shipped with perl 5.005_03.

When the dedicated signal handling thread is started, the registered signals
are blocked in the calling (typically the main) thread. Any threads
subsequently started by the calling thread will inherit this signal mask.

The dedicated thread blocks all signals except those that are registered.
Thus, the registered signals will only be acted upon in the dedicated
thread, while all unregistered signals should retain their default behaviour
in all threads except the dedicated thread.

=head1 CONSTRUCTOR

To create the signal handling thread, call the B<new> method. The parameters
to the constructor are a series of key-value pairs, with the signal names
(or numbers) as keys and the actions as values. If signals are given as
names they should omit the leading C<SIG>. The action for each signal is an
anonymous subroutine (coderef).

The signal handling thread should be constructed early on in the program's
behaviour, preferably before any other threads are started. If there is a
need to start a thread before starting the signal handling, POSIX::SigAction
should be used to block delivery of signals in that thread; otherwise there
is a chance that the lone thread could receive a signal and act upon it
instead of the dedicated thread.

If code references are used, they must be fully defined starting the signal
handling thread. This example will not work:

 use subs 'handle_sigterm';
 sub init
    Thread::SigHandler->new(
        TERM => \&handle_sigterm,
    );
    sub handle_sigterm { die; }
 }

because when the B<new> method is called (and the dedicated thread is
started), C<handle_sigterm()> will be an undefined subroutine. The
subsequent re-definition of the subroutine will not be seen in the dedicated
thread due to the default-to-unshared semantics of ithreads.

If you need to change signal handling actions after the dedicated thread has
been started, you can use the B<shutdown> method to stop the dedicated
thread and then start another with a different set of signal actions.

The constructor returns an Thread::SigHandler object which can be used to
shut down the dedicated thread later on in the program. The signal handling
thread will be shut down when this object goes out of scope. Any error in
the constructor will throw an exception (another reason to start the thread
as early as possible).

=head1 METHODS

=head2 shutdown()

=head1 COMPATIBILITY

Signal handling under Perl ithreads is heavily dependant on the underlying
thread implementation. Thread::SigHandler is designed to work with
implementations that confirm to the POSIX thread standard. With other thread
implementations, Thread::SigHandler may break into a great many pieces.
Patches are welcomed. On the upside, implementations where
Thread::SigHandler does not work may not exhibit the unreliable signal
delivery that makes this module necessary in the first place. The
pseudo-process thread implementation used in Linux is one such
implementation.

=head1 TODO

This is admittedly not the most elegant solution to signal handling in
threads, but POSIX didn't exactly make it easy on any implementation to do
so. I'd like to make this module allow for simple signal management in a
threaded program, possibly still allowing for redefinition of actions after
the dedicated thread has been started.

Perl 5.005 using Threads.pm had a simpler solution in Thread::Signal that
started a dedicated thread as soon as the module was loaded; signals caught
in any other thread were written to a pipe that was shared among all
threads. The default-to-unshared semantics of ithreads prevents this direct
approach, as the signal handling actions must be in memory prior to the
signal handling thread being started.

Liz (E<lt>liz@dijkmat.nlE<gt>) created a new version of Thread::Signal which
does something slightly different: it allows you to send a signal to a
specific thread. This only works on thread implementations that use
pseudo-processes (which conversely don't have the issue of not knowing which
thread will receive a signal). Apparantly fewer and fewer systems are using
pseudo-process implementations, so going forward the approach laid out in
Thread::SigHandler may be more compatible.

=head1 SEE ALSO

L<Thread::App::Shutdown>

L<Thread::Signal> (both the perl 5.005_03 version and Liz's version on CPAN)

=head1 AUTHOR

James FitzGibbon E<lt>jfitz@CPAN.orgE<gt>

=head1 COPYRIGHT

Copyright (c) 2003, James FitzGibbon.  All Rights Reserved.

This module is free software. You may use it under the same terms as perl
itself.

=cut

#
# EOF


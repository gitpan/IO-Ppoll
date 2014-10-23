#  You may distribute under the terms of either the GNU General Public License
#  or the Artistic License (the same terms as Perl itself)
#
#  (C) Paul Evans, 2007 -- leonerd@leonerd.org.uk

package IO::Ppoll;

use strict;

use Carp;

require DynaLoader;
require Exporter;

require POSIX;

our @ISA = qw( DynaLoader Exporter );

our $VERSION = 0.03;

our @EXPORT = qw(
   POLLIN
   POLLOUT
   POLLERR
   POLLHUP
   POLLNVAL
);

bootstrap IO::Ppoll $VERSION;

=head1 NAME

C<IO::Ppoll> - Object interface to Linux's C<ppoll()> call

=head1 SYNOPSIS

 use IO::Ppoll qw( POLLIN POLLOUT );
 use POSIX qw( sigprocmask SIG_BLOCK SIGHUP );

 my $ppoll = IO::Poll->new();
 $ppoll->mask( $input_handle => POLLIN );
 $ppoll->mask( $output_handle => POLLOUT );

 $SIG{HUP} = sub { print "SIGHUP happened\n"; };
 sigprocmask( SIG_BLOCK, POSIX::SigSet->new( SIGHUP ), undef );

 # If a SIGHUP happens, it can only happen during this poll
 $ppoll->poll( $timeout );

 $input_ev = $poll->events( $input_handle );

=head1 DESCRIPTION

C<IO::Ppoll> is a simple interface to Linux's C<ppoll()> system call. It
provides an interface that is drop-in compatible with L<IO::Poll>. The object
itself stores a signal mask that will be in effect during the actual
C<ppoll()> system call and has additional methods for manipulating the signal
mask.

The C<ppoll()> system call itself atomically switches the process's signal
mask to that provided by the call, waits identically to C<poll()>, then
switches it back again. This allows a program to safely wait on either file
handle IO or signals, without needing such tricks as a self-connected pipe or
socket.

The usual way in which this is used is to block the signals the application is
interested in during the normal running of code. Whenever the C<ppoll()> wait
is entered the process signal mask will be switched to that stored in the 
object. If there are any pending signals, the Linux kernel will then deliver
them and make C<ppoll()> return -1 with C<errno> set to C<EINTR>. If no
signals are pending, it will wait as a normal C<poll()> would. This guarantees
the signals will only be delivered during the C<ppoll()> wait, when it would
be safe to do so.

=cut

=head1 CONSTRUCTOR

=cut

=head2 $ppoll = IO::Ppoll->new()

Returns a new instance of an C<IO::Ppoll> object. It will contain no file
handles and its signal mask will be empty.

=cut

sub new
{
   my $class = shift;

   my $self = bless {
      fds => "",
      nfds => 0,
      handles => [],
      sigmask => POSIX::SigSet->new(),
   }, $class;

   return $self;
}

=head1 METHODS

=cut

=head2 $mask = $ppoll->mask( $handle )

Returns the current mask bits for the given IO handle

=head2 $ppoll->mask( $handle, $newmask )

Sets the mask bits for the given IO handle. If C<$newmask> is 0, the handle
will be removed.

=cut

sub mask
{
   my $self = shift;
   my ( $handle, $newmask ) = @_;

   my $fd = fileno $handle;
   defined $fd or croak "Expected a filehandle";

   if( @_ > 1 ) {
      if( $newmask ) {
         $self->{handles}->[$fd] = $handle;
         set_events( $self->{fds}, $self->{nfds}, $fd, $newmask );
      }
      else {
         delete $self->{handles}->[$fd];
         del_events( $self->{fds}, $self->{nfds}, $fd );
      }
   }
   else {
      return get_events( $self->{fds}, $self->{nfds}, $fd );
   }
}

=head2 $ret = $ppoll->poll( $timeout )

Call the C<ppoll> system call. If C<$timeout> is not supplied then no timeout
value will be passed to the system call. Returns the result of the system call
which is the number of filehandles that have non-zero events, 0 on timeout, or
-1 if an error occurred (including being interrupted by a signal).

=cut

sub poll
{
   my $self = shift;
   my ( $timeout ) = @_;

   return do_poll( $self->{fds}, $self->{nfds}, $timeout * 1000, $self->{sigmask} );
}

=head2 $bits = $ppoll->events( $handle )

Returns the event mask which represents the events that happened on the
filehandle during the last call to C<poll()>.

=cut

sub events
{
   my $self = shift;
   my ( $handle ) = @_;

   my $fd = fileno $handle;
   defined $fd or croak "Expected a filehandle";

   return get_revents( $self->{fds}, $self->{nfds}, $fd );
}

=head2 $ppoll->remove( $handle )

Removes the handle from the list of file descriptors for the next poll.

=cut

sub remove
{
   my $self = shift;
   my ( $handle ) = @_;

   $self->mask( $handle, 0 );
}

=head2 @handles = $ppoll->handles( $bits )

Returns a list of handles. If C<$bits> is not given then all of the handles
will be returned. If C<$bits> is given then the list will only contain handles
which reported at least one of the bits specified during the last C<poll()>
call.

=cut

sub handles
{
   my $self = shift;
   my ( $events ) = @_;

   my @fds;
   if( @_ ) {
      @fds = get_fds_for( $self->{fds}, $self->{nfds}, $events );
   }
   else {
      @fds = get_fds( $self->{fds}, $self->{nfds} );
   }

   my $handle_map = $self->{handles};
   return map { $handle_map->[$_] } @fds;
}

=head2 $sigset = $ppoll->sigmask

Returns the C<POSIX::SigSet> object in which the signal mask is stored. Since
this is a reference to the object the C<IO::Ppoll> object uses, any
modifications made to it will be reflected in the signal mask given to the
C<ppoll()> system call.

=head2 $ppoll->sigmask( $newsigset )

Sets the C<POSIX::SigSet> object in which the signal mask is stored. Usually
this is not required, as a new C<IO::Ppoll> is initialised with an empty set,
and the C<sigmask_add()> and C<sigmask_del()> methods can be used to modify
it.

=cut

sub sigmask
{
   my $self = shift;
   my ( $newmask ) = @_;

   if( @_ ) {
      $self->{sigmask} = $newmask;
   }
   else {
      return $self->{sigmask};
   }
}

=head2 $ppoll->sigmask_add( @signals )

Adds the given signals to the signal mask. These signals will be blocked
during the C<poll()> call.

=cut

sub sigmask_add
{
   my $self = shift;
   my @signals = @_;

   $self->{sigmask}->addset( $_ ) foreach @signals;
}

=head2 $ppoll->sigmask_del( @signals )

Removes the given signals from the signal mask. These signals will not be
blocked during the C<poll()> call, and may be delivered while C<poll()> is
waiting.

=cut

sub sigmask_del
{
   my $self = shift;
   my @signals = @_;

   $self->{sigmask}->delset( $_ ) foreach @signals;
}

=head2 $present = $ppoll->sigmask_ismember( $signal )

Tests if the given signal is present in the signal mask.

=cut

sub sigmask_ismember
{
   my $self = shift;
   my ( $signal ) = @_;

   return $self->{sigmask}->ismember( $signal );
}

# Keep perl happy; keep Britain tidy
1;

__END__

=head1 SEE ALSO

=over 4

=item *

L<IO::Poll> - Object interface to system poll call

=item *

C<ppoll(2)> - wait for some event on a file descriptor (Linux manpages)

=back

=head1 AUTHOR

Paul Evans E<lt>leonerd@leonerd.org.ukE<gt>

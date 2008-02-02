/*  You may distribute under the terms of either the GNU General Public License
 *  or the Artistic License (the same terms as Perl itself)
 *
 *  (C) Paul Evans, 2007 -- leonerd@leonerd.org.uk
 */

#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include "poll.h"

MODULE = IO::Ppoll      PACKAGE = IO::Ppoll

BOOT:
{
  HV *stash;
  stash = gv_stashpvn("IO::Ppoll", 9, TRUE);
  newCONSTSUB(stash, "POLLIN",  newSViv(POLLIN));
  newCONSTSUB(stash, "POLLOUT", newSViv(POLLOUT));
  newCONSTSUB(stash, "POLLERR", newSViv(POLLERR));
  newCONSTSUB(stash, "POLLHUP", newSViv(POLLHUP));
  newCONSTSUB(stash, "POLLNVAL",newSViv(POLLNVAL));
}

SV *
get_events(fds, nfds, fd)
    SV *fds
    int nfds
    int fd
  INIT:
    int i;
    struct pollfd *fds_real;
  CODE:
    fds_real = (struct pollfd *)SvPV_nolen(fds);
    for(i = 0; i < nfds; i++) {
      if(fds_real[i].fd == fd)
        XSRETURN_IV(fds_real[i].events);
    }
    XSRETURN_NO;

int
get_revents(fds, nfds, fd)
    SV *fds
    int nfds
    int fd
  INIT:
    int i;
    struct pollfd *fds_real;
  CODE:
    fds_real = (struct pollfd *)SvPV_nolen(fds);
    for(i = 0; i < nfds; i++) {
      if(fds_real[i].fd == fd)
        XSRETURN_IV(fds_real[i].revents);
    }
    XSRETURN_NO;

void
get_fds(fds, nfds)
    SV *fds
    int nfds
  INIT:
    int i;
    struct pollfd *fds_real;
  PPCODE:
    fds_real = (struct pollfd *)SvPV_nolen(fds);
    EXTEND(SP, nfds);
    for(i = 0; i < nfds; i++) {
      int fd = fds_real[i].fd;
      mPUSHi(fd);
    }

void
get_fds_for(fds, nfds, events)
    SV *fds
    int nfds
    int events
  INIT:
    int i;
    struct pollfd *fds_real;
  PPCODE:
    fds_real = (struct pollfd *)SvPV_nolen(fds);
    EXTEND(SP, nfds);
    for(i = 0; i < nfds; i++) {
      int fd;
      if((fds_real[i].revents & events) == 0)
        continue;
      fd = fds_real[i].fd;
      mPUSHi(fd);
    }

void
set_events(fds, nfds, fd, newmask)
    SV *fds
    int &nfds
    int fd
    int newmask
  CODE:
    struct pollfd *fds_real = (struct pollfd *)SvPV_nolen(fds);
    int i;
    for(i = 0; i < nfds; i++) {
      if(fds_real[i].fd == fd) {
        fds_real[i].events = newmask;
        break;
      }
    }
    if(i == nfds) {
      nfds++;
      SvGROW(fds, nfds * sizeof(struct pollfd));
      SvCUR_set(fds, nfds * sizeof(struct pollfd));
      SvPOK_only(fds);
      fds_real = (struct pollfd *)SvPV(fds, PL_na);
      fds_real[i].fd = fd;
      fds_real[i].events = newmask;
    }
  OUTPUT:
    nfds

void
del_events(fds, nfds, fd)
    SV *fds
    int &nfds
    int fd
  INIT:
    struct pollfd *fds_real;
  CODE:
    fds_real = (struct pollfd *)SvPV_nolen(fds);
    int i;
    for(i = 0; i < nfds; i++) {
      if(fds_real[i].fd == fd) {
        /* Since we don't care about the ordering here, just move the
         * top one down */
        fds_real[i]= fds_real[nfds];
        nfds--;
        SvCUR_set(fds, nfds * sizeof(struct pollfd));
        break;
      }
    }
  OUTPUT:
    nfds

int
do_poll(fds, nfds, timeout, sigmask)
    SV *fds
    int nfds
    SV *timeout
    SV *sigmask
  INIT:
    struct pollfd *fds_real;
    struct timespec timeout_real; char timeout_valid;
    sigset_t *sigmask_real;
    int pollret;
  CODE:
    fds_real = (struct pollfd *)SvPV_nolen(fds);

    if(SvOK(timeout)) {
      if(SvNOK(timeout)) {
        double timeout_msec = SvNV(timeout);
        timeout_real.tv_sec = ((long)timeout_msec) / 1000;
        timeout_real.tv_nsec = 1000000 * (timeout_msec - 1000*timeout_real.tv_sec);
      }
      else {
        long timeout_msec = SvIV(timeout);
        timeout_real.tv_sec = timeout_msec / 1000;
        timeout_real.tv_nsec = 1000000 * (timeout_msec % 1000);
      }
      timeout_valid = 1;
    }
    else
      timeout_valid = 0;

    if(SvOK(sigmask)) {
      /* This code borrowed from POSIX.xs */
      IV tmp = SvIV((SV*)SvRV(sigmask));
      sigmask_real = INT2PTR(sigset_t*, tmp);
    }
    else
      sigmask_real = NULL;

    RETVAL = ppoll(fds_real, nfds, timeout_valid ? &timeout_real : NULL, sigmask_real);
  OUTPUT:
    RETVAL

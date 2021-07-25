#line 1 "Errno.pm"
# -*- buffer-read-only: t -*-
#
# This file is auto-generated. ***ANY*** changes here will be lost
#

package Errno;
require Exporter;
use strict;

use Config;
"$Config{'archname'}-$Config{'osvers'}" eq
"x86_64-linux-thread-multi-3.16.0-4-amd64" or
	die "Errno architecture (x86_64-linux-thread-multi-3.16.0-4-amd64) does not match executable architecture ($Config{'archname'}-$Config{'osvers'})";

our $VERSION = "1.25";
$VERSION = eval $VERSION;
our @ISA = 'Exporter';

my %err;

BEGIN {
    %err = (
	EPERM => 1,
	ENOENT => 2,
	ESRCH => 3,
	EINTR => 4,
	EIO => 5,
	ENXIO => 6,
	E2BIG => 7,
	ENOEXEC => 8,
	EBADF => 9,
	ECHILD => 10,
	EAGAIN => 11,
	EWOULDBLOCK => 11,
	ENOMEM => 12,
	EACCES => 13,
	EFAULT => 14,
	ENOTBLK => 15,
	EBUSY => 16,
	EEXIST => 17,
	EXDEV => 18,
	ENODEV => 19,
	ENOTDIR => 20,
	EISDIR => 21,
	EINVAL => 22,
	ENFILE => 23,
	EMFILE => 24,
	ENOTTY => 25,
	ETXTBSY => 26,
	EFBIG => 27,
	ENOSPC => 28,
	ESPIPE => 29,
	EROFS => 30,
	EMLINK => 31,
	EPIPE => 32,
	EDOM => 33,
	ERANGE => 34,
	EDEADLK => 35,
	EDEADLOCK => 35,
	ENAMETOOLONG => 36,
	ENOLCK => 37,
	ENOSYS => 38,
	ENOTEMPTY => 39,
	ELOOP => 40,
	ENOMSG => 42,
	EIDRM => 43,
	ECHRNG => 44,
	EL2NSYNC => 45,
	EL3HLT => 46,
	EL3RST => 47,
	ELNRNG => 48,
	EUNATCH => 49,
	ENOCSI => 50,
	EL2HLT => 51,
	EBADE => 52,
	EBADR => 53,
	EXFULL => 54,
	ENOANO => 55,
	EBADRQC => 56,
	EBADSLT => 57,
	EBFONT => 59,
	ENOSTR => 60,
	ENODATA => 61,
	ETIME => 62,
	ENOSR => 63,
	ENONET => 64,
	ENOPKG => 65,
	EREMOTE => 66,
	ENOLINK => 67,
	EADV => 68,
	ESRMNT => 69,
	ECOMM => 70,
	EPROTO => 71,
	EMULTIHOP => 72,
	EDOTDOT => 73,
	EBADMSG => 74,
	EOVERFLOW => 75,
	ENOTUNIQ => 76,
	EBADFD => 77,
	EREMCHG => 78,
	ELIBACC => 79,
	ELIBBAD => 80,
	ELIBSCN => 81,
	ELIBMAX => 82,
	ELIBEXEC => 83,
	EILSEQ => 84,
	ERESTART => 85,
	ESTRPIPE => 86,
	EUSERS => 87,
	ENOTSOCK => 88,
	EDESTADDRREQ => 89,
	EMSGSIZE => 90,
	EPROTOTYPE => 91,
	ENOPROTOOPT => 92,
	EPROTONOSUPPORT => 93,
	ESOCKTNOSUPPORT => 94,
	ENOTSUP => 95,
	EOPNOTSUPP => 95,
	EPFNOSUPPORT => 96,
	EAFNOSUPPORT => 97,
	EADDRINUSE => 98,
	EADDRNOTAVAIL => 99,
	ENETDOWN => 100,
	ENETUNREACH => 101,
	ENETRESET => 102,
	ECONNABORTED => 103,
	ECONNRESET => 104,
	ENOBUFS => 105,
	EISCONN => 106,
	ENOTCONN => 107,
	ESHUTDOWN => 108,
	ETOOMANYREFS => 109,
	ETIMEDOUT => 110,
	ECONNREFUSED => 111,
	EHOSTDOWN => 112,
	EHOSTUNREACH => 113,
	EALREADY => 114,
	EINPROGRESS => 115,
	ESTALE => 116,
	EUCLEAN => 117,
	ENOTNAM => 118,
	ENAVAIL => 119,
	EISNAM => 120,
	EREMOTEIO => 121,
	EDQUOT => 122,
	ENOMEDIUM => 123,
	EMEDIUMTYPE => 124,
	ECANCELED => 125,
	ENOKEY => 126,
	EKEYEXPIRED => 127,
	EKEYREVOKED => 128,
	EKEYREJECTED => 129,
	EOWNERDEAD => 130,
	ENOTRECOVERABLE => 131,
	ERFKILL => 132,
	EHWPOISON => 133,
    );
    # Generate proxy constant subroutines for all the values.
    # Well, almost all the values. Unfortunately we can't assume that at this
    # point that our symbol table is empty, as code such as if the parser has
    # seen code such as C<exists &Errno::EINVAL>, it will have created the
    # typeglob.
    # Doing this before defining @EXPORT_OK etc means that even if a platform is
    # crazy enough to define EXPORT_OK as an error constant, everything will
    # still work, because the parser will upgrade the PCS to a real typeglob.
    # We rely on the subroutine definitions below to update the internal caches.
    # Don't use %each, as we don't want a copy of the value.
    foreach my $name (keys %err) {
        if ($Errno::{$name}) {
            # We expect this to be reached fairly rarely, so take an approach
            # which uses the least compile time effort in the common case:
            eval "sub $name() { $err{$name} }; 1" or die $@;
        } else {
            $Errno::{$name} = \$err{$name};
        }
    }
}

our @EXPORT_OK = keys %err;

our %EXPORT_TAGS = (
    POSIX => [qw(
	E2BIG EACCES EADDRINUSE EADDRNOTAVAIL EAFNOSUPPORT EAGAIN EALREADY
	EBADF EBUSY ECHILD ECONNABORTED ECONNREFUSED ECONNRESET EDEADLK
	EDESTADDRREQ EDOM EDQUOT EEXIST EFAULT EFBIG EHOSTDOWN EHOSTUNREACH
	EINPROGRESS EINTR EINVAL EIO EISCONN EISDIR ELOOP EMFILE EMLINK
	EMSGSIZE ENAMETOOLONG ENETDOWN ENETRESET ENETUNREACH ENFILE ENOBUFS
	ENODEV ENOENT ENOEXEC ENOLCK ENOMEM ENOPROTOOPT ENOSPC ENOSYS ENOTBLK
	ENOTCONN ENOTDIR ENOTEMPTY ENOTSOCK ENOTTY ENXIO EOPNOTSUPP EPERM
	EPFNOSUPPORT EPIPE EPROTONOSUPPORT EPROTOTYPE ERANGE EREMOTE ERESTART
	EROFS ESHUTDOWN ESOCKTNOSUPPORT ESPIPE ESRCH ESTALE ETIMEDOUT
	ETOOMANYREFS ETXTBSY EUSERS EWOULDBLOCK EXDEV
    )],
);

sub TIEHASH { bless \%err }

sub FETCH {
    my (undef, $errname) = @_;
    return "" unless exists $err{$errname};
    my $errno = $err{$errname};
    return $errno == $! ? $errno : 0;
}

sub STORE {
    require Carp;
    Carp::confess("ERRNO hash is read only!");
}

*CLEAR = *DELETE = \*STORE; # Typeglob aliasing uses less space

sub NEXTKEY {
    each %err;
}

sub FIRSTKEY {
    my $s = scalar keys %err;	# initialize iterator
    each %err;
}

sub EXISTS {
    my (undef, $errname) = @_;
    exists $err{$errname};
}

tie %!, __PACKAGE__; # Returns an object, objects are true.

__END__

#line 286

# ex: set ro:

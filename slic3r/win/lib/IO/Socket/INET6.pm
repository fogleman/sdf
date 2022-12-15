#line 1 "IO/Socket/INET6.pm"
# IO::Socket::INET6.pm
#
# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Modified by Rafael Martinez-Torres <rafael.martinez@novagnet.com>
# Euro6IX project (www.euro6ix.org) 2003.

package IO::Socket::INET6;

use strict;
use warnings;

use 5.008;

our(@ISA, $VERSION);

# Do it so we won't import any symbols from IO::Socket which it does export
# by default:
#
# <LeoNerd> IO::Socket is stupidstupidstupid beyond belief. Despite being an
# object class, it has an import method
# <LeoNerd> So you have to use IO::Socket ();
# <LeoNerd> Having done that, this test is now clean
use IO::Socket ();

use Socket (qw(
    AF_INET6 PF_INET6 SOCK_RAW SOCK_STREAM INADDR_ANY SOCK_DGRAM
    AF_INET SO_REUSEADDR SO_REUSEPORT AF_UNSPEC SO_BROADCAST
    sockaddr_in
    )
);

# IO::Socket and Socket already import stuff here - possibly AF_INET6
# and PF_INET6 so selectively import things from Socket6.
use Socket6 (
    qw(AI_PASSIVE getaddrinfo
    sockaddr_in6 unpack_sockaddr_in6_all pack_sockaddr_in6_all in6addr_any)
);

use Carp;
use Errno;

@ISA = qw(IO::Socket);
$VERSION = "2.72";
#Purpose: allow protocol independent protocol and original interface.

my $EINVAL = exists(&Errno::EINVAL) ? Errno::EINVAL() : 1;

IO::Socket::INET6->register_domain( AF_INET6 );


my %socket_type = ( tcp  => SOCK_STREAM,
		    udp  => SOCK_DGRAM,
		    icmp => SOCK_RAW
		  );

sub new {
    my $class = shift;
    unshift(@_, "PeerAddr") if @_ == 1;
    return $class->SUPER::new(@_);
}

# Parsing analysis:
# addr,port,and proto may be syntactically related...
sub _sock_info {
  my($addr,$port,$proto) = @_;
  my $origport = $port;
  my @proto = ();
  my @serv = ();

  if (defined $addr) {
	if (!Socket6::inet_pton(AF_INET6,$addr)) {
         if($addr =~ s,^\[([\da-fA-F:]+)\]:([\w\(\)/]+)$,$1,) {
   	     $port = $2;
         } elsif($addr =~ s,^\[(::[\da-fA-F.:]+)\]:([\w\(\)/]+)$,$1,) {
             $port = $2;
         } elsif($addr =~ s,^\[([\da-fA-F:]+)\],$1,) {
             $port = $origport;
         } elsif($addr =~ s,:([\w\(\)/]+)$,,) {
             $port = $1
         }
	}
  }

  # $proto as "string".
  if(defined $proto  && $proto =~ /\D/) {
    if(@proto = getprotobyname($proto)) {
      $proto = $proto[2] || undef;
    }
    else {
      $@ = "Bad protocol '$proto'";
      return;
    }
  }

  if(defined $port) {
    my $defport = ($port =~ s,\((\d+)\)$,,) ? $1 : undef;
    my $pnum = ($port =~ m,^(\d+)$,)[0];

    @serv = getservbyname($port, $proto[0] || "")
	if ($port =~ m,\D,);

    $port = $serv[2] || $defport || $pnum;
    unless (defined $port) {
	$@ = "Bad service '$origport'";
	return;
    }

    $proto = (getprotobyname($serv[3]))[2] || undef
	if @serv && !$proto;
  }
 #printf "Selected port  is $port and proto is $proto \n";

 return ($addr || undef,
	 $port || undef,
	 $proto || undef,
	);

}

sub _error {
    my $sock = shift;
    my $err = shift;
    {
      local($!);
      my $title = ref($sock).": ";
      $@ = join("", $_[0] =~ /^$title/ ? "" : $title, @_);
      close($sock)
	if(defined fileno($sock));
    }
    $! = $err;
    return undef;
}

sub configure {
    my($sock,$arg) = @_;

    $arg->{LocalAddr} = $arg->{LocalHost}
        if exists $arg->{LocalHost} && !exists $arg->{LocalAddr};
    $arg->{PeerAddr} = $arg->{PeerHost}
        if exists $arg->{PeerHost} && !exists $arg->{PeerAddr};

    my $family = $arg->{Domain};
    # in case no local and peer is given we prefer AF_INET6
    # because we are IO::Socket::INET6
    $family ||= ! $arg->{LocalAddr} && ! $arg->{PeerAddr} && AF_INET6
        || AF_UNSPEC;

    # parse Local*
    my ($laddr,$lport,$proto) = _sock_info(
        $arg->{LocalAddr},
        $arg->{LocalPort},
        $arg->{Proto}
    ) or return _error($sock, $!, "sock_info: $@");
    $laddr ||= '';
    $lport ||= 0;
    $proto ||= (getprotobyname('tcp'))[2];


    # MSWin32 expects at least one of $laddr or $lport to be specified
    # and does not accept 0 for $lport if $laddr is specified.
    if ($^O eq 'MSWin32') {
        if ((!$laddr) && (!$lport)) {
            $laddr = ($family == AF_INET) ? '0.0.0.0' : '::';
            $lport = '';
        } elsif (!$lport) {
            $lport = '';
        }
    }

    my $type = $arg->{Type} || $socket_type{(getprotobynumber($proto))[0]};

    # parse Peer*
    my($rport,$raddr);
    unless(exists $arg->{Listen}) {
        ($raddr,$rport) = _sock_info(
            $arg->{PeerAddr},
            $arg->{PeerPort},
            $proto
        ) or return _error($sock, $!, "sock_info: $@");
    }

    # find out all combinations of local and remote addr with
    # the same family
    my @lres = getaddrinfo($laddr,$lport,$family,$type,$proto,AI_PASSIVE);
    return _error($sock, $EINVAL, "getaddrinfo: $lres[0]") if @lres<5;
    my @rres;
    if ( defined $raddr ) {
        @rres = getaddrinfo($raddr,$rport,$family,$type,$proto);
        return _error($sock, $EINVAL, "getaddrinfo: $rres[0]") if @rres<5;
    }

    my @flr;
    if (@rres) {
        # Collect all combinations with the same family in lres and rres
        # the order we search should be defined by the order of @rres,
        # not @lres!
        for( my $r=0;$r<@rres;$r+=5 ) {
            for( my $l=0;$l<@lres;$l+=5) {
                my $fam_listen = $lres[$l];
                next if $rres[$r] != $fam_listen; # must be same family
                push @flr,[ $fam_listen,$lres[$l+3],$rres[$r+3] ];
            }
        }
    } else {
        for( my $l=0;$l<@lres;$l+=5) {
            my $fam_listen = $lres[$l];
            my $lsockaddr = $lres[$l+3];
            # collect only the binding side
            push @flr,[ $fam_listen,$lsockaddr ];
        }
    }

    # try to bind and maybe connect
    # if multihomed try all combinations until success
    for my $flr (@flr) {
        my ($family,$lres,$rres) = @$flr;

        if ( $family == AF_INET6) {
            if ($arg->{LocalFlow} || $arg->{LocalScope}) {
                my @sa_in6 = unpack_sockaddr_in6_all($lres);
                $sa_in6[1] = $arg->{LocalFlow}  || 0;
                $sa_in6[3] = _scope_ntohl($arg->{LocalScope}) || 0;
                $lres = pack_sockaddr_in6_all(@sa_in6);
            }
        }

        $sock->socket($family, $type, $proto) or
            return _error($sock, $!, "socket: $!");

        if (defined $arg->{Blocking}) {
            defined $sock->blocking($arg->{Blocking}) or
                return _error($sock, $!, "sockopt: $!");
        }

        if ($arg->{Reuse} || $arg->{ReuseAddr}) {
            $sock->sockopt(SO_REUSEADDR,1) or
                return _error($sock, $!, "sockopt: $!");
        }

        if ($arg->{ReusePort}) {
            $sock->sockopt(SO_REUSEPORT,1) or
                return _error($sock, $!, "sockopt: $!");
        }

        if ($arg->{Broadcast}) {
            $sock->sockopt(SO_BROADCAST,1) or
                return _error($sock, $!, "sockopt: $!");
        }

        if ( $family == AF_INET ) {
            my ($p,$a) = sockaddr_in($lres);
            $sock->bind($lres) or return _error($sock, $!, "bind: $!")
                if ($a ne INADDR_ANY  or $p!=0);
        } else {
            my ($p,$a) = sockaddr_in6($lres);
            $sock->bind($lres) or return _error($sock, $!, "bind: $!")
                if ($a ne in6addr_any  or $p!=0);
        }

        if(exists $arg->{Listen}) {
            $sock->listen($arg->{Listen} || 5) or
                return _error($sock, $!, "listen: $!");
        }

        # connect only if PeerAddr and thus $rres is given
        last if ! $rres;

        if ( $family == AF_INET6) {
            if ($arg->{PeerFlow} || $arg->{PeerScope}) {
                my @sa_in6 = unpack_sockaddr_in6_all($rres);
                $sa_in6[1] = $arg->{PeerFlow}  || 0;
                $sa_in6[3] = _scope_ntohl($arg->{PeerScope}) || 0;
                $rres = pack_sockaddr_in6_all(@sa_in6);
            }
        }

        undef $@;
        last if $sock->connect($rres);

        return _error($sock, $!, $@ || "Timeout")
            if ! $arg->{MultiHomed};

    }

    return $sock;
}

sub _scope_ntohl($)
{
    # As of Socket6 0.17 the scope field is incorrectly put into
    # network byte order when it should be in host byte order
    # in the sockaddr_in6 structure.  We correct for that here.

    if ((Socket6->VERSION <= 0.17) && (pack('s', 0x1234) ne pack('n', 0x1234)))
    {
        unpack('N', pack('V', $_[0]));
    } else {
        $_[0];
    }
}

sub sockdomain
{
   my $sock = shift;
   $sock->SUPER::sockdomain(@_) || AF_INET6;
}

sub accept
{
    my $sock = shift;

    my ($new, $peer) = $sock->SUPER::accept(@_);

    return unless defined($new);

    ${*$new}{io_socket_domain} = ${*$sock}{io_socket_domain};
    ${*$new}{io_socket_type}   = ${*$sock}{io_socket_type};
    ${*$new}{io_socket_proto}  = ${*$sock}{io_socket_proto};

    return wantarray ? ($new, $peer) : $new;
}

sub bind {
    @_ == 2 or
       croak 'usage: $sock->bind(NAME) ';
    my $sock = shift;
    return $sock->SUPER::bind( shift );
}

sub connect {
    @_ == 2 or
       croak 'usage: $sock->connect(NAME) ';
    my $sock = shift;
    return $sock->SUPER::connect( shift );
}

sub sockaddr {
    @_ == 1 or croak 'usage: $sock->sockaddr()';
    my ($sock) = @_;
    return undef unless (my $name = $sock->sockname);
    ($sock->sockdomain == AF_INET) ? (sockaddr_in($name))[1] : (sockaddr_in6($name))[1];
}

sub sockport {
    @_ == 1 or croak 'usage: $sock->sockport()';
    my($sock) = @_;
    return undef unless (my $name = $sock->sockname);
    ($sock->sockdomain == AF_INET) ? (sockaddr_in($name))[0] : (sockaddr_in6($name))[0];
}

sub sockhost {
    @_ == 1 or croak 'usage: $sock->sockhost()';
    my ($sock) = @_;
    return undef unless (my $addr = $sock->sockaddr);
    Socket6::inet_ntop($sock->sockdomain, $addr);
}

sub sockflow
{
    @_ == 1 or croak 'usage: $sock->sockflow()';
    my ($sock) = @_;
    return undef unless (my $name = $sock->sockname);
    ($sock->sockdomain == AF_INET6) ? (unpack_sockaddr_in6_all($name))[1] : 0;
}

sub sockscope
{
    @_ == 1 or croak 'usage: $sock->sockscope()';
    my ($sock) = @_;
    return undef unless (my $name = $sock->sockname);
    _scope_ntohl(($sock->sockdomain == AF_INET6) ? (unpack_sockaddr_in6_all($name))[3] : 0);
}

sub peeraddr {
    @_ == 1 or croak 'usage: $sock->peeraddr()';
    my ($sock) = @_;
    return undef unless (my $name = $sock->peername);
    ($sock->sockdomain == AF_INET) ? (sockaddr_in($name))[1] : (sockaddr_in6($name))[1];
}

sub peerport {
    @_ == 1 or croak 'usage: $sock->peerport()';
    my($sock) = @_;
    return undef unless (my $name = $sock->peername);
    ($sock->sockdomain == AF_INET) ? (sockaddr_in($name))[0] : (sockaddr_in6($name))[0];
}

sub peerhost {
    @_ == 1 or croak 'usage: $sock->peerhost()';
    my ($sock) = @_;
    return undef unless (my $addr = $sock->peeraddr);
    Socket6::inet_ntop($sock->sockdomain, $addr);
}

sub peerflow
{
    @_ == 1 or croak 'usage: $sock->peerflow()';
    my ($sock) = @_;
    return undef unless (my $name = $sock->peername);
    _scope_ntohl(($sock->sockdomain == AF_INET6) ? (unpack_sockaddr_in6_all($name))[1] : 0);
}

sub peerscope
{
    @_ == 1 or croak 'usage: $sock->peerscope()';
    my ($sock) = @_;
    return undef unless (my $name = $sock->peername);
    ($sock->sockdomain == AF_INET6) ? (unpack_sockaddr_in6_all($name))[3] : 0;
}

1;

__END__

#line 660

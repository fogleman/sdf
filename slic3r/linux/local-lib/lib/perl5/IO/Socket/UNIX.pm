#line 1 "IO/Socket/UNIX.pm"
# IO::Socket::UNIX.pm
#
# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package IO::Socket::UNIX;

use strict;
our(@ISA, $VERSION);
use IO::Socket;
use Carp;

@ISA = qw(IO::Socket);
$VERSION = "1.26";
$VERSION = eval $VERSION;

IO::Socket::UNIX->register_domain( AF_UNIX );

sub new {
    my $class = shift;
    unshift(@_, "Peer") if @_ == 1;
    return $class->SUPER::new(@_);
}

sub configure {
    my($sock,$arg) = @_;
    my($bport,$cport);

    my $type = $arg->{Type} || SOCK_STREAM;

    $sock->socket(AF_UNIX, $type, 0) or
	return undef;

    if(exists $arg->{Local}) {
	my $addr = sockaddr_un($arg->{Local});
	$sock->bind($addr) or
	    return undef;
    }
    if(exists $arg->{Listen} && $type != SOCK_DGRAM) {
	$sock->listen($arg->{Listen} || 5) or
	    return undef;
    }
    elsif(exists $arg->{Peer}) {
	my $addr = sockaddr_un($arg->{Peer});
	$sock->connect($addr) or
	    return undef;
    }

    $sock;
}

sub hostpath {
    @_ == 1 or croak 'usage: $sock->hostpath()';
    my $n = $_[0]->sockname || return undef;
    (sockaddr_un($n))[0];
}

sub peerpath {
    @_ == 1 or croak 'usage: $sock->peerpath()';
    my $n = $_[0]->peername || return undef;
    (sockaddr_un($n))[0];
}

1; # Keep require happy

__END__

#line 160

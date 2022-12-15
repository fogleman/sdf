#line 1 "Net/HTTP.pm"
package Net::HTTP;
$Net::HTTP::VERSION = '6.13';
use strict;
use warnings;

use vars qw($SOCKET_CLASS);
unless ($SOCKET_CLASS) {
    # Try several, in order of capability and preference
    if (eval { require IO::Socket::IP }) {
       $SOCKET_CLASS = "IO::Socket::IP";    # IPv4+IPv6
    } elsif (eval { require IO::Socket::INET6 }) {
       $SOCKET_CLASS = "IO::Socket::INET6"; # IPv4+IPv6
    } elsif (eval { require IO::Socket::INET }) {
       $SOCKET_CLASS = "IO::Socket::INET";  # IPv4 only
    } else {
       require IO::Socket;
       $SOCKET_CLASS = "IO::Socket::INET";
    }
}
require Net::HTTP::Methods;
require Carp;

our @ISA = ($SOCKET_CLASS, 'Net::HTTP::Methods');

sub new {
    my $class = shift;
    Carp::croak("No Host option provided") unless @_;
    $class->SUPER::new(@_);
}

sub configure {
    my($self, $cnf) = @_;
    $self->http_configure($cnf);
}

sub http_connect {
    my($self, $cnf) = @_;
    $self->SUPER::configure($cnf);
}

1;

#line 303

__END__

# ABSTRACT: Low-level HTTP connection (client)


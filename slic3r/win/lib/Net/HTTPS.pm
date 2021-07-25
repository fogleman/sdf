#line 1 "Net/HTTPS.pm"
package Net::HTTPS;
$Net::HTTPS::VERSION = '6.13';
use strict;
use warnings;

# Figure out which SSL implementation to use
use vars qw($SSL_SOCKET_CLASS);
if ($SSL_SOCKET_CLASS) {
    # somebody already set it
}
elsif ($SSL_SOCKET_CLASS = $ENV{PERL_NET_HTTPS_SSL_SOCKET_CLASS}) {
    unless ($SSL_SOCKET_CLASS =~ /^(IO::Socket::SSL|Net::SSL)\z/) {
	die "Bad socket class [$SSL_SOCKET_CLASS]";
    }
    eval "require $SSL_SOCKET_CLASS";
    die $@ if $@;
}
elsif ($IO::Socket::SSL::VERSION) {
    $SSL_SOCKET_CLASS = "IO::Socket::SSL"; # it was already loaded
}
elsif ($Net::SSL::VERSION) {
    $SSL_SOCKET_CLASS = "Net::SSL";
}
else {
    eval { require IO::Socket::SSL; };
    if ($@) {
	my $old_errsv = $@;
	eval {
	    require Net::SSL;  # from Crypt-SSLeay
	};
	if ($@) {
	    $old_errsv =~ s/\s\(\@INC contains:.*\)/)/g;
	    die $old_errsv . $@;
	}
	$SSL_SOCKET_CLASS = "Net::SSL";
    }
    else {
	$SSL_SOCKET_CLASS = "IO::Socket::SSL";
    }
}

require Net::HTTP::Methods;

our @ISA=($SSL_SOCKET_CLASS, 'Net::HTTP::Methods');

sub configure {
    my($self, $cnf) = @_;
    $self->http_configure($cnf);
}

sub http_connect {
    my($self, $cnf) = @_;
    if ($self->isa("Net::SSL")) {
	if ($cnf->{SSL_verify_mode}) {
	    if (my $f = $cnf->{SSL_ca_file}) {
		$ENV{HTTPS_CA_FILE} = $f;
	    }
	    if (my $f = $cnf->{SSL_ca_path}) {
		$ENV{HTTPS_CA_DIR} = $f;
	    }
	}
	if ($cnf->{SSL_verifycn_scheme}) {
	    $@ = "Net::SSL from Crypt-SSLeay can't verify hostnames; either install IO::Socket::SSL or turn off verification by setting the PERL_LWP_SSL_VERIFY_HOSTNAME environment variable to 0";
	    return undef;
	}
    }
    $self->SUPER::configure($cnf);
}

sub http_default_port {
    443;
}

if ($SSL_SOCKET_CLASS eq "Net::SSL") {
    # The underlying SSLeay classes fails to work if the socket is
    # placed in non-blocking mode.  This override of the blocking
    # method makes sure it stays the way it was created.
    *blocking = sub { };
}

1;

#line 131

__END__

#ABSTRACT: Low-level HTTP over SSL/TLS connection (client)


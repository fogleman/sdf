#line 1 "LWP/Protocol/https.pm"
package LWP::Protocol::https;

use strict;
our $VERSION = "6.07";

require LWP::Protocol::http;
our @ISA = qw(LWP::Protocol::http);
require Net::HTTPS;

sub socket_type
{
    return "https";
}

sub _extra_sock_opts
{
    my $self = shift;
    my %ssl_opts = %{$self->{ua}{ssl_opts} || {}};
    if (delete $ssl_opts{verify_hostname}) {
	$ssl_opts{SSL_verify_mode} ||= 1;
	$ssl_opts{SSL_verifycn_scheme} = 'www';
    }
    else {
	$ssl_opts{SSL_verify_mode} = 0;
    }
    if ($ssl_opts{SSL_verify_mode}) {
	unless (exists $ssl_opts{SSL_ca_file} || exists $ssl_opts{SSL_ca_path}) {
	    eval {
		require Mozilla::CA;
	    };
	    if ($@) {
		if ($@ =~ /^Can't locate Mozilla\/CA\.pm/) {
		    $@ = <<'EOT';
Can't verify SSL peers without knowing which Certificate Authorities to trust

This problem can be fixed by either setting the PERL_LWP_SSL_CA_FILE
environment variable or by installing the Mozilla::CA module.

To disable verification of SSL peers set the PERL_LWP_SSL_VERIFY_HOSTNAME
environment variable to 0.  If you do this you can't be sure that you
communicate with the expected peer.
EOT
		}
		die $@;
	    }
	    $ssl_opts{SSL_ca_file} = Mozilla::CA::SSL_ca_file();
	}
    }
    $self->{ssl_opts} = \%ssl_opts;
    return (%ssl_opts, $self->SUPER::_extra_sock_opts);
}

#------------------------------------------------------------
# _cn_match($common_name, $san_name)
#  common_name: an IA5String
#  san_name: subjectAltName
# initially we were only concerned with the dNSName
# and the 'left-most' only wildcard as noted in
#   https://tools.ietf.org/html/rfc6125#section-6.4.3
# this method does not match any wildcarding in the
# domain name as listed in section-6.4.3.3
#
sub _cn_match {
    my( $me, $common_name, $san_name ) = @_;

    # /CN has a '*.' prefix
    # MUST be an FQDN -- fishing?
    return 0 if( $common_name =~ /^\*\./ );

    my $re = q{}; # empty string

     # turn a leading "*." into a regex
    if( $san_name =~ /^\*\./ ) {
        $san_name =~ s/\*//;
        $re = "[^.]+";
    }

      # quotemeta the rest and match anchored
    if( $common_name =~ /^$re\Q$san_name\E$/ ) {
        return 1;
    }
    return 0;
}

#-------------------------------------------------------
# _in_san( cn, cert )
#  'cn' of the form  /CN=host_to_check ( "Common Name" form )
#  'cert' any object that implements a peer_certificate('subjectAltNames') method
#   which will return an array of  ( type-id, value ) pairings per
#   http://tools.ietf.org/html/rfc5280#section-4.2.1.6
# if there is no subjectAltNames there is nothing more to do.
# currently we have a _cn_match() that will allow for simple compare.
sub _in_san
{
    my($me, $cn, $cert) = @_;

	  # we can return early if there are no SAN options.
	my @sans = $cert->peer_certificate('subjectAltNames');
	return unless scalar @sans;

	(my $common_name = $cn) =~ s/.*=//; # strip off the prefix.

      # get the ( type-id, value ) pairwise
      # currently only the basic CN to san_name check
    while( my ( $type_id, $value ) = splice( @sans, 0, 2 ) ) {
        return 'ok' if $me->_cn_match($common_name,$value);
    }
    return;
}

sub _check_sock
{
    my($self, $req, $sock) = @_;
    my $check = $req->header("If-SSL-Cert-Subject");
    if (defined $check) {
        my $cert = $sock->get_peer_certificate ||
            die "Missing SSL certificate";
        my $subject = $cert->subject_name;
        unless ( $subject =~ /$check/ ) {
            my $ok = $self->_in_san( $check, $cert);
            die "Bad SSL certificate subject: '$subject' !~ /$check/"
                unless $ok;
        }
        $req->remove_header("If-SSL-Cert-Subject");  # don't pass it on
    }
}

sub _get_sock_info
{
    my $self = shift;
    $self->SUPER::_get_sock_info(@_);
    my($res, $sock) = @_;
    $res->header("Client-SSL-Cipher" => $sock->get_cipher);
    my $cert = $sock->get_peer_certificate;
    if ($cert) {
	$res->header("Client-SSL-Cert-Subject" => $cert->subject_name);
	$res->header("Client-SSL-Cert-Issuer" => $cert->issuer_name);
    }
    if (!$self->{ssl_opts}{SSL_verify_mode}) {
	$res->push_header("Client-SSL-Warning" => "Peer certificate not verified");
    }
    elsif (!$self->{ssl_opts}{SSL_verifycn_scheme}) {
	$res->push_header("Client-SSL-Warning" => "Peer hostname match with certificate not verified");
    }
    $res->header("Client-SSL-Socket-Class" => $Net::HTTPS::SSL_SOCKET_CLASS);
}

# upgrade plain socket to SSL, used for CONNECT tunnel when proxying https
# will only work if the underlying socket class of Net::HTTPS is
# IO::Socket::SSL, but code will only be called in this case
if ( $Net::HTTPS::SSL_SOCKET_CLASS->can('start_SSL')) {
    *_upgrade_sock = sub {
	my ($self,$sock,$url) = @_;
	$sock = LWP::Protocol::https::Socket->start_SSL( $sock,
	    SSL_verifycn_name => $url->host,
	    SSL_hostname => $url->host,
	    $self->_extra_sock_opts,
	);
	$@ = LWP::Protocol::https::Socket->errstr if ! $sock;
	return $sock;
    }
}

#-----------------------------------------------------------
package LWP::Protocol::https::Socket;

our @ISA = qw(Net::HTTPS LWP::Protocol::http::SocketMethods);

1;

__END__

#line 221
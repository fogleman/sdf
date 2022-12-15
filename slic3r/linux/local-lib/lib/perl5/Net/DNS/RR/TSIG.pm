package Net::DNS::RR::TSIG;

#
# $Id: TSIG.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::TSIG - DNS TSIG resource record

=cut


use integer;

use Carp;

eval 'require Digest::HMAC';
eval 'require Digest::MD5';
eval 'require Digest::SHA';
eval 'require MIME::Base64';

use Net::DNS::DomainName;
use Net::DNS::Parameters;

use constant ANY  => classbyname qw(ANY);
use constant TSIG => typebyname qw(TSIG);

{
	# source: http://www.iana.org/assignments/tsig-algorithm-names
	my @algbyname = (
		'HMAC-MD5.SIG-ALG.REG.INT' => 157,
		'HMAC-SHA1'		   => 161,
		'HMAC-SHA224'		   => 162,
		'HMAC-SHA256'		   => 163,
		'HMAC-SHA384'		   => 164,
		'HMAC-SHA512'		   => 165,
		);

	my @algbyalias = (
		'HMAC-MD5' => 157,
		'HMAC-SHA' => 161,
		);


	my %algbyval = reverse @algbyname;

	my $map = sub {
		my $arg = shift;
		return $arg if $arg =~ /^\d/;
		$arg =~ s/[^A-Za-z0-9]//g;			# strip non-alphanumerics
		uc($arg);
	};

	my @pairedval = sort ( 1 .. 254, 1 .. 254 );		# also accept number
	my %algbyname = map &$map($_), @algbyalias, @algbyname, @pairedval;

	sub _algbyname {
		my $key = uc shift;				# synthetic key
		$key =~ s/[^A-Z0-9]//g;				# strip non-alphanumerics
		$algbyname{$key};
	}

	sub _algbyval {
		my $value = shift;
		$algbyval{$value};
	}
}


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $limit = $offset + $self->{rdlength};
	( $self->{algorithm}, $offset ) = decode Net::DNS::DomainName(@_);

	# Design decision: Use 32 bits, which will work until the end of time()!
	@{$self}{qw(time_signed fudge)} = unpack "\@$offset xxN n", $$data;
	$offset += 8;

	my $mac_size = unpack "\@$offset n", $$data;
	$self->{macbin} = unpack "\@$offset xx a$mac_size", $$data;
	$offset += $mac_size + 2;

	@{$self}{qw(original_id error)} = unpack "\@$offset nn", $$data;
	$offset += 4;

	my $other_size = unpack "\@$offset n", $$data;
	$self->{other} = unpack "\@$offset xx a$other_size", $$data;
	$offset += $other_size + 2;

	croak('misplaced or corrupt TSIG') unless $limit == length $$data;
	my $raw = substr $$data, 0, $self->{offset};
	$self->{rawref} = \$raw;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	my $macbin = $self->macbin;
	unless ($macbin) {
		my ( $offset, undef, $packet ) = @_;

		my $sigdata = $self->sig_data($packet);		# form data to be signed
		$macbin = $self->macbin( $self->_mac_function($sigdata) );
		$self->original_id( $packet->header->id );
	}

	my $rdata = $self->{algorithm}->canonical;

	# Design decision: Use 32 bits, which will work until the end of time()!
	$rdata .= pack 'xxN n', $self->time_signed, $self->fudge;

	$rdata .= pack 'na*', length($macbin), $macbin;

	$rdata .= pack 'nn', $self->original_id, $self->{error};

	my $other = $self->other;
	$rdata .= pack 'na*', length($other), $other;

	return $rdata;
}


sub _defaults {				## specify RR attribute default values
	my $self = shift;

	$self->algorithm(157);
	$self->class('ANY');
	$self->error(0);
	$self->fudge(300);
	$self->other('');
}


sub _size {				## estimate encoded size
	my $self = shift;
	my $clone = bless {%$self}, ref($self);			   # shallow clone
	length $clone->encode( 0, undef, new Net::DNS::Packet() );
}


sub encode {				## overide RR method
	my $self = shift;

	my $kname = $self->{owner}->encode();			# uncompressed key name
	my $rdata = eval { $self->_encode_rdata(@_) } || '';
	pack 'a* n2 N n a*', $kname, TSIG, ANY, 0, length $rdata, $rdata;
}


sub string {				## overide RR method
	my $self = shift;

	my $owner	= $self->{owner}->string;
	my $type	= $self->type;
	my $algorithm	= $self->algorithm;
	my $time_signed = $self->time_signed;
	my $fudge	= $self->fudge;
	my $signature	= $self->mac;
	my $original_id = $self->original_id;
	my $error	= $self->error;
	my $other	= $self->other;

	return <<"QQ";
; $owner	$type	
;	algorithm:	$algorithm
;	time signed:	$time_signed	fudge:	$fudge
;	signature:	$signature
;	original id:	$original_id
;			$error	$other
QQ
}


sub algorithm { &_algorithm; }


sub key {
	my $self = shift;

	$self->keybin( MIME::Base64::decode( join "", @_ ) ) if scalar @_;
	MIME::Base64::encode( $self->keybin(), "" ) if defined wantarray;
}


sub keybin { &_keybin; }


sub time_signed {
	my $self = shift;

	$self->{time_signed} = 0 + shift if scalar @_;
	$self->{time_signed} = time() unless $self->{time_signed};
}


sub fudge {
	my $self = shift;

	$self->{fudge} = 0 + shift if scalar @_;
	$self->{fudge} || 0;
}


sub mac {
	my $self = shift;

	$self->macbin( pack "H*", map { die "!hex!" if m/[^0-9A-Fa-f]/; $_ } join "", @_ ) if scalar @_;
	unpack "H*", $self->macbin() if defined wantarray;
}


sub macbin {
	my $self = shift;

	$self->{macbin} = shift if scalar @_;
	$self->{macbin} || "";
}


sub prior_mac {
	my $self = shift;
	my @args = map { /[^0-9A-Fa-f]/ ? croak "corrupt hexadecimal" : $_ } @_;

	$self->prior_macbin( pack "H*", join "", @args ) if scalar @args;
	unpack "H*", $self->prior_macbin() if defined wantarray;
}


sub prior_macbin {
	my $self = shift;

	$self->{prior_macbin} = shift if scalar @_;
	$self->{prior_macbin} || "";
}


sub request_mac {
	my $self = shift;
	my @args = map { /[^0-9A-Fa-f]/ ? croak "corrupt hexadecimal" : $_ } @_;

	$self->request_macbin( pack "H*", join "", @args ) if scalar @args;
	unpack "H*", $self->request_macbin() if defined wantarray;
}


sub request_macbin {
	my $self = shift;

	$self->{request_macbin} = shift if scalar @_;
	$self->{request_macbin} || "";
}


sub original_id {
	my $self = shift;

	$self->{original_id} = 0 + shift if scalar @_;
	$self->{original_id} || 0;
}


sub error {
	my $self = shift;
	$self->{error} = rcodebyname(shift) if scalar @_;
	rcodebyval( $self->{error} );
}


sub other {
	my $self = shift;
	$self->{other} = shift if scalar @_;
	my $time = $self->{error} == 18 ? pack 'xxN', time() : '';
	$self->{other} = $time unless $self->{other};
}


sub other_data { &other; }					# uncoverable pod


sub sig_function {
	my $self = shift;

	return $self->{sig_function} unless scalar @_;
	$self->{sig_function} = shift;
}

sub sign_func { &sig_function; }				# uncoverable pod


sub sig_data {
	my ( $self, $message ) = @_;

	if ( ref($message) ) {
		die 'missing packet reference' unless $message->isa('Net::DNS::Packet');
		my @unsigned = grep ref($_) ne ref($self), @{$message->{additional}};
		local $message->{additional} = \@unsigned;	# remake header image
		my @part = qw(question answer authority additional);
		my @size = map scalar( @{$message->{$_}} ), @part;
		if ( my $rawref = $self->{rawref} ) {
			delete $self->{rawref};
			my $hbin = pack 'n6', $self->original_id, $message->{status}, @size;
			$message = join '', $hbin, substr $$rawref, length $hbin;
		} else {
			my $data = $message->data;
			my $hbin = pack 'n6', $message->{id}, $message->{status}, @size;
			$message = join '', $hbin, substr $data, length $hbin;
		}
	}

	# Design decision: Use 32 bits, which will work until the end of time()!
	my $time = pack 'xxN n', $self->time_signed, $self->fudge;

	# Insert the prior MAC if present (multi-packet message).
	$self->prior_macbin( $self->{link}->macbin ) if $self->{link};
	my $prior_macbin = $self->prior_macbin;
	return pack 'na* a* a*', length($prior_macbin), $prior_macbin, $message, $time if $prior_macbin;

	# Insert the request MAC if present (used to validate responses).
	my $req_mac = $self->request_macbin;
	my $sigdata = $req_mac ? pack( 'na*', length($req_mac), $req_mac ) : '';

	$sigdata .= $message || '';

	my $kname = $self->{owner}->canonical;			# canonical key name
	$sigdata .= pack 'a* n N', $kname, ANY, 0;

	$sigdata .= $self->{algorithm}->canonical;		# canonical algorithm name

	$sigdata .= $time;

	$sigdata .= pack 'n', $self->{error};

	my $other = $self->other;
	$sigdata .= pack 'na*', length($other), $other;

	return $sigdata;
}


sub create {
	my $class = shift;
	my $karg  = shift;
	croak 'argument undefined' unless defined $karg;

	if ( ref($karg) ) {
		if ( $karg->isa('Net::DNS::Packet') ) {
			my $sigrr = $karg->sigrr;
			croak 'no TSIG in request packet' unless defined $sigrr;
			return new Net::DNS::RR(		# ( request, options )
				name	       => $sigrr->name,
				type	       => 'TSIG',
				algorithm      => $sigrr->algorithm,
				request_macbin => $sigrr->macbin,
				@_
				);

		} elsif ( ref($karg) eq __PACKAGE__ ) {
			my $tsig = $karg->_chain;
			$tsig->{macbin} = undef;
			return $tsig;

		} elsif ( ref($karg) eq 'Net::DNS::RR::KEY' ) {
			return new Net::DNS::RR(
				name	  => $karg->name,
				type	  => 'TSIG',
				algorithm => $karg->algorithm,
				key	  => $karg->key,
				@_
				);
		}

		croak "Usage:	create $class(keyfile)\n\tcreate $class(keyname, key)"

	} elsif ( scalar(@_) == 1 ) {
		my $key = shift;				# ( keyname, key )
		return new Net::DNS::RR(
			name => $karg,
			type => 'TSIG',
			key  => $key
			);

	} elsif ( $karg =~ /[+.0-9]+private$/ ) {		# ( keyfile, options )
		require File::Spec;
		require Net::DNS::ZoneFile;
		my $keyfile = new Net::DNS::ZoneFile($karg);
		my ( $alg, $key, $junk );
		while ( my $line = $keyfile->_getline ) {
			for ($line) {
				( $junk, $alg ) = split if /Algorithm:/;
				( $junk, $key ) = split if /Key:/;
			}
		}

		my ( $vol, $dir, $file ) = File::Spec->splitpath( $keyfile->name );
		my $kname;
		$kname = $1 if $file =~ /^K([^+]+)+.+private$/;
		return new Net::DNS::RR(
			name	  => $kname,
			type	  => 'TSIG',
			algorithm => $alg,
			key	  => $key,
			@_
			);

	} else {						# ( keyfile, options )
		require Net::DNS::ZoneFile;
		my $keyrr = new Net::DNS::ZoneFile($karg)->read;
		croak 'key file incompatible with TSIG' unless $keyrr->type eq 'KEY';
		return new Net::DNS::RR(
			name	  => $keyrr->name,
			type	  => 'TSIG',
			algorithm => $keyrr->algorithm,
			key	  => $keyrr->key,
			@_
			);
	}
}


sub verify {
	my $self = shift;
	my $data = shift;

	unless ( abs( time() - $self->time_signed ) < $self->fudge ) {
		$self->error(18);				# bad time
		return;
	}

	if ( scalar @_ ) {
		my $arg = shift;

		unless ( ref($arg) ) {
			$self->error(16);			# bad sig (multi-packet)
			return;
		}

		my $signerkey = lc( join '+', $self->name, $self->algorithm );
		if ( $arg->isa('Net::DNS::Packet') ) {
			my $request = $arg->sigrr;		# request TSIG
			my $rqstkey = lc( join '+', $request->name, $request->algorithm );
			$self->error(17) unless $signerkey eq $rqstkey;
			$self->request_macbin( $request->macbin );

		} elsif ( $arg->isa(__PACKAGE__) ) {
			my $priorkey = lc( join '+', $arg->name, $arg->algorithm );
			$self->error(17) unless $signerkey eq $priorkey;
			$self->prior_macbin( $arg->macbin );

		} else {
			croak 'Usage: $tsig->verify( $reply, $query )';
		}
	}
	return if $self->{error};

	my $sigdata = $self->sig_data($data);			# form data to be verified
	my $tsigmac = $self->_mac_function($sigdata);
	my $tsig    = $self->_chain;

	my $macbin = $self->macbin;
	my $maclen = length $macbin;
	my $minlen = length($tsigmac) >> 1;			# per RFC4635, 3.1
	$self->error(16) unless $macbin eq substr $tsigmac, 0, $maclen;
	$self->error(1) if $maclen < $minlen or $maclen < 10 or $maclen > length $tsigmac;

	return $self->{error} ? undef : $tsig;
}

sub vrfyerrstr {
	my $self = shift;
	return $self->error;
}


########################################

{
	my %digest = (
		'157' => ['Digest::MD5'],
		'161' => ['Digest::SHA'],
		'162' => ['Digest::SHA', 224, 64],
		'163' => ['Digest::SHA', 256, 64],
		'164' => ['Digest::SHA', 384, 128],
		'165' => ['Digest::SHA', 512, 128],
		);


	my %keytable;

	sub _algorithm {		## install sig function in key table
		my $self = shift;

		if ( my $algname = shift ) {

			unless ( my $digtype = _algbyname($algname) ) {
				$self->{algorithm} = new Net::DNS::DomainName($algname);

			} else {
				$algname = _algbyval($digtype);
				$self->{algorithm} = new Net::DNS::DomainName($algname);

				my ( $hash, @param ) = @{$digest{$digtype}};
				my ( undef, @block ) = @param;
				my $digest   = new $hash(@param);
				my $function = sub {
					my $hmac = new Digest::HMAC( shift, $digest, @block );
					$hmac->add(shift);
					return $hmac->digest;
				};

				$self->sig_function($function);

				my $keyname = ( $self->{owner} || return )->canonical;
				$keytable{$keyname}{digest} = $function;
			}
		}

		return $self->{algorithm}->name if defined wantarray;
	}


	sub _keybin {			## install key in key table
		my $self = shift;
		croak 'Unauthorised access to TSIG key material denied' unless scalar @_;
		my $keyref = $keytable{$self->{owner}->canonical} ||= {};
		my $private = shift;	# closure keeps private key private
		$keyref->{key} = sub {
			my $function = $keyref->{digest};
			return &$function( $private, shift );
		};
		return undef;
	}


	sub _mac_function {		## apply keyed hash function to argument
		my $self = shift;

		my $owner = $self->{owner}->canonical;
		$self->algorithm( $self->algorithm ) unless $keytable{$owner}{digest};
		my $keyref = $keytable{$owner};
		$keyref->{digest} = $self->sig_function unless $keyref->{digest};
		my $function = $keyref->{key};
		&$function(shift);
	}
}


# _chain() creates a new TSIG object linked to the original
# RR, for the purpose of signing multi-message transfers.

sub _chain {
	my $self = shift;
	$self->{link} = undef;
	bless {%$self, link => $self}, ref($self);
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $tsig = create Net::DNS::RR::TSIG( $keyfile );

    $tsig = create Net::DNS::RR::TSIG( $keyfile,
					fudge => 300
					);

=head1 DESCRIPTION

Class for DNS Transaction Signature (TSIG) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 algorithm

    $algorithm = $rr->algorithm;
    $rr->algorithm( $algorithm );

A domain name which specifies the name of the algorithm.

=head2 key

    $rr->key( $key );

Base64 representation of the key material.

=head2 keybin

    $rr->keybin( $keybin );

Binary representation of the key material.

=head2 time_signed

    $time_signed = $rr->time_signed;
    $rr->time_signed( $time_signed );

Signing time as the number of seconds since 1 Jan 1970 00:00:00 UTC.
The default signing time is the current time.

=head2 fudge

    $fudge = $rr->fudge;
    $rr->fudge( $fudge );

"fudge" represents the permitted error in the signing time.
The default fudge is 300 seconds.

=head2 mac

    $mac = $rr->mac;

Returns the message authentication code (MAC) as a string of hex
characters.  The programmer must call the Net::DNS::Packet data()
object method before this will return anything meaningful.

=cut


=head2 macbin

    $macbin = $rr->macbin;
    $rr->macbin( $macbin );

Binary message authentication code (MAC).

=head2 prior_mac

    $prior_mac = $rr->prior_mac;
    $rr->prior_mac( $prior_mac );

Prior message authentication code (MAC).

=head2 prior_macbin

    $prior_macbin = $rr->prior_macbin;
    $rr->prior_macbin( $prior_macbin );

Binary prior message authentication code.

=head2 request_mac

    $request_mac = $rr->request_mac;
    $rr->request_mac( $request_mac );

Request message authentication code (MAC).

=head2 request_macbin

    $request_macbin = $rr->request_macbin;
    $rr->request_macbin( $request_macbin );

Binary request message authentication code.

=head2 original_id

    $original_id = $rr->original_id;
    $rr->original_id( $original_id );

The message ID from the header of the original packet.

=head2 error

=head2 vrfyerrstr

     $rcode = $tsig->error;

Returns the RCODE covering TSIG processing.  Common values are
NOERROR, BADSIG, BADKEY, and BADTIME.  See RFC 2845 for details.


=head2 other

     $other = $tsig->other;

This field should be empty unless the error is BADTIME, in which
case it will contain the server time as the number of seconds since
1 Jan 1970 00:00:00 UTC.

=head2 sig_function

    sub signing_function {
	my ( $keybin, $data ) = @_;

	my $hmac = new Digest::HMAC( $keybin, 'Digest::MD5' );
	$hmac->add( $data );
	return $hmac->digest;
    }

    $tsig->sig_function( \&signing_function );

This sets the signing function to be used for this TSIG record.
The default signing function is HMAC-MD5.


=head2 sig_data

     $sigdata = $tsig->sig_data($packet);

Returns the packet packed according to RFC2845 in a form for signing. This
is only needed if you want to supply an external signing function, such as is
needed for TSIG-GSS.


=head2 create

    $tsig = create Net::DNS::RR::TSIG( $keyfile );

    $tsig = create Net::DNS::RR::TSIG( $keyfile,
					fudge => 300
					);

Returns a TSIG RR constructed using the parameters in the specified
key file, which is assumed to have been generated by dnssec-keygen.

    $tsig = create Net::DNS::RR::TSIG( $keyname, $key );

The two argument form is supported for backward compatibility.

=head2 verify

    $verify = $tsig->verify( $data );
    $verify = $tsig->verify( $packet );

    $verify = $tsig->verify( $reply,  $query );

    $verify = $tsig->verify( $packet, $prior );

The boolean verify method will return true if the hash over the
packet data conforms to the data in the TSIG itself


=head1 TSIG Keys

TSIG keys are symmetric keys generated using dnssec-keygen:

	$ dnssec-keygen -a HMAC-SHA1 -b 160 -n HOST <keyname>

	The key will be stored as a private and public keyfile pair
	K<keyname>+161+<keyid>.private and K<keyname>+161+<keyid>.key

    where
	<keyname> is the DNS name of the key.

	<keyid> is the (generated) numerical identifier used to
	distinguish this key.

Other algorithms may be substituted for HMAC-SHA1 in the above example.

It is recommended that the keyname be globally unique and incorporate
the fully qualified domain names of the resolver and nameserver in
that order. It should be possible for more than one key to be in use
simultaneously between any such pair of hosts.

Although the formats differ, the private and public keys are identical
and both should be stored and handled as secret data.


=head1 Configuring BIND Nameserver

The following lines must be added to the /etc/named.conf file:

    key <keyname> {
	algorithm HMAC-SHA1;
	secret "<keydata>";
    };

<keyname> is the name of the key chosen when the key was generated.

<keydata> is the key string extracted from the generated key file.


=head1 ACKNOWLEDGMENT

Most of the code in the Net::DNS::RR::TSIG module was contributed
by Chris Turbeville. 

Support for external signing functions was added by Andrew Tridgell.

TSIG verification, BIND keyfile handling and support for HMAC-SHA1,
HMAC-SHA224, HMAC-SHA256, HMAC-SHA384 and HMAC-SHA512 functions was
added by Dick Franks.


=head1 BUGS

A 32-bit representation of time is used, contrary to RFC2845 which
demands 48 bits.  This design decision will need to be reviewed
before the code stops working on 7 February 2106.


=head1 COPYRIGHT

Copyright (c)2000,2001 Michael Fuhr. 

Portions Copyright (c)2002,2003 Chris Reinhardt.

Portions Copyright (c)2013 Dick Franks.

All rights reserved.

Package template (c)2009,2012 O.M.Kolkman and R.W.Franks.


=head1 LICENSE

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted, provided
that the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation, and that the name of the author not be used in advertising
or publicity pertaining to distribution of the software without specific
prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.


=head1 SEE ALSO

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC2845, RFC4635

L<TSIG Algorithm Names|http://www.iana.org/assignments/tsig-algorithm-names>

=cut

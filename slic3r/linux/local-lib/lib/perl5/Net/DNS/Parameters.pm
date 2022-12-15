package Net::DNS::Parameters;

#
# $Id: Parameters.pm 1552 2017-03-13 09:44:07Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1552 $)[1];


################################################
##
##	Domain Name System (DNS) Parameters
##	(last updated 2017-03-07)
##
################################################


use strict;
use warnings;
use integer;
use Carp;

use base qw(Exporter);
our @EXPORT = qw(
		classbyname classbyval %classbyname
		typebyname typebyval %typebyname
		opcodebyname opcodebyval
		rcodebyname rcodebyval
		ednsoptionbyname ednsoptionbyval
		);


# Registry: DNS CLASSes
our %classbyname = (
	IN   => 1,						# RFC1035
	CH   => 3,						# Chaosnet
	HS   => 4,						# Hesiod
	NONE => 254,						# RFC2136
	ANY  => 255,						# RFC1035
	);
our %classbyval = reverse %classbyname;
%classbyname = ( '*' => 255, %classbyname, map lc($_), %classbyname );


# Registry: Resource Record (RR) TYPEs
our %typebyname = (
	A	   => 1,					# RFC1035
	NS	   => 2,					# RFC1035
	MD	   => 3,					# RFC1035
	MF	   => 4,					# RFC1035
	CNAME	   => 5,					# RFC1035
	SOA	   => 6,					# RFC1035
	MB	   => 7,					# RFC1035
	MG	   => 8,					# RFC1035
	MR	   => 9,					# RFC1035
	NULL	   => 10,					# RFC1035
	WKS	   => 11,					# RFC1035
	PTR	   => 12,					# RFC1035
	HINFO	   => 13,					# RFC1035
	MINFO	   => 14,					# RFC1035
	MX	   => 15,					# RFC1035
	TXT	   => 16,					# RFC1035
	RP	   => 17,					# RFC1183
	AFSDB	   => 18,					# RFC1183 RFC5864
	X25	   => 19,					# RFC1183
	ISDN	   => 20,					# RFC1183
	RT	   => 21,					# RFC1183
	NSAP	   => 22,					# RFC1706
	'NSAP-PTR' => 23,					# RFC1348 RFC1637 RFC1706
	SIG	   => 24,					# RFC4034 RFC3755 RFC2535 RFC2536 RFC2537 RFC2931 RFC3110 RFC3008
	KEY	   => 25,					# RFC4034 RFC3755 RFC2535 RFC2536 RFC2537 RFC2539 RFC3008 RFC3110
	PX	   => 26,					# RFC2163
	GPOS	   => 27,					# RFC1712
	AAAA	   => 28,					# RFC3596
	LOC	   => 29,					# RFC1876
	NXT	   => 30,					# RFC3755 RFC2535
	EID	   => 31,					# http://ana-3.lcs.mit.edu/~jnc/nimrod/dns.txt
	NIMLOC	   => 32,					# http://ana-3.lcs.mit.edu/~jnc/nimrod/dns.txt
	SRV	   => 33,					# RFC2782
	ATMA	   => 34,					# http://www.broadband-forum.org/ftp/pub/approved-specs/af-dans-0152.000.pdf
	NAPTR	   => 35,					# RFC2915 RFC2168 RFC3403
	KX	   => 36,					# RFC2230
	CERT	   => 37,					# RFC4398
	A6	   => 38,					# RFC3226 RFC2874 RFC6563
	DNAME	   => 39,					# RFC6672
	SINK	   => 40,					# http://tools.ietf.org/html/draft-eastlake-kitchen-sink
	OPT	   => 41,					# RFC6891 RFC3225
	APL	   => 42,					# RFC3123
	DS	   => 43,					# RFC4034 RFC3658
	SSHFP	   => 44,					# RFC4255
	IPSECKEY   => 45,					# RFC4025
	RRSIG	   => 46,					# RFC4034 RFC3755
	NSEC	   => 47,					# RFC4034 RFC3755
	DNSKEY	   => 48,					# RFC4034 RFC3755
	DHCID	   => 49,					# RFC4701
	NSEC3	   => 50,					# RFC5155
	NSEC3PARAM => 51,					# RFC5155
	TLSA	   => 52,					# RFC6698
	SMIMEA	   => 53,					# draft-ietf-dane-smime
	HIP	   => 55,					# RFC8005
	NINFO	   => 56,					#
	RKEY	   => 57,					#
	TALINK	   => 58,					#
	CDS	   => 59,					# RFC7344
	CDNSKEY	   => 60,					# RFC7344
	OPENPGPKEY => 61,					# RFC7929
	CSYNC	   => 62,					# RFC7477
	SPF	   => 99,					# RFC7208
	UINFO	   => 100,					# IANA-Reserved
	UID	   => 101,					# IANA-Reserved
	GID	   => 102,					# IANA-Reserved
	UNSPEC	   => 103,					# IANA-Reserved
	NID	   => 104,					# RFC6742
	L32	   => 105,					# RFC6742
	L64	   => 106,					# RFC6742
	LP	   => 107,					# RFC6742
	EUI48	   => 108,					# RFC7043
	EUI64	   => 109,					# RFC7043
	TKEY	   => 249,					# RFC2930
	TSIG	   => 250,					# RFC2845
	IXFR	   => 251,					# RFC1995
	AXFR	   => 252,					# RFC1035 RFC5936
	MAILB	   => 253,					# RFC1035
	MAILA	   => 254,					# RFC1035
	ANY	   => 255,					# RFC1035 RFC6895
	URI	   => 256,					# RFC7553
	CAA	   => 257,					# RFC6844
	AVC	   => 258,					#
	TA	   => 32768,					# http://cameo.library.cmu.edu/ http://www.watson.org/~weiler/INI1999-19.pdf
	DLV	   => 32769,					# RFC4431
	);
our %typebyval = reverse %typebyname;
%typebyname = ( '*' => 255, %typebyname, map lc($_), %typebyname );


# Registry: DNS OpCodes
our %opcodebyname = (
	QUERY  => 0,						# RFC1035
	IQUERY => 1,						# RFC3425
	STATUS => 2,						# RFC1035
	NOTIFY => 4,						# RFC1996
	UPDATE => 5,						# RFC2136
	);
our %opcodebyval = reverse %opcodebyname;
%opcodebyname = ( NS_NOTIFY_OP => 4, %opcodebyname, map lc($_), %opcodebyname );


# Registry: DNS RCODEs
our %rcodebyname = (
	NOERROR	  => 0,						# RFC1035
	FORMERR	  => 1,						# RFC1035
	SERVFAIL  => 2,						# RFC1035
	NXDOMAIN  => 3,						# RFC1035
	NOTIMP	  => 4,						# RFC1035
	REFUSED	  => 5,						# RFC1035
	YXDOMAIN  => 6,						# RFC2136 RFC6672
	YXRRSET	  => 7,						# RFC2136
	NXRRSET	  => 8,						# RFC2136
	NOTAUTH	  => 9,						# RFC2136
	NOTAUTH	  => 9,						# RFC2845
	NOTZONE	  => 10,					# RFC2136
	BADVERS	  => 16,					# RFC6891
	BADSIG	  => 16,					# RFC2845
	BADKEY	  => 17,					# RFC2845
	BADTIME	  => 18,					# RFC2845
	BADMODE	  => 19,					# RFC2930
	BADNAME	  => 20,					# RFC2930
	BADALG	  => 21,					# RFC2930
	BADTRUNC  => 22,					# RFC4635
	BADCOOKIE => 23,					# RFC7873
	);
our %rcodebyval = reverse( BADSIG => 16, %rcodebyname );
%rcodebyname = ( %rcodebyname, map lc($_), %rcodebyname );


# Registry: DNS EDNS0 Option Codes (OPT)
our %ednsoptionbyname = (
	LLQ		=> 1,					# http://files.dns-sd.org/draft-sekar-dns-llq.txt
	UL		=> 2,					# http://files.dns-sd.org/draft-sekar-dns-ul.txt
	NSID		=> 3,					# RFC5001
	DAU		=> 5,					# RFC6975
	DHU		=> 6,					# RFC6975
	N3U		=> 7,					# RFC6975
	'CLIENT-SUBNET' => 8,					# RFC7871
	EXPIRE		=> 9,					# RFC7314
	COOKIE		=> 10,					# RFC7873
	'TCP-KEEPALIVE' => 11,					# RFC7828
	PADDING		=> 12,					# RFC7830
	CHAIN		=> 13,					# RFC7901
	'KEY-TAG'	=> 14,					# RFC-ietf-dnsop-edns-key-tag-05
	DEVICEID	=> 26946,				# https://docs.umbrella.com/developer/networkdevices-api/identifying-dns-traffic2
	);
our %ednsoptionbyval = reverse %ednsoptionbyname;
%ednsoptionbyname = ( %ednsoptionbyname, map lc($_), %ednsoptionbyname );


# Registry: DNS Header Flags
our %dnsflagbyname = (
	AA => 0x0400,						# RFC1035
	TC => 0x0200,						# RFC1035
	RD => 0x0100,						# RFC1035
	RA => 0x0080,						# RFC1035
	AD => 0x0020,						# RFC4035 RFC6840
	CD => 0x0010,						# RFC4035 RFC6840
	);
%dnsflagbyname = ( %dnsflagbyname, map lc($_), %dnsflagbyname );


# Registry: EDNS Header Flags (16 bits)
our %ednsflagbyname = (
	DO => 0x8000,						# RFC4035 RFC3225
	);
%ednsflagbyname = ( %ednsflagbyname, map lc($_), %ednsflagbyname );


########

# The following functions are wrappers around similarly named hashes.

sub classbyname {
	my $name = shift;

	$classbyname{$name} || $classbyname{uc $name} || do {
		croak "unknown class $name" unless $name =~ m/(CLASS)?(\d+)/i;
		my $val = 0 + $2;
		croak "classbyname( $name ) out of range" if $val > 0xffff;
		return $val;
			}
}

sub classbyval {
	my $val = shift;

	$classbyval{$val} || do {
		$val += 0;
		croak "classbyval( $val ) out of range" if $val > 0xffff;
		return "CLASS$val";
			}
}


sub typebyname {
	my $name = shift;

	$typebyname{$name} || do {
		if ( $name =~ m/(TYPE)?(\d+)/i ) {
			my $val = 0 + $2;
			croak "typebyname( $name ) out of range" if $val > 0xffff;
			return $val;
		}
		_typespec("$name.RRNAME");
		return $typebyname{uc $name} || croak "unknown type $name";
			}
}

sub typebyval {
	my $val = shift;

	$typebyval{$val} || do {
		$val += 0;
		croak "typebyval( $val ) out of range" if $val > 0xffff;
		$typebyval{$val} = "TYPE$val";
		_typespec("$val.RRTYPE");
		return $typebyval{$val};
			}
}


sub opcodebyname {
	my $arg = shift;
	return $opcodebyname{$arg} if defined $opcodebyname{$arg};
	return 0 + $arg if $arg =~ /^\d/;
	croak "unknown opcode $arg";
}

sub opcodebyval {
	my $val = shift;
	$opcodebyval{$val} || return $val;
}


sub rcodebyname {
	my $arg = shift;
	return $rcodebyname{$arg} if defined $rcodebyname{$arg};
	return 0 + $arg if $arg =~ /^\d/;
	croak "unknown rcode $arg";
}

sub rcodebyval {
	my $val = shift;
	$rcodebyval{$val} || return $val;
}


sub ednsoptionbyname {
	my $arg = shift;
	return $ednsoptionbyname{$arg} if defined $ednsoptionbyname{$arg};
	return 0 + $arg if $arg =~ /^\d/;
	croak "unknown option $arg";
}

sub ednsoptionbyval {
	my $val = shift;
	$ednsoptionbyval{$val} || return $val;
}


our $DNSEXTLANG = 'ARPA.';		## draft-levine-dnsextlang

use constant DNSEXTLANG => defined eval <<'END';
	die 'preempt failure' if $^O =~ /cygwin|MSWin32/i;
	require IO::File;
	local $SIG{__WARN__} = sub { };
	new IO::File('RRTYPEgen |') or die $!;
END


sub register {				## register( 'TOY', 1234 )	(NOT part of published API)
	my ( $mnemonic, $rrtype ) = map uc($_), @_;		# uncoverable pod
	$rrtype = rand(255) + 65280 unless $rrtype;
	for ( typebyval $rrtype = int($rrtype) ) {
		croak "'$mnemonic' is a CLASS identifier" if $classbyname{$mnemonic};
		return $rrtype if /^$mnemonic$/;    # duplicate registration
		croak "'$mnemonic' conflicts with TYPE$rrtype ($_)" unless /^TYPE\d+$/;
		my $known = $typebyname{$mnemonic};
		croak "'$mnemonic' conflicts with TYPE$known" if $known;
	}
	$typebyval{$rrtype} = $mnemonic;
	return $typebyname{$mnemonic} = $rrtype;
}


sub _typespec {				## draft-levine-dnsextlang
	eval <<'END' if DNSEXTLANG;
	my ($node) = @_;
	require Net::DNS::Resolver;
	my $resolver = new Net::DNS::Resolver;
	my $response = $resolver->send( "$node.$DNSEXTLANG", 'TXT' );

	foreach my $txt ( grep $_->type eq 'TXT', $response->answer ) {
		my @stanza = $txt->txtdata;
		my ( $tag, $identifier ) = @stanza;
		next unless defined($tag) && $tag =~ /^RRTYPE=\d+$/;
		register( split /[:\s]/, $identifier );
		return unless defined wantarray;
		require 5.008009;				# support for reference in @INC
		my @arg = map { s/\s.*$//; qq("$_") } @stanza;	# strip descriptive text
		return new IO::File("RRTYPEgen @arg |");
	}
	return undef;
END
}


1;
__END__


=head1 NAME

    Net::DNS::Parameters - DNS parameter assignments


=head1 SYNOPSIS

    use Net::DNS::Parameters;


=head1 DESCRIPTION

Net::DNS::Parameters is a Perl package representing the DNS parameter
allocation (key,value) tables as recorded in the definitive registry
maintained and published by IANA.


=head1 FUNCTIONS

=head2 classbyname, typebyname, opcodebyname, rcodebyname, ednsoptionbyname

Access functions which return the numerical code corresponding to
the given mnemonic.

=head2 classbyval, typebyval, opcodebyval, rcodebyval, ednsoptionbyval

Access functions which return the canonical mnemonic corresponding to
the given numerical code.


=head1 COPYRIGHT

Copyright (c)2012,2016 Dick Franks.

Portions Copyright (c)1997 Michael Fuhr.

Portions Copyright (c)2003 Olaf Kolkman.

All rights reserved.


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

L<perl>, L<Net::DNS>,
L<IANA Registry|http://www.iana.org/assignments/dns-parameters>

=cut


package Net::DNS::RR::IPSECKEY;

#
# $Id: IPSECKEY.pm 1552 2017-03-13 09:44:07Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1552 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::IPSECKEY - DNS IPSECKEY resource record

=cut


use integer;

use Carp;
use MIME::Base64;

use Net::DNS::DomainName;
use Net::DNS::RR::A;
use Net::DNS::RR::AAAA;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $limit = $offset + $self->{rdlength};

	@{$self}{qw(precedence gatetype algorithm)} = unpack "\@$offset C3", $$data;
	$offset += 3;

	my $gatetype = $self->{gatetype};
	if ( not $gatetype ) {
		$self->{gateway} = undef;			# no gateway

	} elsif ( $gatetype == 1 ) {
		$self->{gateway} = unpack "\@$offset a4", $$data;
		$offset += 4;

	} elsif ( $gatetype == 2 ) {
		$self->{gateway} = unpack "\@$offset a16", $$data;
		$offset += 16;

	} elsif ( $gatetype == 3 ) {
		my $name;
		( $name, $offset ) = decode Net::DNS::DomainName( $data, $offset );
		$self->{gateway} = $name;

	} else {
		die "unknown gateway type ($gatetype)";
	}

	$self->keybin( substr $$data, $offset, $limit - $offset );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{algorithm};
	my $gatetype   = $self->gatetype;
	my $gateway    = $self->{gateway};
	my $precedence = $self->precedence;
	my $algorithm  = $self->algorithm;
	my $keybin     = $self->keybin;

	if ( not $gatetype ) {
		return pack 'C3 a*', $precedence, $gatetype, $algorithm, $keybin;

	} elsif ( $gatetype == 1 ) {
		return pack 'C3 a4 a*', $precedence, $gatetype, $algorithm, $gateway, $keybin;

	} elsif ( $gatetype == 2 ) {
		return pack 'C3 a16 a*', $precedence, $gatetype, $algorithm, $gateway, $keybin;

	} elsif ( $gatetype == 3 ) {
		my $namebin = $gateway->encode;
		return pack 'C3 a* a*', $precedence, $gatetype, $algorithm, $namebin, $keybin;
	}
	die "unknown gateway type ($gatetype)";
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{algorithm};
	my @params = map $self->$_, qw(precedence gatetype algorithm);
	my @base64 = split /\s+/, encode_base64( $self->keybin );
	my @rdata = ( @params, $self->gateway, @base64 );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	foreach (qw(precedence gatetype algorithm gateway)) { $self->$_(shift) }
	$self->key(@_);
}


sub precedence {
	my $self = shift;

	$self->{precedence} = 0 + shift if scalar @_;
	$self->{precedence} || 0;
}


sub gatetype {
	return shift->{gatetype} || 0;
}


sub algorithm {
	my $self = shift;

	$self->{algorithm} = 0 + shift if scalar @_;
	$self->{algorithm} || 0;
}


sub gateway {
	my $self = shift;

	for (@_) {
		/^\.*$/ && do {
			$self->{gatetype} = 0;
			$self->{gateway}  = undef;		# no gateway
			last;
		};
		/:.*:/ && do {
			$self->{gatetype} = 2;
			$self->{gateway} = Net::DNS::RR::AAAA::address( {}, $_ );
			last;
		};
		/\.\d+$/ && do {
			$self->{gatetype} = 1;
			$self->{gateway} = Net::DNS::RR::A::address( {}, $_ );
			last;
		};
		/\..+/ && do {
			$self->{gatetype} = 3;
			$self->{gateway}  = new Net::DNS::DomainName($_);
			last;
		};
		croak "unrecognised gateway type";
	}

	if ( defined wantarray ) {
		my $gatetype = $self->{gatetype};
		return wantarray ? '.' : undef unless $gatetype;
		my $gateway = $self->{gateway};
		for ($gatetype) {
			/^1$/ && return Net::DNS::RR::A::address( {address => $gateway} );
			/^2$/ && return Net::DNS::RR::AAAA::address( {address => $gateway} );
			/^3$/ && return wantarray ? $gateway->string : $gateway->name;
			die "unknown gateway type ($gatetype)";
		}
	}
}


sub key {
	my $self = shift;

	$self->keybin( MIME::Base64::decode( join "", @_ ) ) if scalar @_;
	MIME::Base64::encode( $self->keybin(), "" ) if defined wantarray;
}


sub keybin {
	my $self = shift;

	$self->{keybin} = shift if scalar @_;
	$self->{keybin} || "";
}


sub pubkey { &key; }


my $function = sub {			## sort RRs in numerically ascending order.
	$Net::DNS::a->{'preference'} <=> $Net::DNS::b->{'preference'};
};

__PACKAGE__->set_rrsort_func( 'preference', $function );

__PACKAGE__->set_rrsort_func( 'default_sort', $function );


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name IPSECKEY precedence gatetype algorithm gateway key');

=head1 DESCRIPTION

DNS IPSEC Key Storage (IPSECKEY) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 precedence

    $precedence = $rr->precedence;
    $rr->precedence( $precedence );

This is an 8-bit precedence for this record.  Gateways listed in
IPSECKEY records with lower precedence are to be attempted first.

=head2 gatetype

    $gatetype = $rr->gatetype;

The gateway type field indicates the format of the information that is
stored in the gateway field.

=head2 algorithm

    $algorithm = $rr->algorithm;
    $rr->algorithm( $algorithm );

The algorithm type field identifies the public keys cryptographic
algorithm and determines the format of the public key field.

=head2 gateway

    $gateway = $rr->gateway;
    $rr->gateway( $gateway );

The gateway field indicates a gateway to which an IPsec tunnel may be
created in order to reach the entity named by this resource record.

=head2 pubkey

=head2 key

    $key = $rr->key;
    $rr->key( $key );

Base64 representation of the optional public key block for the resource record.

=head2 keybin

    $keybin = $rr->keybin;
    $rr->keybin( $keybin );

Binary representation of the public key block for the resource record.


=head1 COPYRIGHT

Copyright (c)2007 Olaf Kolkman, NLnet Labs.

Portions Copyright (c)2012,2015 Dick Franks.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC4025

=cut

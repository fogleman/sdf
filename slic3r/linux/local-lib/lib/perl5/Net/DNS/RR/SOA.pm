package Net::DNS::RR::SOA;

#
# $Id: SOA.pm 1546 2017-03-06 09:27:31Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1546 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::SOA - DNS SOA resource record

=cut


use integer;

use Net::DNS::DomainName;
use Net::DNS::Mailbox;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset, @opaque ) = @_;

	( $self->{mname}, $offset ) = decode Net::DNS::DomainName1035(@_);
	( $self->{rname}, $offset ) = decode Net::DNS::Mailbox1035( $data, $offset, @opaque );
	@{$self}{qw(serial refresh retry expire minimum)} = unpack "\@$offset N5", $$data;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;
	my ( $offset, @opaque ) = @_;

	my $rname = $self->{rname} || return '';
	my $rdata = $self->{mname}->encode(@_);
	$rdata .= $rname->encode( $offset + length($rdata), @opaque );
	$rdata .= pack 'N5', $self->serial, @{$self}{qw(refresh retry expire minimum)};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{rname};
	my $mname  = $self->{mname}->string;
	my $rname  = $self->{rname}->string;
	my $serial = $self->serial;
	my $spacer = length "$serial" > 7 ? "" : "\t";
	my @rdata  = $mname, $rname, join "\n\t\t\t\t",
			"\t\t\t$serial$spacer\t;serial",
			"$self->{refresh}\t\t;refresh",
			"$self->{retry}\t\t;retry",
			"$self->{expire}\t\t;expire",
			"$self->{minimum}\t\t;minimum\n";
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->mname(shift);
	$self->rname(shift);
	$self->serial(shift);
	for (qw(refresh retry expire minimum)) {
		$self->$_( Net::DNS::RR::ttl( {}, shift ) ) if scalar @_;
	}
}


sub _defaults {				## specify RR attribute default values
	my $self = shift;

	$self->_parse_rdata(qw(. . 0 4h 1h 3w 1h));
	delete $self->{serial};
}


sub mname {
	my $self = shift;

	$self->{mname} = new Net::DNS::DomainName1035(shift) if scalar @_;
	$self->{mname}->name if $self->{mname};
}


sub rname {
	my $self = shift;

	$self->{rname} = new Net::DNS::Mailbox1035(shift) if scalar @_;
	$self->{rname}->address if $self->{rname};
}


sub serial {
	my $self = shift;

	return $self->{serial} || 0 unless scalar @_;		# current/default value

	my $value = shift;					# replace if in sequence
	return $self->{serial} = 0 + ( $value || 0 ) if _ordered( $self->{serial}, $value );

	# unwise to assume 64-bit arithmetic, or that 32-bit integer overflow goes unpunished
	my $serial = ( 0 + $self->{serial} ) & 0xFFFFFFFF;
	return $self->{serial} = $serial ^ 0xFFFFFFFF if ( $serial & 0x7FFFFFFF ) == 0x7FFFFFFF;    # wrap
	return $self->{serial} = $serial + 1;			# increment
}


sub refresh {
	my $self = shift;

	$self->{refresh} = 0 + shift if scalar @_;
	$self->{refresh} || 0;
}


sub retry {
	my $self = shift;

	$self->{retry} = 0 + shift if scalar @_;
	$self->{retry} || 0;
}


sub expire {
	my $self = shift;

	$self->{expire} = 0 + shift if scalar @_;
	$self->{expire} || 0;
}


sub minimum {
	my $self = shift;

	$self->{minimum} = 0 + shift if scalar @_;
	$self->{minimum} || 0;
}


########################################

sub _ordered($$) {			## irreflexive 32-bit partial ordering
	use integer;
	my ( $a, $b ) = @_;

	return 1 unless defined $a;				# ( undef, any )
	return 0 unless defined $b;				# ( any, undef )

	# unwise to assume 64-bit arithmetic, or that 32-bit integer overflow goes unpunished
	if ( $a < 0 ) {						# translate $a<0 region
		$a = ( $a ^ 0x80000000 ) & 0xFFFFFFFF;		#  0	 <= $a < 2**31
		$b = ( $b ^ 0x80000000 ) & 0xFFFFFFFF;		# -2**31 <= $b < 2**32
	}

	return $a < $b ? ( $a > ( $b - 0x80000000 ) ) : ( $b < ( $a - 0x80000000 ) );
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name SOA mname rname 0 14400 3600 1814400 3600');

=head1 DESCRIPTION

Class for DNS Start of Authority (SOA) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 mname

    $mname = $rr->mname;
    $rr->mname( $mname );

The domain name of the name server that was the
original or primary source of data for this zone.

=head2 rname

    $rname = $rr->rname;
    $rr->rname( $rname );

The mailbox which identifies the person responsible
for maintaining this zone.

=head2 serial

    $serial = $rr->serial;
    $serial = $rr->serial(value);

Unsigned 32 bit version number of the original copy of the zone.
Zone transfers preserve this value.

RFC1982 defines a strict (irreflexive) partial ordering for zone
serial numbers. The serial number will be incremented unless the
replacement value argument satisfies the ordering constraint.

=head2 refresh

    $refresh = $rr->refresh;
    $rr->refresh( $refresh );

A 32 bit time interval before the zone should be refreshed.

=head2 retry

    $retry = $rr->retry;
    $rr->retry( $retry );

A 32 bit time interval that should elapse before a
failed refresh should be retried.

=head2 expire

    $expire = $rr->expire;
    $rr->expire( $expire );

A 32 bit time value that specifies the upper limit on
the time interval that can elapse before the zone is no
longer authoritative.

=head2 minimum

    $minimum = $rr->minimum;
    $rr->minimum( $minimum );

The unsigned 32 bit minimum TTL field that should be
exported with any RR from this zone.

=head1 Zone Serial Number Management

The internal logic of the serial() method offers support for several
widely used zone serial numbering policies.

=head2 Strictly Sequential

    $successor = $soa->serial( SEQUENTIAL );

The existing serial number is incremented modulo 2**32 because the
value returned by the auxiliary SEQUENTIAL() function can never
satisfy the serial number ordering constraint.

=head2 Date Encoded

    $successor = $soa->serial( YYYYMMDDxx );

The 32 bit value returned by the auxiliary YYYYMMDDxx() function will
be used if it satisfies the ordering constraint, otherwise the serial
number will be incremented as above.

Serial number increments must be limited to 100 per day for the date
information to remain useful.

=head2 Time Encoded

    $successor = $soa->serial( UNIXTIME );

The 32 bit value returned by the auxiliary UNIXTIME() function will
used if it satisfies the ordering constraint, otherwise the existing
serial number will be incremented as above.


=head1 COPYRIGHT

Copyright (c)1997 Michael Fuhr. 

Portions Copyright (c)2003 Chris Reinhardt.

Portions Copyright (c)2010,2012 Dick Franks.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC1035 Section 3.3.13, RFC1982

=cut

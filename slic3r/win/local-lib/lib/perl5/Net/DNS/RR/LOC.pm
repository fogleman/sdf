package Net::DNS::RR::LOC;

#
# $Id: LOC.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::LOC - DNS LOC resource record

=cut


use integer;

use Carp;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $version = $self->{version} = unpack "\@$offset C", $$data;
	@{$self}{qw(size hp vp latitude longitude altitude)} = unpack "\@$offset xC3N3", $$data;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{longitude};
	pack 'C4N3', @{$self}{qw(version size hp vp latitude longitude altitude)};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{longitude};
	my ( $altitude, @precision ) = map $self->$_() . 'm', qw(altitude size hp vp);
	my $precision = join ' ', @precision;
	for ($precision) {
		s/\s+10m$//;
		s/\s+10000m$//;
		s/\s*1m$//;
	}
	my @rdata = ( $self->latitude, '', $self->longitude, '', $altitude, $precision );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	my @lat;
	while ( scalar @_ ) {
		my $this = shift;
		push( @lat, $this );
		last if $this =~ /[NSns]/;
	}
	$self->latitude(@lat);

	my @long;
	while ( scalar @_ ) {
		my $this = shift;
		push( @long, $this );
		last if $this =~ /[EWew]/;
	}
	$self->longitude(@long);

	foreach my $attr (qw(altitude size hp vp)) {
		$self->$attr(@_);
		shift;
	}
}


sub _defaults {				## specify RR attribute default values
	my $self = shift;

	$self->{version} = 0;
	$self->size(1);
	$self->hp(10000);
	$self->vp(10);
}


sub latitude {
	my $self = shift;
	$self->{latitude} = _encode_lat(@_) if scalar @_;
	return _decode_lat( $self->{latitude} ) if defined wantarray;
}


sub longitude {
	my $self = shift;
	$self->{longitude} = _encode_lat(@_) if scalar @_;
	return undef unless defined wantarray;
	return _decode_lat( $self->{longitude} ) unless wantarray;
	my @long = map { s/N/E/; s/S/W/; $_ } _decode_lat( $self->{longitude} );
}


sub altitude {
	my $self = shift;
	$self->{altitude} = _encode_alt(shift) if scalar @_;
	_decode_alt( $self->{altitude} ) if defined wantarray;
}


sub size {
	my $self = shift;
	$self->{size} = _encode_prec(shift) if scalar @_;
	_decode_prec( $self->{size} ) if defined wantarray;
}


sub hp {
	my $self = shift;
	$self->{hp} = _encode_prec(shift) if scalar @_;
	_decode_prec( $self->{hp} ) if defined wantarray;
}

sub horiz_pre { &hp; }						# uncoverable pod


sub vp {
	my $self = shift;
	$self->{vp} = _encode_prec(shift) if scalar @_;
	_decode_prec( $self->{vp} ) if defined wantarray;
}

sub vert_pre { &vp; }						# uncoverable pod


sub latlon {
	my $self = shift;
	my ( $lat, @lon ) = @_;
	my @pair = scalar $self->latitude(@_), scalar $self->longitude(@lon);
}


sub version {
	shift->{version};
}


########################################

no integer;

use constant ALTITUDE0 => 10000000;
use constant LATITUDE0 => 0x80000000;

sub _decode_lat {
	my $msec = shift || LATITUDE0;
	return int( 0.5 + ( $msec - LATITUDE0 ) / 0.36 ) / 10000000 unless wantarray;
	use integer;
	my $abs = abs( $msec - LATITUDE0 );
	my $deg = int( $abs / 3600000 );
	my $min = int( $abs / 60000 ) % 60;
	no integer;
	my $sec = ( $abs % 60000 ) / 1000;
	return ( $deg, $min, $sec, ( $msec < LATITUDE0 ? 'S' : 'N' ) );
}


sub _encode_lat {
	my @ang = scalar @_ > 1 ? (@_) : ( split /[\s\260'"]+/, shift );
	my $ang = ( 0 + shift @ang ) * 3600000;
	my $neg = ( @ang ? pop @ang : '' ) =~ /[SWsw]/;
	$ang += ( @ang ? shift @ang : 0 ) * 60000;
	$ang += ( @ang ? shift @ang : 0 ) * 1000;
	return int( 0.5 + ( $neg ? LATITUDE0 - $ang : LATITUDE0 + $ang ) );
}


sub _decode_alt {
	my $cm = ( shift || ALTITUDE0 ) - ALTITUDE0;
	return 0.01 * $cm;
}


sub _encode_alt {
	( my $argument = shift ) =~ s/[Mm]$//;
	$argument += 0;
	return int( 0.5 + ALTITUDE0 + 100 * $argument );
}


my @power10 = ( 0.01, 0.1, 1, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 0, 0, 0, 0, 0 );

sub _decode_prec {
	my $argument = shift || 0;
	my $mantissa = $argument >> 4;
	return $mantissa * $power10[$argument & 0x0F];
}

sub _encode_prec {
	( my $argument = shift ) =~ s/[Mm]$//;
	foreach my $exponent ( 0 .. 9 ) {
		next unless $argument < $power10[1 + $exponent];
		my $mantissa = int( 0.5 + $argument / $power10[$exponent] );
		return ( $mantissa & 0xF ) << 4 | $exponent;
	}
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name LOC latitude longitude altitude size hp vp');

=head1 DESCRIPTION

DNS geographical location (LOC) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 latitude

    $latitude = $rr->latitude;
    ($deg, $min, $sec, $ns ) = $rr->latitude;

    $rr->latitude( 42.357990 );
    $rr->latitude( 42, 21, 28.764, 'N' );
    $rr->latitude( '42 21 28.764 N' );

When invoked in scalar context, latitude is returned in degrees,
a negative ordinate being south of the equator.

When invoked in list context, latitude is returned as a list of
separate degree, minute, and second values followed by N or S
as appropriate.

Optional replacement values may be represented as single value, list
or formatted string. Trailing zero values are optional.

=head2 longitude

    $longitude = $rr->longitude;
    ($deg, $min, $sec, $ew ) = $rr->longitude;

    $rr->longitude( -71.014338 );
    $rr->longitude( 71, 0, 51.617, 'W' );
    $rr->longitude( '71 0 51.617 W' );

When invoked in scalar context, longitude is returned in degrees,
a negative ordinate being west of the prime meridian.

When invoked in list context, longitude is returned as a list of
separate degree, minute, and second values followed by E or W
as appropriate.

=head2 altitude

    $altitude = $rr->altitude;

Represents altitude, in metres, relative to the WGS 84 reference
spheroid used by GPS.

=head2 size

    $size = $rr->size;

Represents the diameter, in metres, of a sphere enclosing the
described entity.

=head2 hp

    $hp = $rr->hp;

Represents the horizontal precision of the data expressed as the
diameter, in metres, of the circle of error.

=head2 vp

    $vp = $rr->vp;

Represents the vertical precision of the data expressed as the
total spread, in metres, of the distribution of possible values.

=head2 latlon

    ($lat, $lon) = $rr->latlon;
    $rr->latlon($lat, $lon);

Representation of the latitude and longitude coordinate pair as
signed floating-point degrees.

=head2 version

    $version = $rr->version;

Version of LOC protocol.


=head1 COPYRIGHT

Copyright (c)1997 Michael Fuhr. 

Portions Copyright (c)2011 Dick Franks. 

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC1876

=cut

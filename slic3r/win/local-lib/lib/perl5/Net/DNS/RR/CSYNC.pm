package Net::DNS::RR::CSYNC;

#
# $Id: CSYNC.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::CSYNC - DNS CSYNC resource record

=cut


use integer;

use Net::DNS::Parameters;
use Net::DNS::RR::NSEC;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $limit = $offset + $self->{rdlength};
	@{$self}{qw(soaserial flags)} = unpack "\@$offset Nn", $$data;
	$offset += 6;
	$self->{typebm} = substr $$data, $offset, $limit - $offset;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{typebm};
	pack 'N n a*', $self->soaserial, $self->flags, $self->{typebm};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{typebm};
	my @rdata = ( $self->soaserial, $self->flags, $self->typelist );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->soaserial(shift);
	$self->flags(shift);
	$self->typelist(@_);
}


sub soaserial {
	my $self = shift;

	$self->{soaserial} = 0 + shift if scalar @_;
	$self->{soaserial} || 0;
}


sub SOAserial {&soaserial}


sub flags {
	my $self = shift;

	$self->{flags} = 0 + shift if scalar @_;
	$self->{flags} || 0;
}


sub immediate {
	my $bit = 0x0001;
	for ( shift->{flags} ) {
		my $set = $bit | ( $_ ||= 0 );
		return $bit & $_ unless scalar @_;
		$_ = (shift) ? $set : ( $set ^ $bit );
		return $_ & $bit;
	}
}


sub soaminimum {
	my $bit = 0x0002;
	for ( shift->{flags} ) {
		my $set = $bit | ( $_ ||= 0 );
		return $bit & $_ unless scalar @_;
		$_ = (shift) ? $set : ( $set ^ $bit );
		return $_ & $bit;
	}
}


sub typelist {
	&Net::DNS::RR::NSEC::typelist;
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name CSYNC SOAserial flags typelist');

=head1 DESCRIPTION

Class for DNSSEC CSYNC resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 SOAserial

=head2 soaserial

    $soaserial = $rr->soaserial;
    $rr->soaserial( $soaserial );

The SOA Serial field contains a copy of the 32-bit SOA serial number from
the child zone.

=head2 flags

    $flags = $rr->flags;
    $rr->flags( $flags );

The flags field contains 16 bits of boolean flags that define operations
which affect the processing of the CSYNC record.

=over 4

=item immediate

 $rr->immediate(1);

 if ( $rr->immediate ) {
	...
 }

If not set, a parental agent must not process the CSYNC record until
the zone administrator approves the operation through an out-of-band
mechanism.

=back

=over 4

=item soaminimum

 $rr->soaminimum(1);

 if ( $rr->soaminimum ) {
	...
 }

If set, a parental agent querying child authoritative servers must not
act on data from zones advertising an SOA serial number less than the
SOAserial value.

=back

=head2 typelist

    @typelist = $rr->typelist;
    $typelist = $rr->typelist;

The type list indicates the record types to be processed by the parental
agent. When called in scalar context, the list is interpolated into a
string.


=head1 COPYRIGHT

Copyright (c)2015 Dick Franks

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC7477

=cut

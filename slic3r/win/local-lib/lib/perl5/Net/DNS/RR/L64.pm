package Net::DNS::RR::L64;

#
# $Id: L64.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::L64 - DNS L64 resource record

=cut


use integer;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	@{$self}{qw(preference locator64)} = unpack "\@$offset n a8", $$data;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{locator64};
	pack 'n a8', $self->{preference}, $self->{locator64};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{locator64};
	join ' ', $self->preference, $self->locator64;
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->preference(shift);
	$self->locator64(shift);
}


sub preference {
	my $self = shift;

	$self->{preference} = 0 + shift if scalar @_;
	$self->{preference} || 0;
}


sub locator64 {
	my $self = shift;
	my $prfx = shift;

	$self->{locator64} = pack 'n4', map hex($_), split /:/, $prfx if defined $prfx;

	sprintf '%x:%x:%x:%x', unpack 'n4', $self->{locator64} if $self->{locator64};
}


my $function = sub {			## sort RRs in numerically ascending order.
	$Net::DNS::a->{'preference'} <=> $Net::DNS::b->{'preference'};
};

__PACKAGE__->set_rrsort_func( 'preference', $function );

__PACKAGE__->set_rrsort_func( 'default_sort', $function );


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name IN L64 preference locator64');

    $rr = new Net::DNS::RR(
	name	   => 'example.com',
	type	   => 'L64',
	preference => 10,
	locator64  => '2001:0DB8:1140:1000'
	);

=head1 DESCRIPTION

Class for DNS 64-bit Locator (L64) resource records.

The L64 resource record is used to hold 64-bit Locator values for
ILNPv6-capable nodes.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 preference

    $preference = $rr->preference;
    $rr->preference( $preference );

A 16 bit unsigned integer in network byte order that indicates the
relative preference for this L64 record among other L64 records
associated with this owner name.  Lower values are preferred over
higher values.

=head2 locator64

    $locator64 = $rr->locator64;

The Locator64 field is an unsigned 64-bit integer in network byte
order that has the same syntax and semantics as a 64-bit IPv6
routing prefix.


=head1 COPYRIGHT

Copyright (c)2012 Dick Franks.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC6742

=cut

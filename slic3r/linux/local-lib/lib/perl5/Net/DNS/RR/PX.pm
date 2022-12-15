package Net::DNS::RR::PX;

#
# $Id: PX.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::PX - DNS PX resource record

=cut


use integer;

use Net::DNS::DomainName;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset, @opaque ) = @_;

	$self->{preference} = unpack( "\@$offset n", $$data );
	( $self->{map822},  $offset ) = decode Net::DNS::DomainName2535( $data, $offset + 2, @opaque );
	( $self->{mapx400}, $offset ) = decode Net::DNS::DomainName2535( $data, $offset + 0, @opaque );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;
	my ( $offset, @opaque ) = @_;

	my $mapx400 = $self->{mapx400} || return '';
	my $rdata = pack( 'n', $self->{preference} );
	$rdata .= $self->{map822}->encode( $offset + 2, @opaque );
	$rdata .= $mapx400->encode( $offset + length($rdata), @opaque );
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my $mapx400 = $self->{mapx400} || return '';
	join ' ', $self->preference, $self->{map822}->string, $mapx400->string;
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->preference(shift);
	$self->map822(shift);
	$self->mapx400(shift);
}


sub preference {
	my $self = shift;

	$self->{preference} = 0 + shift if scalar @_;
	$self->{preference} || 0;
}


sub map822 {
	my $self = shift;

	$self->{map822} = new Net::DNS::DomainName2535(shift) if scalar @_;
	$self->{map822}->name if $self->{map822};
}


sub mapx400 {
	my $self = shift;

	$self->{mapx400} = new Net::DNS::DomainName2535(shift) if scalar @_;
	$self->{mapx400}->name if $self->{mapx400};
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
    $rr = new Net::DNS::RR('name PX preference map822 mapx400');

=head1 DESCRIPTION

Class for DNS X.400 Mail Mapping Information (PX) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 preference

    $preference = $rr->preference;
    $rr->preference( $preference );

A 16 bit integer which specifies the preference
given to this RR among others at the same owner.
Lower values are preferred.

=head2 map822

    $map822 = $rr->map822;
    $rr->map822( $map822 );

A domain name element containing <rfc822-domain>, the
RFC822 part of the MIXER Conformant Global Address Mapping.

=head2 mapx400

    $mapx400 = $rr->mapx400;
    $rr->mapx400( $mapx400 );

A <domain-name> element containing the value of
<x400-in-domain-syntax> derived from the X.400 part of
the MIXER Conformant Global Address Mapping.


=head1 COPYRIGHT

Copyright (c)1997 Michael Fuhr. 

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC2163

=cut

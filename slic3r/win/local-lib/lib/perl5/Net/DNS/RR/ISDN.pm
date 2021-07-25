package Net::DNS::RR::ISDN;

#
# $Id: ISDN.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::ISDN - DNS ISDN resource record

=cut


use integer;

use Net::DNS::Text;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	( $self->{address}, $offset ) = decode Net::DNS::Text( $data, $offset );
	( $self->{sa},	    $offset ) = decode Net::DNS::Text( $data, $offset );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	my $address = $self->{address} || return '';
	join '', $address->encode, $self->{sa}->encode;
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my $address = $self->{address} || return '';
	join ' ', $address->string, $self->{sa}->string;
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->address(shift);
	$self->sa(@_);
}


sub _defaults {				## specify RR attribute default values
	my $self = shift;

	$self->sa('');
}


sub address {
	my $self = shift;

	$self->{address} = new Net::DNS::Text(shift) if scalar @_;
	$self->{address}->value if $self->{address};
}


sub sa {
	my $self = shift;

	$self->{sa} = new Net::DNS::Text(shift) if scalar @_;
	$self->{sa}->value if $self->{sa};
}


sub ISDNaddress { &address; }


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name ISDN ISDNaddress sa');

=head1 DESCRIPTION

Class for DNS ISDN resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 ISDNaddress

=head2 address

    $address = $rr->address;
    $rr->address( $address );

The ISDN-address is a string of characters, normally decimal
digits, beginning with the E.163 country code and ending with
the DDI if any.

=head2 sa

    $sa = $rr->sa;
    $rr->sa( $sa );

The optional subaddress (SA) is a string of hexadecimal digits.


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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC1183 Section 3.2

=cut

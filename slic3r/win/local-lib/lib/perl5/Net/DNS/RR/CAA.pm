package Net::DNS::RR::CAA;

#
# $Id: CAA.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::CAA - DNS CAA resource record

=cut


use integer;

use Net::DNS::Text;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $limit = $offset + $self->{rdlength};
	$self->{flags} = unpack "\@$offset C", $$data;
	( $self->{tag}, $offset ) = decode Net::DNS::Text( $data, $offset + 1 );
	$self->{value} = decode Net::DNS::Text( $data, $offset, $limit - $offset );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	my $tag = $self->{tag} || return '';
	pack 'C a* a*', $self->flags, $tag->encode, $self->{value}->raw;
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my $tag = $self->{tag} || return '';
	my @rdata = ( $self->flags, $tag->string, $self->{value}->string );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->flags(shift);
	$self->tag(shift);
	$self->value(shift);
}


sub _defaults {				## specify RR attribute default values
	my $self = shift;

	$self->flags(0);
}


sub flags {
	my $self = shift;

	$self->{flags} = 0 + shift if scalar @_;
	$self->{flags} || 0;
}


sub critical {
	my $bit = 0x0080;
	for ( shift->{flags} ) {
		my $set = $bit | ( $_ ||= 0 );
		return $bit & $_ unless scalar @_;
		$_ = (shift) ? $set : ( $set ^ $bit );
		return $_ & $bit;
	}
}


sub tag {
	my $self = shift;

	$self->{tag} = new Net::DNS::Text(shift) if scalar @_;
	$self->{tag}->value if $self->{tag};
}


sub value {
	my $self = shift;

	$self->{value} = new Net::DNS::Text(shift) if scalar @_;
	$self->{value}->value if $self->{value};
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name IN CAA flags tag value');

=head1 DESCRIPTION

Class for Certification Authority Authorization (CAA) DNS resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 flags

    $flags = $rr->flags;
    $rr->flags( $flags );

Unsigned 8-bit number representing Boolean flags.

=over 4

=item critical

 $rr->critical(1);

 if ( $rr->critical ) {
	...
 }

Issuer critical flag.

=back

=head2 tag

    $tag = $rr->tag;
    $rr->tag( $tag );

The property identifier, a sequence of ASCII characters.

Tag values may contain ASCII characters a-z, A-Z, and 0-9.
Tag values should not contain any other characters.
Matching of tag values is not case sensitive.

=head2 value

    $value = $rr->value;
    $rr->value( $value );

A sequence of octets representing the property value.
Property values are encoded as binary values and may employ
sub-formats.


=head1 COPYRIGHT

Copyright (c)2013,2015 Dick Franks

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC6844

=cut

package Net::DNS::RR::NAPTR;

#
# $Id: NAPTR.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::NAPTR - DNS NAPTR resource record

=cut


use integer;

use Net::DNS::DomainName;
use Net::DNS::Text;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset, @opaque ) = @_;

	@{$self}{qw(order preference)} = unpack "\@$offset n2", $$data;
	( $self->{flags},   $offset ) = decode Net::DNS::Text( $data, $offset + 4 );
	( $self->{service}, $offset ) = decode Net::DNS::Text( $data, $offset );
	( $self->{regexp},  $offset ) = decode Net::DNS::Text( $data, $offset );
	$self->{replacement} = decode Net::DNS::DomainName2535( $data, $offset, @opaque );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;
	my ( $offset, @opaque ) = @_;

	return '' unless defined $self->{replacement};
	my $rdata = pack 'n2', @{$self}{qw(order preference)};
	$rdata .= $self->{flags}->encode;
	$rdata .= $self->{service}->encode;
	$rdata .= $self->{regexp}->encode;
	$rdata .= $self->{replacement}->encode( $offset + length($rdata), @opaque );
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{replacement};
	my @order = @{$self}{qw(order preference)};
	my @rdata = ( @order, map $_->string, @{$self}{qw(flags service regexp replacement)} );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	foreach (qw(order preference flags service regexp replacement)) { $self->$_(shift) }
}


sub order {
	my $self = shift;

	$self->{order} = 0 + shift if scalar @_;
	$self->{order} || 0;
}


sub preference {
	my $self = shift;

	$self->{preference} = 0 + shift if scalar @_;
	$self->{preference} || 0;
}


sub flags {
	my $self = shift;

	$self->{flags} = new Net::DNS::Text(shift) if scalar @_;
	$self->{flags}->value if $self->{flags};
}


sub service {
	my $self = shift;

	$self->{service} = new Net::DNS::Text(shift) if scalar @_;
	$self->{service}->value if $self->{service};
}


sub regexp {
	my $self = shift;

	$self->{regexp} = new Net::DNS::Text(shift) if scalar @_;
	$self->{regexp}->value if $self->{regexp};
}


sub replacement {
	my $self = shift;

	$self->{replacement} = new Net::DNS::DomainName2535(shift) if scalar @_;
	$self->{replacement}->name if $self->{replacement};
}


my $function = sub {
	my ( $a, $b ) = ( $Net::DNS::a, $Net::DNS::b );
	$a->{order} <=> $b->{order}
			|| $a->{preference} <=> $b->{preference};
};

__PACKAGE__->set_rrsort_func( 'order', $function );

__PACKAGE__->set_rrsort_func( 'default_sort', $function );


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name NAPTR order preference flags service regexp replacement');

=head1 DESCRIPTION

DNS Naming Authority Pointer (NAPTR) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 order

    $order = $rr->order;
    $rr->order( $order );

A 16-bit unsigned integer specifying the order in which the NAPTR
records must be processed to ensure the correct ordering of rules.
Low numbers are processed before high numbers.

=head2 preference

    $preference = $rr->preference;
    $rr->preference( $preference );

A 16-bit unsigned integer that specifies the order in which NAPTR
records with equal "order" values should be processed, low numbers
being processed before high numbers.

=head2 flags

    $flags = $rr->flags;
    $rr->flags( $flags );

A string containing flags to control aspects of the rewriting and
interpretation of the fields in the record.  Flags are single
characters from the set [A-Z0-9].

=head2 service

    $service = $rr->service;
    $rr->service( $service );

Specifies the service(s) available down this rewrite path. It may
also specify the protocol used to communicate with the service.

=head2 regexp

    $regexp = $rr->regexp;
    $rr->regexp;

A string containing a substitution expression that is applied to
the original string held by the client in order to construct the
next domain name to lookup.

=head2 replacement

    $replacement = $rr->replacement;
    $rr->replacement( $replacement );

The next NAME to query for NAPTR, SRV, or address records
depending on the value of the flags field.


=head1 COPYRIGHT

Copyright (c)1997 Michael Fuhr.

Portions Copyright (c)2005 Olaf Kolkman, NLnet Labs.

Based on code contributed by Ryan Moats.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC2915, RFC2168, RFC3403

=cut

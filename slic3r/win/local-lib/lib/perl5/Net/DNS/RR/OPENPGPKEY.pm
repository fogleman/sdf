package Net::DNS::RR::OPENPGPKEY;

#
# $Id: OPENPGPKEY.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::OPENPGPKEY - DNS OPENPGPKEY resource record

=cut


use integer;

use MIME::Base64;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $length = $self->{rdlength};
	$self->keysbin( substr $$data, $offset, $length );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	pack 'a*', $self->keysbin;
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my @base64 = split /\s+/, encode_base64( $self->keysbin );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->keys(@_);
}


sub keys {
	my $self = shift;

	$self->keysbin( MIME::Base64::decode( join "", @_ ) ) if scalar @_;
	MIME::Base64::encode( $self->keysbin(), "" ) if defined wantarray;
}


sub keysbin {
	my $self = shift;

	$self->{keysbin} = shift if scalar @_;
	$self->{keysbin} || "";
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name OPENPGPKEY keys');

=head1 DESCRIPTION

Class for OpenPGP Key (OPENPGPKEY) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 keys

    $keys = $rr->keys;
    $rr->keys( $keys );

Base64 encoded representation of the binary OpenPGP public key material.

=head2 keysbin

    $keysbin = $rr->keysbin;
    $rr->keysbin( $keysbin );

Binary representation of the public key material.
The key material is a simple concatenation of OpenPGP keys in RFC4880 format.


=head1 COPYRIGHT

Copyright (c)2014 Dick Franks

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC7929

=cut

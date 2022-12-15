package Net::DNS::RR::HIP;

#
# $Id: HIP.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::HIP - DNS HIP resource record

=cut


use integer;

use Carp;
use Net::DNS::DomainName;
use MIME::Base64;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my ( $hitlen, $pklen ) = unpack "\@$offset Cxn", $$data;
	@{$self}{qw(pkalgorithm hitbin keybin)} = unpack "\@$offset xCxx a$hitlen a$pklen", $$data;

	my $limit = $offset + $self->{rdlength};
	$offset += 4 + $hitlen + $pklen;
	$self->{servers} = [];
	while ( $offset < $limit ) {
		my $item;
		( $item, $offset ) = decode Net::DNS::DomainName( $data, $offset );
		push @{$self->{servers}}, $item;
	}
	croak('corrupt HIP data') unless $offset == $limit;	# more or less FUBAR
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{hitbin};
	my $hit = $self->hitbin;
	my $key = $self->keybin;
	my $nos = pack 'C2n a* a*', length($hit), $self->pkalgorithm, length($key), $hit, $key;
	join '', $nos, map $_->encode, @{$self->{servers}};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{hitbin};
	my $base64 = encode_base64( $self->keybin, '' );
	my @server = map $_->string, @{$self->{servers}};
	my @rdata = ( $self->pkalgorithm, $self->hit, $base64, @server );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	foreach (qw(pkalgorithm hit key)) { $self->$_(shift) }
	$self->servers(@_);
}


sub pkalgorithm {
	my $self = shift;

	$self->{pkalgorithm} = 0 + shift if scalar @_;
	$self->{pkalgorithm} || 0;
}


sub hit {
	my $self = shift;
	my @args = map { /[^0-9A-Fa-f]/ ? croak "corrupt hexadecimal" : $_ } @_;

	$self->hitbin( pack "H*", join "", @args ) if scalar @args;
	unpack "H*", $self->hitbin() if defined wantarray;
}


sub hitbin {
	my $self = shift;

	$self->{hitbin} = shift if scalar @_;
	$self->{hitbin} || "";
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

sub servers {
	my $self = shift;

	my $servers = $self->{servers} ||= [];
	@$servers = map Net::DNS::DomainName->new($_), @_ if scalar @_;
	return map $_->name, @$servers if defined wantarray;
}

sub rendezvousservers {			## historical
	my @servers = &servers;					# uncoverable pod
	\@servers;
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name IN HIP algorithm hit key servers');

=head1 DESCRIPTION

Class for DNS Host Identity Protocol (HIP) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 pkalgorithm

    $pkalgorithm = $rr->pkalgorithm;
    $rr->pkalgorithm( $pkalgorithm );

The PK algorithm field indicates the public key cryptographic
algorithm and the implied public key field format.
The values are those defined for the IPSECKEY algorithm type [RFC4025].

=head2 hit

    $hit = $rr->hit;
    $rr->hit( $hit );

The hexadecimal representation of the host identity tag.

=head2 hitbin

    $hitbin = $rr->hitbin;
    $rr->hitbin( $hitbin );

The binary representation of the host identity tag.

=head2 pubkey

=head2 key

    $key = $rr->key;
    $rr->key( $key );

The hexadecimal representation of the public key.

=head2 keybin

    $keybin = $rr->keybin;
    $rr->keybin( $keybin );

The binary representation of the public key.

=head2 servers

    @servers = $rr->servers;

Optional list of domain names of rendezvous servers.


=head1 COPYRIGHT

Copyright (c)2009 Olaf Kolkman, NLnet Labs

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC8005

=cut

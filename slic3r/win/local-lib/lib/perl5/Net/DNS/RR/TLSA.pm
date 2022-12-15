package Net::DNS::RR::TLSA;

#
# $Id: TLSA.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::TLSA - DNS TLSA resource record

=cut


use integer;

use Carp;
use constant BABBLE => defined eval 'require Digest::BubbleBabble';


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $next = $offset + $self->{rdlength};

	@{$self}{qw(usage selector matchingtype)} = unpack "\@$offset C3", $$data;
	$offset += 3;
	$self->{certbin} = substr $$data, $offset, $next - $offset;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{certbin};
	return pack 'C3 a*', @{$self}{qw(usage selector matchingtype certbin)};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{certbin};
	$self->_annotation( $self->babble ) if BABBLE;
	my @cert = split /(\S{64})/, $self->cert;
	my @rdata = ( $self->usage, $self->selector, $self->matchingtype, @cert );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->usage(shift);
	$self->selector(shift);
	$self->matchingtype(shift);
	$self->cert(@_);
}


sub usage {
	my $self = shift;

	$self->{usage} = 0 + shift if scalar @_;
	$self->{usage} || 0;
}


sub selector {
	my $self = shift;

	$self->{selector} = 0 + shift if scalar @_;
	$self->{selector} || 0;
}


sub matchingtype {
	my $self = shift;

	$self->{matchingtype} = 0 + shift if scalar @_;
	$self->{matchingtype} || 0;
}


sub cert {
	my $self = shift;
	my @args = map { /[^0-9A-Fa-f]/ ? croak "corrupt hexadecimal" : $_ } @_;

	$self->certbin( pack "H*", join "", @args ) if scalar @args;
	unpack "H*", $self->certbin() if defined wantarray;
}


sub certbin {
	my $self = shift;

	$self->{certbin} = shift if scalar @_;
	$self->{certbin} || "";
}


sub certificate { &cert; }


sub babble {
	return BABBLE ? Digest::BubbleBabble::bubblebabble( Digest => shift->certbin ) : '';
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name TLSA usage selector matchingtype certificate');

=head1 DESCRIPTION

The Transport Layer Security Authentication (TLSA) DNS resource record
is used to associate a TLS server certificate or public key with the
domain name where the record is found, forming a "TLSA certificate
association".  The semantics of how the TLSA RR is interpreted are
described in RFC6698.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 usage

    $usage = $rr->usage;
    $rr->usage( $usage );

8-bit integer value which specifies the provided association that
will be used to match the certificate presented in the TLS handshake.

=head2 selector

    $selector = $rr->selector;
    $rr->selector( $selector );

8-bit integer value which specifies which part of the TLS certificate
presented by the server will be matched against the association data.

=head2 matchingtype

    $matchingtype = $rr->matchingtype;
    $rr->matchingtype( $matchingtype );

8-bit integer value which specifies how the certificate association
is presented.

=head2 certificate

=head2 cert

    $cert = $rr->cert;
    $rr->cert( $cert );

Hexadecimal representation of the certificate data.

=head2 certbin

    $certbin = $rr->certbin;
    $rr->certbin( $certbin );

Binary representation of the certificate data.

=head2 babble

    print $rr->babble;

The babble() method returns the 'BubbleBabble' representation of the
digest if the Digest::BubbleBabble package is available, otherwise
an empty string is returned.

BubbleBabble represents a message digest as a string of plausible
words, to make the digest easier to verify.  The "words" are not
necessarily real words, but they look more like words than a string
of hex characters.

The 'BubbleBabble' string is appended as a comment when the string
method is called.


=head1 COPYRIGHT

Copyright (c)2012 Willem Toorop, NLnet Labs.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC6698

=cut

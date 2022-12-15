package Net::DNS::RR::SSHFP;

#
# $Id: SSHFP.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::SSHFP - DNS SSHFP resource record

=cut


use integer;

use Carp;

use constant BABBLE => defined eval 'require Digest::BubbleBabble';


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $size = $self->{rdlength} - 2;
	@{$self}{qw(algorithm fptype fpbin)} = unpack "\@$offset C2 a$size", $$data;
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{fpbin};
	pack 'C2 a*', @{$self}{qw(algorithm fptype fpbin)};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{fpbin};
	$self->_annotation( $self->babble ) if BABBLE;
	my @fprint = split /(\S{64})/, $self->fp;
	my @rdata = ( $self->algorithm, $self->fptype, @fprint );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->algorithm(shift);
	$self->fptype(shift);
	$self->fp(@_);
}


sub algorithm {
	my $self = shift;

	$self->{algorithm} = 0 + shift if scalar @_;
	$self->{algorithm} || 0;
}


sub fptype {
	my $self = shift;

	$self->{fptype} = 0 + shift if scalar @_;
	$self->{fptype} || 0;
}


sub fp {
	my $self = shift;
	my @args = map { /[^0-9A-Fa-f]/ ? croak "corrupt hexadecimal" : $_ } @_;

	$self->fpbin( pack "H*", join "", @args ) if scalar @args;
	unpack "H*", $self->fpbin() if defined wantarray;
}


sub fpbin {
	my $self = shift;

	$self->{fpbin} = shift if scalar @_;
	$self->{fpbin} || "";
}


sub babble {
	return BABBLE ? Digest::BubbleBabble::bubblebabble( Digest => shift->fpbin ) : '';
}


sub fingerprint { &fp; }		## historical


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name SSHFP algorithm fptype fp');

=head1 DESCRIPTION

DNS SSH Fingerprint (SSHFP) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 algorithm

    $algorithm = $rr->algorithm;
    $rr->algorithm( $algorithm );

The 8-bit algorithm number describes the algorithm used to
construct the public key.

=head2 fptype

    $fptype = $rr->fptype;
    $rr->fptype( $fptype );

The 8-bit fingerprint type number describes the message-digest
algorithm used to calculate the fingerprint of the public key.

=head2 fingerprint

=head2 fp

    $fp = $rr->fp;
    $rr->fp( $fp );

Hexadecimal representation of the fingerprint digest.

=head2 fpbin

    $fpbin = $rr->fpbin;
    $rr->fpbin( $fpbin );

Returns opaque octet string representing the fingerprint digest.

=head2 babble

    print $rr->babble;

The babble() method returns the 'BabbleBubble' representation of
the fingerprint if the Digest::BubbleBabble package is available,
otherwise an empty string is returned.

Bubble babble represents a message digest as a string of "real"
words, to make the fingerprint easier to remember. The "words"
are not necessarily real words, but they look more like words
than a string of hex characters.

Bubble babble fingerprinting is used by the SSH2 suite (and
consequently by Net::SSH::Perl, the Perl SSH implementation)
to display easy-to-remember key fingerprints.

The 'BubbleBabble' string is appended as a comment when the
string method is called.


=head1 COPYRIGHT

Copyright (c)2007 Olaf Kolkman, NLnet Labs.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC4255

=cut

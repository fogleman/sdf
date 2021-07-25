package Net::DNS::RR::NSEC3;

#
# $Id: NSEC3.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR::NSEC);

=head1 NAME

Net::DNS::RR::NSEC3 - DNS NSEC3 resource record

=cut


use integer;

use base qw(Exporter);
our @EXPORT_OK = qw(name2hash);

use Carp;

require Net::DNS::DomainName;

eval 'require Digest::SHA';		## optional for simple Net::DNS RR

my %digest = (
	'1' => ['Digest::SHA', 1],				# RFC3658
	);

{
	my @digestbyname = (
		'SHA-1' => 1,					# RFC3658
		);

	my @digestbyalias = ( 'SHA' => 1 );

	my %digestbyval = reverse @digestbyname;

	my @digestbynum = map { ( $_, 0 + $_ ) } keys %digestbyval;    # accept algorithm number

	my %digestbyname = map { s /[^A-Za-z0-9]//g; $_ } @digestbyalias, @digestbyname, @digestbynum;


	sub _digestbyname {
		my $name = shift;
		my $key	 = uc $name;				# synthetic key
		$key =~ s /[^A-Z0-9]//g;			# strip non-alphanumerics
		$digestbyname{$key} || croak "unknown digest type $name";
	}

	sub _digestbyval {
		my $value = shift;
		$digestbyval{$value} || return $value;
	}
}


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $limit = $offset + $self->{rdlength};
	my $ssize = unpack "\@$offset x4 C", $$data;
	@{$self}{qw(algorithm flags iterations saltbin)} = unpack "\@$offset CCnx a$ssize", $$data;
	$offset += 5 + $ssize;
	my $hsize = unpack "\@$offset C", $$data;
	$self->{hnxtname} = unpack "\@$offset x a$hsize", $$data;
	$offset += 1 + $hsize;
	$self->{typebm} = substr $$data, $offset, ( $limit - $offset );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	return '' unless defined $self->{typebm};
	my $salt = $self->saltbin;
	my $hash = $self->{hnxtname};
	pack 'CCn C a* C a* a*', $self->algorithm, $self->flags, $self->iterations,
			length($salt), $salt,
			length($hash), $hash,
			$self->{typebm};
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	return '' unless defined $self->{typebm};
	my @rdata = (
		$self->algorithm, $self->flags, $self->iterations,
		$self->salt || '-', $self->hnxtname, $self->typelist
		);
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->algorithm(shift);
	$self->flags(shift);
	$self->iterations(shift);
	my $salt = shift;
	$self->salt($salt) unless $salt eq '-';
	$self->hnxtname(shift);
	$self->typelist(@_);
}


sub _defaults {				## specify RR attribute default values
	my $self = shift;

	$self->_parse_rdata( 1, 0, 0, '' );
}


sub algorithm {
	my ( $self, $arg ) = @_;

	unless ( ref($self) ) {		## class method or simple function
		my $argn = pop;
		return $argn =~ /[^0-9]/ ? _digestbyname($argn) : _digestbyval($argn);
	}

	return $self->{algorithm} unless defined $arg;
	return _digestbyval( $self->{algorithm} ) if $arg =~ /MNEMONIC/i;
	return $self->{algorithm} = _digestbyname($arg);
}


sub flags {
	my $self = shift;

	$self->{flags} = 0 + shift if scalar @_;
	$self->{flags} || 0;
}


sub optout {
	my $bit = 0x01;
	for ( shift->{flags} ) {
		my $set = $bit | ( $_ ||= 0 );
		return $bit & $_ unless scalar @_;
		$_ = (shift) ? $set : ( $set ^ $bit );
		return $_ & $bit;
	}
}


sub iterations {
	my $self = shift;

	$self->{iterations} = 0 + shift if scalar @_;
	$self->{iterations} || 0;
}


sub salt {
	my $self = shift;
	my @args = map { /[^0-9A-Fa-f]/ ? croak "corrupt hexadecimal" : $_ } @_;

	$self->saltbin( pack "H*", join "", @args ) if scalar @args;
	unpack "H*", $self->saltbin() if defined wantarray;
}


sub saltbin {
	my $self = shift;

	$self->{saltbin} = shift if scalar @_;
	$self->{saltbin} || "";
}


sub hnxtname {
	my $self = shift;
	$self->{hnxtname} = _decode_base32(shift) if scalar @_;
	_encode_base32( $self->{hnxtname} ) if defined wantarray;
}


sub covered {
	my $self = shift;
	my $name = shift;

	# first test if the domain name is in the NSEC3 zone.
	my @domainlabels = new Net::DNS::DomainName($name)->_wire;
	my ( $owner, @zonelabels ) = $self->{owner}->_wire;
	my $ownerhash = _decode_base32($owner);

	foreach ( reverse @zonelabels ) {
		return 0 unless lc($_) eq lc( pop(@domainlabels) || return 0 );
	}

	my $namehash = _hash( $self->algorithm, $name, $self->iterations, $self->saltbin );
	my $nexthash = "$self->{hnxtname}";

	unless ( $ownerhash lt $nexthash ) {			# last or only NSEC3 RR
		return 1 if $namehash lt $nexthash;
		return $namehash gt $ownerhash;
	}

	return 0 unless $namehash gt $ownerhash;		# general case
	return $namehash lt $nexthash;
}


sub match {
	my $self = shift;
	my $name = shift;

	my $namehash = _hash( $self->algorithm, $name, $self->iterations, $self->saltbin );

	my ($owner) = $self->{owner}->_wire;
	my $ownerhash = _decode_base32($owner);

	$namehash eq $ownerhash;
}


########################################

sub _decode_base32 {
	local $_ = shift || '';
	tr [0-9a-vA-V] [\000-\037\012-\037];
	$_ = unpack 'B*', $_;
	s/000(.....)/$1/g;
	my $l = length;
	$_ = substr $_, 0, $l & ~7 if $l & 7;
	pack 'B*', $_;
}


sub _encode_base32 {
	local $_ = unpack 'B*', shift;
	s/(.....)/000$1/g;
	my $l = length;
	my $x = substr $_, $l & ~7;
	my $n = length $x;
	substr( $_, $l & ~7 ) = join '', '000', $x, '0' x ( 5 - $n ) if $n;
	$_ = pack( 'B*', $_ );
	tr [\000-\037] [0-9a-v];
	return $_;
}


sub _hash {
	my $hashalg    = shift;
	my $name       = shift;
	my $iterations = shift;
	my $salt       = shift || '';

	my $arglist = $digest{$hashalg};
	my ( $object, @argument ) = @$arglist;
	my $hash = $object->new(@argument);

	my $wirename = new Net::DNS::DomainName($name)->canonical;
	$iterations++;

	while ( $iterations-- ) {
		$hash->add($wirename);
		$hash->add($salt);
		$wirename = $hash->digest;
	}

	return $wirename;
}


sub name2hash { _encode_base32(&_hash); }			# uncoverable pod


sub hashalgo { &algorithm; }					# uncoverable pod


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name NSEC3 algorithm flags iterations salt hnxtname');

=head1 DESCRIPTION

Class for DNSSEC NSEC3 resource records.

The NSEC3 Resource Record (RR) provides authenticated denial of
existence for DNS Resource Record Sets.

The NSEC3 RR lists RR types present at the original owner name of the
NSEC3 RR.  It includes the next hashed owner name in the hash order
of the zone.  The complete set of NSEC3 RRs in a zone indicates which
RRSets exist for the original owner name of the RR and form a chain
of hashed owner names in the zone.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 algorithm

    $algorithm = $rr->algorithm;
    $rr->algorithm( $algorithm );

The Hash Algorithm field is represented as an unsigned decimal
integer.  The value has a maximum of 255.

algorithm() may also be invoked as a class method or simple function
to perform mnemonic and numeric code translation.

=head2 flags

    $flags = $rr->flags;
    $rr->flags( $flags );

The Flags field is represented as an unsigned decimal integer.
The value has a maximum value of 255. 

=over 4

=item optout

 $rr->optout(1);

 if ( $rr->optout ) {
	...
 }

Boolean Opt Out flag.

=back

=head2 iterations

    $iterations = $rr->iterations;
    $rr->iterations( $iterations );

The Iterations field is represented as an unsigned decimal
integer.  The value is between 0 and 65535, inclusive. 

=head2 salt

    $salt = $rr->salt;
    $rr->salt( $salt );

The Salt field is represented as a contiguous sequence of hexadecimal
digits. A "-" (unquoted) is used in string format to indicate that the
salt field is absent. 

=head2 saltbin

    $saltbin = $rr->saltbin;
    $rr->saltbin( $saltbin );

The Salt field as a sequence of octets. 

=head2 hnxtname

    $hnxtname = $rr->hnxtname;
    $rr->hnxtname( $hnxtname );

The Next Hashed Owner Name field points to the next node that has
authoritative data or contains a delegation point NS RRset.

=head2 typelist

    @typelist = $rr->typelist;
    $typelist = $rr->typelist;
    $rr->typelist( @typelist );

The Type List identifies the RRset types that exist at the domain name
matched by the NSEC3 RR.  When called in scalar context, the list is
interpolated into a string.

=head2 covered, match

    print "covered" if $rr->covered{'example.foo'}

covered() returns a nonzero value when the the domain name provided as argument
is covered as defined in the NSEC3 specification:

   To cover:  An NSEC3 RR is said to "cover" a name if the hash of the
      name or "next closer" name falls between the owner name and the
      next hashed owner name of the NSEC3.  In other words, if it proves
      the nonexistence of the name, either directly or by proving the
      nonexistence of an ancestor of the name.


Similarly matched() returns a nonzero value when the domainname in the argument
matches as defined in the NSEC3 specification:

   To match: An NSEC3 RR is said to "match" a name if the owner name
      of the NSEC3 RR is the same as the hashed owner name of that
      name.


=head1 COPYRIGHT

Copyright (c)2007,2008 NLnet Labs.  Author Olaf M. Kolkman

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC5155, RFC4648

L<Hash Algorithms|http://www.iana.org/assignments/dnssec-nsec3-parameters>

=cut

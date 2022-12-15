package Net::DNS::Domain;

#
# $Id: Domain.pm 1555 2017-03-22 09:47:16Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1555 $)[1];


=head1 NAME

Net::DNS::Domain - DNS domains

=head1 SYNOPSIS

    use Net::DNS::Domain;

    $domain = new Net::DNS::Domain('example.com');
    $name   = $domain->name;

=head1 DESCRIPTION

The Net::DNS::Domain module implements a class of abstract DNS
domain objects with associated class and instance methods.

Each domain object instance represents a single DNS domain which
has a fixed identity throughout its lifetime.

Internally, the primary representation is a (possibly empty) list
of ASCII domain name labels, and optional link to an arbitrary
origin domain object topologically closer to the DNS root.

The computational expense of Unicode character-set conversion is
partially mitigated by use of caches.

=cut


use strict;
use warnings;
use integer;
use Carp;


use constant ASCII => ref eval {
	require Encode;
	Encode::find_encoding('ascii');				# encoding object
};

use constant UTF8 => scalar eval {	## not UTF-EBCDIC  [see UTR#16 3.6]
	Encode::encode_utf8( chr(182) ) eq pack( 'H*', 'C2B6' );
};

use constant LIBIDN => defined eval { require Net::LibIDN; };


# perlcc: address of encoding objects must be determined at runtime
my $ascii = ASCII ? Encode::find_encoding('ascii') : undef;	# Osborn's Law:
my $utf8  = UTF8  ? Encode::find_encoding('utf8')  : undef;	# Variables won't; constants aren't.


=head1 METHODS

=head2 new

    $object = new Net::DNS::Domain('example.com');

Creates a domain object which represents the DNS domain specified
by the character string argument. The argument consists of a
sequence of labels delimited by dots.

A character preceded by \ represents itself, without any special
interpretation.

Arbitrary 8-bit codes can be represented by \ followed by exactly
three decimal digits.
Character code points are ASCII, irrespective of the character
coding scheme employed by the underlying platform.

Argument string literals should be delimited by single quotes to
avoid escape sequences being interpreted as octal character codes
by the Perl compiler.

The character string presentation format follows the conventions
for zone files described in RFC1035.

=cut

our $ORIGIN;
my ( $cache1, $cache2, $limit ) = ( {}, {}, 100 );

sub new {
	my ( $class, $s ) = @_;
	croak 'domain identifier undefined' unless defined $s;

	my $k = join '', $s, $class, $ORIGIN || '';		# cache key
	my $cache = $$cache1{$k} ||= $$cache2{$k};		# two layer cache
	return $cache if defined $cache;

	( $cache1, $cache2, $limit ) = ( {}, $cache1, 500 ) unless $limit--;	# recycle cache

	my $self = bless {}, $class;

	$s =~ s/\\\\/\\092/g;					# disguise escaped escape
	$s =~ s/\\\./\\046/g;					# disguise escaped dot

	my $label = $self->{label} = $s eq '@' ? [] : [split /\056/, _encode_ascii($s)];

	foreach my $l (@$label) {
		$l = _unescape($l) if $l =~ /\\/;
		croak 'empty domain label' unless my $size = length($l);
		( substr( $l, 63 ) = '', carp 'domain label truncated' ) if $size > 63;
	}

	$$cache1{$k} = $self;					# cache object reference

	return $self if $s =~ /\.$/;				# fully qualified name
	$self->{origin} = $ORIGIN || return $self;		# dynamically scoped $ORIGIN
	return $self;
}


=head2 name

    $name = $domain->name;

Returns the domain name as a character string corresponding to the
"common interpretation" to which RFC1034, 3.1, paragraph 9 alludes.

Character escape sequences are used to represent a dot inside a
domain name label and the escape character itself.

Any non-printable code point is represented using the appropriate
numerical escape sequence.

=cut

my $dot = '.';

sub name {
	my ($self) = @_;

	return $self->{name} if defined $self->{name};
	return unless defined wantarray;

	my $lref = $self->{label};
	my $head = _decode_ascii( join chr(46), map _escape($_), @$lref );
	my $tail = $self->{origin} || return $self->{name} = $head || $dot;
	return $self->{name} = $tail->name unless length $head;
	my $suffix = $tail->name;
	return $self->{name} = $suffix eq $dot ? $head : join $dot, $head, $suffix;
}


=head2 fqdn

    @fqdn = $domain->fqdn;

Returns a character string containing the fully qualified domain
name, including the trailing dot.

=cut

sub fqdn {
	my $name = &name;
	return $name =~ /[$dot]$/o ? $name : $name . $dot;	# append trailing dot
}


=head2 xname

    $xname = $domain->xname;

Interprets an extended name containing Unicode domain name labels
encoded as Punycode A-labels.

Domain names containing Unicode characters are supported if the
Net::LibIDN module is installed.

=cut

sub xname {
	my $name = &name;

	if ( LIBIDN && UTF8 && $name =~ /xn--/ ) {
		my $self = shift;
		return $self->{xname} if defined $self->{xname};
		return $self->{xname} = $utf8->decode( Net::LibIDN::idn_to_unicode $name, 'utf-8' );
	}
	return $name;
}


=head2 label

    @label = $domain->label;

Identifies the domain by means of a list of domain labels.

=cut

sub label {
	my $self = shift;

	my @head = map _decode_ascii( _escape($_) ), @{$self->{label}};
	my $tail = $self->{origin} || return (@head);
	return ( @head, $tail->label );
}


=head2 string

    $string = $object->string;

Returns a character string containing the fully qualified domain
name as it appears in a zone file.

Characters which are recognised by RFC1035 zone file syntax are
represented by the appropriate escape sequence.

=cut

sub string {
	( my $name = &name ) =~ s/(["'\$();@])/\\$1/;		# escape special char
	return $name =~ /[$dot]$/o ? $name : $name . $dot;	# append trailing dot
}


=head2 origin

    $create = origin Net::DNS::Domain( $ORIGIN );
    $result = &$create( sub{ new Net::DNS::RR( 'mx MX 10 a' ); } );
    $expect = new Net::DNS::RR( "mx.$ORIGIN. MX 10 a.$ORIGIN." );

Class method which returns a reference to a subroutine wrapper
which executes a given constructor in a dynamically scoped context
where relative names become descendents of the specified $ORIGIN.

=cut

my $placebo = sub { my $constructor = shift; &$constructor; };

sub origin {
	my ( $class, $name ) = @_;
	my $domain = defined $name ? new Net::DNS::Domain($name) : return $placebo;

	return sub {						# closure w.r.t. $domain
		my $constructor = shift;
		local $ORIGIN = $domain;			# dynamically scoped $ORIGIN
		&$constructor;
			}
}


########################################

sub _decode_ascii {			## translate ASCII to perl string
	my $s = shift;

	# partial transliteration for non-ASCII character encodings
	$s =~ tr
	[\040-\176\000-\377]
	[ !"#$%&'()*+,-./0-9:;<=>?@A-Z\[\\\]^_`a-z{|}~?] unless ASCII;

	my $z = length substr $s, 0, 0;				# pre-5.18 taint workaround
	return ASCII ? pack( "a* x$z", $ascii->decode($s) ) : $s;
}


sub _encode_ascii {			## translate perl string to ASCII
	my $s = shift;

	my $z = length substr $s, 0, 0;				# pre-5.18 taint workaround

	if ( LIBIDN && UTF8 && $s =~ /[^\000-\177]/ ) {
		my $xn = Net::LibIDN::idn_to_ascii( $s, 'utf-8' );
		croak 'invalid name' unless $xn;
		return pack "a* x$z", $xn;
	}

	# partial transliteration for non-ASCII character encodings
	$s =~ tr
	[ !"#$%&'()*+,-./0-9:;<=>?@A-Z\[\\\]^_`a-z{|}~\000-\377]
	[\040-\176\077] unless ASCII;

	return ASCII ? pack( "a* x$z", $ascii->encode($s) ) : $s;
}


my %esc = eval {			## precalculated ASCII escape table
	my %table;

	foreach ( 33 .. 126 ) {					# ASCII printable
		$table{pack( 'C', $_ )} = pack 'C', $_;
	}

	# minimal character escapes
	foreach ( 46, 92 ) {					# \. \\
		$table{pack( 'C', $_ )} = pack 'C*', 92, $_;
	}

	foreach my $n ( 0 .. 32, 127 .. 255 ) {			# \ddd
		my $codepoint = sprintf( '%03u', $n );

		# partial transliteration for non-ASCII character encodings
		$codepoint =~ tr [0-9] [\060-\071];

		$table{pack( 'C', $n )} = pack 'C a3', 92, $codepoint;
	}

	return %table;
};


sub _escape {				## Insert escape sequences in string
	my $s = shift;
	$s =~ s/([^\055\101-\132\141-\172\060-\071])/$esc{$1}/eg;
	return $s;
}


my %unesc = eval {			## precalculated numeric escape table
	my %table;

	foreach my $n ( 0 .. 255 ) {
		my $key = sprintf( '%03u', $n );

		# partial transliteration for non-ASCII character encodings
		$key =~ tr [0-9] [\060-\071];

		$table{$key} = pack 'C*', $n, $n == 92 ? ($n) : ();
	}

	return %table;
};


sub _unescape {				## Remove escape sequences in string
	my $s = shift;
	$s =~ s/\134([\060-\071]{3})/$unesc{$1}/eg;		# numeric escape
	$s =~ s/\134(.)/$1/g;					# character escape
	return $s;
}


1;
__END__


########################################

=head1 BUGS

Coding strategy is intended to avoid creating unnecessary argument
lists and stack frames. This improves efficiency at the expense of
code readability.

Platform specific character coding features are conditionally
compiled into the code.


=head1 COPYRIGHT

Copyright (c)2009-2011 Dick Franks.

All rights reserved.


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

L<perl>, L<Net::LibIDN>, L<Net::DNS>, RFC1034, RFC1035, RFC5891,
Unicode Technical Report #16

=cut


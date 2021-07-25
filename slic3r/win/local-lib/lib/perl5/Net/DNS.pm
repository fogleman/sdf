package Net::DNS;

#
# $Id: DNS.pm 1557 2017-03-23 21:01:32Z willem $
#
require 5.006;
our $VERSION;
$VERSION = '1.09';
$VERSION = eval $VERSION;
our $SVNVERSION = (qw$LastChangedRevision: 1557 $)[1];


=head1 NAME

Net::DNS - Perl Interface to the Domain Name System

=head1 SYNOPSIS

    use Net::DNS;

=head1 DESCRIPTION

Net::DNS is a collection of Perl modules that act as a Domain Name System
(DNS) resolver. It allows the programmer to perform DNS queries that are
beyond the capabilities of "gethostbyname" and "gethostbyaddr".

The programmer should be somewhat familiar with the format of a DNS packet
and its various sections. See RFC 1035 or DNS and BIND (Albitz & Liu) for
details.

=cut


use strict;
use warnings;
use integer;

use base qw(Exporter);
our @EXPORT = qw(SEQUENTIAL UNIXTIME YYYYMMDDxx
		yxrrset nxrrset yxdomain nxdomain rr_add rr_del
		mx rr rrsort);


local $SIG{__DIE__};
require Net::DNS::RR;
require Net::DNS::Packet;
require Net::DNS::Update;
require Net::DNS::Resolver;


sub version { $VERSION; }


#
# rr()
#
# Usage:
#	@rr = rr('example.com');
#	@rr = rr('example.com', 'A', 'IN');
#	@rr = rr($res, 'example.com' ... );
#
sub rr {
	my ($arg1) = @_;
	my $res = ref($arg1) ? shift : new Net::DNS::Resolver();

	my $ans = $res->query(@_);
	my @list = $ans ? $ans->answer : ();
}


#
# mx()
#
# Usage:
#	@mx = mx('example.com');
#	@mx = mx($res, 'example.com');
#
sub mx {
	my ($arg1) = @_;
	my @res = ( ref($arg1) ? shift : () );
	my ( $name, @class ) = @_;

	# This construct is best read backwards.
	#
	# First we take the answer section of the packet.
	# Then we take just the MX records from that list
	# Then we sort the list by preference
	# We do this into an array to force list context.
	# Then we return the list.

	my @list = sort { $a->preference <=> $b->preference }
			grep $_->type eq 'MX', &rr( @res, $name, 'MX', @class );
	return @list;
}


#
# rrsort()
#
# Usage:
#    @prioritysorted = rrsort( "SRV", "priority", @rr_array );
#
sub rrsort {
	my $rrtype = uc shift;
	my ( $attribute, @rr ) = @_;	## NB: attribute is optional
	( @rr, $attribute ) = @_ if ref($attribute) =~ /^Net::DNS::RR/;

	my @extracted = grep $_->type eq $rrtype, @rr;
	return @extracted unless scalar @extracted;
	my $func   = "Net::DNS::RR::$rrtype"->get_rrsort_func($attribute);
	my @sorted = sort $func @extracted;
}


#
# Auxiliary functions to support policy-driven zone serial numbering.
#
#	$successor = $soa->serial(SEQUENTIAL);
#	$successor = $soa->serial(UNIXTIME);
#	$successor = $soa->serial(YYYYMMDDxx);
#

sub SEQUENTIAL {undef}

sub UNIXTIME { return CORE::time; }

sub YYYYMMDDxx {
	my ( $dd, $mm, $yy ) = (localtime)[3 .. 5];
	return 1900010000 + sprintf '%d%0.2d%0.2d00', $yy, $mm, $dd;
}


#
# Auxiliary functions to support dynamic update.
#

sub yxrrset {
	my $rr = new Net::DNS::RR(@_);
	$rr->ttl(0);
	$rr->class('ANY') unless $rr->rdata;
	return $rr;
}

sub nxrrset {
	my $rr = new Net::DNS::RR(@_);
	new Net::DNS::RR(
		name  => $rr->name,
		type  => $rr->type,
		class => 'NONE'
		);
}

sub yxdomain {
	my ( $domain, @etc ) = map split, @_;
	my $rr = new Net::DNS::RR( scalar(@etc) ? @_ : ( name => $domain ) );
	new Net::DNS::RR(
		name  => $rr->name,
		type  => 'ANY',
		class => 'ANY'
		);
}

sub nxdomain {
	my ( $domain, @etc ) = map split, @_;
	my $rr = new Net::DNS::RR( scalar(@etc) ? @_ : ( name => $domain ) );
	new Net::DNS::RR(
		name  => $rr->name,
		type  => 'ANY',
		class => 'NONE'
		);
}

sub rr_add {
	my $rr = new Net::DNS::RR(@_);
	$rr->{ttl} = 86400 unless defined $rr->{ttl};
	return $rr;
}

sub rr_del {
	my ( $domain, @etc ) = map split, @_;
	my $rr = new Net::DNS::RR( scalar(@etc) ? @_ : ( name => $domain ) );
	$rr->class( $rr->rdata ? 'NONE' : 'ANY' );
	$rr->ttl(0);
	return $rr;
}


1;
__END__



=head2 Resolver Objects

A resolver object is an instance of the L<Net::DNS::Resolver> class.
A program can have multiple resolver objects, each maintaining its
own state information such as the nameservers to be queried, whether
recursion is desired, etc.


=head2 Packet Objects

L<Net::DNS::Resolver> queries return L<Net::DNS::Packet> objects.
Packet objects have five sections:

=over 3

=item *

The header section, a L<Net::DNS::Header> object.

=item *

The question section, a list of L<Net::DNS::Question> objects.

=item *

The answer section, a list of L<Net::DNS::RR> objects.

=item *

The authority section, a list of L<Net::DNS::RR> objects.

=item *

The additional section, a list of L<Net::DNS::RR> objects.

=back

=head2 Update Objects

L<Net::DNS::Update> is a subclass of L<Net::DNS::Packet>
used to create dynamic update requests.

=head2 Header Objects

L<Net::DNS::Header> objects represent the header
section of a DNS packet.

=head2 Question Objects

L<Net::DNS::Question> objects represent the content of the question
section of a DNS packet.

=head2 RR Objects

L<Net::DNS::RR> is the base class for DNS resource record (RR) objects
in the answer, authority, and additional sections of a DNS packet.

Do not assume that RR objects will be of the type requested.
The type of an RR object must be checked before calling any methods.


=head1 METHODS

See the manual pages listed above for other class-specific methods.

=head2 version

    print Net::DNS->version, "\n";

Returns the version of Net::DNS.


=head2 rr

    # Use a default resolver -- can not get an error string this way.
    use Net::DNS;
    my @rr = rr("example.com");
    my @rr = rr("example.com", "A");
    my @rr = rr("example.com", "A", "IN");

    # Use your own resolver object.
    my $res = Net::DNS::Resolver->new;
    my @rr  = rr($res, "example.com" ... );

    my ($ptr) = rr("192.0.2.1");

The rr() method provides simple RR lookup for scenarios where
the full flexibility of Net::DNS is not required.

Returns a list of L<Net::DNS::RR> objects for the specified name
or an empty list if the query failed or no record was found.

See L</EXAMPLES> for more complete examples.


=head2 mx

    # Use a default resolver -- can not get an error string this way.
    use Net::DNS;
    my @mx = mx("example.com");

    # Use your own resolver object.
    my $res = Net::DNS::Resolver->new;
    my @mx  = mx($res, "example.com");

Returns a list of L<Net::DNS::RR::MX> objects representing the MX
records for the specified name.
The list will be sorted by preference.
Returns an empty list if the query failed or no MX record was found.

This method does not look up A records; it only performs MX queries.


=head1 Dynamic DNS Update Support

The Net::DNS module provides auxiliary functions which support
dynamic DNS update requests.


=head2 yxrrset

Use this method to add an "RRset exists" prerequisite to a dynamic
update packet.	There are two forms, value-independent and
value-dependent:

    # RRset exists (value-independent)
    $update->push(pre => yxrrset("host.example.com A"));

Meaning:  At least one RR with the specified name and type must
exist.

    # RRset exists (value-dependent)
    $update->push(pre => yxrrset("host.example.com A 10.1.2.3"));

Meaning:  At least one RR with the specified name and type must
exist and must have matching data.

Returns a L<Net::DNS::RR> object or C<undef> if the object could not
be created.

=head2 nxrrset

Use this method to add an "RRset does not exist" prerequisite to
a dynamic update packet.

    $update->push(pre => nxrrset("host.example.com A"));

Meaning:  No RRs with the specified name and type can exist.

Returns a L<Net::DNS::RR> object or C<undef> if the object could not
be created.

=head2 yxdomain

Use this method to add a "name is in use" prerequisite to a dynamic
update packet.

    $update->push(pre => yxdomain("host.example.com"));

Meaning:  At least one RR with the specified name must exist.

Returns a L<Net::DNS::RR> object or C<undef> if the object could not
be created.

=head2 nxdomain

Use this method to add a "name is not in use" prerequisite to a
dynamic update packet.

    $update->push(pre => nxdomain("host.example.com"));

Meaning:  No RR with the specified name can exist.

Returns a L<Net::DNS::RR> object or C<undef> if the object could not
be created.

=head2 rr_add

Use this method to add RRs to a zone.

    $update->push(update => rr_add("host.example.com A 10.1.2.3"));

Meaning:  Add this RR to the zone.

RR objects created by this method should be added to the "update"
section of a dynamic update packet.  The TTL defaults to 86400
seconds (24 hours) if not specified.

Returns a L<Net::DNS::RR> object or C<undef> if the object could not
be created.

=head2 rr_del

Use this method to delete RRs from a zone.  There are three forms:
delete all RRsets, delete an RRset, and delete a specific RR.

    # Delete all RRsets.
    $update->push(update => rr_del("host.example.com"));

Meaning:  Delete all RRs having the specified name.

    # Delete an RRset.
    $update->push(update => rr_del("host.example.com A"));

Meaning:  Delete all RRs having the specified name and type.

    # Delete a specific RR.
    $update->push(update => rr_del("host.example.com A 10.1.2.3"));

Meaning:  Delete all RRs having the specified name, type, and data.

RR objects created by this method should be added to the "update"
section of a dynamic update packet.

Returns a L<Net::DNS::RR> object or C<undef> if the object could not
be created.


=head1 Zone Serial Number Management

The Net::DNS module provides auxiliary functions which support
policy-driven zone serial numbering regimes.

=head2 SEQUENTIAL

    $successor = $soa->serial( SEQUENTIAL );

The existing serial number is incremented modulo 2**32.

=head2 UNIXTIME

    $successor = $soa->serial( UNIXTIME );

The Unix time scale will be used as the basis for zone serial
numbering. The serial number will be incremented if the time
elapsed since the previous update is less than one second.

=head2 YYYYMMDDxx

    $successor = $soa->serial( YYYYMMDDxx );

The 32 bit value returned by the auxiliary YYYYMMDDxx() function
will be used as the base for the date-coded zone serial number.
Serial number increments must be limited to 100 per day for the
date information to remain useful.



=head1 Sorting of RR arrays

rrsort() provides functionality to help you sort RR arrays. In most cases
rrsort() will give you the answer that you want, but you can specify your
own sorting method by using the Net::DNS::RR::FOO->set_rrsort_func() class
method. See Net::DNS::RR for details.

=head2 rrsort()

    use Net::DNS;

    my @sorted = rrsort( $rrtype, $attribute, @rr_array );

rrsort() selects all RRs from the input array that are of the type defined
by the first argument. Those RRs are sorted based on the attribute that is
specified as second argument.

There are a number of RRs for which the sorting function is defined in the
code.

For instance:

    my @prioritysorted = rrsort( "SRV", "priority", @rr_array );

returns the SRV records sorted from lowest to highest priority and for
equal priorities from highest to lowest weight.

If the function does not exist then a numerical sort on the attribute
value is performed.

    my @portsorted = rrsort( "SRV", "port", @rr_array );

If the attribute is not defined then either the default_sort() function or
"canonical sorting" (as defined by DNSSEC) will be used.

rrsort() returns a sorted array containing only elements of the specified
RR type.  Any other RR types are silently discarded.

rrsort() returns an empty list when arguments are incorrect.


=head1 EXAMPLES

The following brief examples illustrate some of the features of Net::DNS.
The documentation for individual modules and the demo scripts included
with the distribution provide more extensive examples.

See L<Net::DNS::Update> for an example of performing dynamic updates.


=head2 Look up host addresses.

    use Net::DNS;
    my $res   = Net::DNS::Resolver->new;
    my $reply = $res->search("host.example.com");

    if ($reply) {
	foreach my $rr ($reply->answer) {
	    print $rr->address, "\n" if $rr->type eq "A";
	}
    } else {
	warn "query failed: ", $res->errorstring, "\n";
    }


=head2 Find the nameservers for a domain.

    use Net::DNS;
    my $res   = Net::DNS::Resolver->new;
    my $reply = $res->query("example.com", "NS");

    if ($reply) {
	foreach $rr (grep { $_->type eq 'NS' } $reply->answer) {
	    print $rr->nsdname, "\n";
	}
    } else {
	warn "query failed: ", $res->errorstring, "\n";
    }


=head2 Find the MX records for a domain.

    use Net::DNS;
    my $name = "example.com";
    my $res  = Net::DNS::Resolver->new;
    my @mx   = mx($res, $name);

    if (@mx) {
	foreach $rr (@mx) {
	    print $rr->preference, " ", $rr->exchange, "\n";
	}
    } else {
	warn "Can not find MX records for $name: ", $res->errorstring, "\n";
    }


=head2 Print domain SOA record in zone file format.

    use Net::DNS;
    my $res   = Net::DNS::Resolver->new;
    my $reply = $res->query("example.com", "SOA");

    if ($reply) {
	($reply->answer)[0]->print;
    } else {
	print "query failed: ", $res->errorstring, "\n";
    }


=head2 Perform a zone transfer and print all the records.

    use Net::DNS;
    my $res  = Net::DNS::Resolver->new;
    $res->nameservers("ns.example.com");

    my @zone = $res->axfr("example.com");

    foreach $rr (@zone) {
	$rr->print;
    }


=head2 Perform a background query and print the reply.

    use Net::DNS;
    my $res    = Net::DNS::Resolver->new;
    my $socket = $res->bgsend("host.example.com");

    while ( $res->bgbusy($socket) ) {
	# do some work here while waiting for the answer
	# ...and some more here
    }

    my $packet = $res->bgread($socket);
    $packet->print;


=head1 BUGS

C<Net::DNS> is slow.

For other items to be fixed, or if you discover a bug in this
distribution please use the CPAN bug reporting system.


=head1 COPYRIGHT

Copyright (c)1997-2000 Michael Fuhr.

Portions Copyright (c)2002,2003 Chris Reinhardt.

Portions Copyright (c)2005 Olaf Kolkman (RIPE NCC)

Portions Copyright (c)2006 Olaf Kolkman (NLnet Labs)

Portions Copyright (c)2014 Dick Franks

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


=head1 AUTHOR INFORMATION

Net::DNS is maintained at NLnet Labs (www.nlnetlabs.nl) by Willem Toorop.

Between 2005 and 2012 Net::DNS was maintained by Olaf Kolkman.

Between 2002 and 2004 Net::DNS was maintained by Chris Reinhardt.

Net::DNS was created in 1997 by Michael Fuhr.


=head1 SEE ALSO

L<perl>, L<Net::DNS::Resolver>, L<Net::DNS::Question>, L<Net::DNS::RR>,
L<Net::DNS::Packet>, L<Net::DNS::Update>,
RFC1035, L<http://www.net-dns.org/>,
I<DNS and BIND> by Paul Albitz & Cricket Liu

=cut


package Net::DNS::Resolver;

#
# $Id: Resolver.pm 1527 2017-01-18 21:42:48Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1527 $)[1];

=head1 NAME

Net::DNS::Resolver - DNS resolver class

=cut


use strict;
use warnings;

use constant CONFIG => defined eval "require Net::DNS::Resolver::$^O";

use constant OS_CONF => join '::', __PACKAGE__, CONFIG ? $^O : 'UNIX';

use base OS_CONF;


1;

__END__


=head1 SYNOPSIS

    use Net::DNS;

    $resolver = new Net::DNS::Resolver();

    # Perform a lookup, using the searchlist if appropriate.
    $reply = $resolver->search( 'example.com' );

    # Perform a lookup, without the searchlist
    $reply = $resolver->query( 'example.com', 'MX' );

    # Perform a lookup, without pre or post-processing
    $reply = $resolver->send( 'example.com', 'MX', 'IN' );

    # Send a prebuilt query packet
    $query = new Net::DNS::Packet( ... );
    $reply = $resolver->send( $packet );

=head1 DESCRIPTION

Instances of the C<Net::DNS::Resolver> class represent resolver objects.
A program can have multiple resolver objects, each maintaining its
own state information such as the nameservers to be queried, whether
recursion is desired, etc.

=head1 METHODS

=head2 new

    # Use the default configuration
    $resolver = new Net::DNS::Resolver();

    # Use my own configuration file
    $resolver = new Net::DNS::Resolver( config_file => '/my/dns.conf' );

    # Set options in the constructor
    $resolver = new Net::DNS::Resolver(
	nameservers => [ '10.1.1.128', '10.1.2.128' ],
	recurse	    => 0,
	debug	    => 1
	);

Returns a resolver object.  If no arguments are supplied, new()
returns an object having the default configuration.

On Unix and Linux systems,
the default values are read from the following files,
in the order indicated:

    /etc/resolv.conf
    $HOME/.resolv.conf
    ./.resolv.conf

The following keywords are recognised in resolver configuration files:

=over 4

=item domain

The default domain.

=item search

A space-separated list of domains to put in the search list.

=item nameserver

A space-separated list of nameservers to query.

=item options

A space-separated list of key:value items.

=back

Except for F</etc/resolv.conf>, files will only be read if owned by the
effective userid running the program.  In addition, several environment
variables may contain configuration information; see L</ENVIRONMENT>.

Note that the domain and searchlist keywords are mutually exclusive.
If both are present, the resulting behaviour is unspecified.

On Windows systems, an attempt is made to determine the system defaults
using the registry.  Systems with many dynamically configured network
interfaces may confuse Net::DNS.


You can include a configuration file of your own when creating a
resolver object:

    # Use my own configuration file
    $resolver = new Net::DNS::Resolver( config_file => '/my/dns.conf' );

This is supported on both Unix and Windows.


If a custom configuration file is specified at first instantiation,
both the system configuration and environment variables are ignored.

Explicit arguments to new() override the corresponding configuration
variables.  The following arguments are supported:

=over 4

=item nameservers

A reference to an array of nameservers to query.

=item domain

Domain name suffix to be appended to queries of unqualified names.

=item searchlist

A reference to an array of domains to search for unqualified names.

=item debug

=item defnames

=item dnsrch

=item dnssec

=item igntc

=item persistent_tcp

=item persistent_udp

=item port

=item recurse

=item retrans

=item retry

=item srcaddr

=item srcport

=item tcp_timeout

=item udp_timeout

=item usevc

=back

For more information on any of these options, please consult the method
of the same name.


=head2 print

    $resolver->print;

Prints the resolver state on the standard output.


=head2 query

    $packet = $resolver->query( 'mailhost' );
    $packet = $resolver->query( 'mailhost.example.com' );
    $packet = $resolver->query( '192.0.2.1' );
    $packet = $resolver->query( 'example.com', 'MX' );
    $packet = $resolver->query( 'annotation.example.com', 'TXT', 'IN' );

Performs a DNS query for the given name; the search list is not
applied.  If the name does not contain any dots and C<defnames>
is true, the default domain will be appended.

The record type and class can be omitted; they default to A and IN.
If the name looks like an IP address (IPv4 or IPv6),
then a query within in-addr.arpa or ip6.arpa will be performed.

Returns a C<Net::DNS::Packet> object, or C<undef> if no answers were found.
The reason for failure may be determined using errorstring().

If you need to examine the response packet, whether it contains
any answers or not, use the send() method instead.


=head2 search

    $packet = $resolver->search( 'mailhost' );
    $packet = $resolver->search( 'mailhost.example.com' );
    $packet = $resolver->search( '192.0.2.1' );
    $packet = $resolver->search( 'example.com', 'MX' );
    $packet = $resolver->search( 'annotation.example.com', 'TXT', 'IN' );

Performs a DNS query for the given name, applying the searchlist if
appropriate.  The search algorithm is as follows:

=over 4

=item 1.

If the name contains at least one dot, try it as is.

=item 2.

If the name does not end in a dot, try appending each item in the
search list to the name.  This is only done if C<dnsrch> is true.

=item 3.

If the name does not contain any dots, try it as is.

=back

The record type and class can be omitted; they default to A and IN.
If the name looks like an IP address (IPv4 or IPv6),
then a query within in-addr.arpa or ip6.arpa will be performed.

Returns a C<Net::DNS::Packet> object, or C<undef> if no answers were found.
The reason for failure may be determined using errorstring().

If you need to examine the response packet, whether it contains
any answers or not, use the send() method instead.


=head2 send

    $packet = $resolver->send( $packet );

    $packet = $resolver->send( 'mailhost.example.com' );
    $packet = $resolver->query( '192.0.2.1' );
    $packet = $resolver->send( 'example.com', 'MX' );
    $packet = $resolver->send( 'annotation.example.com', 'TXT', 'IN' );

Performs a DNS query for the given name.  Neither the searchlist
nor the default domain will be appended.

The argument list can be either a C<Net::DNS::Packet> object or a list
of strings.  The record type and class can be omitted; they default to
A and IN.  If the name looks like an IP address (IPv4 or IPv6),
then a query within in-addr.arpa or ip6.arpa will be performed.

Returns a C<Net::DNS::Packet> object whether there were any answers or not.
Use C<< $packet->header->ancount >> or C<< $packet->answer >> to find out
if there were any records in the answer section.
Returns C<undef> if no response was received.


=head2 axfr

    @zone = $resolver->axfr();
    @zone = $resolver->axfr( 'example.com' );
    @zone = $resolver->axfr( 'example.com', 'IN' );

    $iterator = $resolver->axfr();
    $iterator = $resolver->axfr( 'example.com' );
    $iterator = $resolver->axfr( 'example.com', 'IN' );

    $rr = $iterator->();

Performs a zone transfer using the resolver nameservers list,
attempted in the order listed.

If the zone is omitted, it defaults to the first zone listed
in the resolver search list.

If the class is omitted, it defaults to IN.


When called in list context, axfr() returns a list of C<Net::DNS::RR>
objects.  The redundant SOA record that terminates the zone transfer
is not returned to the caller.

In deferrence to RFC1035(6.3), a complete zone transfer is expected
to return all records in the zone or nothing at all.
When no resource records are returned by axfr(),
the reason for failure may be determined using errorstring().

Here is an example that uses a timeout and TSIG verification:

    $resolver->tcp_timeout( 10 );
    $resolver->tsig( 'Khmac-sha1.example.+161+24053.private' );
    @zone = $resolver->axfr( 'example.com' );

    foreach $rr (@zone) {
	$rr->print;
    }


When called in scalar context, axfr() returns an iterator object.
Each invocation of the iterator returns a single C<Net::DNS::RR>
or C<undef> when the zone is exhausted.

An exception is raised if the zone transfer can not be completed.

The redundant SOA record that terminates the zone transfer is not
returned to the caller.

Here is the example above, implemented using an iterator:

    $resolver->tcp_timeout( 10 );
    $resolver->tsig( 'Khmac-sha1.example.+161+24053.private' );
    $iterator = $resolver->axfr( 'example.com' );

    while ( $rr = $iterator->() ) {
	$rr->print;
    }


=head2 bgsend

    $handle = $resolver->bgsend( $packet ) || die $resolver->errorstring;

    $handle = $resolver->bgsend( 'mailhost.example.com' );
    $handle = $resolver->bgsend( '192.0.2.1' );
    $handle = $resolver->bgsend( 'example.com', 'MX' );
    $handle = $resolver->bgsend( 'annotation.example.com', 'TXT', 'IN' );

Performs a background DNS query for the given name and returns immediately
without waiting for the response. The program can then perform other tasks
while awaiting the response from the nameserver.

The argument list can be either a C<Net::DNS::Packet> object or a list
of strings.  The record type and class can be omitted; they default to
A and IN.  If the name looks like an IP address (IPv4 or IPv6),
then a query within in-addr.arpa or ip6.arpa will be performed.

Returns an opaque handle which is passed to subsequent invocations of
the C<bgbusy> and C<bgread> methods.
Errors are indicated by returning C<undef> in which case
the reason for failure may be determined using errorstring().

The program may determine when the handle is ready for reading by
calling C<bgbusy>.

The response C<Net::DNS::Packet> object is obtained by calling C<bgread>.

B<BEWARE>:
Programs should make no assumptions about the nature of the handles
returned by C<bgsend> which should be used strictly as described here.


=head2 bgread

    $packet = $resolver->bgread($handle);

Reads the answer from a background query.
The argument is the handle returned by C<bgsend>.

Returns a C<Net::DNS::Packet> object or C<undef> if no response was
received or timeout occurred. 


=head2 bgbusy

    $handle = $resolver->bgsend( 'foo.example.com' );

    while ($resolver->bgbusy($handle)) {
	...
    }

    $packet = $resolver->bgread($handle);

Returns true while awaiting the response or for the transaction to time out.
The argument is the handle returned by C<bgsend>.

Truncated UDP packets will be retried over TCP transparently while
continuing to assert busy to the caller.


=head2 bgisready

    until ($resolver->bgisready($handle)) {
	...
    }

C<bgisready> is the logical complement of C<bgbusy> which is retained
for backward compatibility.


=head2 debug

    print 'debug flag: ', $resolver->debug, "\n";
    $resolver->debug(1);

Get or set the debug flag.
If set, calls to C<search>, C<query>, and C<send> will print
debugging information on the standard output.
The default is false.


=head2 defnames

    print 'defnames flag: ', $resolver->defnames, "\n";
    $resolver->defnames(0);

Get or set the defnames flag.
If true, calls to C<query> will append the default domain to names
that contain no dots.
The default is true.


=head2 dnsrch

    print 'dnsrch flag: ', $resolver->dnsrch, "\n";
    $resolver->dnsrch(0);

Get or set the dnsrch flag.
If true, calls to C<search> will apply the search list to resolve
names that are not fully qualified.
The default is true.


=head2 igntc

    print 'igntc flag: ', $resolver->igntc, "\n";
    $resolver->igntc(1);

Get or set the igntc flag.
If true, truncated packets will be ignored.
If false, the query will be retried using TCP.
The default is false.


=head2 nameservers

    @nameservers = $resolver->nameservers();
    $resolver->nameservers( '192.0.2.1', '192.0.2.2', '2001:DB8::3' );

Gets or sets the nameservers to be queried.

Also see the IPv6 transport notes below


=head2 persistent_tcp

    print 'Persistent TCP flag: ', $resolver->persistent_tcp, "\n";
    $resolver->persistent_tcp(1);

Get or set the persistent TCP setting.
If true, Net::DNS will keep a TCP socket open for each host:port
to which it connects.
This is useful if you are using TCP and need to make a lot of queries
or updates to the same nameserver.

The default is false unless you are running a SOCKSified Perl,
in which case the default is true.


=head2 persistent_udp

    print 'Persistent UDP flag: ', $resolver->persistent_udp, "\n";
    $resolver->persistent_udp(1);

Get or set the persistent UDP setting.
If true, a Net::DNS resolver will use the same UDP socket
for all queries within each address family.

This avoids the cost of creating and tearing down UDP sockets,
but also defeats source port randomisation.


=head2 port

    print 'sending queries to port ', $resolver->port, "\n";
    $resolver->port(9732);

Gets or sets the port to which queries are sent.
Convenient for nameserver testing using a non-standard port.
The default is port 53.


=head2 recurse

    print 'recursion flag: ', $resolver->recurse, "\n";
    $resolver->recurse(0);

Get or set the recursion flag.
If true, this will direct nameservers to perform a recursive query.
The default is true.


=head2 retrans

    print 'retrans interval: ', $resolver->retrans, "\n";
    $resolver->retrans(3);

Get or set the retransmission interval
The default is 5 seconds.


=head2 retry

    print 'number of tries: ', $resolver->retry, "\n";
    $resolver->retry(2);

Get or set the number of times to try the query.
The default is 4.


=head2 searchlist

    @searchlist = $resolver->searchlist;
    $resolver->searchlist( 'a.example', 'b.example', 'c.example' );

Gets or sets the resolver search list.


=head2 srcaddr

    $resolver->srcaddr('192.0.2.1');

Sets the source address from which queries are sent.
Convenient for forcing queries from a specific interface on a
multi-homed host.  The default is to use any local address.


=head2 srcport

    $resolver->srcport(5353);

Sets the port from which queries are sent.
The default is 0, meaning any port.


=head2 tcp_timeout

    print 'TCP timeout: ', $resolver->tcp_timeout, "\n";
    $resolver->tcp_timeout(10);

Get or set the TCP timeout in seconds.
The default is 120 seconds (2 minutes).
A timeout of C<undef> means indefinite.


=head2 udp_timeout

    print 'UDP timeout: ', $resolver->udp_timeout, "\n";
    $resolver->udp_timeout(10);

Get or set the UDP timeout in seconds.
The default is C<undef>, which means that the retry and retrans
settings will be used to perform the retries until they exhausted.


=head2 udppacketsize

    print "udppacketsize: ", $resolver->udppacketsize, "\n";
    $resolver->udppacketsize(2048);

udppacketsize will set or get the packet size. If set to a value
greater than the default DNS packet size, an EDNS extension will be
added indicating support for UDP fragment reassembly.


=head2 usevc

    print 'usevc flag: ', $resolver->usevc, "\n";
    $resolver->usevc(1);

Get or set the usevc flag.
If true, queries will be performed using virtual circuits (TCP)
instead of datagrams (UDP).
The default is false.


=head2 answerfrom

    print 'last answer was from: ', $resolver->answerfrom, "\n";

Returns the IP address from which the most recent packet was
received in response to a query.


=head2 answersize

    print 'size of last answer: ', $resolver->answersize, "\n";

Returns the size in bytes of the most recent packet received in
response to a query.


=head2 errorstring

    print 'query status: ', $resolver->errorstring, "\n";

Returns a string containing error information from the most recent method call.
errorstring() is meaningful only when interrogated immediately after an error.


=head2 dnssec

    print "dnssec flag: ", $resolver->dnssec, "\n";
    $resolver->dnssec(0);

The dnssec flag causes the resolver to transmit DNSSEC queries
and to add a EDNS0 record as required by RFC2671 and RFC3225.
The actions of, and response from, the remote nameserver is
determined by the settings of the AD and CD flags.

Calling the dnssec() method with a non-zero value will also set the
UDP packet size to the default value of 2048. If that is too small or
too big for your environment, you should call the udppacketsize()
method immediately after.

   $resolver->dnssec(1);		# DNSSEC using default packetsize
   $resolver->udppacketsize(1250);	# lower the UDP packet size

A fatal exception will be raised if the dnssec() method is called
but the Net::DNS::SEC library has not been installed.


=head2 adflag

    $resolver->dnssec(1);
    $resolver->adflag(1);
    print "authentication desired flag: ", $resolver->adflag, "\n";

Gets or sets the AD bit for dnssec queries.  This bit indicates that
the caller is interested in the returned AD (authentic data) bit but
does not require any dnssec RRs to be included in the response.
The default value is 0.


=head2 cdflag

    $resolver->dnssec(1);
    $resolver->cdflag(1);
    print "checking disabled flag: ", $resolver->cdflag, "\n";

Gets or sets the CD bit for dnssec queries.  This bit indicates that
authentication by upstream nameservers should be suppressed.
Any dnssec RRs required to execute the authentication procedure
should be included in the response.
The default value is 0.


=head2 tsig

    $resolver->tsig( $tsig );

    $resolver->tsig( 'Khmac-sha1.example.+161+24053.private' );

    $resolver->tsig( 'Khmac-sha1.example.+161+24053.key' );

    $resolver->tsig( 'Khmac-sha1.example.+161+24053.key',
		fudge => 60
		);

    $resolver->tsig( $key_name, $key );

    $resolver->tsig( undef );

Set the TSIG record used to automatically sign outgoing queries, zone
transfers and updates. Automatic signing is disabled if called with
undefined arguments.

The default resolver behaviour is not to sign any packets.  You must
call this method to set the key if you would like the resolver to
sign and verify packets automatically.

Packets can also be signed manually; see the L<Net::DNS::Packet>
and L<Net::DNS::Update> manual pages for examples.  TSIG records
in manually-signed packets take precedence over those that the
resolver would add automatically.


=head1 ENVIRONMENT

The following environment variables can also be used to configure
the resolver:

=head2 RES_NAMESERVERS

    # Bourne Shell
    RES_NAMESERVERS="192.0.2.1 192.0.2.2 2001:DB8::3"
    export RES_NAMESERVERS

    # C Shell
    setenv RES_NAMESERVERS "192.0.2.1 192.0.2.2 2001:DB8::3"

A space-separated list of nameservers to query.

=head2 RES_SEARCHLIST

    # Bourne Shell
    RES_SEARCHLIST="a.example.com b.example.com c.example.com"
    export RES_SEARCHLIST

    # C Shell
    setenv RES_SEARCHLIST "a.example.com b.example.com c.example.com"

A space-separated list of domains to put in the search list.

=head2 LOCALDOMAIN

    # Bourne Shell
    LOCALDOMAIN=example.com
    export LOCALDOMAIN

    # C Shell
    setenv LOCALDOMAIN example.com

The default domain.

=head2 RES_OPTIONS

    # Bourne Shell
    RES_OPTIONS="retrans:3 retry:2 inet6"
    export RES_OPTIONS

    # C Shell
    setenv RES_OPTIONS "retrans:3 retry:2 inet6"

A space-separated list of resolver options to set.  Options that
take values are specified as C<option:value>.


=head1 IPv6 TRANSPORT

The Net::DNS::Resolver library will enable IPv6 transport if the
appropriate libraries (IO::Socket::IP or IO::Socket::INET6) are
available and the destination nameserver has an IPv6 address.

The force_v4(), force_v6(), prefer_v4 and prefer_v6() methods with a
non-zero argument may be used to configure transport selection.

The behaviour of the nameserver() method illustrates the transport
selection mechanism.  If, for example, IPv6 is not available or IPv4
transport has been forced, the nameserver() method will only return
IPv4 addresses:

    $resolver->nameservers( '192.0.2.1', '192.0.2.2', '2001:DB8::3' );
    $resolver->force_v4(1);
    print join ' ', $resolver->nameservers();

will print

    192.0.2.1 192.0.2.2


=head1 CUSTOMISED RESOLVERS

Net::DNS::Resolver is actually an empty subclass.  At compile time a
super class is chosen based on the current platform.  A side benefit of
this allows for easy modification of the methods in Net::DNS::Resolver.
You can simply add a method to the namespace!

For example, if we wanted to cache lookups:

    package Net::DNS::Resolver;

    my %cache;

    sub search {
	$self = shift;

	$cache{"@_"} ||= $self->SUPER::search(@_);
    }


=head1 COPYRIGHT

Copyright (c)1997-2000 Michael Fuhr.

Portions Copyright (c)2002-2004 Chris Reinhardt.

Portions Copyright (c)2005 Olaf M. Kolkman, NLnet Labs.

Portions Copyright (c)2014,2015 Dick Franks.

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

L<perl>, L<Net::DNS>, L<Net::DNS::Packet>, L<Net::DNS::Update>,
L<Net::DNS::Header>, L<Net::DNS::Question>, L<Net::DNS::RR>,
L<resolver(5)>, RFC 1034, RFC 1035

=cut


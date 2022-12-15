package Net::DNS::Resolver::MSWin32;

#
# $Id: MSWin32.pm 1527 2017-01-18 21:42:48Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1527 $)[1];


=head1 NAME

Net::DNS::Resolver::MSWin32 - MS Windows resolver class

=cut


use strict;
use warnings;
use base qw(Net::DNS::Resolver::Base);

use Carp;

use constant WINHLP => defined eval 'require Win32::IPHelper';
use constant WINREG => defined eval 'require Win32::TieRegistry';


our $Registry;

Win32::TieRegistry->import(qw(KEY_READ REG_DWORD)) if WINREG;


sub _untaint {
	map { m/^(.*)$/; $1 } grep defined, @_;
}


sub _init {
	my $defaults = shift->_defaults;

	my $debug = 0;

	my $FIXED_INFO = {};

	if ( my $ret = Win32::IPHelper::GetNetworkParams($FIXED_INFO) ) {
		Carp::croak "GetNetworkParams() error %u: %s\n", $ret, Win32::FormatMessage($ret);
	} elsif ($debug) {
		require Data::Dumper;
		print Data::Dumper::Dumper $FIXED_INFO;
	}


	my @nameservers = map { $_->{IpAddress} } @{$FIXED_INFO->{DnsServersList}};
	$defaults->nameservers( _untaint @nameservers );

	my $devolution = 0;
	my $domainname = $FIXED_INFO->{DomainName} || '';
	my @searchlist = map length, lc $domainname;

	if (WINREG) {

		# The Win32::IPHelper does not return searchlist.
		# Make best effort attempt to get searchlist from the registry.

		my @root = qw(HKEY_LOCAL_MACHINE SYSTEM CurrentControlSet Services);

		my $leaf = join '\\', @root, qw(Tcpip Parameters);
		my $reg_tcpip = $Registry->Open( $leaf, {Access => KEY_READ} );

		unless ( defined $reg_tcpip ) {			# Didn't work, Win95/98/Me?
			$leaf = join '\\', @root, qw(VxD MSTCP);
			$reg_tcpip = $Registry->Open( $leaf, {Access => KEY_READ} );
		}

		if ( defined $reg_tcpip ) {
			my $searchlist = $reg_tcpip->GetValue('SearchList') || '';
			push @searchlist, split m/[\s,]+/, lc $searchlist;

			my ( $value, $type ) = $reg_tcpip->GetValue('UseDomainNameDevolution');
			$devolution = defined $value && $type == REG_DWORD ? hex $value : 0;
		}
	}


	# fix devolution if configured, and simultaneously
	# make sure no dups (but keep the order)
	my @list;
	my %seen;
	foreach my $entry (@searchlist) {
		push( @list, $entry ) unless $seen{$entry}++;

		next unless $devolution;

		# as long there are more than two pieces, cut
		while ( $entry =~ m#\..+\.# ) {
			$entry =~ s#^[^\.]+\.(.+)$#$1#;
			push( @list, $entry ) unless $seen{$entry}++;
		}
	}
	$defaults->searchlist( _untaint @list );

	$defaults->_read_env;
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS::Resolver;

=head1 DESCRIPTION

This class implements the OS specific portions of C<Net::DNS::Resolver>.

No user serviceable parts inside, see L<Net::DNS::Resolver>
for all your resolving needs.

=head1 COPYRIGHT

Copyright (c)2003 Chris Reinhardt.

Portions Copyright (c)2009 Olaf Kolkman, NLnet Labs

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

L<perl>, L<Net::DNS>, L<Net::DNS::Resolver>

=cut


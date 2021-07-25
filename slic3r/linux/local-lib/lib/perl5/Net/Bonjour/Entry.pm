package Net::Bonjour::Entry;

=head1 NAME

Net::Bonjour::Entry - Support module for mDNS service discovery (Apple's Bonjour)

=head1 SYNOPSIS

use Net::Bonjour;
	
my $res = Net::Bonjour->new(<service>[, <protocol>]);
$res->discover;
	
foreach my $entry ( $res->entries ) {
	print $entry->name, "\n";
}
	
=head1 DESCRIPTION

Net::Bonjour::Entry is a module used to manage entries returned by a mDNS
service discovery (Apple's Bonjour).  See L<Net::Bonjour> for more information.

=head1 METHODS

=head2 new([<fqdn>])

Creates a new Net::Bonjour::Entry object. The optional argument defines the
fully qualifed domain name (FQDN) of the entry.  Normal usage of the
L<Net::Bonjour> module will not require the construction of
Net::Bonjour::Entry objects, as they are automatically created during the
discovery process.

=head2 address

Returns the IP address of the entry. 

=head2 all_attrs

Returns all the current attributes in the form of hashed array.

=head2 attribute(<attribute>)

Returns the specified attribute from the TXT record of the entry.  TXT records
are used to specify additional information, e.g. path for http.

=head2 dnsrr([<record type>])

Returns an DNS answer packet of the entry.  The output will be in the format
of a L<Net::DNS::Packet> object.  The I<record type> designates the resource
record to answer with, i.e. PTR, SRV, or TXT.  The default is PTR.

=head2 fetch

Reloads the information for the entry via mDNS.

=head2 fqdn

Returns the fully qualifed domain name (FQDN) of entry.  An example FQDN is server._afpovertcp._tcp.local

=head2 hostname

Returns the hostname of the server, e.g. 'server.local'. 

=head2 name

Returns the name of the entry.  In the case of the fqdn example, the name
would be 'server'.  This name may not be the hostname of the server.  For
example, names for presence/tcp will be the name of the user and http/tcp will
be title of the web resource.

=head2 port

Returns the TCP or UDP port of the entry.

=head2 sockaddr

Returns the binary socket address for the resource and can be used directly to bind() sockets.

=head1 EXAMPLES

=head2 Print out a list of local websites

	print "<HTML><TITLE>Local Websites</TITLE>";
	
	use Net::Bonjour;

	my $res = Net::Bonjour->new('http');
	$res->discover;

	foreach my $entry ( $res->entries) {
		printf "<A HREF='http://%s%s'>%s</A><BR>", 
			$entry->address, $entry->attribute('path'), 
			$entry->name; 
	}
	
	print "</HTML>";
	
=head2 Find a service and connect to it

	use Net::Bonjour;
	
	my $res = Net::Bonjour->new('custom');
	$res->discover;
	
	my $entry = $res->shift_entry;
	
	socket SOCK, PF_INET, SOCK_STREAM, scalar(getprotobyname('tcp'));
	
	connect SOCK, $entry->sockaddr;
	
	print SOCK "Send a message to the service";
	
	while ($line = <SOCK>) { print $line; }
	
	close SOCK;	
	
=head1 SEE ALSO

L<Net::Bonjour>

=head1 COPYRIGHT

This library is free software and can be distributed or modified under the same terms as Perl itself.

Bonjour (in this context) is a trademark of Apple Computer, Inc.

=head1 AUTHORS

The Net::Bonjour::Entry module was created by George Chlipala <george@walnutcs.com>

=cut

use strict;
use vars qw($AUTOLOAD);
use Socket;
use Net::DNS;

sub new {
	my $self = {};
	bless $self, shift;
	$self->_init(@_);
	return $self;
}

sub _init {
	my $self = shift;
	$self->{'_dns_server'} = [ '224.0.0.251' ];
	$self->{'_dns_port'} = '5353';
	$self->{'_ip_type'} = 'A';
	$self->{'_index'} = 0;
	$self->{'_ttl'} = 3600;
	if ( ref($_[0]) eq 'HASH') {
		my $attrs = shift;
		foreach my $k ( keys(%{$attrs}) ) {
			$self->{'_' . $k} = $attrs->{$k};
		}
		$self->all_attrs if ref( $attrs->{'attr'} ) eq 'HASH';
	} elsif ( $#_ == 0 ) {
		$self->fqdn(shift);
	}
	return;
}

sub fetch {
	my $self = shift;

	my $res = Net::DNS::Resolver->new(
		nameservers => $self->{'_dns_server'},
		port => $self->{'_dns_port'}
	);

	my ($name, $protocol, $ipType) = split(/(?<!\\)\./, $self->fqdn,3);

	$self->{'_name'} = $name;
	$self->type($protocol, $ipType);

	my $srv   = $res->query($self->fqdn(), 'SRV') || return;
	my $srvrr = ($srv->answer)[0];

	$self->priority($srvrr->priority);
	$self->weight($srvrr->weight);
	$self->port($srvrr->port);
	$self->hostname($srvrr->target); 

	if ($srv->additional) {
		foreach my $additional ($srv->additional) {
			$self->{'_' . uc($additional->type)} = $additional->address;
		}
	} else {
		my $aquery = $res->query($srvrr->target, 'A');
		my $arr = ($aquery->answer)[0];
		if ( $arr->type eq 'A' ) {
			 $self->{'_' . uc($arr->type)} = $arr->address;
		}
	}

	my $txt = $res->query($self->fqdn, 'TXT');

	# Text::Parsewords, which is called by Net::DNS::RR::TXT can spew
	if ( $txt ) {
		local $^W = 0;
		my $txti = 0;

		foreach my $txtrr ( $txt->answer ) {
			$self->txtdata([$txtrr->char_str_list ]);
			$self->index($txti++);
			foreach my $txtln ( $txtrr->char_str_list ) {
				my ($key,$val) = split(/=/,$txtln,2);
				$self->attribute($key, $val);
			}
			$txti++;
		}
	}

	$self->text($txt);

	return;
}

sub all_attrs {
	my $self = shift;
	my $index = $self->index;;
	if ( @_ ) {
		my $hash = shift;
		$index = (shift || 0);
		$self->{'_attr'}[$index] = { %{$hash} };
	}
	my @txts;
	foreach ( keys(%{$self->{'_attr'}[$index]}) ) {
		push(@txts, sprintf('%s=%s', $_, $self->{'_attr'}[$index]{$_}));
	}
	$self->txtdata( \@txts );
	return %{$self->{'_attr'}[$index]};
}

sub attribute {
	my $self = shift;
	my $key = shift;
	my $index = $self->index;
	if ( @_ ) {
		$self->{'_attr'}[$index]{$key} = shift;
	}
	return $self->{'_attr'}[$index]{$key};
}

sub type {
	my $self = shift;
	if ( @_ ) {
		my $type = sprintf '%s/%s', shift, shift;
		$type =~ s/_//g;
		$self->{'_type'} = $type;
	}
	return $self->{'_type'};
}

sub address {
	my $self = shift;
	my $key = '_' . $self->{'_ip_type'};
	if ( @_ ) {
		$self->{$key} = shift;
	}
	return $self->{$key};
}
	
sub sockaddr {
	my $self = shift;
	return sockaddr_in($self->port, inet_aton($self->address));
}

sub dnsrr {
	my $self = shift;
	my $type = uc(shift);

	my $packet;

	my $srv = Net::DNS::RR->new(
		'type' => 'SRV',
		'ttl' => $self->ttl,
		'name' => $self->fqdn,
		'port' => $self->port,
		'priority' => ( $self->priority || 0 ),
		'weight' => ( $self->weight || 0 ), 
		'target' => $self->hostname
	);

	my $txt = Net::DNS::RR->new(
		'type' => 'TXT',
		'ttl' => $self->ttl,
		'name' => $self->fqdn,
		'char_str_list' => $self->txtdata
	);

	if ($type eq 'SRV') {

		$packet = Net::DNS::Packet->new($self->fqdn, 'SRV', 'IN');
		$packet->push('answer', $srv);	

	} elsif ($type eq 'TXT') {

		$packet = Net::DNS::Packet->new($self->fqdn, 'TXT', 'IN');
		$packet->push('answer', $txt);	

	} else {

		my $app = (split(/\./, $self->fqdn,2))[1];

		$packet = Net::DNS::Packet->new($app, 'PTR', 'IN');

		$packet->push('answer', Net::DNS::RR->new(
			'type' => 'PTR',
			'ttl' => $self->ttl,
			'ptrdname' => $self->fqdn,
			'name' => $app
		));

		$packet->push('additional', $srv, $txt);	
	}
		
	$packet->header->qr(1);
	$packet->header->aa(1);
	$packet->header->rd(0);

	my @addrs = ();

	foreach my $type (qw(A AAAA)) {

		my $rr = Net::DNS::RR->new(
			'type'    => $type,
			'ttl' 	  => $self->ttl,
			'address' => $self->{'_' . $type},
			'name'    => $self->hostname
		);

		push(@addrs, $rr) if $self->{'_' . $type};
	}

	$packet->push('additional', @addrs);
	return $packet;
}

sub name {
	my $self = shift;
	if ( $_[0] ) {
		$self->{'_name'} = quotemeta($_[0]);
	} 	
	my $name = $self->{'_name'};
	$name =~ s/\\([0-9]{3})/chr($1)/ge;
	$name =~ s/\\x([0-9A-Fa-f]{2})/chr(hex($1))/ge;
	$name =~ s/\\(.)/$1/g;
	return $name;
}

sub txtdata {
	my $self = shift;
	my $index = $self->index;
	if ( ref($_[0]) eq 'ARRAY' ) {
		my $list = shift;
		$self->{'_txtdata'}[$index] = [ @{$list} ];
	}
	return $self->{'_txtdata'}[$index];
}

sub AUTOLOAD {
	my $self = shift;
	my $key = $AUTOLOAD;
	$key =~ s/^.*:://;
	$key = '_' . $key;
	if ( @_ ) {
		$self->{$key} = shift;
	}
	return $self->{$key};
}

1;

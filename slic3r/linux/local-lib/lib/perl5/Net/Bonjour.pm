package Net::Bonjour;

=head1 NAME

Net::Bonjour - Module for DNS service discovery (Apple's Bonjour)

=head1 SYNOPSIS 

	use Net::Bonjour;
	
	my $res = Net::Bonjour->new(<service>[, <protocol>]);

	$res->discover;

	foreach my $entry ( $res->entries ) {
		printf "%s %s:%s\n", $entry->name, $entry->address, $entry->port;
	}

Or the cyclical way:

	use Net::Bonjour;

	my $res = Net::Bonjour->new(<service>[, <protocol>]);
               
	$res->discover;

	while ( 1 ) {
	   foreach my $entry ( $res->entries ) {
		   print $entry->name, "\n";
	   }
	   $res->discover;
   	}

=head1 DESCRIPTION

Net::Bonjour is a set of modules that allow one to discover local services via multicast DNS (mDNS) 
or enterprise services via traditional DNS.  This method of service discovery has been branded as 
Bonjour by Apple Computer.

=head2 Base Object

The base object would be of the Net::Bonjour class.  This object contains the resolver for DNS service discovery.

=head2 Entry Object

The base object (Net::Bonjour) will return entry objects of the class L<Net::Bonjour::Entry>.

=head1 METHODS

=head2 new([<service>, <protocol>, <domain>])

Creates a new Net::Bonjour discovery object.  First argument specifies the service to discover, 
e.g.  http, ftp, afpovertcp, and ssh.  The second argument specifies the protocol, i.e. tcp or udp.  
I<The default protocol is TCP>. The third argument specifies the discovery domain, the default is 'local'. 

If no arguments are specified, the resulting Net::Bonjour object will be empty and will not perform an 
automatic discovery upon creation.

=head2 all_services([<domain>])

Returns an array of new Net::Renedezvous objects for each service type advertised in the domain. The argument 
specifies the discovery domain, the default is 'local'.  Please note that the resulting Net::Bonjour objects 
will not have performed a discovery during the creation.  Therefore, the discovery process will need to be run
prior to retriving a list of entries for that Net::Bonjour object.

=head2 domain([<domain>])

Get/sets current discovery domain.  By default, the discovery domain is 'local'.  Discovery for the 'local'
domain is done via MDNS while all other domains will be done via traditional DNS.

=head2 discover

Repeats the discovery process and reloads the entry list from this discovery.

=head2 entries

Returns an array of L<Net::Renedezvous::Entry> objects for the last discovery.

=head2 protocol([<protocol>]) 

Get/sets current protocol of the service type, i.e. TCP or UDP.  Please note that this is not the protocol for 
DNS connection.

=head2 service([<service type>])

Get/sets current service type.

=head2 shift_entry

Shifts off the first entry of the last discovery.  The returned object will be a L<Net::Bonjour::Entry> object.

=head1 EXAMPLES 

=head2 Print out a list of local websites

        print "<HTML><TITLE>Local Websites</TITLE>";
        
        use Net::Bonjour;

        my $res = Net::Bonjour->new('http');
	$res->discover;

        foreach my $entry ( $res->entries) {
                printf "<A HREF='http://%s%s'>%s</A><BR>", $entry->address, 
                        $entry->attribute('path'), $entry->name; 
        }
        
        print "</HTML>";

=head2 Find a service and connect to it

        use Socket;
	use Net::Bonjour;
        
        my $res = Net::Bonjour->new('custom');
	$res->discover;
        
        my $entry = $res->shift_entry;
        
        socket SOCK, PF_INET, SOCK_STREAM, scalar(getprotobyname('tcp'));
        
        connect SOCK, $entry->sockaddr;
        
        print SOCK "Send a message to the service";
        
        while ($line = <SOCK>) { print $line; }
        
        close SOCK;     

=head2 Find all service types and print.

	use Net::Bonjour;

	foreach my $res ( Net::Bonjour->all_services ) {
		printf "%s (%s)\n", $res->service, $res->protocol;
	}

=head2 Find and print all service types and entries.

	use Net::Bonjour;

	foreach my $res ( Net::Bonjour->all_services ) {
		printf "-- %s (%s) ---\n", $res->service, $res->protocol;
		$res->discover;
        	foreach my $entry ( $res->entries) {
			printf "\t%s (%s:%s)\n", $entry->name, $entry->address, $entry->port;	
		}
	}

=head1 SEE ALSO

L<Net::Bonjour::Entry>

=head1 COPYRIGHT

This library is free software and can be distributed or modified under the same terms as Perl itself.

Bonjour (in this context) is a trademark of Apple Computer, Inc.

=head1 AUTHORS

The Net::Bonjour module was created by George Chlipala <george@walnutcs.com>

=cut

use strict;
use vars qw($VERSION $AUTOLOAD);

use Net::DNS;
use Net::Bonjour::Entry;
use Socket;

$VERSION = '0.96';

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
	$self->{'_dns_domain'} = 'local';

	if (@_) {
		$self->domain(pop) if $_[$#_] =~ /\./;
		$self->service(@_);
		$self->discover;
	}
	return;
}
	
sub service {
	my $self = shift;

	if (@_) {
		$self->{'_service'} = shift;
		$self->{'_proto'} = shift || 'tcp';
	}
	return $self->{'_service'};
}

sub application {
	my $self = shift;
	return $self->service(@_);
}

sub protocol {
	my $self = shift;
	if (@_) {
		$self->{'_proto'} = shift;
	}
	return $self->{'_proto'};
		
}
	
sub fqdn {
	my $self = shift;
	return sprintf '_%s._%s.%s', $self->{'_service'}, $self->{'_proto'},
		$self->{'_dns_domain'};
}

sub dns_refresh { 
	my $self = shift;
	
	my $resolv = Net::DNS::Resolver->new();
	
	my $query = $resolv->query($self->fqdn, 'PTR');
	return 0 if $query eq '';
	$self->{'_dns_server'} = [$resolv->nameservers];
	$self->{'_dns_port'} = $resolv->port;

	my @list;

	foreach my $rr ($query->answer) {
		next if $rr->type ne 'PTR';
		push(@list, $rr->ptrdname);
	}

	return @list;
}

sub mdns_refresh {
	my $self = shift;

	my $query = Net::DNS::Packet->new($self->fqdn, 'PTR');

	socket DNS, PF_INET, SOCK_DGRAM, scalar(getprotobyname('udp'));
	bind DNS, sockaddr_in(0,inet_aton('0.0.0.0'));
	send DNS, $query->data, 0, sockaddr_in($self->{'_dns_port'}, inet_aton($self->{'_dns_server'}[0]));

	my $rout = '';
	my $rin  = '';
	my %list;

	vec($rin, fileno(DNS), 1) = 1;

	while ( select($rout = $rin, undef, undef, 1.0) ) {
		my $data;
		recv(DNS, $data, 1000, 0);

		my($ans,$err) = Net::DNS::Packet->new(\$data, $self->{'_debug'});
		next if $query->header->id != $ans->header->id;

		foreach my $rr ($ans->answer) {
			next if $rr->type ne 'PTR';
			$list{$rr->ptrdname} = 1;
		}
	}

	return keys(%list);

}

sub entries {
	my $self = shift;	
	return @{$self->{'_results'}};
}

sub shift_entry {
	my $self = shift;
	return shift(@{$self->{'_results'}});
}

sub domain {
	my $self = shift;
	
	if ( @_ ) {
		$self->{'_dns_domain'} = shift;
		$self->{'_dns_domain'} =~ s/(^\.|\.$)//;
	}
	return $self->{'_dns_domain'};
}

sub refresh { 
	my $self = shift;
	return $self->discover(@_);
}

sub discover {
	my $self = shift;

	my @list;
	my $ptrs = [];

	if ( $self->domain(@_) eq 'local' ) {
		@list = $self->mdns_refresh;
	} else {
		@list = $self->dns_refresh;
	}

	foreach my $x ( 0..$#list ) {
		my $host = Net::Bonjour::Entry->new($list[$x]);
		$host->dns_server($self->{'_dns_server'});
		$host->dns_port($self->{'_dns_port'});
		$host->fetch;
		$list[$x] = $host;
	}

	$self->{'_results'} = [ @list ];
	return scalar(@list);
}

sub all_services {
	my $self = {};
	bless $self, shift;
	$self->_init;
	$self->service('services._dns-sd', 'udp');	
	
	my @list;
	if ( $self->domain(@_) eq 'local' ) {
		@list = $self->mdns_refresh;
	} else {
		@list = $self->dns_refresh;
	}

	foreach my $i ( 0..$#list ) {
		next unless $list[$i] =~ /^_(.+)\._(\w+)/;
		my $srvc = Net::Bonjour->new();
		$srvc->service($1, $2);
		$srvc->domain($self->domain);
		$list[$i] = $srvc;
	}
	return @list;
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

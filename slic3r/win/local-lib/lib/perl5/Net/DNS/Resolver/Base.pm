package Net::DNS::Resolver::Base;

#
# $Id: Base.pm 1545 2017-03-06 09:27:11Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1545 $)[1];


#
#  Implementation notes wrt IPv6 support when using perl before 5.20.0.
#
#  In general we try to be gracious to those stacks that do not have IPv6 support.
#  We test that by means of the availability of IO::Socket::INET6 or IO::Socket::IP
#
#  We have chosen not to use mapped IPv4 addresses, there seem to be issues
#  with this; as a result we use separate sockets for each family type.
#
#  inet_pton is not available on WIN32, so we only use the getaddrinfo
#  call to translate IP addresses to socketaddress.
#
#  The configuration options force_v4, force_v6, prefer_v4 and prefer_v6
#  are provided to control IPv6 behaviour for test purposes.
#
# Olaf Kolkman, RIPE NCC, December 2003.
# [Revised March 2016]


use constant USE_SOCKET_IP => defined eval 'use Socket 1.98; use IO::Socket::IP 0.32; 1;';

use constant USE_SOCKET_INET => defined eval 'require IO::Socket::INET';

use constant USE_SOCKET_INET6 => defined eval 'require IO::Socket::INET6';

use constant IPv4 => USE_SOCKET_IP || USE_SOCKET_INET;
use constant IPv6 => USE_SOCKET_IP || USE_SOCKET_INET6;


# If SOCKSified Perl, use TCP instead of UDP and keep the socket open.
use constant SOCKS => scalar eval 'require Config; $Config::Config{usesocks}';


# Allow taint tests to be optimised away when appropriate.
use constant UTIL  => defined eval 'require Scalar::Util';
use constant UNCND => $] < 5.008;	## eval '${^TAINT}' breaks old compilers
use constant TAINT => UTIL && ( UNCND || eval '${^TAINT}' );


use strict;
use warnings;
use integer;
use Carp;
use IO::Select;
use IO::Socket;

use Net::DNS::RR;
use Net::DNS::Packet;

use constant PACKETSZ => 512;


#
# Set up a closure to be our class data.
#
{
	my $defaults = bless {
		nameserver4	=> ['127.0.0.1'],
		nameserver6	=> ['::1'],
		port		=> 53,
		srcaddr4	=> '0.0.0.0',
		srcaddr6	=> '::',
		srcport		=> 0,
		searchlist	=> [],
		retrans		=> 5,
		retry		=> 4,
		usevc		=> ( SOCKS ? 1 : 0 ),
		igntc		=> 0,
		recurse		=> 1,
		defnames	=> 1,
		dnsrch		=> 1,
		debug		=> 0,
		tcp_timeout	=> 120,
		udp_timeout	=> 30,
		persistent_tcp	=> ( SOCKS ? 1 : 0 ),
		persistent_udp	=> 0,
		dnssec		=> 0,
		adflag		=> 0,	# see RFC6840, 5.7
		cdflag		=> 0,	# see RFC6840, 5.9
		udppacketsize	=> 0,	# value bounded below by PACKETSZ
		force_v4	=> ( IPv6 ? 0 : 1 ),
		force_v6	=> 0,	# only relevant if IPv6 is supported
		prefer_v4	=> ( IPv6 ? 1 : 0 ),
		},
			__PACKAGE__;


	sub _defaults { return $defaults; }
}


# These are the attributes that the user may specify in the new() constructor.
my %public_attr = (
	map( {$_ => $_} keys %{&_defaults}, qw(domain nameserver nameservers prefer_v6 srcaddr) ),
	map( {$_ => 0} qw(nameserver4 nameserver6 srcaddr4 srcaddr6) ),
	);


my $initial;

sub new {
	my ( $class, %args ) = @_;

	my $self;
	my $base = $class->_defaults;
	my $init = $initial;
	$initial ||= bless {%$base}, $class;
	if ( my $file = $args{config_file} ) {
		$self = bless {%$initial}, $class;
		$self->_read_config_file($file);		# user specified config
		$self->nameserver( map { m/^(.*)$/; $1 } $self->nameserver );
		$self->searchlist( map { m/^(.*)$/; $1 } $self->searchlist );
		%$base = %$self unless $init;			# define default configuration

	} elsif ($init) {
		$self = bless {%$base}, $class;

	} else {
		$class->_init();				# define default configuration
		$self = bless {%$base}, $class;
	}

	while ( my ( $attr, $value ) = each %args ) {
		next unless $public_attr{$attr};
		my $ref = ref($value);
		croak "usage: $class->new( $attr => [...] )"
				if $ref && ( $ref ne 'ARRAY' );
		$self->$attr( $ref ? @$value : $value );
	}

	return $self;
}


my %resolv_conf = (			## map traditional resolv.conf option names
	attempts => 'retry',
	inet6	 => 'prefer_v6',
	timeout	 => 'retrans',
	);

my %env_option = (			## any resolver attribute except as listed below
	%public_attr,
	%resolv_conf,
	map { $_ => 0 } qw(nameserver nameservers domain searchlist),
	);

sub _read_env {				## read resolver config environment variables
	my $self = shift;

	$self->nameservers( map split, $ENV{RES_NAMESERVERS} ) if exists $ENV{RES_NAMESERVERS};

	$self->domain( $ENV{LOCALDOMAIN} ) if exists $ENV{LOCALDOMAIN};

	$self->searchlist( map split, $ENV{RES_SEARCHLIST} ) if exists $ENV{RES_SEARCHLIST};

	if ( exists $ENV{RES_OPTIONS} ) {
		foreach ( map split, $ENV{RES_OPTIONS} ) {
			my ( $name, $val ) = split( m/:/, $_, 2 );
			my $attribute = $env_option{$name} || next;
			$val = 1 unless defined $val;
			$self->$attribute($val);
		}
	}
}


sub _read_config_file {			## read resolver config file
	my $self = shift;
	my $file = shift;

	my @ns;

	local *FILE;

	open( FILE, $file ) or croak "Could not open $file: $!";

	local $_;
	while (<FILE>) {
		s/[;#].*$//;					# strip comments

		/^nameserver/ && do {
			my ( $keyword, @ip ) = grep defined, split;
			push @ns, @ip;
			next;
		};

		/^option/ && do {
			my ( $keyword, @option ) = grep defined, split;
			foreach (@option) {
				my ( $name, $val ) = split( m/:/, $_, 2 );
				my $attribute = $resolv_conf{$name} || next;
				$val = 1 unless defined $val;
				$self->$attribute($val);
			}
			next;
		};

		/^domain/ && do {
			my ( $keyword, $domain ) = grep defined, split;
			$self->domain($domain);
			next;
		};

		/^search/ && do {
			my ( $keyword, @searchlist ) = grep defined, split;
			$self->searchlist(@searchlist);
			next;
		};
	}

	close(FILE);

	$self->nameservers(@ns);
}


sub string {
	my $self = shift;
	$self = $self->_defaults unless ref($self);

	my @nslist = $self->nameservers();
	my $domain = $self->domain;
	return <<END;
;; RESOLVER state:
;; domain	= $domain
;; searchlist	= @{$self->{searchlist}}
;; nameservers	= @nslist
;; defnames	= $self->{defnames}	dnsrch		= $self->{dnsrch}
;; retrans	= $self->{retrans}	retry		= $self->{retry}
;; recurse	= $self->{recurse}	igntc		= $self->{igntc}
;; usevc	= $self->{usevc}	port		= $self->{port}
;; tcp_timeout	= $self->{tcp_timeout}	persistent_tcp	= $self->{persistent_tcp}
;; udp_timeout	= $self->{udp_timeout}	persistent_udp	= $self->{persistent_udp}
;; prefer_v4	= $self->{prefer_v4}	force_v4	= $self->{force_v4}
;; debug	= $self->{debug}	force_v6	= $self->{force_v6}
END

}


sub print { print &string; }


sub domain {
	my $self   = shift;
	my ($head) = $self->searchlist(@_);
	my @list   = grep defined, $head;
	wantarray ? @list : "@list";
}

sub searchlist {
	my $self = shift;
	$self = $self->_defaults unless ref($self);

	return $self->{searchlist} = [@_] unless defined wantarray;
	$self->{searchlist} = [@_] if scalar @_;
	my @searchlist = @{$self->{searchlist}};
}


sub nameservers {
	my $self = shift;
	$self = $self->_defaults unless ref($self);

	my ( @ipv4, @ipv6 );
	foreach my $ns ( grep defined, @_ ) {
		do { push @ipv6, $ns; next } if _ipv6($ns);
		do { push @ipv4, $ns; next } if _ipv4($ns);

		my $defres = ref($self)->new( debug => $self->{debug} );
		$defres->{persistent} = $self->{persistent};

		my $names  = {};
		my $packet = $defres->search( $ns, 'A' );
		my @iplist = _cname_addr( $packet, $names );

		if (IPv6) {
			$packet = $defres->search( $ns, 'AAAA' );
			push @iplist, _cname_addr( $packet, $names );
		}

		$self->errorstring( $defres->errorstring );

		my %address = map { ( $_ => $_ ) } @iplist;	# tainted
		my @unique = values %address;
		carp "unresolvable name: $ns" unless @unique;
		push @ipv4, grep _ipv4($_), @unique;
		push @ipv6, grep _ipv6($_), @unique;
	}

	unless ( defined wantarray ) {
		$self->{nameserver4} = \@ipv4;
		$self->{nameserver6} = \@ipv6;
		return;
	}

	if ( scalar @_ ) {
		$self->{nameserver4} = \@ipv4;
		$self->{nameserver6} = \@ipv6;
	}

	my @ns4 = $self->force_v6 ? () : @{$self->{nameserver4}};
	my @ns6 = $self->force_v4 ? () : @{$self->{nameserver6}};
	my @returnval = $self->{prefer_v4} ? ( @ns4, @ns6 ) : ( @ns6, @ns4 );

	return @returnval if scalar @returnval;

	my $error = 'no nameservers';
	$error = 'IPv4 transport disabled' if scalar(@ns4) < scalar @{$self->{nameserver4}};
	$error = 'IPv6 transport disabled' if scalar(@ns6) < scalar @{$self->{nameserver6}};
	$self->errorstring($error);
	return @returnval;
}

sub nameserver { &nameservers; }				# uncoverable pod

sub _cname_addr {

	# TODO 20081217
	# This code does not follow CNAME chains, it only looks inside the packet.
	# Out of bailiwick will fail.
	my @null;
	my $packet = shift || return @null;
	my $names = shift;

	map $names->{lc( $_->qname )}++, $packet->question;
	map $names->{lc( $_->cname )}++, grep $_->can('cname'), $packet->answer;

	my @addr = grep $_->can('address'), $packet->answer;
	map $_->address, grep $names->{lc( $_->name )}, @addr;
}


sub answerfrom {
	my $self = shift;
	$self->{answerfrom} = shift if scalar @_;
	return $self->{answerfrom};
}

sub _reset_errorstring {
	shift->{errorstring} = '';
}

sub errorstring {
	my $self = shift;
	$self->{errorstring} = shift if scalar @_;
	return $self->{errorstring};
}


sub query {
	my $self = shift;
	my $name = shift || '.';

	# resolve name containing no dots or colons by appending domain
	my @sfix = ( $self->{defnames} && $name !~ m/[:.]/ ) ? $self->domain : ();
	my $fqdn = join '.', $name, @sfix;

	$self->_diag( 'query(', $fqdn, @_, ')' );

	my $packet = $self->send( $fqdn, @_ ) || return;

	return $packet->header->ancount ? $packet : undef;
}


sub search {
	my $self = shift;

	return $self->query(@_) unless $self->{dnsrch};

	my $name = shift || '.';
	my @sfix = $self->searchlist;
	my @list = $name =~ m/[.]/ ? ( undef, @sfix ) : ( @sfix, undef );

	foreach my $suffix ( $name =~ m/:|\.\d*$/ ? undef : @list ) {
		my $fqname = $suffix ? join( '.', $name, $suffix ) : $name;

		$self->_diag( 'search(', $fqname, @_, ')' );

		my $packet = $self->send( $fqname, @_ ) || next;

		return $packet->header->ancount ? $packet : next;
	}

	return undef;
}


sub send {
	my $self	= shift;
	my $packet	= $self->_make_query_packet(@_);
	my $packet_data = $packet->data;

	return $self->_send_tcp( $packet, $packet_data )
			if $self->{usevc} || length $packet_data > $self->_packetsz;

	my $ans = $self->_send_udp( $packet, $packet_data ) || return;

	return $ans if $self->{igntc};
	return $ans unless $ans->header->tc;

	$self->_diag('packet truncated: retrying using TCP');
	$self->_send_tcp( $packet, $packet_data );
}


sub _send_tcp {
	my ( $self, $packet, $packet_data ) = @_;

	$self->_reset_errorstring;

	my $tcp_packet = pack 'n a*', length($packet_data), $packet_data;
	my @ns = $self->nameservers();
	my $lastanswer;
	my $timeout = $self->{tcp_timeout};

	foreach my $ip (@ns) {
		my $socket = $self->_create_tcp_socket($ip) || next;
		my $select = IO::Select->new($socket);

		$self->_diag( 'tcp send', "[$ip]" );

		$socket->send($tcp_packet);
		$self->errorstring($!);

		next unless $select->can_read($timeout);	# uncoverable branch

		my $buffer = _read_tcp($socket);
		$self->answerfrom($ip);
		$self->_diag( 'answer from', "[$ip]", length($buffer), 'bytes' );

		my $ans = $self->_decode_reply( \$buffer, $packet ) || next;

		$ans->answerfrom($ip);
		$lastanswer = $ans;

		my $rcode = $ans->header->rcode;
		last if $rcode eq 'NOERROR';
		last if $rcode eq 'NXDOMAIN';
		$self->errorstring($rcode);
	}

	return unless $lastanswer;

	if ( $self->{tsig_rr} && !$lastanswer->verify($packet) ) {
		$self->_diag( $self->errorstring( $lastanswer->verifyerr ) );
		return;
	}

	$self->errorstring( $lastanswer->header->rcode );	# historical quirk
	return $lastanswer;
}


sub _send_udp {
	my ( $self, $packet, $packet_data ) = @_;

	$self->_reset_errorstring;

	my @ns	    = $self->nameservers;
	my $port    = $self->{port};
	my $retrans = $self->{retrans} || 1;
	my $retry   = $self->{retry} || 1;
	my $select  = IO::Select->new();
	my $servers = scalar(@ns);
	my $timeout = $servers ? do { no integer; $retrans / $servers } : 0;
	my $lastanswer;

	# Perform each round of retries.
RETRY: for ( 1 .. $retry ) {					# assumed to be a small number

		# Try each nameserver.
NAMESERVER: foreach my $ns (@ns) {

			# Construct an array of 3 element arrays
			unless ( ref $ns ) {
				my $socket = $self->_create_udp_socket($ns) || next;
				my $dst_sockaddr = $self->_create_dst_sockaddr( $ns, $port );
				$ns = [$socket, $ns, $dst_sockaddr];
			}

			my ( $socket, $ip, $dst_sockaddr, $failed ) = @$ns;
			next if $failed;

			$self->_diag( 'udp send', "[$ip]:$port" );

			$socket->send( $packet_data, 0, $dst_sockaddr );
			$self->errorstring( $$ns[3] = $! );

			# handle failure to detect taint inside socket->send()
			die 'Insecure dependency while running with -T switch'
					if TAINT && Scalar::Util::tainted($dst_sockaddr);

			$select->add($socket);

			while ( my ($socket) = $select->can_read($timeout) ) {
				$select->remove($socket);

				my $peer = $socket->peerhost;
				$self->answerfrom($peer);

				my $buffer = _read_udp( $socket, $self->_packetsz );
				$self->_diag( "answer from [$peer]", length($buffer), 'bytes' );

				my $ans = $self->_decode_reply( \$buffer, $packet ) || next;

				$ans->answerfrom($peer);
				$lastanswer = $ans;

				my $rcode = $ans->header->rcode;
				last if $rcode eq 'NOERROR';
				last if $rcode eq 'NXDOMAIN';

				$self->errorstring( $$ns[3] = $rcode );
			}					#SELECTOR LOOP

			next unless $lastanswer;

			if ( $self->{tsig_rr} && !$lastanswer->verify($packet) ) {
				my $error = $$ns[3] = $lastanswer->verifyerr;
				$self->_diag( $self->errorstring($error) );
				next;
			}

			$self->errorstring( $lastanswer->header->rcode );    # historical quirk
			return $lastanswer;
		}						#NAMESERVER LOOP
		no integer;
		$timeout += $timeout;
	}							#RETRY LOOP

	$self->_diag( $self->errorstring('query timed out') ) unless $lastanswer;
	return;
}


sub bgsend {
	my $self	= shift;
	my $packet	= $self->_make_query_packet(@_);
	my $packet_data = $packet->data;

	return $self->_bgsend_tcp( $packet, $packet_data )
			if $self->{usevc} || length $packet_data > $self->_packetsz;

	return $self->_bgsend_udp( $packet, $packet_data );
}


sub _bgsend_tcp {
	my ( $self, $packet, $packet_data ) = @_;

	$self->_reset_errorstring;

	my $tcp_packet = pack 'n a*', length($packet_data), $packet_data;

	foreach my $ip ( $self->nameservers ) {
		my $socket = $self->_create_tcp_socket($ip) || next;

		$self->_diag( 'bgsend', "[$ip]" );

		$socket->blocking(0);
		$socket->send($tcp_packet);
		$self->errorstring($!);

		my $expire = time() + $self->{tcp_timeout};
		${*$socket}{net_dns_bg} = [$expire, $packet];
		return $socket;
	}

	$self->_diag( $self->errorstring );
	return undef;
}


sub _bgsend_udp {
	my ( $self, $packet, $packet_data ) = @_;

	$self->_reset_errorstring;

	my $port = $self->{port};

	foreach my $ip ( $self->nameservers ) {
		my $socket = $self->_create_udp_socket($ip) || next;
		my $dst_sockaddr = $self->_create_dst_sockaddr( $ip, $port );

		$self->_diag( 'bgsend', "[$ip]:$port" );

		$socket->send( $packet_data, 0, $dst_sockaddr );
		$self->errorstring($!);

		# handle failure to detect taint inside $socket->send()
		die 'Insecure dependency while running with -T switch'
				if TAINT && Scalar::Util::tainted($dst_sockaddr);

		my $expire = time() + $self->{udp_timeout};
		${*$socket}{net_dns_bg} = [$expire, $packet];
		return $socket;
	}

	$self->_diag( $self->errorstring );
	return undef;
}


sub bgbusy {
	my ( $self, $handle ) = @_;
	return unless $handle;

	my $appendix = ${*$handle}{net_dns_bg} ||= [time() + $self->{udp_timeout}];
	my ( $expire, $query, $read ) = @$appendix;
	return if ref($read);

	unless ( IO::Select->new($handle)->can_read(0.2) ) {
		return time() <= $expire;
	}

	return if $self->{igntc};
	return unless $handle->socktype() == SOCK_DGRAM;
	return unless $query;					# SpamAssassin 3.4.1 workaround

	my $ans = $self->_bgread($handle);
	$$appendix[2] = [$ans];
	return unless $ans;
	return unless $ans->header->tc;

	$self->_diag('packet truncated: retrying using TCP');
	my $tcp = $self->_bgsend_tcp( $query, $query->data ) || return;
	return defined( $_[1] = $tcp );
}


sub bgisready {				## historical
	!&bgbusy;						# uncoverable pod
}


sub bgread {
	while (&bgbusy) { next; }				# side effect: TCP retry
	&_bgread;
}


sub _bgread {
	my ( $self, $handle ) = @_;
	return unless $handle;

	my $appendix = ${*$handle}{net_dns_bg};
	my ( $expire, $query, $read ) = @$appendix;
	return shift(@$read) if ref($read);

	return unless IO::Select->new($handle)->can_read(0);

	my $peer = $handle->peerhost;
	$self->answerfrom($peer);

	my $dgram = $handle->socktype() == SOCK_DGRAM;
	my $buffer = $dgram ? _read_udp( $handle, $self->_packetsz ) : _read_tcp($handle);
	$self->_diag( "answer from [$peer]", length($buffer), 'bytes' );

	my $reply = $self->_decode_reply( \$buffer, $query ) || return;

	return $reply unless $self->{tsig_rr} && !$reply->verify($query);
	$self->errorstring( $reply->verifyerr );
	return;
}


sub _decode_reply {
	my ( $self, $bufref, $query ) = @_;

	my $reply = Net::DNS::Packet->decode( $bufref, $self->{debug} );
	$self->errorstring($@);

	return unless $reply;

	my $header = $reply->header;
	return unless $header->qr;

	return $reply unless $query;				# SpamAssassin 3.4.1 workaround
	return ( $header->id != $query->header->id ) ? undef : $reply;
}


sub axfr {				## zone transfer
	eval {
		my $self = shift;

		my ( $select, $verify, @rr, $soa ) = $self->_axfr_start(@_);

		my $iterator = sub {	## iterate over RRs
			my $rr = shift(@rr);

			if ( ref($rr) eq 'Net::DNS::RR::SOA' ) {
				return $soa = $rr unless $soa;
				$select = undef;
				return if $rr->encode eq $soa->encode;
				croak $self->errorstring('mismatched final SOA');
			}

			return $rr if scalar @rr;

			my $reply;
			( $reply, $verify ) = $self->_axfr_next( $select, $verify );
			@rr = $reply->answer;
			return $rr;
		};

		return $iterator unless wantarray;

		my @zone;					# assemble whole zone
		while ( my $rr = $iterator->() ) {
			push @zone, $rr, @rr;			# copy RRs en bloc
			@rr = pop(@zone);			# leave last one in @rr
		}
		return @zone;
	};
}


sub axfr_start {			## historical
	my $self = shift;					# uncoverable pod
	defined( $self->{axfr_iter} = $self->axfr(@_) );
}


sub axfr_next {				## historical
	shift->{axfr_iter}->();					# uncoverable pod
}


sub _axfr_start {
	my $self  = shift;
	my $dname = scalar(@_) ? shift : $self->domain;
	my @class = @_;

	my $request = $self->_make_query_packet( $dname, 'AXFR', @class );
	my $content = $request->data;
	my $TCP_msg = pack 'n a*', length($content), $content;

	$self->_diag("axfr_start( $dname @class )");

	my ( $select, $reply, $rcode );
	foreach my $ns ( $self->nameservers ) {
		my $socket = $self->_create_tcp_socket($ns) || next;

		$self->_diag("axfr_start nameserver [$ns]");

		$select = IO::Select->new($socket);
		$socket->send($TCP_msg);
		$self->errorstring($!);

		($reply) = $self->_axfr_next($select);
		last if ( $rcode = $reply->header->rcode ) eq 'NOERROR';
	}

	croak $self->errorstring unless $reply;

	$self->errorstring($rcode);				# historical quirk

	my $verify = $request->sigrr ? $request : undef;
	unless ($verify) {
		croak $self->errorstring unless $rcode eq 'NOERROR';
		return ( $select, $verify, $reply->answer );
	}

	my $verifyok = $reply->verify($verify);
	croak $self->errorstring( $reply->verifyerr ) unless $verifyok;
	croak $self->errorstring unless $rcode eq 'NOERROR';
	return ( $select, $verifyok, $reply->answer );
}


sub _axfr_next {
	my $self   = shift;
	my $select = shift || return;
	my $verify = shift;

	my ($socket) = $select->can_read( $self->{tcp_timeout} );
	croak $self->errorstring('timed out') unless $socket;

	$self->answerfrom( $socket->peerhost );

	my $buffer = _read_tcp($socket);
	$self->_diag( 'received', length($buffer), 'bytes' );

	my $packet = Net::DNS::Packet->new( \$buffer );
	croak $@, $self->errorstring('corrupt packet') if $@;

	return ( $packet, $verify ) unless $verify;

	my $verifyok = $packet->verify($verify);
	croak $self->errorstring( $packet->verifyerr ) unless $verifyok;
	return ( $packet, $verifyok );
}


#
# Usage:  $data = _read_tcp($socket);
#
sub _read_tcp {
	my $socket = shift;

	my ( $s1, $s2 );
	$socket->recv( $s1, 2 );				# one lump
	$socket->recv( $s2, 2 - length $s1 );			# or two?
	my $size = unpack 'n', pack( 'a*a*@2', $s1, $s2 );

	my $buffer = '';
	while ( ( my $read = length $buffer ) < $size ) {

		# During some of my tests recv() returned undef even
		# though there was no error.  Checking the amount
		# of data read appears to work around that problem.

		my $recv_buf;
		$socket->recv( $recv_buf, $size - $read );

		$buffer .= $recv_buf || last;
	}
	return $buffer;
}


#
# Usage:  $data = _read_udp($socket, $length);
#
sub _read_udp {
	my $socket = shift;
	my $buffer = '';
	$socket->recv( $buffer, shift );
	return $buffer;
}


sub _create_tcp_socket {
	my $self = shift;
	my $ip	 = shift;

	my $sock_key = "TCP[$ip]";
	my $socket;

	if ( $socket = $self->{persistent}{$sock_key} ) {
		$self->_diag( 'using persistent socket', $sock_key );
		return $socket if $socket->connected;
		$self->_diag('socket disconnected (trying to connect)');
	}

	my $ip6_addr = IPv6 && _ipv6($ip);

	$socket = IO::Socket::IP->new(
		LocalAddr => $ip6_addr ? $self->{srcaddr6} : $self->{srcaddr4},
		LocalPort => $self->{srcport},
		PeerAddr  => $ip,
		PeerPort  => $self->{port},
		Proto	  => 'tcp',
		Timeout	  => $self->{tcp_timeout},
		)
			if USE_SOCKET_IP;

	unless (USE_SOCKET_IP) {
		$socket = IO::Socket::INET6->new(
			LocalAddr => $self->{srcaddr6},
			LocalPort => ( $self->{srcport} || undef ),
			PeerAddr  => $ip,
			PeerPort  => $self->{port},
			Proto	  => 'tcp',
			Timeout	  => $self->{tcp_timeout},
			)
				if USE_SOCKET_INET6 && $ip6_addr;

		$socket = IO::Socket::INET->new(
			LocalAddr => $self->{srcaddr4},
			LocalPort => ( $self->{srcport} || undef ),
			PeerAddr  => $ip,
			PeerPort  => $self->{port},
			Proto	  => 'tcp',
			Timeout	  => $self->{tcp_timeout},
			)
				unless USE_SOCKET_INET6 && $ip6_addr;
	}

	$self->{persistent}{$sock_key} = $self->{persistent_tcp} ? $socket : undef;
	$self->errorstring("no socket $sock_key $!") unless $socket;
	return $socket;
}


sub _create_udp_socket {
	my $self = shift;
	my $ip	 = shift;

	my $ip6_addr = IPv6 && _ipv6($ip);
	my $sock_key = IPv6 && $ip6_addr ? 'UDP/IPv6' : 'UDP/IPv4';
	my $socket;
	return $socket if $socket = $self->{persistent}{$sock_key};

	$socket = IO::Socket::IP->new(
		LocalAddr => $ip6_addr ? $self->{srcaddr6} : $self->{srcaddr4},
		LocalPort => $self->{srcport},
		Proto	  => 'udp',
		Type	  => SOCK_DGRAM
		)
			if USE_SOCKET_IP;

	unless (USE_SOCKET_IP) {
		$socket = IO::Socket::INET6->new(
			LocalAddr => $self->{srcaddr6},
			LocalPort => ( $self->{srcport} || undef ),
			Proto	  => 'udp',
			Type	  => SOCK_DGRAM
			)
				if USE_SOCKET_INET6 && $ip6_addr;

		$socket = IO::Socket::INET->new(
			LocalAddr => $self->{srcaddr4},
			LocalPort => ( $self->{srcport} || undef ),
			Proto	  => 'udp',
			Type	  => SOCK_DGRAM
			)
				unless USE_SOCKET_INET6 && $ip6_addr;
	}

	$self->{persistent}{$sock_key} = $self->{persistent_udp} ? $socket : undef;
	$self->errorstring("no socket $sock_key $!") unless $socket;
	return $socket;
}


my $hints4 = {
	family	 => AF_INET,
	flags	 => Socket::AI_NUMERICHOST,
	protocol => Socket::IPPROTO_UDP,
	socktype => SOCK_DGRAM
	}
		if USE_SOCKET_IP;

my $hints6 = {
	family	 => AF_INET6,
	flags	 => Socket::AI_NUMERICHOST,
	protocol => Socket::IPPROTO_UDP,
	socktype => SOCK_DGRAM
	}
		if USE_SOCKET_IP;

BEGIN {
	import Socket6 qw(AI_NUMERICHOST) if USE_SOCKET_INET6;
}

my @inet6 = ( AF_INET6, SOCK_DGRAM, 0, AI_NUMERICHOST ) if USE_SOCKET_INET6;

sub _create_dst_sockaddr {		## create UDP destination sockaddr structure
	my ( $self, $ip, $port ) = @_;

	unless (USE_SOCKET_IP) {
		return ( Socket6::getaddrinfo( $ip, $port, @inet6 ) )[3]
				if USE_SOCKET_INET6 && _ipv6($ip);

		return sockaddr_in( $port, inet_aton($ip) );	# NB: errors raised in socket->send
	}

	( Socket::getaddrinfo( $ip, $port, _ipv6($ip) ? $hints6 : $hints4 ) )[1]->{addr}
			if USE_SOCKET_IP;			# NB: errors raised in socket->send
}


# Lightweight versions of subroutines from Net::IP module, recoded to fix RT#96812

sub _ipv4 {
	for (shift) {
		return /^[0-9.]+\.[0-9]+$/;			# dotted digits
	}
}

sub _ipv6 {
	for (shift) {
		return 1 if /^[:0-9a-f]+:[0-9a-f]*$/i;		# mixed : and hexdigits
		return 1 if /^[:0-9a-f]+:[0-9.]+$/i;		# prefix + dotted digits
		return /^[:0-9a-f]+:[0-9a-f]*[%].+$/i;		# RFC4007 scoped address
	}
}


sub _make_query_packet {
	my $self = shift;

	my ($packet) = @_;
	if ( ref($packet) ) {
		my $header = $packet->header;
		$header->rd( $self->{recurse} ) if $header->opcode eq 'QUERY';

	} else {
		$packet = Net::DNS::Packet->new(@_);

		my $header = $packet->header;
		$header->ad( $self->{adflag} );			# RFC6840, 5.7
		$header->cd( $self->{cdflag} );			# RFC6840, 5.9
		$header->do(1) if $self->{dnssec};
		$header->rd( $self->{recurse} );
	}

	$packet->edns->size( $self->{udppacketsize} );		# advertise UDPsize for local stack

	if ( $self->{tsig_rr} ) {
		$packet->sign_tsig( $self->{tsig_rr} ) unless $packet->sigrr;
	}

	return $packet;
}


sub dnssec {
	my $self = shift;

	return $self->{dnssec} unless scalar @_;

	# increase default udppacket size if flag set
	$self->udppacketsize(2048) if $self->{dnssec} = shift;

	return $self->{dnssec};
}


sub force_v6 {
	my $self = shift;
	return $self->{force_v6} unless scalar @_;
	my $value = shift;
	$self->force_v4(0) if $value;
	$self->{force_v6} = $value ? 1 : 0;
}

sub force_v4 {
	my $self = shift;
	return $self->{force_v4} unless scalar @_;
	my $value = shift;
	$self->force_v6(0) if $value;
	$self->{force_v4} = $value ? 1 : 0;
}

sub prefer_v6 {
	my $self = shift;
	$self->{prefer_v4} = shift() ? 0 : 1 if scalar @_;
	$self->{prefer_v4} ? 0 : 1;
}

sub prefer_v4 {
	my $self = shift;
	return $self->{prefer_v4} unless scalar @_;
	$self->{prefer_v4} = shift() ? 1 : 0;
}


sub srcaddr {
	my $self = shift;
	for (@_) {
		my $hashkey = _ipv6($_) ? 'srcaddr6' : 'srcaddr4';
		$self->{$hashkey} = $_;
	}
	return shift;
}


sub tsig {
	my $self = shift;
	$self->{tsig_rr} = eval {
		local $SIG{__DIE__};
		require Net::DNS::RR::TSIG;
		Net::DNS::RR::TSIG->create(@_);
	};
	croak "${@}unable to create TSIG record" if $@;
}


# if ($self->{udppacketsize} > PACKETSZ
# then we use EDNS and $self->{udppacketsize}
# should be taken as the maximum packet_data length
sub _packetsz {
	my $udpsize = shift->{udppacketsize} || 0;
	return $udpsize > PACKETSZ ? $udpsize : PACKETSZ;
}

sub udppacketsize {
	my $self = shift;
	$self->{udppacketsize} = shift if scalar @_;
	return $self->_packetsz;
}


#
# Keep this method around. Folk depend on it although it is neither documented nor exported.
#
my $warned;

sub make_query_packet {			## historical
	unless ( $warned++ ) {					# uncoverable pod
		local $SIG{__WARN__};
		carp 'deprecated method; see RT#37104';
	}
	&_make_query_packet;
}


sub _diag {				## debug output
	my $self = shift;
	print "\n;; @_\n" if $self->{debug};
}


our $AUTOLOAD;

sub DESTROY { }				## Avoid tickling AUTOLOAD (in cleanup)

sub AUTOLOAD {				## Default method
	my ($self) = @_;

	my $name = $AUTOLOAD;
	$name =~ s/.*://;
	croak "$name: no such method" unless $public_attr{$name};

	no strict q/refs/;
	*{$AUTOLOAD} = sub {
		my $self = shift;
		$self = $self->_defaults unless ref($self);
		$self->{$name} = shift if scalar @_;
		return $self->{$name};
	};

	goto &{$AUTOLOAD};
}


1;

__END__


=head1 NAME

Net::DNS::Resolver::Base - DNS resolver base class

=head1 SYNOPSIS

    use base qw(Net::DNS::Resolver::Base);

=head1 DESCRIPTION

This class is the common base class for the different platform
sub-classes of L<Net::DNS::Resolver>.

No user serviceable parts inside, see L<Net::DNS::Resolver>
for all your resolving needs.


=head1 METHODS

=head2 new, domain, searchlist, nameservers, print, string, errorstring,

=head2 search, query, send, bgsend, bgbusy, bgread, axfr, answerfrom,

=head2 force_v4, force_v6, prefer_v4, prefer_v6,

=head2 dnssec, srcaddr, tsig, udppacketsize

See L<Net::DNS::Resolver>.


=head1 COPYRIGHT

Copyright (c)2003,2004 Chris Reinhardt.

Portions Copyright (c)2005 Olaf Kolkman.

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

L<perl>, L<Net::DNS>, L<Net::DNS::Resolver>

=cut


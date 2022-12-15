#line 1 "Storable.pm"
#
#  Copyright (c) 1995-2001, Raphael Manfredi
#  Copyright (c) 2002-2014 by the Perl 5 Porters
#
#  You may redistribute only under the same terms as Perl 5, as specified
#  in the README file that comes with the distribution.
#

require XSLoader;
require Exporter;
package Storable; @ISA = qw(Exporter);

@EXPORT = qw(store retrieve);
@EXPORT_OK = qw(
	nstore store_fd nstore_fd fd_retrieve
	freeze nfreeze thaw
	dclone
	retrieve_fd
	lock_store lock_nstore lock_retrieve
        file_magic read_magic
);

use vars qw($canonical $forgive_me $VERSION);

$VERSION = '2.56_01';

BEGIN {
    if (eval {
        local $SIG{__DIE__};
        local @INC = @INC;
        pop @INC if $INC[-1] eq '.';
        require Log::Agent;
        1;
    }) {
        Log::Agent->import;
    }
    #
    # Use of Log::Agent is optional. If it hasn't imported these subs then
    # provide a fallback implementation.
    #
    unless ($Storable::{logcroak} && *{$Storable::{logcroak}}{CODE}) {
        require Carp;
        *logcroak = sub {
            Carp::croak(@_);
        };
    }
    unless ($Storable::{logcarp} && *{$Storable::{logcarp}}{CODE}) {
	require Carp;
        *logcarp = sub {
          Carp::carp(@_);
        };
    }
}

#
# They might miss :flock in Fcntl
#

BEGIN {
	if (eval { require Fcntl; 1 } && exists $Fcntl::EXPORT_TAGS{'flock'}) {
		Fcntl->import(':flock');
	} else {
		eval q{
			sub LOCK_SH ()	{1}
			sub LOCK_EX ()	{2}
		};
	}
}

sub CLONE {
    # clone context under threads
    Storable::init_perinterp();
}

# By default restricted hashes are downgraded on earlier perls.

$Storable::downgrade_restricted = 1;
$Storable::accept_future_minor = 1;

XSLoader::load('Storable', $Storable::VERSION);

#
# Determine whether locking is possible, but only when needed.
#

sub CAN_FLOCK; my $CAN_FLOCK; sub CAN_FLOCK {
	return $CAN_FLOCK if defined $CAN_FLOCK;
	require Config; import Config;
	return $CAN_FLOCK =
		$Config{'d_flock'} ||
		$Config{'d_fcntl_can_lock'} ||
		$Config{'d_lockf'};
}

sub show_file_magic {
    print <<EOM;
#
# To recognize the data files of the Perl module Storable,
# the following lines need to be added to the local magic(5) file,
# usually either /usr/share/misc/magic or /etc/magic.
#
0	string	perl-store	perl Storable(v0.6) data
>4	byte	>0	(net-order %d)
>>4	byte	&01	(network-ordered)
>>4	byte	=3	(major 1)
>>4	byte	=2	(major 1)

0	string	pst0	perl Storable(v0.7) data
>4	byte	>0
>>4	byte	&01	(network-ordered)
>>4	byte	=5	(major 2)
>>4	byte	=4	(major 2)
>>5	byte	>0	(minor %d)
EOM
}

sub file_magic {
    require IO::File;

    my $file = shift;
    my $fh = IO::File->new;
    open($fh, "<". $file) || die "Can't open '$file': $!";
    binmode($fh);
    defined(sysread($fh, my $buf, 32)) || die "Can't read from '$file': $!";
    close($fh);

    $file = "./$file" unless $file;  # ensure TRUE value

    return read_magic($buf, $file);
}

sub read_magic {
    my($buf, $file) = @_;
    my %info;

    my $buflen = length($buf);
    my $magic;
    if ($buf =~ s/^(pst0|perl-store)//) {
	$magic = $1;
	$info{file} = $file || 1;
    }
    else {
	return undef if $file;
	$magic = "";
    }

    return undef unless length($buf);

    my $net_order;
    if ($magic eq "perl-store" && ord(substr($buf, 0, 1)) > 1) {
	$info{version} = -1;
	$net_order = 0;
    }
    else {
	$buf =~ s/(.)//s;
	my $major = (ord $1) >> 1;
	return undef if $major > 4; # sanity (assuming we never go that high)
	$info{major} = $major;
	$net_order = (ord $1) & 0x01;
	if ($major > 1) {
	    return undef unless $buf =~ s/(.)//s;
	    my $minor = ord $1;
	    $info{minor} = $minor;
	    $info{version} = "$major.$minor";
	    $info{version_nv} = sprintf "%d.%03d", $major, $minor;
	}
	else {
	    $info{version} = $major;
	}
    }
    $info{version_nv} ||= $info{version};
    $info{netorder} = $net_order;

    unless ($net_order) {
	return undef unless $buf =~ s/(.)//s;
	my $len = ord $1;
	return undef unless length($buf) >= $len;
	return undef unless $len == 4 || $len == 8;  # sanity
	@info{qw(byteorder intsize longsize ptrsize)}
	    = unpack "a${len}CCC", $buf;
	(substr $buf, 0, $len + 3) = '';
	if ($info{version_nv} >= 2.002) {
	    return undef unless $buf =~ s/(.)//s;
	    $info{nvsize} = ord $1;
	}
    }
    $info{hdrsize} = $buflen - length($buf);

    return \%info;
}

sub BIN_VERSION_NV {
    sprintf "%d.%03d", BIN_MAJOR(), BIN_MINOR();
}

sub BIN_WRITE_VERSION_NV {
    sprintf "%d.%03d", BIN_MAJOR(), BIN_WRITE_MINOR();
}

#
# store
#
# Store target object hierarchy, identified by a reference to its root.
# The stored object tree may later be retrieved to memory via retrieve.
# Returns undef if an I/O error occurred, in which case the file is
# removed.
#
sub store {
	return _store(\&pstore, @_, 0);
}

#
# nstore
#
# Same as store, but in network order.
#
sub nstore {
	return _store(\&net_pstore, @_, 0);
}

#
# lock_store
#
# Same as store, but flock the file first (advisory locking).
#
sub lock_store {
	return _store(\&pstore, @_, 1);
}

#
# lock_nstore
#
# Same as nstore, but flock the file first (advisory locking).
#
sub lock_nstore {
	return _store(\&net_pstore, @_, 1);
}

# Internal store to file routine
sub _store {
	my $xsptr = shift;
	my $self = shift;
	my ($file, $use_locking) = @_;
	logcroak "not a reference" unless ref($self);
	logcroak "wrong argument number" unless @_ == 2;	# No @foo in arglist
	local *FILE;
	if ($use_locking) {
		open(FILE, ">>$file") || logcroak "can't write into $file: $!";
		unless (&CAN_FLOCK) {
			logcarp
				"Storable::lock_store: fcntl/flock emulation broken on $^O";
			return undef;
		}
		flock(FILE, LOCK_EX) ||
			logcroak "can't get exclusive lock on $file: $!";
		truncate FILE, 0;
		# Unlocking will happen when FILE is closed
	} else {
		open(FILE, ">$file") || logcroak "can't create $file: $!";
	}
	binmode FILE;				# Archaic systems...
	my $da = $@;				# Don't mess if called from exception handler
	my $ret;
	# Call C routine nstore or pstore, depending on network order
	eval { $ret = &$xsptr(*FILE, $self) };
	# close will return true on success, so the or short-circuits, the ()
	# expression is true, and for that case the block will only be entered
	# if $@ is true (ie eval failed)
	# if close fails, it returns false, $ret is altered, *that* is (also)
	# false, so the () expression is false, !() is true, and the block is
	# entered.
	if (!(close(FILE) or undef $ret) || $@) {
		unlink($file) or warn "Can't unlink $file: $!\n";
	}
	logcroak $@ if $@ =~ s/\.?\n$/,/;
	$@ = $da;
	return $ret;
}

#
# store_fd
#
# Same as store, but perform on an already opened file descriptor instead.
# Returns undef if an I/O error occurred.
#
sub store_fd {
	return _store_fd(\&pstore, @_);
}

#
# nstore_fd
#
# Same as store_fd, but in network order.
#
sub nstore_fd {
	my ($self, $file) = @_;
	return _store_fd(\&net_pstore, @_);
}

# Internal store routine on opened file descriptor
sub _store_fd {
	my $xsptr = shift;
	my $self = shift;
	my ($file) = @_;
	logcroak "not a reference" unless ref($self);
	logcroak "too many arguments" unless @_ == 1;	# No @foo in arglist
	my $fd = fileno($file);
	logcroak "not a valid file descriptor" unless defined $fd;
	my $da = $@;				# Don't mess if called from exception handler
	my $ret;
	# Call C routine nstore or pstore, depending on network order
	eval { $ret = &$xsptr($file, $self) };
	logcroak $@ if $@ =~ s/\.?\n$/,/;
	local $\; print $file '';	# Autoflush the file if wanted
	$@ = $da;
	return $ret;
}

#
# freeze
#
# Store object and its hierarchy in memory and return a scalar
# containing the result.
#
sub freeze {
	_freeze(\&mstore, @_);
}

#
# nfreeze
#
# Same as freeze but in network order.
#
sub nfreeze {
	_freeze(\&net_mstore, @_);
}

# Internal freeze routine
sub _freeze {
	my $xsptr = shift;
	my $self = shift;
	logcroak "not a reference" unless ref($self);
	logcroak "too many arguments" unless @_ == 0;	# No @foo in arglist
	my $da = $@;				# Don't mess if called from exception handler
	my $ret;
	# Call C routine mstore or net_mstore, depending on network order
	eval { $ret = &$xsptr($self) };
	logcroak $@ if $@ =~ s/\.?\n$/,/;
	$@ = $da;
	return $ret ? $ret : undef;
}

#
# retrieve
#
# Retrieve object hierarchy from disk, returning a reference to the root
# object of that tree.
#
sub retrieve {
	_retrieve($_[0], 0);
}

#
# lock_retrieve
#
# Same as retrieve, but with advisory locking.
#
sub lock_retrieve {
	_retrieve($_[0], 1);
}

# Internal retrieve routine
sub _retrieve {
	my ($file, $use_locking) = @_;
	local *FILE;
	open(FILE, $file) || logcroak "can't open $file: $!";
	binmode FILE;							# Archaic systems...
	my $self;
	my $da = $@;							# Could be from exception handler
	if ($use_locking) {
		unless (&CAN_FLOCK) {
			logcarp
				"Storable::lock_store: fcntl/flock emulation broken on $^O";
			return undef;
		}
		flock(FILE, LOCK_SH) || logcroak "can't get shared lock on $file: $!";
		# Unlocking will happen when FILE is closed
	}
	eval { $self = pretrieve(*FILE) };		# Call C routine
	close(FILE);
	logcroak $@ if $@ =~ s/\.?\n$/,/;
	$@ = $da;
	return $self;
}

#
# fd_retrieve
#
# Same as retrieve, but perform from an already opened file descriptor instead.
#
sub fd_retrieve {
	my ($file) = @_;
	my $fd = fileno($file);
	logcroak "not a valid file descriptor" unless defined $fd;
	my $self;
	my $da = $@;							# Could be from exception handler
	eval { $self = pretrieve($file) };		# Call C routine
	logcroak $@ if $@ =~ s/\.?\n$/,/;
	$@ = $da;
	return $self;
}

sub retrieve_fd { &fd_retrieve }		# Backward compatibility

#
# thaw
#
# Recreate objects in memory from an existing frozen image created
# by freeze.  If the frozen image passed is undef, return undef.
#
sub thaw {
	my ($frozen) = @_;
	return undef unless defined $frozen;
	my $self;
	my $da = $@;							# Could be from exception handler
	eval { $self = mretrieve($frozen) };	# Call C routine
	logcroak $@ if $@ =~ s/\.?\n$/,/;
	$@ = $da;
	return $self;
}

1;
__END__

#line 1238

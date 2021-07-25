#line 1 "File/stat.pm"
package File::stat;
use 5.006;

use strict;
use warnings;
use warnings::register;
use Carp;

BEGIN { *warnif = \&warnings::warnif }

our(@EXPORT, @EXPORT_OK, %EXPORT_TAGS);

our $VERSION = '1.07';

my @fields;
BEGIN { 
    use Exporter   ();
    @EXPORT      = qw(stat lstat);
    @fields      = qw( $st_dev	   $st_ino    $st_mode 
		       $st_nlink   $st_uid    $st_gid 
		       $st_rdev    $st_size 
		       $st_atime   $st_mtime  $st_ctime 
		       $st_blksize $st_blocks
		    );
    @EXPORT_OK   = ( @fields, "stat_cando" );
    %EXPORT_TAGS = ( FIELDS => [ @fields, @EXPORT ] );
}
use vars @fields;

use Fcntl qw(S_IRUSR S_IWUSR S_IXUSR);

BEGIN {
    # These constants will croak on use if the platform doesn't define
    # them. It's important to avoid inflicting that on the user.
    no strict 'refs';
    for (qw(suid sgid svtx)) {
        my $val = eval { &{"Fcntl::S_I\U$_"} };
        *{"_$_"} = defined $val ? sub { $_[0] & $val ? 1 : "" } : sub { "" };
    }
    for (qw(SOCK CHR BLK REG DIR LNK)) {
        *{"S_IS$_"} = defined eval { &{"Fcntl::S_IF$_"} }
            ? \&{"Fcntl::S_IS$_"} : sub { "" };
    }
    # FIFO flag and macro don't quite follow the S_IF/S_IS pattern above
    # RT #111638
    *{"S_ISFIFO"} = defined &Fcntl::S_IFIFO
      ? \&Fcntl::S_ISFIFO : sub { "" };
}

# from doio.c
sub _ingroup {
    my ($gid, $eff)   = @_;

    # I am assuming that since VMS doesn't have getgroups(2), $) will
    # always only contain a single entry.
    $^O eq "VMS"    and return $_[0] == $);

    my ($egid, @supp) = split " ", $);
    my ($rgid)        = split " ", $(;

    $gid == ($eff ? $egid : $rgid)  and return 1;
    grep $gid == $_, @supp          and return 1;

    return "";
}

# VMS uses the Unix version of the routine, even though this is very
# suboptimal. VMS has a permissions structure that doesn't really fit
# into struct stat, and unlike on Win32 the normal -X operators respect
# that, but unfortunately by the time we get here we've already lost the
# information we need. It looks to me as though if we were to preserve
# the st_devnam entry of vmsish.h's fake struct stat (which actually
# holds the filename) it might be possible to do this right, but both
# getting that value out of the struct (perl's stat doesn't return it)
# and interpreting it later would require this module to have an XS
# component (at which point we might as well just call Perl_cando and
# have done with it).
    
if (grep $^O eq $_, qw/os2 MSWin32 dos/) {

    # from doio.c
    *cando = sub { ($_[0][2] & $_[1]) ? 1 : "" };
}
else {

    # from doio.c
    *cando = sub {
        my ($s, $mode, $eff) = @_;
        my $uid = $eff ? $> : $<;
        my ($stmode, $stuid, $stgid) = @$s[2,4,5];

        # This code basically assumes that the rwx bits of the mode are
        # the 0777 bits, but so does Perl_cando.

        if ($uid == 0 && $^O ne "VMS") {
            # If we're root on unix
            # not testing for executable status => all file tests are true
            return 1 if !($mode & 0111);
            # testing for executable status =>
            # for a file, any x bit will do
            # for a directory, always true
            return 1 if $stmode & 0111 || S_ISDIR($stmode);
            return "";
        }

        if ($stuid == $uid) {
            $stmode & $mode         and return 1;
        }
        elsif (_ingroup($stgid, $eff)) {
            $stmode & ($mode >> 3)  and return 1;
        }
        else {
            $stmode & ($mode >> 6)  and return 1;
        }
        return "";
    };
}

# alias for those who don't like objects
*stat_cando = \&cando;

my %op = (
    r => sub { cando($_[0], S_IRUSR, 1) },
    w => sub { cando($_[0], S_IWUSR, 1) },
    x => sub { cando($_[0], S_IXUSR, 1) },
    o => sub { $_[0][4] == $>           },

    R => sub { cando($_[0], S_IRUSR, 0) },
    W => sub { cando($_[0], S_IWUSR, 0) },
    X => sub { cando($_[0], S_IXUSR, 0) },
    O => sub { $_[0][4] == $<           },

    e => sub { 1 },
    z => sub { $_[0][7] == 0    },
    s => sub { $_[0][7]         },

    f => sub { S_ISREG ($_[0][2]) },
    d => sub { S_ISDIR ($_[0][2]) },
    l => sub { S_ISLNK ($_[0][2]) },
    p => sub { S_ISFIFO($_[0][2]) },
    S => sub { S_ISSOCK($_[0][2]) },
    b => sub { S_ISBLK ($_[0][2]) },
    c => sub { S_ISCHR ($_[0][2]) },

    u => sub { _suid($_[0][2]) },
    g => sub { _sgid($_[0][2]) },
    k => sub { _svtx($_[0][2]) },

    M => sub { ($^T - $_[0][9] ) / 86400 },
    C => sub { ($^T - $_[0][10]) / 86400 },
    A => sub { ($^T - $_[0][8] ) / 86400 },
);

use constant HINT_FILETEST_ACCESS => 0x00400000;

# we need fallback=>1 or stringifying breaks
use overload 
    fallback => 1,
    -X => sub {
        my ($s, $op) = @_;

        if (index("rwxRWX", $op) >= 0) {
            (caller 0)[8] & HINT_FILETEST_ACCESS
                and warnif("File::stat ignores use filetest 'access'");

            $^O eq "VMS" and warnif("File::stat ignores VMS ACLs");

            # It would be nice to have a warning about using -l on a
            # non-lstat, but that would require an extra member in the
            # object.
        }

        if ($op{$op}) {
            return $op{$op}->($_[0]);
        }
        else {
            croak "-$op is not implemented on a File::stat object";
        }
    };

# Class::Struct forbids use of @ISA
sub import { goto &Exporter::import }

use Class::Struct qw(struct);
struct 'File::stat' => [
     map { $_ => '$' } qw{
	 dev ino mode nlink uid gid rdev size
	 atime mtime ctime blksize blocks
     }
];

sub populate (@) {
    return unless @_;
    my $stob = new();
    @$stob = (
	$st_dev, $st_ino, $st_mode, $st_nlink, $st_uid, $st_gid, $st_rdev,
        $st_size, $st_atime, $st_mtime, $st_ctime, $st_blksize, $st_blocks ) 
	    = @_;
    return $stob;
} 

sub lstat ($)  { populate(CORE::lstat(shift)) }

sub stat ($) {
    my $arg = shift;
    my $st = populate(CORE::stat $arg);
    return $st if defined $st;
	my $fh;
    {
		local $!;
		no strict 'refs';
		require Symbol;
		$fh = \*{ Symbol::qualify( $arg, caller() )};
		return unless defined fileno $fh;
	}
    return populate(CORE::stat $fh);
}

1;
__END__

#line 357
#line 1 "Win32API/File.pm"
# File.pm -- Low-level access to Win32 file/dir functions/constants.

package Win32API::File;

use strict;
use integer;
use Carp;
use Config qw( %Config );
use Fcntl qw( O_RDONLY O_RDWR O_WRONLY O_APPEND O_BINARY O_TEXT );
use vars qw( $VERSION @ISA );
use vars qw( @EXPORT @EXPORT_OK @EXPORT_FAIL %EXPORT_TAGS );

$VERSION= '0.1203';

use base qw( Exporter DynaLoader Tie::Handle IO::File );

# Math::BigInt optimizations courtesy of Tels
my $_64BITINT;
BEGIN {
    $_64BITINT = defined($Config{use64bitint}) &&
                 ($Config{use64bitint} eq 'define');

    require Math::BigInt unless $_64BITINT;
}

my $THIRTY_TWO = $_64BITINT ? 32 : Math::BigInt->new(32);

my $FFFFFFFF   = $_64BITINT ? 0xFFFFFFFF : Math::BigInt->new(0xFFFFFFFF);

@EXPORT= qw();
%EXPORT_TAGS= (
    Func =>	[qw(		attrLetsToBits		createFile
    	fileConstant		fileLastError		getLogicalDrives
	CloseHandle		CopyFile		CreateFile
	DefineDosDevice		DeleteFile		DeviceIoControl
	FdGetOsFHandle		GetDriveType		GetFileAttributes		GetFileType
	GetHandleInformation	GetLogicalDrives	GetLogicalDriveStrings
	GetOsFHandle		GetVolumeInformation	IsRecognizedPartition
	IsContainerPartition	MoveFile		MoveFileEx
	OsFHandleOpen		OsFHandleOpenFd		QueryDosDevice
	ReadFile		SetErrorMode		SetFilePointer
	SetHandleInformation	WriteFile		GetFileSize
	getFileSize		setFilePointer		GetOverlappedResult)],
    FuncA =>	[qw(
	CopyFileA		CreateFileA		DefineDosDeviceA
	DeleteFileA		GetDriveTypeA		GetFileAttributesA		GetLogicalDriveStringsA
	GetVolumeInformationA	MoveFileA		MoveFileExA
	QueryDosDeviceA )],
    FuncW =>	[qw(
	CopyFileW		CreateFileW		DefineDosDeviceW
	DeleteFileW		GetDriveTypeW		GetFileAttributesW		GetLogicalDriveStringsW
	GetVolumeInformationW	MoveFileW		MoveFileExW
	QueryDosDeviceW )],
    Misc =>		[qw(
	CREATE_ALWAYS		CREATE_NEW		FILE_BEGIN
	FILE_CURRENT		FILE_END		INVALID_HANDLE_VALUE
	OPEN_ALWAYS		OPEN_EXISTING		TRUNCATE_EXISTING )],
    DDD_ =>	[qw(
	DDD_EXACT_MATCH_ON_REMOVE			DDD_RAW_TARGET_PATH
	DDD_REMOVE_DEFINITION )],
    DRIVE_ =>	[qw(
	DRIVE_UNKNOWN		DRIVE_NO_ROOT_DIR	DRIVE_REMOVABLE
	DRIVE_FIXED		DRIVE_REMOTE		DRIVE_CDROM
	DRIVE_RAMDISK )],
    FILE_ =>	[qw(
	FILE_READ_DATA			FILE_LIST_DIRECTORY
	FILE_WRITE_DATA			FILE_ADD_FILE
	FILE_APPEND_DATA		FILE_ADD_SUBDIRECTORY
	FILE_CREATE_PIPE_INSTANCE	FILE_READ_EA
	FILE_WRITE_EA			FILE_EXECUTE
	FILE_TRAVERSE			FILE_DELETE_CHILD
	FILE_READ_ATTRIBUTES		FILE_WRITE_ATTRIBUTES
	FILE_ALL_ACCESS			FILE_GENERIC_READ
	FILE_GENERIC_WRITE		FILE_GENERIC_EXECUTE )],
    FILE_ATTRIBUTE_ =>	[qw(
    INVALID_FILE_ATTRIBUTES
    FILE_ATTRIBUTE_DEVICE        FILE_ATTRIBUTE_DIRECTORY
    FILE_ATTRIBUTE_ENCRYPTED     FILE_ATTRIBUTE_NOT_CONTENT_INDEXED
    FILE_ATTRIBUTE_REPARSE_POINT FILE_ATTRIBUTE_SPARSE_FILE
	FILE_ATTRIBUTE_ARCHIVE		 FILE_ATTRIBUTE_COMPRESSED
	FILE_ATTRIBUTE_HIDDEN		 FILE_ATTRIBUTE_NORMAL
	FILE_ATTRIBUTE_OFFLINE		 FILE_ATTRIBUTE_READONLY
	FILE_ATTRIBUTE_SYSTEM		 FILE_ATTRIBUTE_TEMPORARY )],
    FILE_FLAG_ =>	[qw(
	FILE_FLAG_BACKUP_SEMANTICS	FILE_FLAG_DELETE_ON_CLOSE
	FILE_FLAG_NO_BUFFERING		FILE_FLAG_OVERLAPPED
	FILE_FLAG_POSIX_SEMANTICS	FILE_FLAG_RANDOM_ACCESS
	FILE_FLAG_SEQUENTIAL_SCAN	FILE_FLAG_WRITE_THROUGH
	FILE_FLAG_OPEN_REPARSE_POINT )],
    FILE_SHARE_ =>	[qw(
	FILE_SHARE_DELETE	FILE_SHARE_READ		FILE_SHARE_WRITE )],
    FILE_TYPE_ =>	[qw(
	FILE_TYPE_CHAR		FILE_TYPE_DISK		FILE_TYPE_PIPE
	FILE_TYPE_UNKNOWN )],
    FS_ =>	[qw(
	FS_CASE_IS_PRESERVED		FS_CASE_SENSITIVE
	FS_UNICODE_STORED_ON_DISK	FS_PERSISTENT_ACLS 
	FS_FILE_COMPRESSION		FS_VOL_IS_COMPRESSED )],
	FSCTL_ => [qw(
	FSCTL_SET_REPARSE_POINT		FSCTL_GET_REPARSE_POINT
	FSCTL_DELETE_REPARSE_POINT )],
    HANDLE_FLAG_ =>	[qw(
	HANDLE_FLAG_INHERIT		HANDLE_FLAG_PROTECT_FROM_CLOSE )],
    IOCTL_STORAGE_ =>	[qw(
	IOCTL_STORAGE_CHECK_VERIFY	IOCTL_STORAGE_MEDIA_REMOVAL
	IOCTL_STORAGE_EJECT_MEDIA	IOCTL_STORAGE_LOAD_MEDIA
	IOCTL_STORAGE_RESERVE		IOCTL_STORAGE_RELEASE
	IOCTL_STORAGE_FIND_NEW_DEVICES	IOCTL_STORAGE_GET_MEDIA_TYPES
	)],
    IOCTL_DISK_ =>	[qw(
	IOCTL_DISK_FORMAT_TRACKS	IOCTL_DISK_FORMAT_TRACKS_EX
	IOCTL_DISK_GET_DRIVE_GEOMETRY	IOCTL_DISK_GET_DRIVE_LAYOUT
	IOCTL_DISK_GET_MEDIA_TYPES	IOCTL_DISK_GET_PARTITION_INFO
	IOCTL_DISK_HISTOGRAM_DATA	IOCTL_DISK_HISTOGRAM_RESET
	IOCTL_DISK_HISTOGRAM_STRUCTURE	IOCTL_DISK_IS_WRITABLE
	IOCTL_DISK_LOGGING		IOCTL_DISK_PERFORMANCE
	IOCTL_DISK_REASSIGN_BLOCKS	IOCTL_DISK_REQUEST_DATA
	IOCTL_DISK_REQUEST_STRUCTURE	IOCTL_DISK_SET_DRIVE_LAYOUT
	IOCTL_DISK_SET_PARTITION_INFO	IOCTL_DISK_VERIFY )],
    GENERIC_ =>		[qw(
	GENERIC_ALL			GENERIC_EXECUTE
	GENERIC_READ			GENERIC_WRITE )],
    MEDIA_TYPE =>	[qw(
	Unknown			F5_1Pt2_512		F3_1Pt44_512
	F3_2Pt88_512		F3_20Pt8_512		F3_720_512
	F5_360_512		F5_320_512		F5_320_1024
	F5_180_512		F5_160_512		RemovableMedia
	FixedMedia		F3_120M_512 )],
    MOVEFILE_ =>	[qw(
	MOVEFILE_COPY_ALLOWED		MOVEFILE_DELAY_UNTIL_REBOOT
	MOVEFILE_REPLACE_EXISTING	MOVEFILE_WRITE_THROUGH )],
    SECURITY_ =>	[qw(
	SECURITY_ANONYMOUS		SECURITY_CONTEXT_TRACKING
	SECURITY_DELEGATION		SECURITY_EFFECTIVE_ONLY
	SECURITY_IDENTIFICATION		SECURITY_IMPERSONATION
	SECURITY_SQOS_PRESENT )],
    SEM_ =>		[qw(
	SEM_FAILCRITICALERRORS		SEM_NOGPFAULTERRORBOX
	SEM_NOALIGNMENTFAULTEXCEPT	SEM_NOOPENFILEERRORBOX )],
    PARTITION_ =>	[qw(
	PARTITION_ENTRY_UNUSED		PARTITION_FAT_12
	PARTITION_XENIX_1		PARTITION_XENIX_2
	PARTITION_FAT_16		PARTITION_EXTENDED
	PARTITION_HUGE			PARTITION_IFS
	PARTITION_FAT32			PARTITION_FAT32_XINT13
	PARTITION_XINT13		PARTITION_XINT13_EXTENDED
	PARTITION_PREP			PARTITION_UNIX
	VALID_NTFT			PARTITION_NTFT )],
    STD_HANDLE_ =>		[qw(
	STD_INPUT_HANDLE		STD_OUTPUT_HANDLE
	STD_ERROR_HANDLE )],
);
@EXPORT_OK= ();
{
    my $key;
    foreach $key (  keys(%EXPORT_TAGS)  ) {
	push( @EXPORT_OK, @{$EXPORT_TAGS{$key}} );
	#push( @EXPORT_FAIL, @{$EXPORT_TAGS{$key}} )   unless  $key =~ /^Func/;
    }
}
$EXPORT_TAGS{ALL}= \@EXPORT_OK;

bootstrap Win32API::File $VERSION;

# Preloaded methods go here.

# To convert C constants to Perl code in cFile.pc
# [instead of C or C++ code in cFile.h]:
#    * Modify F<Makefile.PL> to add WriteMakeFile() =>
#      CONST2PERL/postamble => [[ "Win32API::File" => ]] WRITE_PERL => 1.
#    * Either comment out C<#include "cFile.h"> from F<File.xs>
#      or make F<cFile.h> an empty file.
#    * Make sure the following C<if> block is not commented out.
#    * "nmake clean", "perl Makefile.PL", "nmake"

if(  ! defined &GENERIC_READ  ) {
    require "Win32API/File/cFile.pc";
}

sub fileConstant
{
    my( $name )= @_;
    if(  1 != @_  ||  ! $name  ||  $name =~ /\W/  ) {
	require Carp;
	Carp::croak( 'Usage: ',__PACKAGE__,'::fileConstant("CONST_NAME")' );
    }
    my $proto= prototype $name;
    if(  defined \&$name
     &&  defined $proto
     &&  "" eq $proto  ) {
	no strict 'refs';
	return &$name;
    }
    return undef;
}

# We provide this for backwards compatibility:
sub constant
{
    my( $name )= @_;
    my $value= fileConstant( $name );
    if(  defined $value  ) {
	$!= 0;
	return $value;
    }
    $!= 11; # EINVAL
    return 0;
}

# BEGIN {
#     my $code= 'return _fileLastError(@_)';
#     local( $!, $^E )= ( 1, 1 );
#     if(  $! ne $^E  ) {
# 	$code= '
# 	    local( $^E )= _fileLastError(@_);
# 	    my $ret= $^E;
# 	    return $ret;
# 	';
#     }
#     eval "sub fileLastError { $code }";
#     die "$@"   if  $@;
# }

package Win32API::File::_error;

use overload
    '""' => sub {
	require Win32 unless defined &Win32::FormatMessage;
	$_ = Win32::FormatMessage(Win32API::File::_fileLastError());
	tr/\r\n//d;
	return $_;
    },
    '0+' => sub { Win32API::File::_fileLastError() },
    'fallback' => 1;

sub new { return bless {}, shift }
sub set { Win32API::File::_fileLastError($_[1]); return $_[0] }

package Win32API::File;

my $_error = Win32API::File::_error->new();

sub fileLastError {
    croak 'Usage: ',__PACKAGE__,'::fileLastError( [$setWin32ErrCode] )'	if @_ > 1;
    $_error->set($_[0]) if defined $_[0];
    return $_error;
}

# Since we ISA DynaLoader which ISA AutoLoader, we ISA AutoLoader so we
# need this next chunk to prevent Win32API::File->nonesuch() from
# looking for "nonesuch.al" and producing confusing error messages:
use vars qw($AUTOLOAD);
sub AUTOLOAD {
    require Carp;
    Carp::croak(
      "Can't locate method $AUTOLOAD via package Win32API::File" );
}

# Replace "&rout;" with "goto &rout;" when that is supported on Win32.

# Aliases for non-Unicode functions:
sub CopyFile			{ &CopyFileA; }
sub CreateFile			{ &CreateFileA; }
sub DefineDosDevice		{ &DefineDosDeviceA; }
sub DeleteFile			{ &DeleteFileA; }
sub GetDriveType		{ &GetDriveTypeA; }
sub GetFileAttributes	{ &GetFileAttributesA; }
sub GetLogicalDriveStrings	{ &GetLogicalDriveStringsA; }
sub GetVolumeInformation	{ &GetVolumeInformationA; }
sub MoveFile			{ &MoveFileA; }
sub MoveFileEx			{ &MoveFileExA; }
sub QueryDosDevice		{ &QueryDosDeviceA; }

sub OsFHandleOpen {
    if(  3 != @_  ) {
	croak 'Win32API::File Usage:  ',
	      'OsFHandleOpen(FILE,$hNativeHandle,"rwatb")';
    }
    my( $fh, $osfh, $access )= @_;
    if(  ! ref($fh)  ) {
	if(  $fh !~ /('|::)/  ) {
	    $fh= caller() . "::" . $fh;
	}
	no strict "refs";
	$fh= \*{$fh};
    }
    my( $mode, $pref );
    if(  $access =~ /r/i  ) {
	if(  $access =~ /w/i  ) {
	    $mode= O_RDWR;
	    $pref= "+<";
	} else {
	    $mode= O_RDONLY;
	    $pref= "<";
	}
    } else {
	if(  $access =~ /w/i  ) {
	    $mode= O_WRONLY;
	    $pref= ">";
	} else {
	#   croak qq<Win32API::File::OsFHandleOpen():  >,
	#	  qq<Access ($access) missing both "r" and "w">;
	    $mode= O_RDONLY;
	    $pref= "<";
	}
    }
    $mode |= O_APPEND   if  $access =~ /a/i;
    #$mode |= O_TEXT   if  $access =~ /t/i;
    # Some versions of the Fcntl module are broken and won't autoload O_TEXT:
    if(  $access =~ /t/i  ) {
	my $o_text= eval "O_TEXT";
	$o_text= 0x4000   if  $@;
	$mode |= $o_text;
    }
    $mode |= O_BINARY   if  $access =~ /b/i;
    my $fd = eval { OsFHandleOpenFd( $osfh, $mode ) };
    if ($@) {
	return tie *{$fh}, __PACKAGE__, $osfh;
    }
    return  undef unless  $fd;
    return  open( $fh, $pref."&=".(0+$fd) );
}

sub GetOsFHandle {
    if(  1 != @_  ) {
	croak 'Win32API::File Usage:  $OsFHandle= GetOsFHandle(FILE)';
    }
    my( $file )= @_;
    if(  ! ref($file)  ) {
	if(  $file !~ /('|::)/  ) {
	    $file= caller() . "::" . $file;
	}
	no strict "refs";
	# The eval "" is necessary in Perl 5.6, avoid it otherwise.
	my $tied = !defined($^]) || $^] < 5.008
                       ? eval "tied *{$file}"
                       : tied *{$file};

	if (UNIVERSAL::isa($tied => __PACKAGE__)) {
		return $tied->win32_handle;
	}

	$file= *{$file};
    }
    my( $fd )= fileno($file);
    if(  ! defined( $fd )  ) {
	if(  $file =~ /^\d+\Z/  ) {
	    $fd= $file;
	} else {
	    return ();	# $! should be set by fileno().
	}
    }
    my $h= FdGetOsFHandle( $fd );
    if(  INVALID_HANDLE_VALUE() == $h  ) {
	$h= "";
    } elsif(  "0" eq $h  ) {
	$h= "0 but true";
    }
    return $h;
}

sub getFileSize {
    croak 'Win32API::File Usage:  $size= getFileSize($hNativeHandle)'
	if @_ != 1;

    my $handle    = shift;
    my $high_size = 0;

    my $low_size = GetFileSize($handle, $high_size);

    my $retval = $_64BITINT ? $high_size : Math::BigInt->new($high_size);

    $retval <<= $THIRTY_TWO;
    $retval +=  $low_size;

    return $retval;
}

sub setFilePointer {
    croak 'Win32API::File Usage:  $pos= setFilePointer($hNativeHandle, $posl, $from_where)'
	if @_ != 3;

    my ($handle, $pos, $from_where) = @_;

    my ($pos_low, $pos_high) = ($pos, 0);

    if ($_64BITINT) {
	$pos_low  = ($pos & $FFFFFFFF);
	$pos_high = (($pos >> $THIRTY_TWO) & $FFFFFFFF);
    }
    elsif (UNIVERSAL::isa($pos => 'Math::BigInt')) {
	$pos_low  = ($pos & $FFFFFFFF)->numify();
	$pos_high = (($pos >> $THIRTY_TWO) & $FFFFFFFF)->numify();
    }

    my $retval = SetFilePointer($handle, $pos_low, $pos_high, $from_where);

    if (defined $pos_high && $pos_high != 0) {
	if (! $_64BITINT) {
	    $retval   = Math::BigInt->new($retval);
	    $pos_high = Math::BigInt->new($pos_high);
	}

	$retval += $pos_high << $THIRTY_TWO;
    }

    return $retval;
}

sub attrLetsToBits
{
    my( $lets )= @_;
    my( %a )= (
      "a"=>FILE_ATTRIBUTE_ARCHIVE(),	"c"=>FILE_ATTRIBUTE_COMPRESSED(),
      "h"=>FILE_ATTRIBUTE_HIDDEN(),	"o"=>FILE_ATTRIBUTE_OFFLINE(),
      "r"=>FILE_ATTRIBUTE_READONLY(),	"s"=>FILE_ATTRIBUTE_SYSTEM(),
      "t"=>FILE_ATTRIBUTE_TEMPORARY() );
    my( $bits )= 0;
    foreach(  split(//,$lets)  ) {
	croak "Win32API::File::attrLetsToBits: Unknown attribute letter ($_)"
	  unless  exists $a{$_};
	$bits |= $a{$_};
    }
    return $bits;
}

use vars qw( @_createFile_Opts %_createFile_Opts );
@_createFile_Opts= qw( Access Create Share Attributes
		       Flags Security Model );
@_createFile_Opts{@_createFile_Opts}= (1) x @_createFile_Opts;

sub createFile
{
    my $opts= "";
    if(  2 <= @_  &&  "HASH" eq ref($_[$#_])  ) {
	$opts= pop( @_ );
    }
    my( $sPath, $svAccess, $svShare )= @_;
    if(  @_ < 1  ||  3 < @_  ) {
	croak "Win32API::File::createFile() usage:  \$hObject= createFile(\n",
	      "  \$sPath, [\$svAccess_qrw_ktn_ce,[\$svShare_rwd,]]",
	      " [{Option=>\$Value}] )\n",
	      "    options: @_createFile_Opts\nCalled";
    }
    my( $create, $flags, $sec, $model )= ( "", 0, [], 0 );
    if(  ref($opts)  ) {
        my @err= grep( ! $_createFile_Opts{$_}, keys(%$opts) );
	@err  and  croak "_createFile:  Invalid options (@err)";
	$flags= $opts->{Flags}		if  exists( $opts->{Flags} );
	$flags |= attrLetsToBits( $opts->{Attributes} )
					if  exists( $opts->{Attributes} );
	$sec= $opts->{Security}		if  exists( $opts->{Security} );
	$model= $opts->{Model}		if  exists( $opts->{Model} );
	$svAccess= $opts->{Access}	if  exists( $opts->{Access} );
	$create= $opts->{Create}	if  exists( $opts->{Create} );
	$svShare= $opts->{Share}	if  exists( $opts->{Share} );
    }
    $svAccess= "r"		unless  defined($svAccess);
    $svShare= "rw"		unless  defined($svShare);
    if(  $svAccess =~ /^[qrw ktn ce]*$/i  ) {
	( my $c= $svAccess ) =~ tr/qrw QRW//d;
	$create= $c   if  "" ne $c  &&  "" eq $create;
	local( $_ )= $svAccess;
	$svAccess= 0;
	$svAccess |= GENERIC_READ()   if  /r/i;
	$svAccess |= GENERIC_WRITE()   if  /w/i;
    } elsif(  "?" eq $svAccess  ) {
	croak
	  "Win32API::File::createFile:  \$svAccess can use the following:\n",
	      "    One or more of the following:\n",
	      "\tq -- Query access (same as 0)\n",
	      "\tr -- Read access (GENERIC_READ)\n",
	      "\tw -- Write access (GENERIC_WRITE)\n",
	      "    At most one of the following:\n",
	      "\tk -- Keep if exists\n",
	      "\tt -- Truncate if exists\n",
	      "\tn -- New file only (fail if file already exists)\n",
	      "    At most one of the following:\n",
	      "\tc -- Create if doesn't exist\n",
	      "\te -- Existing file only (fail if doesn't exist)\n",
	      "  ''   is the same as 'q  k e'\n",
	      "  'r'  is the same as 'r  k e'\n",
	      "  'w'  is the same as 'w  t c'\n",
	      "  'rw' is the same as 'rw k c'\n",
	      "  'rt' or 'rn' implies 'c'.\n",
	      "  Or \$svAccess can be numeric.\n", "Called from";
    } elsif(  $svAccess == 0  &&  $svAccess !~ /^[-+.]*0/  ) {
	croak "Win32API::File::createFile:  Invalid \$svAccess ($svAccess)";
    }
    if(  $create =~ /^[ktn ce]*$/  ) {
        local( $_ )= $create;
        my( $k, $t, $n, $c, $e )= ( scalar(/k/i), scalar(/t/i),
	  scalar(/n/i), scalar(/c/i), scalar(/e/i) );
	if(  1 < $k + $t + $n  ) {
	    croak "Win32API::File::createFile: \$create must not use ",
	      qq<more than one of "k", "t", and "n" ($create)>;
	}
	if(  $c  &&  $e  ) {
	    croak "Win32API::File::createFile: \$create must not use ",
	      qq<both "c" and "e" ($create)>;
	}
	my $r= ( $svAccess & GENERIC_READ() ) == GENERIC_READ();
	my $w= ( $svAccess & GENERIC_WRITE() ) == GENERIC_WRITE();
	if(  ! $k  &&  ! $t  &&  ! $n  ) {
	    if(  $w  &&  ! $r  ) {		$t= 1;
	    } else {				$k= 1; }
	}
	if(  $k  ) {
	    if(  $c  ||  $w && ! $e  ) {	$create= OPEN_ALWAYS();
	    } else {				$create= OPEN_EXISTING(); }
	} elsif(  $t  ) {
	    if(  $e  ) {			$create= TRUNCATE_EXISTING();
	    } else {				$create= CREATE_ALWAYS(); }
	} else { # $n
	    if(  ! $e  ) {			$create= CREATE_NEW();
	    } else {
		croak "Win32API::File::createFile: \$create must not use ",
		  qq<both "n" and "e" ($create)>;
	    }
	}
    } elsif(  "?" eq $create  ) {
	croak 'Win32API::File::createFile: $create !~ /^[ktn ce]*$/;',
	      ' pass $svAccess as "?" for more information.';
    } elsif(  $create == 0  &&  $create ne "0"  ) {
	croak "Win32API::File::createFile: Invalid \$create ($create)";
    }
    if(  $svShare =~ /^[drw]*$/  ) {
        my %s= ( "d"=>FILE_SHARE_DELETE(), "r"=>FILE_SHARE_READ(),
	         "w"=>FILE_SHARE_WRITE() );
        my @s= split(//,$svShare);
	$svShare= 0;
	foreach( @s ) {
	    $svShare |= $s{$_};
	}
    } elsif(  $svShare == 0  &&  $svShare !~ /^[-+.]*0/  ) {
	croak "Win32API::File::createFile: Invalid \$svShare ($svShare)";
    }
    return  CreateFileA(
	      $sPath, $svAccess, $svShare, $sec, $create, $flags, $model );
}


sub getLogicalDrives
{
    my( $ref )= @_;
    my $s= "";
    if(  ! GetLogicalDriveStringsA( 256, $s )  ) {
	return undef;
    }
    if(  ! defined($ref)  ) {
	return  split( /\0/, $s );
    } elsif(  "ARRAY" ne ref($ref)  ) {
	croak 'Usage:  C<@arr= getLogicalDrives()> ',
	      'or C<getLogicalDrives(\\@arr)>', "\n";
    }
    @$ref= split( /\0/, $s );
    return $ref;
}

###############################################################################
#   Experimental Tied Handle and Object Oriented interface.                   #
###############################################################################

sub new {
	my $class = shift;
	$class = ref $class || $class;

	my $self = IO::File::new($class);
	tie *$self, __PACKAGE__;

	$self->open(@_) if @_;

	return $self;
}

sub TIEHANDLE {
	my ($class, $win32_handle) = @_;
	$class = ref $class || $class;

	return bless {
		_win32_handle => $win32_handle,
		_binmode      => 0,
		_buffered     => 0,
		_buffer       => '',
		_eof          => 0,
		_fileno       => undef,
		_access       => 'r',
		_append       => 0,
	}, $class;
}

# This is called for getting the tied object from hard refs to glob refs in
# some cases, for reasons I don't quite grok.

sub FETCH { return $_[0] }

# Public accessors

sub win32_handle{ $_[0]->{_win32_handle}||= $_[1] }

# Protected accessors

sub _buffer	{ $_[0]->{_buffer}	||= $_[1] }
sub _binmode	{ $_[0]->{_binmode}	||= $_[1] }
sub _fileno	{ $_[0]->{_fileno}	||= $_[1] }
sub _access	{ $_[0]->{_access}	||= $_[1] }
sub _append	{ $_[0]->{_append}	||= $_[1] }

# Tie interface

sub OPEN {
	my $self  = shift;
	my $expr  = shift;
	croak "Only the two argument form of open is supported at this time" if @_;
# FIXME: this needs to parse the full Perl open syntax in $expr

	my ($mixed, $mode, $path) =
		($expr =~ /^\s* (\+)? \s* (<|>|>>)? \s* (.*?) \s*$/x);

	croak "Unsupported open mode" if not $path;

	my $access = 'r';
	my $append = $mode eq '>>' ? 1 : 0;

	if ($mixed) {
		$access = 'rw';
	} elsif($mode eq '>') {
		$access = 'w';
	}

	my $w32_handle = createFile($path, $access);

	$self->win32_handle($w32_handle);

	$self->seek(1,2) if $append;

	$self->_access($access);
	$self->_append($append);

	return 1;
}

sub BINMODE {
	$_[0]->_binmode(1);
}

sub WRITE {
	my ($self, $buf, $len, $offset, $overlap) = @_;

	if ($offset) {
		$buf = substr($buf, $offset);
		$len = length($buf);
	}

	$len       = length($buf) if not defined $len;

	$overlap   = [] if not defined $overlap;;

	my $bytes_written = 0;

	WriteFile (
		$self->win32_handle, $buf, $len,
		$bytes_written, $overlap
	);

	return $bytes_written;
}

sub PRINT {
	my $self = shift;

	my $buf = join defined $, ? $, : "" => @_;

	$buf =~ s/\012/\015\012/sg unless $self->_binmode();

	$buf .= $\ if defined $\;

	$self->WRITE($buf, length($buf), 0);
}

sub READ {
	my $self = shift;
	my $into = \$_[0]; shift;
	my ($len, $offset, $overlap) = @_;

	my $buffer     = defined $self->_buffer ? $self->_buffer : "";
	my $buf_length = length($buffer);
	my $bytes_read = 0;
	my $data;
	$offset        = 0 if not defined $offset;

	if ($buf_length >= $len) {
		$data       = substr($buffer, 0, $len => "");
		$bytes_read = $len;
		$self->_buffer($buffer);
	} else {
		if ($buf_length > 0) {
			$len -= $buf_length;
			substr($$into, $offset) = $buffer;
			$offset += $buf_length;
		}

		$overlap ||= [];

		ReadFile (
			$self->win32_handle, $data, $len,
			$bytes_read, $overlap
		);
	}

	$$into = "" if not defined $$into;

	substr($$into, $offset) = $data;

	return $bytes_read;
}

sub READLINE {
	my $self = shift;
	my $line = "";

	while ((index $line, $/) == -1) { # read until end of line marker
		my $char = $self->GETC();

		last if !defined $char || $char eq '';

		$line .= $char;
	}

	return undef if $line eq '';

	return $line;
}


sub FILENO {
	my $self = shift;

	return $self->_fileno() if defined $self->_fileno();

	return -1 if $^O eq 'cygwin';

# FIXME: We don't always open the handle, better to query the handle or to set
# the right access info at TIEHANDLE time.

	my $access = $self->_access();
	my $mode   = $access eq 'rw' ? O_RDWR :
		$access eq 'w' ? O_WRONLY : O_RDONLY;

	$mode |= O_APPEND if $self->_append();

	$mode |= O_TEXT   if not $self->_binmode();

	return $self->_fileno ( OsfHandleOpenFd (
		$self->win32_handle, $mode
	));
}

sub SEEK {
	my ($self, $pos, $whence) = @_;

	$whence = 0 if not defined $whence;
	my @file_consts = map {
		fileConstant($_)
	} qw(FILE_BEGIN FILE_CURRENT FILE_END);

	my $from_where = $file_consts[$whence];

	return setFilePointer($self->win32_handle, $pos, $from_where);
}

sub TELL {
# SetFilePointer with position 0 at FILE_CURRENT will return position.
	return $_[0]->SEEK(0, 1);
}

sub EOF {
	my $self = shift;

	my $current = $self->TELL() + 0;
	my $end     = getFileSize($self->win32_handle) + 0;

	return $current == $end;
}

sub CLOSE {
	my $self = shift;

	my $retval = 1;
	
	if (defined $self->win32_handle) {
		$retval = CloseHandle($self->win32_handle);

		$self->win32_handle(undef);
	}

	return $retval;
}

# Only close the handle on explicit close, too many problems otherwise.
sub UNTIE {}

sub DESTROY {}

# End of Tie/OO Interface

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

#line 3047

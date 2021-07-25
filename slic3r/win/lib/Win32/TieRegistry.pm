#line 1 "Win32/TieRegistry.pm"
package Win32::TieRegistry;

# Win32/TieRegistry.pm -- Perl module to easily use a Registry
# (on Win32 systems so far).
# by Tye McQueen, tye@metronet.com, see http://www.metronet.com/~tye/.

#
# Skip to "=head" line for user documentation.
#
use 5.006;
use strict;
use Carp;
use Tie::Hash ();

use vars qw( $PACK $VERSION @ISA @EXPORT @EXPORT_OK );
BEGIN {
	$PACK    = 'Win32::TieRegistry';
	$VERSION = '0.30';
	@ISA     = 'Tie::Hash';
}

# Required other modules:
use Win32API::Registry 0.24 qw( :KEY_ :HKEY_ :REG_ );

#Optional other modules:
use vars qw( $_NoMoreItems $_FileNotFound $_TooSmall $_MoreData $_SetDualVar );

if ( eval { require Win32::WinError } ) {
    $_NoMoreItems  = Win32::WinError::constant("ERROR_NO_MORE_ITEMS",0);
    $_FileNotFound = Win32::WinError::constant("ERROR_FILE_NOT_FOUND",0);
    $_TooSmall     = Win32::WinError::constant("ERROR_INSUFFICIENT_BUFFER",0);
    $_MoreData     = Win32::WinError::constant("ERROR_MORE_DATA",0);
} else {
    $_NoMoreItems  = "^No more data";
    $_FileNotFound = "cannot find the file";
    $_TooSmall     = " data area passed to ";
    $_MoreData     = "^more data is avail";
}
if ( $_SetDualVar = eval { require SetDualVar }  ) {
    import SetDualVar;
}

#Implementation details:
#    When opened:
#	HANDLE		long; actual handle value
#	MACHINE		string; name of remote machine ("" if local)
#	PATH		list ref; machine-relative full path for this key:
#			["LMachine","System","Disk"]
#			["HKEY_LOCAL_MACHINE","System","Disk"]
#	DELIM		char; delimiter used to separate subkeys (def="\\")
#	OS_DELIM	char; always "\\" for Win32
#	ACCESS		long; usually KEY_ALL_ACCESS, perhaps KEY_READ, etc.
#	ROOTS		string; var name for "Lmachine"->HKEY_LOCAL_MACHINE map
#	FLAGS		int; bits to control certain options
#    Often:
#	VALUES		ref to list of value names (data/type never cached)
#	SUBKEYS		ref to list of subkey names
#	SUBCLASSES	ref to list of subkey classes
#	SUBTIMES	ref to list of subkey write times
#	MEMBERS		ref to list of subkey_name.DELIM's, DELIM.value_name's
#	MEMBHASH	hash ref to with MEMBERS as keys and 1's as values
#    Once Key "Info" requested:
#	Class CntSubKeys CntValues MaxSubKeyLen MaxSubClassLen
#	MaxValNameLen MaxValDataLen SecurityLen LastWrite
#    If is tied to a hash and iterating over key values:
#	PREVIDX		int; index of last MEMBERS element return
#    If is the key object returned by Load():
#	UNLOADME	list ref; information about Load()ed key
#    If is a subkey of a "loaded" key other than the one returned by Load():
#	DEPENDON	obj ref; object that can't be destroyed before us


#Package-local variables:

# Option flag bits:
use vars qw(
	$Flag_ArrVal $Flag_TieVal $Flag_DualTyp $Flag_DualBin
	$Flag_FastDel $Flag_HexDWord $Flag_Split $Flag_FixNulls
);
BEGIN {
	$Flag_ArrVal   = 0x0001;
	$Flag_TieVal   = 0x0002;
	$Flag_FastDel  = 0x0004;
	$Flag_HexDWord = 0x0008;
	$Flag_Split    = 0x0010;
	$Flag_DualTyp  = 0x0020;
	$Flag_DualBin  = 0x0040;
	$Flag_FixNulls = 0x0080;
}

use vars qw( $RegObj %_Roots %RegHash $Registry );

# Short-hand for HKEY_* constants:
%_Roots= (
    "Classes"  => HKEY_CLASSES_ROOT,
    "CUser"    => HKEY_CURRENT_USER,
    "LMachine" => HKEY_LOCAL_MACHINE,
    "Users"    => HKEY_USERS,
    "PerfData" => HKEY_PERFORMANCE_DATA, # Too picky to be useful
    "CConfig"  => HKEY_CURRENT_CONFIG,
    "DynData"  => HKEY_DYN_DATA,         # Too picky to be useful
);

# Basic master Registry object:
$RegObj= {};
@$RegObj{qw( HANDLE MACHINE PATH DELIM OS_DELIM ACCESS FLAGS ROOTS )}= (
    "NONE", "", [], "\\", "\\",
    KEY_READ|KEY_WRITE, $Flag_HexDWord|$Flag_FixNulls, "${PACK}::_Roots" );
$RegObj->{FLAGS} |= $Flag_DualTyp|$Flag_DualBin   if  $_SetDualVar;
bless $RegObj;

# Fill cache for master Registry object:
@$RegObj{qw( VALUES SUBKEYS SUBCLASSES SUBTIMES )}= (
    [],  [ keys(%_Roots) ],  [],  []  );
grep( s#$#$RegObj->{DELIM}#,
  @{ $RegObj->{MEMBERS}= [ @{$RegObj->{SUBKEYS}} ] } );
@$RegObj{qw( Class MaxSubKeyLen MaxSubClassLen MaxValNameLen
  MaxValDataLen SecurityLen LastWrite CntSubKeys CntValues )}=
    ( "", 0, 0, 0, 0, 0, 0, 0, 0 );

# Create master Registry tied hash:
$RegObj->Tie( \%RegHash );

# Create master Registry combination object and tied hash reference:
$Registry= \%RegHash;
bless $Registry;


# Preloaded methods go here.


# Map option names to name of subroutine that controls that option:
use vars qw( @_opt_subs %_opt_subs );
@_opt_subs= qw( Delimiter ArrayValues TieValues SplitMultis DWordsToHex
	FastDelete FixSzNulls DualTypes DualBinVals AllowLoad AllowSave );
@_opt_subs{@_opt_subs}= @_opt_subs;

sub import
{
    my $pkg      = shift(@_);
    my $level    = $Exporter::ExportLevel;
    my $expto    = caller($level);
    my @export   = ();
    my @consts   = ();
    my $registry = $Registry->Clone;
    local( $_ );
    while(  @_  ) {
	$_= shift(@_);
	if(  /^\$(\w+::)*\w+$/  ) {
	    push( @export, "ObjVar" )   if  /^\$RegObj$/;
	    push( @export, $_ );
	} elsif(  /^\%(\w+::)*\w+$/  ) {
	    push( @export, $_ );
	} elsif(  /^[$%]/  ) {
	    croak "${PACK}->import:  Invalid variable name ($_)";
	} elsif(  /^:/  ||  /^(H?KEY|REG)_/  ) {
	    push( @consts, $_ );
	} elsif(  ! @_  ) {
	    croak "${PACK}->import:  Missing argument after option ($_)";
	} elsif(  exists $_opt_subs{$_}  ) {
	    $_= $_opt_subs{$_};
	    $registry->$_( shift(@_) );
	} elsif(  /^TiedRef$/  ) {
	    $_= shift(@_);
	    if(  ! ref($_)  &&  /^(\$?)(\w+::)*\w+$/  ) {
		$_= '$'.$_   unless  '$' eq $1;
	    } elsif(  "SCALAR" ne ref($_)  ) {
		croak "${PACK}->import:  Invalid var after TiedRef ($_)";
	    }
	    push( @export, $_ );
	} elsif(  /^TiedHash$/  ) {
	    $_= shift(@_);
	    if(  ! ref($_)  &&  /^(\%?)(\w+::)*\w+$/  ) {
		$_= '%'.$_   unless  '%' eq $1;
	    } elsif(  "HASH" ne ref($_)  ) {
		croak "${PACK}->import:  Invalid var after TiedHash ($_)";
	    }
	    push( @export, $_ );
	} elsif(  /^ObjectRef$/  ) {
	    $_= shift(@_);
	    if(  ! ref($_)  &&  /^(\$?)(\w+::)*\w+$/  ) {
		push( @export, "ObjVar" );
		$_= '$'.$_   unless  '$' eq $1;
	    } elsif(  "SCALAR" eq ref($_)  ) {
		push( @export, "ObjRef" );
	    } else {
		croak "${PACK}->import:  Invalid var after ObjectRef ($_)";
	    }
	    push( @export, $_ );
	} elsif(  /^ExportLevel$/  ) {
	    $level= shift(@_);
	    $expto= caller($level);
	} elsif(  /^ExportTo$/  ) {
	    undef $level;
	    $expto= caller($level);
	} else {
	    croak "${PACK}->import:  Invalid option ($_)";
	}
    }
    Win32API::Registry->export( $expto, @consts ) if  @consts;
    @export= ('$Registry')   unless  @export;
    while(  @export  ) {
	$_= shift( @export );
	if(  /^\$((?:\w+::)*)(\w+)$/  ) {
	    my( $pack, $sym )= ( $1, $2 );
	    $pack= $expto   unless  defined($pack)  &&  "" ne $pack;
	    no strict 'refs';
	    *{"${pack}::$sym"}= \${"${pack}::$sym"};
	    ${"${pack}::$sym"}= $registry;
	} elsif(  /^\%((?:\w+::)*)(\w+)$/  ) {
	    my( $pack, $sym )= ( $1, $2 );
	    $pack= $expto   unless  defined($pack)  &&  "" ne $pack;
	    no strict 'refs';
	    *{"${pack}::$sym"}= \%{"${pack}::$sym"};
	    $registry->Tie( \%{"${pack}::$sym"} );
	} elsif(  "SCALAR" eq ref($_)  ) {
	    $$_= $registry;
	} elsif(  "HASH" eq ref($_)  ) {
	    $registry->Tie( $_ );
	} elsif(  /^ObjVar$/  ) {
	    $_= shift( @_ );
	    /^\$((?:\w+::)*)(\w+)$/;
	    my( $pack, $sym )= ( $1, $2 );
	    $pack= $expto   unless  defined($pack)  &&  "" ne $pack;
	    no strict 'refs';
	    *{"${pack}::$sym"}= \${"${pack}::$sym"};
	    ${"${pack}::$sym"}= $registry->ObjectRef;
	} elsif(  /^ObjRef$/  ) {
	    ${shift(@_)}= $registry->ObjectRef;
	} else {
	    die "Impossible var to export ($_)";
	}
    }
}


use vars qw( @_new_Opts %_new_Opts );
@_new_Opts= qw( ACCESS DELIM MACHINE DEPENDON );
@_new_Opts{@_new_Opts}= (1) x @_new_Opts;

sub _new
{
    my $this= shift( @_ );
    $this= tied(%$this)   if  ref($this)  &&  tied(%$this);
    my $class= ref($this) || $this;
    my $self= {};
    my( $handle, $rpath, $opts )= @_;
    if(  @_ < 2  ||  "ARRAY" ne ref($rpath)  ||  3 < @_
     ||  3 == @_ && "HASH" ne ref($opts)  ) {
	croak "Usage:  ${PACK}->_new( \$handle, \\\@path, {OPT=>VAL,...} );\n",
	      "  options: @_new_Opts\nCalled";
    }
    @$self{qw( HANDLE PATH )}= ( $handle, $rpath );
    @$self{qw( MACHINE ACCESS DELIM OS_DELIM ROOTS FLAGS )}=
      ( $this->Machine, $this->Access, $this->Delimiter,
        $this->OS_Delimiter, $this->_Roots, $this->_Flags );
    if(  ref($opts)  ) {
	my @err= grep( ! $_new_Opts{$_}, keys(%$opts) );
	@err  and  croak "${PACK}->_new:  Invalid options (@err)";
	@$self{ keys(%$opts) }= values(%$opts);
    }
    bless $self, $class;
    return $self;
}


sub _split
{
    my $self= shift( @_ );
    $self= tied(%$self)   if  tied(%$self);
    my $path= shift( @_ );
    my $delim= @_ ? shift(@_) : $self->Delimiter;
    my $list= [ split( /\Q$delim/, $path ) ];
    return $list;
}


sub _rootKey
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $keyPath= shift(@_);
    my $delim= @_ ? shift(@_) : $self->Delimiter;
    my( $root, $subPath );
    if(  "ARRAY" eq ref($keyPath)  ) {
	$subPath= $keyPath;
    } else {
	$subPath= $self->_split( $keyPath, $delim );
    }
    $root= shift( @$subPath );
    if(  $root =~ /^HKEY_/  ) {
	my $handle= Win32API::Registry::constant($root,0);
	$handle  or  croak "Invalid HKEY_ constant ($root): $!";
	return( $self->_new( $handle, [$root], {DELIM=>$delim} ),
	        $subPath );
    } elsif(  $root =~ /^([-+]|0x)?\d/  ) {
	return( $self->_new( $root, [sprintf("0x%lX",$root)],
			     {DELIM=>$delim} ),
		$subPath );
    } else {
	my $roots= $self->Roots;
	if(  $roots->{$root}  ) {
	    return( $self->_new( $roots->{$root}, [$root], {DELIM=>$delim} ),
	            $subPath );
	}
	croak "No such root key ($root)";
    }
}


sub _open
{
    my $this    = shift(@_);
    $this       = tied(%$this)   if  ref($this)  &&  tied(%$this);
    my $subPath = shift(@_);
    my $sam     = @_ ? shift(@_) : $this->Access;
    my $subKey  = join( $this->OS_Delimiter, @$subPath );
    my $handle  = 0;
    $this->RegOpenKeyEx( $subKey, 0, $sam, $handle ) or return ();
    return $this->_new( $handle, [ @{$this->_Path}, @$subPath ],
      { ACCESS=>$sam, ( defined($this->{UNLOADME}) ? ("DEPENDON",$this)
	: defined($this->{DEPENDON}) ? ("DEPENDON",$this->{DEPENDON}) : () )
      } );
}


sub ObjectRef
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    return $self;
}


sub _constant
{
    my( $name, $desc )= @_;
    my $value= Win32API::Registry::constant( $name, 0 );
    my $func= (caller(1))[3];
    if(  0 == $value  ) {
	if(  $! =~ /invalid/i  ) {
	    croak "$func: Invalid $desc ($name)";
	} elsif(  0 != $!  ) {
	    croak "$func: \u$desc ($name) not support on this platform";
	}
    }
    return $value;
}


sub _connect
{
    my $this= shift(@_);
    $this= tied(%$this)   if  ref($this)  &&  tied(%$this);
    my $subPath= pop(@_);
    $subPath= $this->_split( $subPath )   unless  ref($subPath);
    my $machine= @_ ? shift(@_) : shift(@$subPath);
    my $handle= 0;
    my( $temp )= $this->_rootKey( [@$subPath] );
    $temp->RegConnectRegistry( $machine, $temp->Handle, $handle )
      or  return ();
    my $self= $this->_new( $handle, [shift(@$subPath)], {MACHINE=>$machine} );
    return( $self, $subPath );
}


use vars qw( @Connect_Opts %Connect_Opts );
@Connect_Opts= qw(Access Delimiter);
@Connect_Opts{@Connect_Opts}= (1) x @Connect_Opts;

sub Connect
{
    my $this= shift(@_);
    my $tied=  ref($this)  &&  tied(%$this);
    $this= tied(%$this)   if  $tied;
    my( $machine, $key, $opts )= @_;
    my $delim= "";
    my $sam;
    my $subPath;
    if(  @_ < 2  ||  3 < @_
     ||  3 == @_ && "HASH" ne ref($opts)  ) {
	croak "Usage:  \$obj= ${PACK}->Connect(",
	      " \$Machine, \$subKey, { OPT=>VAL,... } );\n",
	      "  options: @Connect_Opts\nCalled";
    }
    if(  ref($opts)  ) {
	my @err= grep( ! $Connect_Opts{$_}, keys(%$opts) );
	@err  and  croak "${PACK}->Connect:  Invalid options (@err)";
    }
    $delim= "$opts->{Delimiter}"   if  defined($opts->{Delimiter});
    $delim= $this->Delimiter   if  "" eq $delim;
    $sam= defined($opts->{Access}) ? $opts->{Access} : $this->Access;
    $sam= _constant($sam,"key access type")   if  $sam =~ /^KEY_/;
    ( $this, $subPath )= $this->_connect( $machine, $key );
    return ()   unless  defined($this);
    my $self= $this->_open( $subPath, $sam );
    return ()   unless  defined($self);
    $self->Delimiter( $delim );
    $self= $self->TiedRef   if  $tied;
    return $self;
}


my @_newVirtual_keys= qw( MEMBERS VALUES SUBKEYS SUBTIMES SUBCLASSES
    Class SecurityLen LastWrite CntValues CntSubKeys
    MaxValNameLen MaxValDataLen MaxSubKeyLen MaxSubClassLen );

sub _newVirtual
{
    my $self= shift(@_);
    my( $rPath, $root, $opts )= @_;
    my $new= $self->_new( "NONE", $rPath, $opts )
      or  return ();
    @{$new}{@_newVirtual_keys}= @{$root->ObjectRef}{@_newVirtual_keys};
    return $new;
}


#$key= new Win32::TieRegistry "LMachine/System/Disk";
#$key= new Win32::TieRegistry "//Server1/LMachine/System/Disk";
#Win32::TieRegistry->new( HKEY_LOCAL_MACHINE, {DELIM=>"/",ACCESS=>KEY_READ} );
#Win32::TieRegistry->new( [ HKEY_LOCAL_MACHINE, ".../..." ], {DELIM=>$DELIM} );
#$key->new( ... );

use vars qw( @new_Opts %new_Opts );
@new_Opts= qw(Access Delimiter);
@new_Opts{@new_Opts}= (1) x @new_Opts;

sub new
{
    my $this= shift( @_ );
    $this= tied(%$this)   if  ref($this)  &&  tied(%$this);
    if(  ! ref($this)  ) {
	no strict "refs";
	my $self= ${"${this}::Registry"};
	croak "${this}->new failed since ${PACK}::new sees that ",
	  "\$${this}::Registry is not an object."
	  if  ! ref($self);
	$this= $self->Clone;
    }
    my( $subKey, $opts )= @_;
    my $delim= "";
    my $dlen;
    my $sam;
    my $subPath;
    if(  @_ < 1  ||  2 < @_
     ||  2 == @_ && "HASH" ne ref($opts)  ) {
	croak "Usage:  \$obj= ${PACK}->new( \$subKey, { OPT=>VAL,... } );\n",
	      "  options: @new_Opts\nCalled";
    }
    if(  defined($opts)  ) {
	my @err= grep( ! $new_Opts{$_}, keys(%$opts) );
	@err  and  die "${PACK}->new:  Invalid options (@err)";
    }
    $delim= "$opts->{Delimiter}"   if  defined($opts->{Delimiter});
    $delim= $this->Delimiter   if  "" eq $delim;
    $dlen= length($delim);
    $sam= defined($opts->{Access}) ? $opts->{Access} : $this->Access;
    $sam= _constant($sam,"key access type")   if  $sam =~ /^KEY_/;
    if(  "ARRAY" eq ref($subKey)  ) {
	$subPath= $subKey;
	if(  "NONE" eq $this->Handle  &&  @$subPath  ) {
	    ( $this, $subPath )= $this->_rootKey( $subPath );
	}
    } elsif(  $delim x 2 eq substr($subKey,0,2*$dlen)  ) {
	my $path= $this->_split( substr($subKey,2*$dlen), $delim );
	my $mach= shift(@$path);
	if(  ! @$path  ) {
	    return $this->_newVirtual( $path, $Registry,
			    {MACHINE=>$mach,DELIM=>$delim,ACCESS=>$sam} );
	}
	( $this, $subPath )= $this->_connect( $mach, $path );
	return ()   if  ! defined($this);
	if(  0 == @$subPath  ) {
	    $this->Delimiter( $delim );
	    return $this;
	}
    } elsif(  $delim eq substr($subKey,0,$dlen)  ) {
	( $this, $subPath )= $this->_rootKey( substr($subKey,$dlen), $delim );
    } elsif(  "NONE" eq $this->Handle  &&  "" ne $subKey  ) {
	my( $mach )= $this->Machine;
	if(  $mach  ) {
	    ( $this, $subPath )= $this->_connect( $mach, $subKey );
	} else {
	    ( $this, $subPath )= $this->_rootKey( $subKey, $delim );
	}
    } else {
	$subPath= $this->_split( $subKey, $delim );
    }
    return ()   unless  defined($this);
    if(  0 == @$subPath  &&  "NONE" eq $this->Handle  ) {
	return $this->_newVirtual( $this->_Path, $this,
				   { DELIM=>$delim, ACCESS=>$sam } );
    }
    my $self= $this->_open( $subPath, $sam );
    return ()   unless  defined($self);
    $self->Delimiter( $delim );
    return $self;
}


sub Open
{
    my $self= shift(@_);
    my $tied=  ref($self)  &&  tied(%$self);
    $self= tied(%$self)   if  $tied;
    $self= $self->new( @_ );
    $self= $self->TiedRef   if  defined($self)  &&  $tied;
    return $self;
}


sub Clone
{
    my $self= shift( @_ );
    my $new= $self->Open("");
    return $new;
}


{ my @flush;
    sub Flush
    {
	my $self= shift(@_);
	$self= tied(%$self)   if  tied(%$self);
	my( $flush )= @_;
	@_  and  croak "Usage:  \$key->Flush( \$bFlush );";
	return 0   if  "NONE" eq $self->Handle;
	@flush= qw( VALUES SUBKEYS SUBCLASSES SUBTIMES MEMBERS Class
		    CntSubKeys CntValues MaxSubKeyLen MaxSubClassLen
		    MaxValNameLen MaxValDataLen SecurityLen LastWrite PREVIDX )
	  unless  @flush;
	delete( @$self{@flush} );
	if(  defined($flush)  &&  $flush  ) {
	    return $self->RegFlushKey();
	} else {
	    return 1;
	}
    }
}


sub _DualVal
{
    my( $hRef, $num )= @_;
    if(  $_SetDualVar  &&  $$hRef{$num}  ) {
	&SetDualVar( $num, "$$hRef{$num}", 0+$num );
    }
    return $num;
}


use vars qw( @_RegDataTypes %_RegDataTypes );
@_RegDataTypes= qw( REG_SZ REG_EXPAND_SZ REG_BINARY REG_LINK REG_MULTI_SZ
		    REG_DWORD_LITTLE_ENDIAN REG_DWORD_BIG_ENDIAN REG_DWORD
		    REG_RESOURCE_LIST REG_FULL_RESOURCE_DESCRIPTOR
		    REG_RESOURCE_REQUIREMENTS_LIST REG_NONE );
# Make sure that REG_DWORD appears _after_ other REG_DWORD_*
# items above and that REG_NONE appears _last_.
foreach(  @_RegDataTypes  ) {
    $_RegDataTypes{Win32API::Registry::constant($_,0)}= $_;
}

sub GetValue
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    1 == @_  or  croak "Usage:  (\$data,\$type)= \$key->GetValue('ValName');";
    my( $valName )= @_;
    my( $valType, $valData, $dLen )= (0,"",0);
    return ()   if  "NONE" eq $self->Handle;
    $self->RegQueryValueEx( $valName, [], $valType, $valData,
      $dLen= ( defined($self->{MaxValDataLen}) ? $self->{MaxValDataLen} : 0 )
    )  or  return ();
    if(  REG_DWORD == $valType  ) {
	my $val= unpack("L",$valData);
	$valData= sprintf "0x%08.8lX", $val   if  $self->DWordsToHex;
	&SetDualVar( $valData, $valData, $val )   if  $self->DualBinVals
    } elsif(  REG_BINARY == $valType  &&  length($valData) <= 4  ) {
	&SetDualVar( $valData, $valData, hex reverse unpack("h*",$valData) )
	  if  $self->DualBinVals;
    } elsif(  ( REG_SZ == $valType || REG_EXPAND_SZ == $valType )
          &&  $self->FixSzNulls  ) {
	substr($valData,-1)= ""   if  "\0" eq substr($valData,-1);
    } elsif(  REG_MULTI_SZ == $valType  &&  $self->SplitMultis  ) {
	## $valData =~ s/\0\0$//;	# Why does this often fail??
	substr($valData,-2)= ""   if  "\0\0" eq substr($valData,-2);
	$valData= [ split( /\0/, $valData, -1 ) ]
    }
    if(  ! wantarray  ) {
	return $valData;
    } elsif(  ! $self->DualTypes  ) {
	return( $valData, $valType );
    } else {
	return(  $valData,  _DualVal( \%_RegDataTypes, $valType )  );
    }
}


sub _ErrNum
{
    # return $^E;
    return Win32::GetLastError();
}


sub _ErrMsg
{
    # return $^E;
    return Win32::FormatMessage( Win32::GetLastError() );
}

sub _Err
{
    my $err;
    # return $^E;
    return _ErrMsg   if  ! $_SetDualVar;
    return &SetDualVar( $err, _ErrMsg, _ErrNum );
}

sub _NoMoreItems
{
    return
      $_NoMoreItems =~ /^\d/
        ?  _ErrNum == $_NoMoreItems
        :  _ErrMsg =~ /$_NoMoreItems/io;
}


sub _FileNotFound
{
    return
      $_FileNotFound =~ /^\d/
        ?  _ErrNum == $_FileNotFound
        :  _ErrMsg =~ /$_FileNotFound/io;
}


sub _TooSmall
{
    return
      $_TooSmall =~ /^\d/
        ?  _ErrNum == $_TooSmall
        :  _ErrMsg =~ /$_TooSmall/io;
}


sub _MoreData
{
    return
      $_MoreData =~ /^\d/
        ?  _ErrNum == $_MoreData
        :  _ErrMsg =~ /$_MoreData/io;
}


sub _enumValues
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my( @names )= ();
    my $pos= 0;
    my $name= "";
    my $nlen= 1+$self->Information("MaxValNameLen");
    while(  $self->RegEnumValue($pos++,$name,my $nlen1=$nlen,[],[],[],[])  ) {
    #RegEnumValue modifies $nlen1
	push( @names, $name );
    }
    if(  ! _NoMoreItems()  ) {
	return ();
    }
    $self->{VALUES}= \@names;
    return 1;
}


sub ValueNames
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \@names= \$key->ValueNames;";
    $self->_enumValues   unless  $self->{VALUES};
    return @{$self->{VALUES}};
}


sub _enumSubKeys
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my( @subkeys, @classes, @times )= ();
    my $pos= 0;
    my( $subkey, $class, $time )= ("","","");
    my( $namSiz, $clsSiz )= $self->Information(
			      qw( MaxSubKeyLen MaxSubClassLen ));
    $namSiz++;  $clsSiz++;
    my $namSiz1 = $namSiz;
    while(  $self->RegEnumKeyEx(
	      $pos++, $subkey, $namSiz, [], $class, $clsSiz, $time )  ) {
	push( @subkeys, $subkey );
	push( @classes, $class );
	push( @times, $time );
	$namSiz = $namSiz1; #RegEnumKeyEx modifies $namSiz
    }
    if(  ! _NoMoreItems()  ) {
	return ();
    }
    $self->{SUBKEYS}= \@subkeys;
    $self->{SUBCLASSES}= \@classes;
    $self->{SUBTIMES}= \@times;
    return 1;
}


sub SubKeyNames
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \@names= \$key->SubKeyNames;";
    $self->_enumSubKeys   unless  $self->{SUBKEYS};
    return @{$self->{SUBKEYS}};
}


sub SubKeyClasses
{
    my $self= shift(@_);
    @_  and  croak "Usage:  \@classes= \$key->SubKeyClasses;";
    $self->_enumSubKeys   unless  $self->{SUBCLASSES};
    return @{$self->{SUBCLASSES}};
}


sub SubKeyTimes
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \@times= \$key->SubKeyTimes;";
    $self->_enumSubKeys   unless  $self->{SUBTIMES};
    return @{$self->{SUBTIMES}};
}


sub _MemberNames
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$arrayRef= \$key->_MemberNames;";
    if(  ! $self->{MEMBERS}  ) {
	$self->_enumValues   unless  $self->{VALUES};
	$self->_enumSubKeys   unless  $self->{SUBKEYS};
	my( @members )= (  map( $_.$self->{DELIM}, @{$self->{SUBKEYS}} ),
			   map( $self->{DELIM}.$_, @{$self->{VALUES}} )  );
	$self->{MEMBERS}= \@members;
    }
    return $self->{MEMBERS};
}


sub _MembersHash
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$hashRef= \$key->_MembersHash;";
    if(  ! $self->{MEMBHASH}  ) {
	my $aRef= $self->_MemberNames;
	$self->{MEMBHASH}= {};
	@{$self->{MEMBHASH}}{@$aRef}= (1) x @$aRef;
    }
    return $self->{MEMBHASH};
}


sub MemberNames
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \@members= \$key->MemberNames;";
    return @{$self->_MemberNames};
}


sub Information
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my( $time, $nkeys, $nvals, $xsec, $xkey, $xcls, $xname, $xdata )=
	("",0,0,0,0,0,0,0);
    my $clen= 8;
    if(  ! $self->RegQueryInfoKey( [], [], $nkeys, $xkey, $xcls,
				   $nvals, $xname, $xdata, $xsec, $time )  ) {
	return ();
    }
    if(  defined($self->{Class})  ) {
	$clen= length($self->{Class});
    } else {
	$self->{Class}= "";
    }
    while(  ! $self->RegQueryInfoKey( $self->{Class}, $clen,
				      [],[],[],[],[],[],[],[],[])
        &&  _MoreData  ) {
	$clen *= 2;
    }
    my( %info );
    @info{ qw( LastWrite CntSubKeys CntValues SecurityLen
	       MaxValDataLen MaxSubKeyLen MaxSubClassLen MaxValNameLen )
    }=       ( $time,    $nkeys,    $nvals,   $xsec,
               $xdata,       $xkey,       $xcls,         $xname );
    if(  @_  ) {
	my( %check );
	@check{keys(%info)}= keys(%info);
	my( @err )= grep( ! $check{$_}, @_ );
	if(  @err  ) {
	    croak "${PACK}::Information- Invalid info requested (@err)";
	}
	return @info{@_};
    } else {
	return %info;
    }
}


sub Delimiter
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    $self= $RegObj   unless  ref($self);
    my( $oldDelim )= $self->{DELIM};
    if(  1 == @_  &&  "" ne "$_[0]"  ) {
	delete $self->{MEMBERS};
	delete $self->{MEMBHASH};
	$self->{DELIM}= "$_[0]";
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldDelim= \$key->Delimiter(\$newDelim);";
    }
    return $oldDelim;
}


sub Handle
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$handle= \$key->Handle;";
    $self= $RegObj   unless  ref($self);
    return $self->{HANDLE};
}


sub Path
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$path= \$key->Path;";
    my $delim= $self->{DELIM};
    $self= $RegObj   unless  ref($self);
    if(  "" eq $self->{MACHINE}  ) {
	return(  $delim . join( $delim, @{$self->{PATH}} ) . $delim  );
    } else {
	return(  $delim x 2
	  . join( $delim, $self->{MACHINE}, @{$self->{PATH}} )
	  . $delim  );
    }
}


sub _Path
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$arrRef= \$key->_Path;";
    $self= $RegObj   unless  ref($self);
    return $self->{PATH};
}


sub Machine
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$machine= \$key->Machine;";
    $self= $RegObj   unless  ref($self);
    return $self->{MACHINE};
}


sub Access
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$access= \$key->Access;";
    $self= $RegObj   unless  ref($self);
    return $self->{ACCESS};
}


sub OS_Delimiter
{
    my $self= shift(@_);
    @_  and  croak "Usage:  \$backslash= \$key->OS_Delimiter;";
    return $self->{OS_DELIM};
}


sub _Roots
{
    my $self= shift(@_);
    $self= tied(%$self)   if  ref($self)  &&  tied(%$self);
    @_  and  croak "Usage:  \$varName= \$key->_Roots;";
    $self= $RegObj   unless  ref($self);
    return $self->{ROOTS};
}


sub Roots
{
    my $self= shift(@_);
    $self= tied(%$self)   if  ref($self)  &&  tied(%$self);
    @_  and  croak "Usage:  \$hashRef= \$key->Roots;";
    $self= $RegObj   unless  ref($self);
    return eval "\\%$self->{ROOTS}";
}


sub TIEHASH
{
    my( $this )= shift(@_);
    $this= tied(%$this)   if  ref($this)  &&  tied(%$this);
    my( $key )= @_;
    if(  1 == @_  &&  ref($key)  &&  "$key" =~ /=/  ) {
	return $key;	# $key is already an object (blessed reference).
    }
    return $this->new( @_ );
}


sub Tie
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my( $hRef )= @_;
    if(  1 != @_  ||  ! ref($hRef)  ||  "$hRef" !~ /(^|=)HASH\(/  ) {
	croak "Usage: \$key->Tie(\\\%hash);";
    }
    return  tie %$hRef, ref($self), $self;
}


sub TiedRef
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $hRef= @_ ? shift(@_) : {};
    return ()   if  ! defined($self);
    $self->Tie($hRef);
    bless $hRef, ref($self);
    return $hRef;
}


sub _Flags
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlags= $self->{FLAGS};
    if(  1 == @_  ) {
	$self->{FLAGS}= shift(@_);
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBits= \$key->_Flags(\$newBits);";
    }
    return $oldFlags;
}


sub ArrayValues
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_ArrVal == ( $Flag_ArrVal & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    $self->{FLAGS} |= $Flag_ArrVal;
	} else {
	    $self->{FLAGS} &= ~( $Flag_ArrVal | $Flag_TieVal );
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->ArrayValues(\$newBool);";
    }
    return $oldFlag;
}


sub TieValues
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_TieVal == ( $Flag_TieVal & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    croak "${PACK}->TieValues cannot be enabled with this version";
	    $self->{FLAGS} |= $Flag_TieVal;
	} else {
	    $self->{FLAGS} &= ~$Flag_TieVal;
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->TieValues(\$newBool);";
    }
    return $oldFlag;
}


sub FastDelete
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_FastDel == ( $Flag_FastDel & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    $self->{FLAGS} |= $Flag_FastDel;
	} else {
	    $self->{FLAGS} &= ~$Flag_FastDel;
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->FastDelete(\$newBool);";
    }
    return $oldFlag;
}


sub SplitMultis
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_Split == ( $Flag_Split & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    $self->{FLAGS} |= $Flag_Split;
	} else {
	    $self->{FLAGS} &= ~$Flag_Split;
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->SplitMultis(\$newBool);";
    }
    return $oldFlag;
}


sub DWordsToHex
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_HexDWord == ( $Flag_HexDWord & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    $self->{FLAGS} |= $Flag_HexDWord;
	} else {
	    $self->{FLAGS} &= ~$Flag_HexDWord;
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->DWordsToHex(\$newBool);";
    }
    return $oldFlag;
}


sub FixSzNulls
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_FixNulls == ( $Flag_FixNulls & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    $self->{FLAGS} |= $Flag_FixNulls;
	} else {
	    $self->{FLAGS} &= ~$Flag_FixNulls;
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->FixSzNulls(\$newBool);";
    }
    return $oldFlag;
}


sub DualTypes
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_DualTyp == ( $Flag_DualTyp & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    croak "${PACK}->DualTypes cannot be enabled since ",
		  "SetDualVar module not installed"
	      unless  $_SetDualVar;
	    $self->{FLAGS} |= $Flag_DualTyp;
	} else {
	    $self->{FLAGS} &= ~$Flag_DualTyp;
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->DualTypes(\$newBool);";
    }
    return $oldFlag;
}


sub DualBinVals
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $oldFlag= $Flag_DualBin == ( $Flag_DualBin & $self->{FLAGS} );
    if(  1 == @_  ) {
	my $bool= shift(@_);
	if(  $bool  ) {
	    croak "${PACK}->DualBinVals cannot be enabled since ",
		  "SetDualVar module not installed"
	      unless  $_SetDualVar;
	    $self->{FLAGS} |= $Flag_DualBin;
	} else {
	    $self->{FLAGS} &= ~$Flag_DualBin;
	}
    } elsif(  0 != @_  ) {
	croak "Usage:  \$oldBool= \$key->DualBinVals(\$newBool);";
    }
    return $oldFlag;
}


sub GetOptions
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my( $opt, $meth );
    if(  ! @_  ||  1 == @_  &&  "HASH" eq ref($_[0])  ) {
	my $href= @_ ? $_[0] : {};
	foreach $opt (  grep !/^Allow/, @_opt_subs  ) {
	    $meth= $_opt_subs{$opt};
	    $href->{$opt}=  $self->$meth();
	}
	return @_ ? $self : $href;
    }
    my @old;
    foreach $opt (  @_  ) {
	$meth= $_opt_subs{$opt};
	if(  defined $meth  ) {
	    if(  $opt eq "AllowLoad"  ||  $opt eq "AllowSave"  ) {
		croak "${PACK}->GetOptions:  Getting current setting of $opt ",
		      "not supported in this release";
	    }
	    push(  @old,  $self->$meth()  );
	} else {
	    croak "${PACK}->GetOptions:  Invalid option ($opt) ",
		  "not one of ( ", join(" ",grep !/^Allow/, @_opt_subs), " )";
	}
    }
    return wantarray ? @old : $old[-1];
}


sub SetOptions
{
    my $self= shift(@_);
    # Don't get object if hash ref so "ref" returns original ref.
    my( $opt, $meth, @old );
    while(  @_  ) {
	$opt= shift(@_);
	$meth= $_opt_subs{$opt};
	if(  ! @_  ) {
	    croak "${PACK}->SetOptions:  Option value missing ",
		  "after option name ($opt)";
	} elsif(  defined $meth  ) {
	    push(  @old,  $self->$meth( shift(@_) )  );
	} elsif(  $opt eq substr("reference",0,length($opt))  ) {
	    shift(@_)   if  @_;
	    push(  @old,  $self  );
	} else {
	    croak "${PACK}->SetOptions:  Invalid option ($opt) ",
		  "not one of ( @_opt_subs )";
	}
    }
    return wantarray ? @old : $old[-1];
}


sub _parseTiedEnt
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $ent= shift(@_);
    my $delim= shift(@_);
    my $dlen= length( $delim );
    my $parent= @_ ? shift(@_) : 0;
    my $off;
    if(  $delim x 2 eq substr($ent,0,2*$dlen)  &&  "NONE" eq $self->Handle  ) {
	if(  0 <= ( $off= index( $ent, $delim x 2, 2*$dlen ) )  ) {
	    return(  substr( $ent, 0, $off ),  substr( $ent, 2*$dlen+$off )  );
	} elsif(  $delim eq substr($ent,-$dlen)  ) {
	    return( substr($ent,0,-$dlen) );
	} elsif(  2*$dlen <= ( $off= rindex( $ent, $delim ) )  ) {
	    return(  substr( $ent, 0, $off ),
	      undef,  substr( $ent, $dlen+$off )  );
	} elsif(  $parent  ) {
	    return();
	} else {
	    return( $ent );
	}
    } elsif(  $delim eq substr($ent,0,$dlen)  &&  "NONE" ne $self->Handle  ) {
	return( undef, substr($ent,$dlen) );
    } elsif(  $self->{MEMBERS}  &&  $self->_MembersHash->{$ent}  ) {
	return( substr($ent,0,-$dlen) );
    } elsif(  0 <= ( $off= index( $ent, $delim x 2 ) )  ) {
	return(  substr( $ent, 0, $off ),  substr( $ent, 2*$dlen+$off ) );
    } elsif(  $delim eq substr($ent,-$dlen)  ) {
	if(  $parent
	 &&  0 <= ( $off= rindex( $ent, $delim, length($ent)-2*$dlen ) )  ) {
	    return(  substr($ent,0,$off),
	      undef,  undef,  substr($ent,$dlen+$off,-$dlen)  );
	} else {
	    return( substr($ent,0,-$dlen) );
	}
    } elsif(  0 <= ( $off= rindex( $ent, $delim ) )  ) {
	return(
	  substr( $ent, 0, $off ),  undef,  substr( $ent, $dlen+$off )  );
    } else {
	return( undef, undef, $ent );
    }
}


sub _FetchValue
{
    my $self= shift( @_ );
    my( $val, $createKey )= @_;
    my( $data, $type );
    if(  ( $data, $type )= $self->GetValue( $val )  ) {
	return $self->ArrayValues ? [ $data, $type ]
	       : wantarray        ? ( $data, $type )
				  : $data;
    } elsif(  $createKey  and  $data= $self->new($val)  ) {
	return $data->TiedRef;
    } else {
	return ();
    }
}


sub FETCH
{
    my $self= shift(@_);
    my $ent= shift(@_);
    my $delim= $self->Delimiter;
    my( $key, $val, $ambig )= $self->_parseTiedEnt( $ent, $delim, 0 );
    my $sub;
    if(  defined($key)  ) {
	if(  defined($self->{MEMBHASH})
	 &&  $self->{MEMBHASH}->{$key.$delim}
	 &&  0 <= index($key,$delim)  ) {
	    return ()
	      unless  $sub= $self->new( $key,
			      {"Delimiter"=>$self->OS_Delimiter} );
	    $sub->Delimiter($delim);
	} else {
	    return ()
	      unless  $sub= $self->new( $key );
	}
    } else {
	$sub= $self;
    }
    if(  defined($val)  ) {
	return $sub->_FetchValue( $val );
    } elsif(  ! defined($ambig)  ) {
	return $sub->TiedRef;
    } elsif(  defined($key)  ) {
	return $sub->FETCH(  $ambig  );
    } else {
	return $sub->_FetchValue( $ambig, "" ne $ambig );
    }
}


sub _FetchOld
{
    my( $self, $key )= @_;
    my $old= $self->FETCH($key);
    if(  $old  ) {
	my $copy= {};
	%$copy= %$old;
	return $copy;
    }
    # return $^E;
    return _Err;
}


sub DELETE
{
    my $self= shift(@_);
    my $ent= shift(@_);
    my $delim= $self->Delimiter;
    my( $key, $val, $ambig, $subkey )= $self->_parseTiedEnt( $ent, $delim, 1 );
    my $sub;
    my $fast= defined(wantarray) ? $self->FastDelete : 2;
    my $old= 1;	# Value returned if FastDelete is set.
    if(  defined($key)
     &&  ( defined($val) || defined($ambig) || defined($subkey) )  ) {
	return ()
	  unless  $sub= $self->new( $key );
    } else {
	$sub= $self;
    }
    if(  defined($val)  ) {
	$old= $sub->GetValue($val) || _Err   unless  2 <= $fast;
	$sub->RegDeleteValue( $val );
    } elsif(  defined($subkey)  ) {
	$old= $sub->_FetchOld( $subkey.$delim )   unless  $fast;
	$sub->RegDeleteKey( $subkey );
    } elsif(  defined($ambig)  ) {
	if(  defined($key)  ) {
	    $old= $sub->DELETE($ambig);
	} else {
	    $old= $sub->GetValue($ambig) || _Err   unless  2 <= $fast;
	    if(  defined( $old )  ) {
		$sub->RegDeleteValue( $ambig );
	    } else {
		$old= $sub->_FetchOld( $ambig.$delim )   unless  $fast;
		$sub->RegDeleteKey( $ambig );
	    }
	}
    } elsif(  defined($key)  ) {
	$old= $sub->_FetchOld( $key.$delim )   unless  $fast;
	$sub->RegDeleteKey( $key );
    } else {
	croak "${PACK}->DELETE:  Key ($ent) can never be deleted";
    }
    return $old;
}


sub SetValue
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    my $name= shift(@_);
    my $data= shift(@_);
    my( $type )= @_;
    my $size;
    if(  ! defined($type)  ) {
	if(  "ARRAY" eq ref($data)  ) {
	    croak "${PACK}->SetValue:  Value is array reference but ",
		  "no data type given"
	      unless  2 == @$data;
	    ( $data, $type )= @$data;
	} else {
	    $type= REG_SZ;
	}
    }
    $type= _constant($type,"registry value data type")   if  $type =~ /^REG_/;
    if(  REG_MULTI_SZ == $type  &&  "ARRAY" eq ref($data)  ) {
	$data= join( "\0", @$data ) . "\0\0";
	## $data= pack(  "a*" x (1+@$data),  map( $_."\0", @$data, "" )  );
    } elsif(  ( REG_SZ == $type || REG_EXPAND_SZ == $type )
          &&  $self->FixSzNulls  ) {
	$data .= "\0"    unless  "\0" eq substr($data,0,-1);
    } elsif(  REG_DWORD == $type  &&  $data =~ /^0x[0-9a-fA-F]{3,}$/  ) {
	$data= pack( "L", hex($data) );
	# We could to $data=pack("L",$data) for REG_DWORD but I see
	# no nice way to always distinguish when to do this or not.
    }
    return $self->RegSetValueEx( $name, 0, $type, $data, length($data) );
}


sub StoreKey
{
    my $this= shift(@_);
    $this= tied(%$this)   if  ref($this)  &&  tied(%$this);
    my $subKey= shift(@_);
    my $data= shift(@_);
    my $ent;
    my $self;
    if(  ! ref($data)  ||  "$data" !~ /(^|=)HASH/  ) {
	croak "${PACK}->StoreKey:  For ", $this->Path.$subKey, ",\n",
	      "  subkey data must be a HASH reference";
    }
    if(  defined( $$data{""} )  &&  "HASH" eq ref($$data{""})  ) {
	$self= $this->CreateKey( $subKey, delete $$data{""} );
    } else {
	$self= $this->CreateKey( $subKey );
    }
    return ()   if  ! defined($self);
    foreach $ent (  keys(%$data)  ) {
	return ()
	  unless  $self->STORE( $ent, $$data{$ent} );
    }
    return $self;
}


# = { "" => {OPT=>VAL}, "val"=>[], "key"=>{} } creates a new key
# = "string" creates a new REG_SZ value
# = [ data, type ] creates a new value
sub STORE
{
    my $self= shift(@_);
    my $ent= shift(@_);
    my $data= shift(@_);
    my $delim= $self->Delimiter;
    my( $key, $val, $ambig, $subkey )= $self->_parseTiedEnt( $ent, $delim, 1 );
    my $sub;
    if(  defined($key)
     &&  ( defined($val) || defined($ambig) || defined($subkey) )  ) {
	return ()
	  unless  $sub= $self->new( $key );
    } else {
	$sub= $self;
    }
    if(  defined($val)  ) {
	croak "${PACK}->STORE:  For ", $sub->Path.$delim.$val, ",\n",
	      "  value data cannot be a HASH reference"
	  if  ref($data)  &&  "$data" =~ /(^|=)HASH/;
	$sub->SetValue( $val, $data );
    } elsif(  defined($subkey)  ) {
	croak "${PACK}->STORE:  For ", $sub->Path.$subkey.$delim, ",\n",
	      "  subkey data must be a HASH reference"
	  unless  ref($data)  &&  "$data" =~ /(^|=)HASH/;
	$sub->StoreKey( $subkey, $data );
    } elsif(  defined($ambig)  ) {
	if(  ref($data)  &&  "$data" =~ /(^|=)HASH/  ) {
	    $sub->StoreKey( $ambig, $data );
	} else {
	    $sub->SetValue( $ambig, $data );
	}
    } elsif(  defined($key)  ) {
	croak "${PACK}->STORE:  For ", $sub->Path.$key.$delim, ",\n",
	      "  subkey data must be a HASH reference"
	  unless  ref($data)  &&  "$data" =~ /(^|=)HASH/;
	$sub->StoreKey( $key, $data );
    } else {
	croak "${PACK}->STORE:  Key ($ent) can never be created nor set";
    }
}


sub EXISTS
{
    my $self= shift(@_);
    my $ent= shift(@_);
    return defined( $self->FETCH($ent) );
}


sub FIRSTKEY
{
    my $self= shift(@_);
    my $members= $self->_MemberNames;
    $self->{PREVIDX}= 0;
    return @{$members} ? $members->[0] : undef;
}


sub NEXTKEY
{
    my $self= shift(@_);
    my $prev= shift(@_);
    my $idx= $self->{PREVIDX};
    my $members= $self->_MemberNames;
    if(  ! defined($idx)  ||  $prev ne $members->[$idx]  ) {
	$idx= 0;
	while(  $idx < @$members  &&  $prev ne $members->[$idx]  ) {
	    $idx++;
	}
    }
    $self->{PREVIDX}= ++$idx;
    return $members->[$idx];
}


sub DESTROY
{
    my $self= shift(@_);
    return   if  tied(%$self);
    my $unload;
    eval { $unload= $self->{UNLOADME}; 1 }
	or  return;
    my $debug= $ENV{DEBUG_TIE_REGISTRY};
    if(  defined($debug)  ) {
	if(  1 < $debug  ) {
	    my $hand= $self->Handle;
	    my $dep= $self->{DEPENDON};
	    carp "${PACK} destroying ", $self->Path, " (",
		 "NONE" eq $hand ? $hand : sprintf("0x%lX",$hand), ")",
		 defined($dep) ? (" [depends on ",$dep->Path,"]") : ();
	} else {
	    warn "${PACK} destroying ", $self->Path, ".\n";
	}
    }
    $self->RegCloseKey
      unless  "NONE" eq $self->Handle;
    if(  defined($unload)  ) {
	if(  defined($debug)  &&  1 < $debug  ) {
	    my( $obj, $subKey, $file )= @$unload;
	    warn "Unloading ", $self->Path,
	      " (from ", $obj->Path, ", $subKey)...\n";
	}
	$self->UnLoad
	  ||  warn "Couldn't unload ", $self->Path, ": ", _ErrMsg, "\n";
	## carp "Never unloaded ${PACK}::Load($$unload[2])";
    }
    #delete $self->{DEPENDON};
}


use vars qw( @CreateKey_Opts %CreateKey_Opts %_KeyDispNames );
@CreateKey_Opts= qw( Access Class Options Delimiter
		     Disposition Security Volatile Backup );
@CreateKey_Opts{@CreateKey_Opts}= (1) x @CreateKey_Opts;
%_KeyDispNames= ( REG_CREATED_NEW_KEY() => "REG_CREATED_NEW_KEY",
		  REG_OPENED_EXISTING_KEY() => "REG_OPENED_EXISTING_KEY" );

sub CreateKey
{
    my $self= shift(@_);
    my $tied= tied(%$self);
    $self= tied(%$self)   if  $tied;
    my( $subKey, $opts )= @_;
    my( $sam )= $self->Access;
    my( $delim )= $self->Delimiter;
    my( $class )= "";
    my( $flags )= 0;
    my( $secure )= [];
    my( $garb )= [];
    my( $result )= \$garb;
    my( $handle )= 0;
    if(  @_ < 1  ||  2 < @_
     ||  2 == @_ && "HASH" ne ref($opts)  ) {
	croak "Usage:  \$new= \$old->CreateKey( \$subKey, {OPT=>VAL,...} );\n",
	      "  options: @CreateKey_Opts\nCalled";
    }
    if(  defined($opts)  ) {
	$sam= $opts->{"Access"}   if  defined($opts->{"Access"});
	$class= $opts->{Class}   if  defined($opts->{Class});
	$flags= $opts->{Options}   if  defined($opts->{Options});
	$delim= $opts->{"Delimiter"}   if  defined($opts->{"Delimiter"});
	$secure= $opts->{Security}   if  defined($opts->{Security});
	if(  defined($opts->{Disposition})  ) {
	    "SCALAR" eq ref($opts->{Disposition})
	      or  croak "${PACK}->CreateKey option `Disposition'",
			" must provide a scalar reference";
	    $result= $opts->{Disposition};
	}
	if(  0 == $flags  ) {
	    $flags |= REG_OPTION_VOLATILE
	      if  defined($opts->{Volatile})  &&  $opts->{Volatile};
	    $flags |= REG_OPTION_BACKUP_RESTORE
	      if  defined($opts->{Backup})  &&  $opts->{Backup};
	}
    }
    my $subPath= ref($subKey) ? $subKey : $self->_split($subKey,$delim);
    $subKey= join( $self->OS_Delimiter, @$subPath );
    $self->RegCreateKeyEx( $subKey, 0, $class, $flags, $sam,
			   $secure, $handle, $$result )
      or  return ();
    if(  ! ref($$result)  &&  $self->DualTypes  ) {
	$$result= _DualVal( \%_KeyDispNames, $$result );
    }
    my $new= $self->_new( $handle, [ @{$self->_Path}, @{$subPath} ] );
    $new->{ACCESS}= $sam;
    $new->{DELIM}= $delim;
    $new= $new->TiedRef   if  $tied;
    return $new;
}


use vars qw( $Load_Cnt @Load_Opts %Load_Opts );
$Load_Cnt= 0;
@Load_Opts= qw(NewSubKey);
@Load_Opts{@Load_Opts}= (1) x @Load_Opts;

sub Load
{
    my $this= shift(@_);
    my $tied=  ref($this)  &&  tied(%$this);
    $this= tied(%$this)   if  $tied;
    my( $file, $subKey, $opts )= @_;
    if(  2 == @_  &&  "HASH" eq ref($subKey)  ) {
	$opts= $subKey;
	undef $subKey;
    }
    @_ < 1  ||  3 < @_  ||  defined($opts) && "HASH" ne ref($opts)
      and  croak "Usage:  \$key= ",
	     "${PACK}->Load( \$fileName, [\$newSubKey,] {OPT=>VAL...} );\n",
	     "  options: @Load_Opts @new_Opts\nCalled";
    if(  defined($opts)  &&  exists($opts->{NewSubKey})  ) {
	$subKey= delete $opts->{NewSubKey};
    }
    if(  ! defined( $subKey )  ) {
	if(  "" ne $this->Machine  ) {
	    ( $this )= $this->_connect( [$this->Machine,"LMachine"] );
	} else {
	    ( $this )= $this->_rootKey( "LMachine" );	# Could also be "Users"
	}
	$subKey= "PerlTie:$$." . ++$Load_Cnt;
    }
    $this->RegLoadKey( $subKey, $file )
      or  return ();
    my $self= $this->new( $subKey, defined($opts) ? $opts : () );
    if(  ! defined( $self )  ) {
	{ my $err= Win32::GetLastError();
	#{ local( $^E ); #}
	    $this->RegUnLoadKey( $subKey )  or  carp
	      "Can't unload $subKey from ", $this->Path, ": ", _ErrMsg, "\n";
	    Win32::SetLastError($err);
	}
	return ();
    }
    $self->{UNLOADME}= [ $this, $subKey, $file ];
    $self= $self->TiedRef   if  $tied;
    return $self;
}


sub UnLoad
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    @_  and  croak "Usage:  \$key->UnLoad;";
    my $unload= $self->{UNLOADME};
    "ARRAY" eq ref($unload)
      or  croak "${PACK}->UnLoad called on a key which was not Load()ed";
    my( $obj, $subKey, $file )= @$unload;
    $self->RegCloseKey;
    return Win32API::Registry::RegUnLoadKey( $obj->Handle, $subKey );
}


sub AllowSave
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    return $self->AllowPriv( "SeBackupPrivilege", @_ );
}


sub AllowLoad
{
    my $self= shift(@_);
    $self= tied(%$self)   if  tied(%$self);
    return $self->AllowPriv( "SeRestorePrivilege", @_ );
}


# RegNotifyChangeKeyValue( hKey, bWatchSubtree, iNotifyFilter, hEvent, bAsync )


sub RegCloseKey { my $self= shift(@_);
    Win32API::Registry::RegCloseKey $self->Handle, @_; }
sub RegConnectRegistry { my $self= shift(@_);
    Win32API::Registry::RegConnectRegistry @_; }
sub RegCreateKey { my $self= shift(@_);
    Win32API::Registry::RegCreateKey $self->Handle, @_; }
sub RegCreateKeyEx { my $self= shift(@_);
    Win32API::Registry::RegCreateKeyEx $self->Handle, @_; }
sub RegDeleteKey { my $self= shift(@_);
    Win32API::Registry::RegDeleteKey $self->Handle, @_; }
sub RegDeleteValue { my $self= shift(@_);
    Win32API::Registry::RegDeleteValue $self->Handle, @_; }
sub RegEnumKey { my $self= shift(@_);
    Win32API::Registry::RegEnumKey $self->Handle, @_; }
sub RegEnumKeyEx { my $self= shift(@_);
    Win32API::Registry::RegEnumKeyEx $self->Handle, @_; }
sub RegEnumValue { my $self= shift(@_);
    Win32API::Registry::RegEnumValue $self->Handle, @_; }
sub RegFlushKey { my $self= shift(@_);
    Win32API::Registry::RegFlushKey $self->Handle, @_; }
sub RegGetKeySecurity { my $self= shift(@_);
    Win32API::Registry::RegGetKeySecurity $self->Handle, @_; }
sub RegLoadKey { my $self= shift(@_);
    Win32API::Registry::RegLoadKey $self->Handle, @_; }
sub RegNotifyChangeKeyValue { my $self= shift(@_);
    Win32API::Registry::RegNotifyChangeKeyValue $self->Handle, @_; }
sub RegOpenKey { my $self= shift(@_);
    Win32API::Registry::RegOpenKey $self->Handle, @_; }
sub RegOpenKeyEx { my $self= shift(@_);
    Win32API::Registry::RegOpenKeyEx $self->Handle, @_; }
sub RegQueryInfoKey { my $self= shift(@_);
    Win32API::Registry::RegQueryInfoKey $self->Handle, @_; }
sub RegQueryMultipleValues { my $self= shift(@_);
    Win32API::Registry::RegQueryMultipleValues $self->Handle, @_; }
sub RegQueryValue { my $self= shift(@_);
    Win32API::Registry::RegQueryValue $self->Handle, @_; }
sub RegQueryValueEx { my $self= shift(@_);
    Win32API::Registry::RegQueryValueEx $self->Handle, @_; }
sub RegReplaceKey { my $self= shift(@_);
    Win32API::Registry::RegReplaceKey $self->Handle, @_; }
sub RegRestoreKey { my $self= shift(@_);
    Win32API::Registry::RegRestoreKey $self->Handle, @_; }
sub RegSaveKey { my $self= shift(@_);
    Win32API::Registry::RegSaveKey $self->Handle, @_; }
sub RegSetKeySecurity { my $self= shift(@_);
    Win32API::Registry::RegSetKeySecurity $self->Handle, @_; }
sub RegSetValue { my $self= shift(@_);
    Win32API::Registry::RegSetValue $self->Handle, @_; }
sub RegSetValueEx { my $self= shift(@_);
    Win32API::Registry::RegSetValueEx $self->Handle, @_; }
sub RegUnLoadKey { my $self= shift(@_);
    Win32API::Registry::RegUnLoadKey $self->Handle, @_; }
sub AllowPriv { my $self= shift(@_);
    Win32API::Registry::AllowPriv @_; }


# Autoload methods go after =cut, and are processed by the autosplit program.

1;

__END__

#line 3802

# Autoload not currently supported by Perl under Windows.

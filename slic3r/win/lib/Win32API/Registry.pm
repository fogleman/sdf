#line 1 "Win32API/Registry.pm"
# Registry.pm -- Low-level access to functions/constants from WINREG.h

package Win32API::Registry;

use strict;
use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS); #@EXPORT_FAIL);
$VERSION= '0.33';

require Exporter;
require DynaLoader;
@ISA= qw(Exporter DynaLoader);

@EXPORT= qw();
%EXPORT_TAGS= (
    Func =>	[qw(		regConstant		regLastError
	AllowPriv		AbortSystemShutdown	InitiateSystemShutdown
	RegCloseKey		RegConnectRegistry	RegCreateKey
	RegCreateKeyEx		RegDeleteKey		RegDeleteValue
	RegEnumKey		RegEnumKeyEx		RegEnumValue
	RegFlushKey		RegGetKeySecurity	RegLoadKey
	RegNotifyChangeKeyValue	RegOpenKey		RegOpenKeyEx
	RegQueryInfoKey		RegQueryMultipleValues	RegQueryValue
	RegQueryValueEx		RegReplaceKey		RegRestoreKey
	RegSaveKey		RegSetKeySecurity	RegSetValue
	RegSetValueEx		RegUnLoadKey )],
    FuncA =>	[qw(
	AbortSystemShutdownA	InitiateSystemShutdownA
	RegConnectRegistryA	RegCreateKeyA		RegCreateKeyExA
	RegDeleteKeyA		RegDeleteValueA		RegEnumKeyA
	RegEnumKeyExA		RegEnumValueA		RegLoadKeyA
	RegOpenKeyA		RegOpenKeyExA		RegQueryInfoKeyA
	RegQueryMultipleValuesA	RegQueryValueA		RegQueryValueExA
	RegReplaceKeyA		RegRestoreKeyA		RegSaveKeyA
	RegSetValueA		RegSetValueExA		RegUnLoadKeyA )],
    FuncW =>	[qw(
	AbortSystemShutdownW	InitiateSystemShutdownW
	RegConnectRegistryW	RegCreateKeyW		RegCreateKeyExW
	RegDeleteKeyW		RegDeleteValueW		RegEnumKeyW
	RegEnumKeyExW		RegEnumValueW		RegLoadKeyW
	RegOpenKeyW		RegOpenKeyExW		RegQueryInfoKeyW
	RegQueryMultipleValuesW	RegQueryValueW		RegQueryValueExW
	RegReplaceKeyW		RegRestoreKeyW		RegSaveKeyW
	RegSetValueW		RegSetValueExW		RegUnLoadKeyW )],
    HKEY_ =>	[qw(
	HKEY_CLASSES_ROOT	HKEY_CURRENT_CONFIG	HKEY_CURRENT_USER
	HKEY_DYN_DATA		HKEY_LOCAL_MACHINE	HKEY_PERFORMANCE_DATA
	HKEY_USERS )],
    KEY_ =>	[qw(
	KEY_QUERY_VALUE		KEY_SET_VALUE		KEY_CREATE_SUB_KEY
	KEY_ENUMERATE_SUB_KEYS	KEY_NOTIFY		KEY_CREATE_LINK
	KEY_READ		KEY_WRITE		KEY_EXECUTE
	KEY_ALL_ACCESS),
	'KEY_DELETE',		# DELETE          (0x00010000L)
	'KEY_READ_CONTROL',	# READ_CONTROL    (0x00020000L)
	'KEY_WRITE_DAC',	# WRITE_DAC       (0x00040000L)
	'KEY_WRITE_OWNER',	# WRITE_OWNER     (0x00080000L)
	'KEY_SYNCHRONIZE',	# SYNCHRONIZE     (0x00100000L) (not used)
	],
    REG_ =>	[qw(
	REG_OPTION_RESERVED	REG_OPTION_NON_VOLATILE	REG_OPTION_VOLATILE
	REG_OPTION_CREATE_LINK	REG_OPTION_BACKUP_RESTORE
	REG_OPTION_OPEN_LINK	REG_LEGAL_OPTION	REG_CREATED_NEW_KEY
	REG_OPENED_EXISTING_KEY	REG_WHOLE_HIVE_VOLATILE	REG_REFRESH_HIVE
	REG_NO_LAZY_FLUSH	REG_NOTIFY_CHANGE_ATTRIBUTES
	REG_NOTIFY_CHANGE_NAME	REG_NOTIFY_CHANGE_LAST_SET
	REG_NOTIFY_CHANGE_SECURITY			REG_LEGAL_CHANGE_FILTER
	REG_NONE		REG_SZ			REG_EXPAND_SZ
	REG_BINARY		REG_DWORD		REG_DWORD_LITTLE_ENDIAN
	REG_DWORD_BIG_ENDIAN	REG_LINK		REG_MULTI_SZ
	REG_RESOURCE_LIST	REG_FULL_RESOURCE_DESCRIPTOR
	REG_RESOURCE_REQUIREMENTS_LIST )],
    SE_ =>	[qw(
	SE_ASSIGNPRIMARYTOKEN_NAME	SE_AUDIT_NAME
	SE_BACKUP_NAME			SE_CHANGE_NOTIFY_NAME
	SE_CREATE_PAGEFILE_NAME		SE_CREATE_PERMANENT_NAME
	SE_CREATE_TOKEN_NAME		SE_DEBUG_NAME
	SE_INCREASE_QUOTA_NAME		SE_INC_BASE_PRIORITY_NAME
	SE_LOAD_DRIVER_NAME		SE_LOCK_MEMORY_NAME
	SE_MACHINE_ACCOUNT_NAME		SE_PROF_SINGLE_PROCESS_NAME
	SE_REMOTE_SHUTDOWN_NAME		SE_RESTORE_NAME
	SE_SECURITY_NAME		SE_SHUTDOWN_NAME
	SE_SYSTEMTIME_NAME		SE_SYSTEM_ENVIRONMENT_NAME
	SE_SYSTEM_PROFILE_NAME		SE_TAKE_OWNERSHIP_NAME
	SE_TCB_NAME			SE_UNSOLICITED_INPUT_NAME )],
);
@EXPORT_OK= ();
{ my $ref;
    foreach $ref (  values(%EXPORT_TAGS)  ) {
	push( @EXPORT_OK, @$ref )   unless  $ref->[0] =~ /^SE_/;
    }
}
$EXPORT_TAGS{ALL}= [ @EXPORT_OK ];	# \@EXPORT_OK once SE_* settles down.
# push( @EXPORT_OK, "JHEREG_TACOSALAD" );	# Used to test Mkconst2perl
push( @EXPORT_OK, @{$EXPORT_TAGS{SE_}} );

bootstrap Win32API::Registry $VERSION;

# Preloaded methods go here.

# To convert C constants to Perl code in cRegistry.pc
# [instead of C or C++ code in cRegistry.h]:
#    * Modify F<Makefile.PL> to add WriteMakeFile() =>
#      CONST2PERL/postamble => [[ "Win32API::Registry" => ]] WRITE_PERL => 1.
#    * Either comment out C<#include "cRegistry.h"> from F<Registry.xs>
#      or make F<cRegistry.h> an empty file.
#    * Make sure the following C<if> block is not commented out.
#    * "nmake clean", "perl Makefile.PL", "nmake"

if(  ! defined &REG_NONE  ) {
    require "Win32API/Registry/cRegistry.pc";
}

# This would be convenient but inconsistent and hard to explain:
#push( @{$EXPORT_TAGS{ALL}}, @{$EXPORT_TAGS{SE_}} )
#  if  defined &SE_TCB_NAME;

sub regConstant
{
    my( $name )= @_;
    if(  1 != @_  ||  ! $name  ||  $name =~ /\W/  ) {
	require Carp;
	Carp::croak( 'Usage: ',__PACKAGE__,'::regConstant("CONST_NAME")' );
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
    my $value= regConstant( $name );
    if(  defined $value  ) {
	$!= 0;
	return $value;
    }
    $!= 11; # EINVAL
    return 0;
}

BEGIN {
    my $code= 'return _regLastError(@_)';
    local( $!, $^E )= ( 1, 1 );
    if(  $! ne $^E  ) {
	$code= '
	    local( $^E )= _regLastError(@_);
	    my $ret= $^E;
	    return $ret;
	';
    }
    eval "sub regLastError { $code }";
    die "$@"   if  $@;
}

# Since we ISA DynaLoader which ISA AutoLoader, we ISA AutoLoader so we
# need this next chunk to prevent Win32API::Registry->nonesuch() from
# looking for "nonesuch.al" and producing confusing error messages:
use vars qw($AUTOLOAD);
sub AUTOLOAD {
    require Carp;
    Carp::croak(
      "Can't locate method $AUTOLOAD via package Win32API::Registry" );
}

# Replace "&rout;" with "goto &rout;" when that is supported on Win32.

# Let user omit all buffer sizes:
sub RegEnumKeyExA {
    if(  6 == @_  ) {	splice(@_,4,0,[]);  splice(@_,2,0,[]);  }
    &_RegEnumKeyExA;
}
sub RegEnumKeyExW {
    if(  6 == @_  ) {	splice(@_,4,0,[]);  splice(@_,2,0,[]);  }
    &_RegEnumKeyExW;
}
sub RegEnumValueA {
    if(  6 == @_  ) {	splice(@_,2,0,[]);  push(@_,[]);  }
    &_RegEnumValueA;
}
sub RegEnumValueW {
    if(  6 == @_  ) {	splice(@_,2,0,[]);  push(@_,[]);  }
    &_RegEnumValueW;
}
sub RegQueryInfoKeyA {
    if(  11 == @_  ) {	splice(@_,2,0,[]);  }
    &_RegQueryInfoKeyA;
}
sub RegQueryInfoKeyW {
    if(  11 == @_  ) {	splice(@_,2,0,[]);  }
    &_RegQueryInfoKeyW;
}

sub RegEnumKeyA {
    push(@_,[])   if  3 == @_;
    &_RegEnumKeyA;
}
sub RegEnumKeyW {
    push(@_,[])   if  3 == @_;
    &_RegEnumKeyW;
}
sub RegGetKeySecurity {
    push(@_,[])   if  3 == @_;
    &_RegGetKeySecurity;
}
sub RegQueryMultipleValuesA {
    push(@_,[])   if  4 == @_;
    &_RegQueryMultipleValuesA;
}
sub RegQueryMultipleValuesW {
    push(@_,[])   if  4 == @_;
    &_RegQueryMultipleValuesW;
}
sub RegQueryValueA {
    push(@_,[])   if  3 == @_;
    &_RegQueryValueA;
}
sub RegQueryValueW {
    push(@_,[])   if  3 == @_;
    &_RegQueryValueW;
}
sub RegQueryValueExA {
    push(@_,[])   if  5 == @_;
    &_RegQueryValueExA;
}
sub RegQueryValueExW {
    push(@_,[])   if  5 == @_;
    &_RegQueryValueExW;
}
sub RegSetValueA {
    push(@_,0)   if  4 == @_;
    &_RegSetValueA;
}
sub RegSetValueW {
    push(@_,0)   if  4 == @_;
    &_RegSetValueW;
}
sub RegSetValueExA {
    push(@_,0)   if  5 == @_;
    &_RegSetValueExA;
}
sub RegSetValueExW {
    push(@_,0)   if  5 == @_;
    &_RegSetValueExW;
}

# Aliases for non-Unicode functions:
sub AbortSystemShutdown		{ &AbortSystemShutdownA; }
sub InitiateSystemShutdown	{ &InitiateSystemShutdownA; }
sub RegConnectRegistry		{ &RegConnectRegistryA; }
sub RegCreateKey		{ &RegCreateKeyA; }
sub RegCreateKeyEx		{ &RegCreateKeyExA; }
sub RegDeleteKey		{ &RegDeleteKeyA; }
sub RegDeleteValue		{ &RegDeleteValueA; }
sub RegEnumKey			{ &RegEnumKeyA; }
sub RegEnumKeyEx		{ &RegEnumKeyExA; }
sub RegEnumValue		{ &RegEnumValueA; }
sub RegLoadKey			{ &RegLoadKeyA; }
sub RegOpenKey			{ &RegOpenKeyA; }
sub RegOpenKeyEx		{ &RegOpenKeyExA; }
sub RegQueryInfoKey		{ &RegQueryInfoKeyA; }
sub RegQueryMultipleValues	{ &RegQueryMultipleValuesA; }
sub RegQueryValue		{ &RegQueryValueA; }
sub RegQueryValueEx		{ &RegQueryValueExA; }
sub RegReplaceKey		{ &RegReplaceKeyA; }
sub RegRestoreKey		{ &RegRestoreKeyA; }
sub RegSaveKey			{ &RegSaveKeyA; }
sub RegSetValue			{ &RegSetValueA; }
sub RegSetValueEx		{ &RegSetValueExA; }
sub RegUnLoadKey		{ &RegUnLoadKeyA; }

1;
__END__

#line 1780

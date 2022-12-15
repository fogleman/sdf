#line 1 "Win32.pm"
package Win32;

# BEGIN {
    use strict;
    use vars qw|$VERSION $XS_VERSION @ISA @EXPORT @EXPORT_OK|;

    require Exporter;
    require DynaLoader;

    @ISA = qw|Exporter DynaLoader|;
    $VERSION = '0.52';
    $XS_VERSION = $VERSION;
    $VERSION = eval $VERSION;

    @EXPORT = qw(
	NULL
	WIN31_CLASS
	OWNER_SECURITY_INFORMATION
	GROUP_SECURITY_INFORMATION
	DACL_SECURITY_INFORMATION
	SACL_SECURITY_INFORMATION
	MB_ICONHAND
	MB_ICONQUESTION
	MB_ICONEXCLAMATION
	MB_ICONASTERISK
	MB_ICONWARNING
	MB_ICONERROR
	MB_ICONINFORMATION
	MB_ICONSTOP
    );
    @EXPORT_OK = qw(
        GetOSName
        SW_HIDE
        SW_SHOWNORMAL
        SW_SHOWMINIMIZED
        SW_SHOWMAXIMIZED
        SW_SHOWNOACTIVATE

        CSIDL_DESKTOP
        CSIDL_PROGRAMS
        CSIDL_PERSONAL
        CSIDL_FAVORITES
        CSIDL_STARTUP
        CSIDL_RECENT
        CSIDL_SENDTO
        CSIDL_STARTMENU
        CSIDL_MYMUSIC
        CSIDL_MYVIDEO
        CSIDL_DESKTOPDIRECTORY
        CSIDL_NETHOOD
        CSIDL_FONTS
        CSIDL_TEMPLATES
        CSIDL_COMMON_STARTMENU
        CSIDL_COMMON_PROGRAMS
        CSIDL_COMMON_STARTUP
        CSIDL_COMMON_DESKTOPDIRECTORY
        CSIDL_APPDATA
        CSIDL_PRINTHOOD
        CSIDL_LOCAL_APPDATA
        CSIDL_COMMON_FAVORITES
        CSIDL_INTERNET_CACHE
        CSIDL_COOKIES
        CSIDL_HISTORY
        CSIDL_COMMON_APPDATA
        CSIDL_WINDOWS
        CSIDL_SYSTEM
        CSIDL_PROGRAM_FILES
        CSIDL_MYPICTURES
        CSIDL_PROFILE
        CSIDL_PROGRAM_FILES_COMMON
        CSIDL_COMMON_TEMPLATES
        CSIDL_COMMON_DOCUMENTS
        CSIDL_COMMON_ADMINTOOLS
        CSIDL_ADMINTOOLS
        CSIDL_COMMON_MUSIC
        CSIDL_COMMON_PICTURES
        CSIDL_COMMON_VIDEO
        CSIDL_RESOURCES
        CSIDL_RESOURCES_LOCALIZED
        CSIDL_CDBURN_AREA
    );
# }

# We won't bother with the constant stuff, too much of a hassle.  Just hard
# code it here.

sub NULL 				{ 0 }
sub WIN31_CLASS 			{ &NULL }

sub OWNER_SECURITY_INFORMATION		{ 0x00000001 }
sub GROUP_SECURITY_INFORMATION		{ 0x00000002 }
sub DACL_SECURITY_INFORMATION		{ 0x00000004 }
sub SACL_SECURITY_INFORMATION		{ 0x00000008 }

sub MB_ICONHAND				{ 0x00000010 }
sub MB_ICONQUESTION			{ 0x00000020 }
sub MB_ICONEXCLAMATION			{ 0x00000030 }
sub MB_ICONASTERISK			{ 0x00000040 }
sub MB_ICONWARNING			{ 0x00000030 }
sub MB_ICONERROR			{ 0x00000010 }
sub MB_ICONINFORMATION			{ 0x00000040 }
sub MB_ICONSTOP				{ 0x00000010 }

#
# Newly added constants.  These have an empty prototype, unlike the
# the ones above, which aren't prototyped for compatibility reasons.
#
sub SW_HIDE           ()		{ 0 }
sub SW_SHOWNORMAL     ()		{ 1 }
sub SW_SHOWMINIMIZED  ()		{ 2 }
sub SW_SHOWMAXIMIZED  ()		{ 3 }
sub SW_SHOWNOACTIVATE ()		{ 4 }

sub CSIDL_DESKTOP              ()       { 0x0000 }     # <desktop>
sub CSIDL_PROGRAMS             ()       { 0x0002 }     # Start Menu\Programs
sub CSIDL_PERSONAL             ()       { 0x0005 }     # "My Documents" folder
sub CSIDL_FAVORITES            ()       { 0x0006 }     # <user name>\Favorites
sub CSIDL_STARTUP              ()       { 0x0007 }     # Start Menu\Programs\Startup
sub CSIDL_RECENT               ()       { 0x0008 }     # <user name>\Recent
sub CSIDL_SENDTO               ()       { 0x0009 }     # <user name>\SendTo
sub CSIDL_STARTMENU            ()       { 0x000B }     # <user name>\Start Menu
sub CSIDL_MYMUSIC              ()       { 0x000D }     # "My Music" folder
sub CSIDL_MYVIDEO              ()       { 0x000E }     # "My Videos" folder
sub CSIDL_DESKTOPDIRECTORY     ()       { 0x0010 }     # <user name>\Desktop
sub CSIDL_NETHOOD              ()       { 0x0013 }     # <user name>\nethood
sub CSIDL_FONTS                ()       { 0x0014 }     # windows\fonts
sub CSIDL_TEMPLATES            ()       { 0x0015 }
sub CSIDL_COMMON_STARTMENU     ()       { 0x0016 }     # All Users\Start Menu
sub CSIDL_COMMON_PROGRAMS      ()       { 0x0017 }     # All Users\Start Menu\Programs
sub CSIDL_COMMON_STARTUP       ()       { 0x0018 }     # All Users\Startup
sub CSIDL_COMMON_DESKTOPDIRECTORY ()    { 0x0019 }     # All Users\Desktop
sub CSIDL_APPDATA              ()       { 0x001A }     # Application Data, new for NT4
sub CSIDL_PRINTHOOD            ()       { 0x001B }     # <user name>\PrintHood
sub CSIDL_LOCAL_APPDATA        ()       { 0x001C }     # non roaming, user\Local Settings\Application Data
sub CSIDL_COMMON_FAVORITES     ()       { 0x001F }
sub CSIDL_INTERNET_CACHE       ()       { 0x0020 }
sub CSIDL_COOKIES              ()       { 0x0021 }
sub CSIDL_HISTORY              ()       { 0x0022 }
sub CSIDL_COMMON_APPDATA       ()       { 0x0023 }     # All Users\Application Data
sub CSIDL_WINDOWS              ()       { 0x0024 }     # GetWindowsDirectory()
sub CSIDL_SYSTEM               ()       { 0x0025 }     # GetSystemDirectory()
sub CSIDL_PROGRAM_FILES        ()       { 0x0026 }     # C:\Program Files
sub CSIDL_MYPICTURES           ()       { 0x0027 }     # "My Pictures", new for Win2K
sub CSIDL_PROFILE              ()       { 0x0028 }     # USERPROFILE
sub CSIDL_PROGRAM_FILES_COMMON ()       { 0x002B }     # C:\Program Files\Common
sub CSIDL_COMMON_TEMPLATES     ()       { 0x002D }     # All Users\Templates
sub CSIDL_COMMON_DOCUMENTS     ()       { 0x002E }     # All Users\Documents
sub CSIDL_COMMON_ADMINTOOLS    ()       { 0x002F }     # All Users\Start Menu\Programs\Administrative Tools
sub CSIDL_ADMINTOOLS           ()       { 0x0030 }     # <user name>\Start Menu\Programs\Administrative Tools
sub CSIDL_COMMON_MUSIC         ()       { 0x0035 }     # All Users\My Music
sub CSIDL_COMMON_PICTURES      ()       { 0x0036 }     # All Users\My Pictures
sub CSIDL_COMMON_VIDEO         ()       { 0x0037 }     # All Users\My Video
sub CSIDL_RESOURCES            ()       { 0x0038 }     # %windir%\Resources\, For theme and other windows resources.
sub CSIDL_RESOURCES_LOCALIZED  ()       { 0x0039 }     # %windir%\Resources\<LangID>, for theme and other windows specific resources.
sub CSIDL_CDBURN_AREA          ()       { 0x003B }     # <user name>\Local Settings\Application Data\Microsoft\CD Burning

sub VER_NT_DOMAIN_CONTROLLER () { 0x0000002 } # The system is a domain controller and the operating system is Windows Server 2008, Windows Server 2003, or Windows 2000 Server.
sub VER_NT_SERVER () { 0x0000003 } # The operating system is Windows Server 2008, Windows Server 2003, or Windows 2000 Server.
# Note that a server that is also a domain controller is reported as VER_NT_DOMAIN_CONTROLLER, not VER_NT_SERVER.
sub VER_NT_WORKSTATION () { 0x0000001 } # The operating system is Windows Vista, Windows XP Professional, Windows XP Home Edition, or Windows 2000 Professional.


sub VER_SUITE_BACKOFFICE               () { 0x00000004 } # Microsoft BackOffice components are installed.
sub VER_SUITE_BLADE                    () { 0x00000400 } # Windows Server 2003, Web Edition is installed.
sub VER_SUITE_COMPUTE_SERVER           () { 0x00004000 } # Windows Server 2003, Compute Cluster Edition is installed.
sub VER_SUITE_DATACENTER               () { 0x00000080 } # Windows Server 2008 Datacenter, Windows Server 2003, Datacenter Edition, or Windows 2000 Datacenter Server is installed.
sub VER_SUITE_ENTERPRISE               () { 0x00000002 } # Windows Server 2008 Enterprise, Windows Server 2003, Enterprise Edition, or Windows 2000 Advanced Server is installed. Refer to the Remarks section for more information about this bit flag.
sub VER_SUITE_EMBEDDEDNT               () { 0x00000040 } # Windows XP Embedded is installed.
sub VER_SUITE_PERSONAL                 () { 0x00000200 } # Windows Vista Home Premium, Windows Vista Home Basic, or Windows XP Home Edition is installed.
sub VER_SUITE_SINGLEUSERTS             () { 0x00000100 } # Remote Desktop is supported, but only one interactive session is supported. This value is set unless the system is running in application server mode.
sub VER_SUITE_SMALLBUSINESS            () { 0x00000001 } # Microsoft Small Business Server was once installed on the system, but may have been upgraded to another version of Windows. Refer to the Remarks section for more information about this bit flag.
sub VER_SUITE_SMALLBUSINESS_RESTRICTED () { 0x00000020 } # Microsoft Small Business Server is installed with the restrictive client license in force. Refer to the Remarks section for more information about this bit flag.
sub VER_SUITE_STORAGE_SERVER           () { 0x00002000 } # Windows Storage Server 2003 R2 or Windows Storage Server 2003 is installed.
sub VER_SUITE_TERMINAL                 () { 0x00000010 } # Terminal Services is installed. This value is always set.
# If VER_SUITE_TERMINAL is set but VER_SUITE_SINGLEUSERTS is not set, the system is running in application server mode.
sub VER_SUITE_WH_SERVER                () { 0x00008000 } # Windows Home Server is installed.


sub SM_TABLETPC                ()       { 86 }
sub SM_MEDIACENTER             ()       { 87 }
sub SM_STARTER                 ()       { 88 }
sub SM_SERVERR2                ()       { 89 }

sub PRODUCT_UNDEFINED                        () { 0x000 } # An unknown product
sub PRODUCT_ULTIMATE                         () { 0x001 } # Ultimate
sub PRODUCT_HOME_BASIC                       () { 0x002 } # Home Basic
sub PRODUCT_HOME_PREMIUM                     () { 0x003 } # Home Premium
sub PRODUCT_ENTERPRISE                       () { 0x004 } # Enterprise
sub PRODUCT_HOME_BASIC_N                     () { 0x005 } # Home Basic N
sub PRODUCT_BUSINESS                         () { 0x006 } # Business
sub PRODUCT_STANDARD_SERVER                  () { 0x007 } # Server Standard (full installation)
sub PRODUCT_DATACENTER_SERVER                () { 0x008 } # Server Datacenter (full installation)
sub PRODUCT_SMALLBUSINESS_SERVER             () { 0x009 } # Windows Small Business Server
sub PRODUCT_ENTERPRISE_SERVER                () { 0x00A } # Server Enterprise (full installation)
sub PRODUCT_STARTER                          () { 0x00B } # Starter
sub PRODUCT_DATACENTER_SERVER_CORE           () { 0x00C } # Server Datacenter (core installation)
sub PRODUCT_STANDARD_SERVER_CORE             () { 0x00D } # Server Standard (core installation)
sub PRODUCT_ENTERPRISE_SERVER_CORE           () { 0x00E } # Server Enterprise (core installation)
sub PRODUCT_ENTERPRISE_SERVER_IA64           () { 0x00F } # Server Enterprise for Itanium-based Systems
sub PRODUCT_BUSINESS_N                       () { 0x010 } # Business N
sub PRODUCT_WEB_SERVER                       () { 0x011 } # Web Server (full installation)
sub PRODUCT_CLUSTER_SERVER                   () { 0x012 } # HPC Edition
sub PRODUCT_HOME_SERVER                      () { 0x013 } # Home Server Edition
sub PRODUCT_STORAGE_EXPRESS_SERVER           () { 0x014 } # Storage Server Express
sub PRODUCT_STORAGE_STANDARD_SERVER          () { 0x015 } # Storage Server Standard
sub PRODUCT_STORAGE_WORKGROUP_SERVER         () { 0x016 } # Storage Server Workgroup
sub PRODUCT_STORAGE_ENTERPRISE_SERVER        () { 0x017 } # Storage Server Enterprise
sub PRODUCT_SERVER_FOR_SMALLBUSINESS         () { 0x018 } # Windows Server 2008 for Windows Essential Server Solutions
sub PRODUCT_SMALLBUSINESS_SERVER_PREMIUM     () { 0x019 } # Windows Small Business Server Premium
sub PRODUCT_HOME_PREMIUM_N                   () { 0x01A } # Home Premium N
sub PRODUCT_ENTERPRISE_N                     () { 0x01B } # Enterprise N
sub PRODUCT_ULTIMATE_N                       () { 0x01C } # Ultimate N
sub PRODUCT_WEB_SERVER_CORE                  () { 0x01D } # Web Server (core installation)
sub PRODUCT_MEDIUMBUSINESS_SERVER_MANAGEMENT () { 0x01E } # Windows Essential Business Server Management Server
sub PRODUCT_MEDIUMBUSINESS_SERVER_SECURITY   () { 0x01F } # Windows Essential Business Server Security Server
sub PRODUCT_MEDIUMBUSINESS_SERVER_MESSAGING  () { 0x020 } # Windows Essential Business Server Messaging Server
sub PRODUCT_SERVER_FOUNDATION                () { 0x021 } # Server Foundation
#define PRODUCT_HOME_PREMIUM_SERVER                 0x00000022
sub PRODUCT_SERVER_FOR_SMALLBUSINESS_V       () { 0x023 } # Windows Server 2008 without Hyper-V for Windows Essential Server Solutions
sub PRODUCT_STANDARD_SERVER_V                () { 0x024 } # Server Standard without Hyper-V (full installation)
sub PRODUCT_DATACENTER_SERVER_V              () { 0x025 } # Server Datacenter without Hyper-V (full installation)
sub PRODUCT_ENTERPRISE_SERVER_V              () { 0x026 } # Server Enterprise without Hyper-V (full installation)
sub PRODUCT_DATACENTER_SERVER_CORE_V         () { 0x027 } # Server Datacenter without Hyper-V (core installation)
sub PRODUCT_STANDARD_SERVER_CORE_V           () { 0x028 } # Server Standard without Hyper-V (core installation)
sub PRODUCT_ENTERPRISE_SERVER_CORE_V         () { 0x029 } # Server Enterprise without Hyper-V (core installation)
sub PRODUCT_HYPERV                           () { 0x02A } # Microsoft Hyper-V Server
#define PRODUCT_STORAGE_EXPRESS_SERVER_CORE         0x0000002B
#define PRODUCT_STORAGE_STANDARD_SERVER_CORE        0x0000002C
#define PRODUCT_STORAGE_WORKGROUP_SERVER_CORE       0x0000002D
#define PRODUCT_STORAGE_ENTERPRISE_SERVER_CORE      0x0000002E
sub PRODUCT_STARTER_N                        () { 0x02F } # Starter N
sub PRODUCT_PROFESSIONAL                     () { 0x030 } # Professional
sub PRODUCT_PROFESSIONAL_N                   () { 0x031 } # Professional N
#define PRODUCT_SB_SOLUTION_SERVER                  0x00000032
#define PRODUCT_SERVER_FOR_SB_SOLUTIONS             0x00000033
#define PRODUCT_STANDARD_SERVER_SOLUTIONS           0x00000034
#define PRODUCT_STANDARD_SERVER_SOLUTIONS_CORE      0x00000035
#define PRODUCT_SB_SOLUTION_SERVER_EM               0x00000036
#define PRODUCT_SERVER_FOR_SB_SOLUTIONS_EM          0x00000037
#define PRODUCT_SOLUTION_EMBEDDEDSERVER             0x00000038
#define PRODUCT_SOLUTION_EMBEDDEDSERVER_CORE        0x00000039
#define PRODUCT_PROFESSIONAL_EMBEDDED               0x0000003A
#define PRODUCT_ESSENTIALBUSINESS_SERVER_MGMT       0x0000003B
#define PRODUCT_ESSENTIALBUSINESS_SERVER_ADDL       0x0000003C
#define PRODUCT_ESSENTIALBUSINESS_SERVER_MGMTSVC    0x0000003D
#define PRODUCT_ESSENTIALBUSINESS_SERVER_ADDLSVC    0x0000003E
#define PRODUCT_SMALLBUSINESS_SERVER_PREMIUM_CORE   0x0000003F
#define PRODUCT_CLUSTER_SERVER_V                    0x00000040
#define PRODUCT_EMBEDDED                            0x00000041
sub PRODUCT_STARTER_E                        () { 0x042 } # Starter E
sub PRODUCT_HOME_BASIC_E                     () { 0x043 } # Home Basic E
sub PRODUCT_HOME_PREMIUM_E                   () { 0x044 } # Home Premium E
sub PRODUCT_PROFESSIONAL_E                   () { 0x045 } # Professional E
sub PRODUCT_ENTERPRISE_E                     () { 0x046 } # Enterprise E
sub PRODUCT_ULTIMATE_E                       () { 0x047 } # Ultimate E
#define PRODUCT_ENTERPRISE_EVALUATION               0x00000048
#define PRODUCT_MULTIPOINT_STANDARD_SERVER          0x0000004C
#define PRODUCT_MULTIPOINT_PREMIUM_SERVER           0x0000004D
#define PRODUCT_STANDARD_EVALUATION_SERVER          0x0000004F
#define PRODUCT_DATACENTER_EVALUATION_SERVER        0x00000050
#define PRODUCT_ENTERPRISE_N_EVALUATION             0x00000054
#define PRODUCT_EMBEDDED_AUTOMOTIVE                 0x00000055
#define PRODUCT_EMBEDDED_INDUSTRY_A                 0x00000056
#define PRODUCT_THINPC                              0x00000057
#define PRODUCT_EMBEDDED_A                          0x00000058
#define PRODUCT_EMBEDDED_INDUSTRY                   0x00000059
#define PRODUCT_EMBEDDED_E                          0x0000005A
#define PRODUCT_EMBEDDED_INDUSTRY_E                 0x0000005B
#define PRODUCT_EMBEDDED_INDUSTRY_A_E               0x0000005C
#define PRODUCT_STORAGE_WORKGROUP_EVALUATION_SERVER 0x0000005F
#define PRODUCT_STORAGE_STANDARD_EVALUATION_SERVER  0x00000060
#define PRODUCT_CORE_ARM                            0x00000061
sub PRODUCT_CORE_N                           () { 0x62 } # Windows 10 Home N
sub PRODUCT_CORE_COUNTRYSPECIFIC             () { 0x63 } # Windows 10 Home China
sub PRODUCT_CORE_SINGLELANGUAGE              () { 0x64 } # Windows 10 Home Single Language
sub PRODUCT_CORE                             () { 0x65 } # Windows 10 Home
#define PRODUCT_PROFESSIONAL_WMC                    0x00000067
#define PRODUCT_MOBILE_CORE                         0x00000068
#define PRODUCT_EMBEDDED_INDUSTRY_EVAL              0x00000069
#define PRODUCT_EMBEDDED_INDUSTRY_E_EVAL            0x0000006A
#define PRODUCT_EMBEDDED_EVAL                       0x0000006B
#define PRODUCT_EMBEDDED_E_EVAL                     0x0000006C
#define PRODUCT_NANO_SERVER                         0x0000006D
#define PRODUCT_CLOUD_STORAGE_SERVER                0x0000006E
#define PRODUCT_CORE_CONNECTED                      0x0000006F
#define PRODUCT_PROFESSIONAL_STUDENT                0x00000070
#define PRODUCT_CORE_CONNECTED_N                    0x00000071
#define PRODUCT_PROFESSIONAL_STUDENT_N              0x00000072
#define PRODUCT_CORE_CONNECTED_SINGLELANGUAGE       0x00000073
#define PRODUCT_CORE_CONNECTED_COUNTRYSPECIFIC      0x00000074
#define PRODUCT_CONNECTED_CAR                       0x00000075
#define PRODUCT_INDUSTRY_HANDHELD                   0x00000076
#define PRODUCT_PPI_PRO                             0x00000077
#define PRODUCT_ARM64_SERVER                        0x00000078
sub PRODUCT_EDUCATION                        () { 0x79 } # Windows 10 Education
sub PRODUCT_EDUCATION_N                      () { 0x7A } # Windows 10 Education N
#define PRODUCT_IOTUAP                              0x0000007B
#define PRODUCT_CLOUD_HOST_INFRASTRUCTURE_SERVER    0x0000007C
#define PRODUCT_ENTERPRISE_S                        0x0000007D
#define PRODUCT_ENTERPRISE_S_N                      0x0000007E
#define PRODUCT_PROFESSIONAL_S                      0x0000007F
#define PRODUCT_PROFESSIONAL_S_N                    0x00000080
#define PRODUCT_ENTERPRISE_S_EVALUATION             0x00000081
#define PRODUCT_ENTERPRISE_S_N_EVALUATION           0x00000082

sub PRODUCT_UNLICENSED                       () { 0xABCDABCD } # product has not been activated and is no longer in the grace period

sub PROCESSOR_ARCHITECTURE_AMD64   ()   { 9 }      # x64 (AMD or Intel)
sub PROCESSOR_ARCHITECTURE_IA64    ()   { 6 }      # Intel Itanium Processor Family (IPF)
sub PROCESSOR_ARCHITECTURE_INTEL   ()   { 0 }      # x86
sub PROCESSOR_ARCHITECTURE_UNKNOWN ()   { 0xffff } # Unknown architecture.

sub _GetProcessorArchitecture {
    my $arch = {
	 386 => PROCESSOR_ARCHITECTURE_INTEL,
	 486 => PROCESSOR_ARCHITECTURE_INTEL,
	 586 => PROCESSOR_ARCHITECTURE_INTEL,
	2200 => PROCESSOR_ARCHITECTURE_IA64,
	8664 => PROCESSOR_ARCHITECTURE_AMD64,
    }->{Win32::GetChipName()};
    return defined($arch) ? $arch : PROCESSOR_ARCHITECTURE_UNKNOWN;
}

### This method is just a simple interface into GetOSVersion().  More
### specific or demanding situations should use that instead.

my ($cached_os, $cached_desc);

sub GetOSName {
    unless (defined $cached_os) {
	my($desc, $major, $minor, $build, $id, undef, undef, $suitemask, $producttype)
	    = Win32::GetOSVersion();
	my $arch = _GetProcessorArchitecture();
	my $productinfo = Win32::GetProductInfo(6, 0, 0, 0);
	($cached_os, $cached_desc) = _GetOSName($desc, $major, $minor, $build, $id,
						$suitemask, $producttype, $productinfo, $arch);
    }
    return wantarray ? ($cached_os, $cached_desc) : $cached_os;
}

sub GetOSDisplayName {
    # Calling GetOSDisplayName() with arguments is for the test suite only!
    my($name,$desc) = @_ ? @_ : GetOSName();
    $name =~ s/^Win//;
    if ($desc =~ /^Windows Home Server\b/ || $desc =~ /^Windows XP Professional x64 Edition\b/) {
	($name, $desc) = ($desc, "");
    }
    elsif ($desc =~ s/\s*(Windows (.*) Server( \d+)?)//) {
	$name = "$1 $name";
	$desc =~ s/^\s+//;
    }
    else {
	for ($name) {
	    s/^/Windows / unless /^Win32s$/;
	    s/\/.Net//;
	    s/NT(\d)/NT $1/;
	    if ($desc =~ s/\s*(HPC|Small Business|Web) Server//) {
		my $name = $1;
		$desc =~ s/^\s*//;
		s/(200.)/$name Server $1/;
	    }
	    s/^Windows (20(03|08|12))/Windows Server $1/;
	}
    }
    $name .= " $desc" if length $desc;
    return $name;
}

sub _GetSystemMetrics {
    my($index,$metrics) = @_;
    return Win32::GetSystemMetrics($index) unless ref $metrics;
    return $metrics->{$index} if ref $metrics eq "HASH" && defined $metrics->{$index};
    return 1 if ref $metrics eq "ARRAY" && grep $_ == $index, @$metrics;
    return 0;
}

sub _GetOSName {
    # The $metrics argument only exists for the benefit of t/GetOSName.t
    my($csd, $major, $minor, $build, $id, $suitemask, $producttype, $productinfo, $arch, $metrics) = @_;

    my($os,@tags);
    my $desc = "";
    if ($id == 0) {
	$os = "Win32s";
    }
    elsif ($id == 1) {
	if ($minor == 0) {
	    $os = "95";
	}
	elsif ($minor == 10) {
	    $os = "98";
	}
	elsif ($minor == 90) {
	    $os = "Me";
	}
    }
    elsif ($id == 2) {
	if ($major == 3) {
	    $os = "NT3.51";
	}
	elsif ($major == 4) {
	    $os = "NT4";
	}
	elsif ($major == 5) {
	    if ($minor == 0) {
		$os = "2000";
		if ($producttype == VER_NT_WORKSTATION) {
		    $desc = "Professional";
		}
		else {
		    if ($suitemask & VER_SUITE_DATACENTER) {
			$desc = "Datacenter Server";
		    }
		    elsif ($suitemask & VER_SUITE_ENTERPRISE) {
			$desc = "Advanced Server";
		    }
		    elsif ($suitemask & VER_SUITE_SMALLBUSINESS_RESTRICTED) {
			$desc = "Small Business Server";
		    }
		    else {
			$desc = "Server";
		    }
		}
		# XXX ignoring "Windows 2000 Advanced Server Limited Edition" for Itanium
		# XXX and "Windows 2000 Datacenter Server Limited Edition" for Itanium
	    }
	    elsif ($minor == 1) {
		$os = "XP/.Net";
		if (_GetSystemMetrics(SM_MEDIACENTER, $metrics)) {
		    $desc = "Media Center Edition";
		}
		elsif (_GetSystemMetrics(SM_TABLETPC, $metrics)) {
		    # Tablet PC Edition is based on XP Pro
		    $desc = "Tablet PC Edition";
		}
		elsif (_GetSystemMetrics(SM_STARTER, $metrics)) {
		    $desc = "Starter Edition";
		}
		elsif ($suitemask & VER_SUITE_PERSONAL) {
		    $desc = "Home Edition";
		}
		else {
		    $desc = "Professional";
		}
		# XXX ignoring all Windows XP Embedded and Fundamentals versions
	    }
	    elsif ($minor == 2) {
		$os = "2003";

		if (_GetSystemMetrics(SM_SERVERR2, $metrics)) {
		    # XXX R2 was released for all x86 and x64 versions,
		    # XXX but only Enterprise Edition for Itanium.
		    $desc = "R2";
		}

		if ($suitemask == VER_SUITE_STORAGE_SERVER) {
		    $desc .= " Windows Storage Server";
		}
		elsif ($suitemask == VER_SUITE_WH_SERVER) {
		    $desc .= " Windows Home Server";
		}
		elsif ($producttype == VER_NT_WORKSTATION && $arch == PROCESSOR_ARCHITECTURE_AMD64) {
		    $desc .= " Windows XP Professional x64 Edition";
		}

		# Test for the server type.
		if ($producttype != VER_NT_WORKSTATION) {
		    if ($arch == PROCESSOR_ARCHITECTURE_IA64) {
			if ($suitemask & VER_SUITE_DATACENTER) {
			    $desc .= " Datacenter Edition for Itanium-based Systems";
			}
			elsif ($suitemask & VER_SUITE_ENTERPRISE) {
			    $desc .= " Enterprise Edition for Itanium-based Systems";
			}
		    }
		    elsif ($arch == PROCESSOR_ARCHITECTURE_AMD64) {
			if ($suitemask & VER_SUITE_DATACENTER) {
			    $desc .= " Datacenter x64 Edition";
			}
			elsif ($suitemask & VER_SUITE_ENTERPRISE) {
			    $desc .= " Enterprise x64 Edition";
			}
			else {
			    $desc .= " Standard x64 Edition";
			}
		    }
		    else {
			if ($suitemask & VER_SUITE_COMPUTE_SERVER) {
			    $desc .= " Windows Compute Cluster Server";
			}
			elsif ($suitemask & VER_SUITE_DATACENTER) {
			    $desc .= " Datacenter Edition";
			}
			elsif ($suitemask & VER_SUITE_ENTERPRISE) {
			    $desc .= " Enterprise Edition";
			}
			elsif ($suitemask & VER_SUITE_BLADE) {
			    $desc .= " Web Edition";
			}
			elsif ($suitemask & VER_SUITE_SMALLBUSINESS_RESTRICTED) {
			    $desc .= " Small Business Server";
			}
			else {
			    if ($desc !~ /Windows (Home|Storage) Server/) {
				$desc .= " Standard Edition";
			    }
			}
		    }
		}
	    }
	}
	elsif ($major == 6) {
	    if ($minor == 0) {
		if ($producttype == VER_NT_WORKSTATION) {
		    $os = "Vista";
		}
		else {
		    $os = "2008";
		}
	    }
	    elsif ($minor == 1) {
		if ($producttype == VER_NT_WORKSTATION) {
		    $os = "7";
		}
		else {
		    $os = "2008";
		    $desc = "R2";
		}
	    }
	    elsif ($minor == 2) {
	    if ($producttype == VER_NT_WORKSTATION) {
	        $os = "8";
	    }
	    else {
	        $os = "2012";
	    }
	    }
	    elsif ($minor == 3) {
		if ($producttype == VER_NT_WORKSTATION) {
		    $os = "8.1";
		}
		else {
		    $os = "2012";
		    $desc = "R2";
		}
	    }
        }
	elsif ($major == 10) {
            $os = '10';
        }

        if ($major >= 6) {
            if ($productinfo == PRODUCT_ULTIMATE) {
		$desc .= " Ultimate";
	    }
            elsif ($productinfo == PRODUCT_HOME_PREMIUM) {
               $desc .= " Home Premium";
            }
            elsif ($productinfo == PRODUCT_HOME_BASIC) {
               $desc .= " Home Basic";
            }
            elsif ($productinfo == PRODUCT_ENTERPRISE) {
               $desc .= " Enterprise";
            }
            elsif ($productinfo == PRODUCT_BUSINESS) {
	       # "Windows 7 Business" had a name change to "Windows 7 Professional"
               $desc .= $minor == 0 ? " Business" : " Professional";
            }
            elsif ($productinfo == PRODUCT_STARTER) {
               $desc .= " Starter";
            }
            elsif ($productinfo == PRODUCT_CLUSTER_SERVER) {
               $desc .= " HPC Server";
            }
            elsif ($productinfo == PRODUCT_DATACENTER_SERVER) {
               $desc .= " Datacenter";
            }
            elsif ($productinfo == PRODUCT_DATACENTER_SERVER_CORE) {
               $desc .= " Datacenter Edition (core installation)";
            }
            elsif ($productinfo == PRODUCT_ENTERPRISE_SERVER) {
               $desc .= " Enterprise";
            }
            elsif ($productinfo == PRODUCT_ENTERPRISE_SERVER_CORE) {
               $desc .= " Enterprise Edition (core installation)";
            }
            elsif ($productinfo == PRODUCT_ENTERPRISE_SERVER_IA64) {
               $desc .= " Enterprise Edition for Itanium-based Systems";
            }
            elsif ($productinfo == PRODUCT_SMALLBUSINESS_SERVER) {
               $desc .= " Small Business Server";
            }
            elsif ($productinfo == PRODUCT_SMALLBUSINESS_SERVER_PREMIUM) {
               $desc .= " Small Business Server Premium Edition";
            }
            elsif ($productinfo == PRODUCT_STANDARD_SERVER) {
               $desc .= " Standard";
            }
            elsif ($productinfo == PRODUCT_STANDARD_SERVER_CORE) {
               $desc .= " Standard Edition (core installation)";
            }
            elsif ($productinfo == PRODUCT_WEB_SERVER) {
               $desc .= " Web Server";
            }
            elsif ($productinfo == PRODUCT_PROFESSIONAL) {
               $desc .= " Professional";
            }

	    if ($arch == PROCESSOR_ARCHITECTURE_INTEL) {
		$desc .= " (32-bit)";
	    }
	    elsif ($arch == PROCESSOR_ARCHITECTURE_AMD64) {
		$desc .= " (64-bit)";
	    }
	} 
    }

    unless (defined $os) {
	warn "Unknown Windows version [$id:$major:$minor]";
	return;
    }

    for ($desc) {
	s/\s\s+/ /g;
	s/^\s//;
	s/\s$//;
    }

    # XXX What about "Small Business Server"? NT, 200, 2003, 2008 editions...

    if ($major >= 5) {
	# XXX XP, Vista, 7 all have starter editions
	#push(@tags, "Starter Edition") if _GetSystemMetrics(SM_STARTER, $metrics);
    }

    if (@tags) {
	unshift(@tags, $desc) if length $desc;
	$desc = join(" ", @tags);
    }

    if (length $csd) {
	$desc .= " " if length $desc;
	$desc .= $csd;
    }
    return ("Win$os", $desc);
}

# "no warnings 'redefine';" doesn't work for 5.8.7 and earlier
local $^W = 0;
bootstrap Win32;

1;

__END__

#line 1336

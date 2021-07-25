#line 1 "File/Spec.pm"
package File::Spec;

use strict;
use vars qw(@ISA $VERSION);

$VERSION = '3.63_01';
$VERSION =~ tr/_//d;

my %module = (MacOS   => 'Mac',
	      MSWin32 => 'Win32',
	      os2     => 'OS2',
	      VMS     => 'VMS',
	      epoc    => 'Epoc',
	      NetWare => 'Win32', # Yes, File::Spec::Win32 works on NetWare.
	      symbian => 'Win32', # Yes, File::Spec::Win32 works on symbian.
	      dos     => 'OS2',   # Yes, File::Spec::OS2 works on DJGPP.
	      cygwin  => 'Cygwin',
	      amigaos => 'AmigaOS');


my $module = $module{$^O} || 'Unix';

require "File/Spec/$module.pm";
@ISA = ("File::Spec::$module");

1;

__END__

#line 341

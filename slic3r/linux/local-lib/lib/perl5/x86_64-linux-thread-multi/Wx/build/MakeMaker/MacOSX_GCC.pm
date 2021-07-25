package Wx::build::MakeMaker::MacOSX_GCC;

use strict;
use base 'Wx::build::MakeMaker::Any_wx_config';
use Wx::build::Utils qw(write_string);

use Config;

if ($ENV{MACOSX_DEPLOYMENT_TARGET}) {
  my ($dt0, $dt1, @discard) = split(/[^0-9]+/,$ENV{MACOSX_DEPLOYMENT_TARGET} );
  if (($dt0 <= 10) && ( $dt1 < 3 )) {
	die "Please set MACOSX_DEPLOYMENT_TARGET to 10.3 or above";
  }
}

my $tools43 = '/Applications/Xcode.app/Contents/Developer/Tools';
my $restoolpath = ( -d $tools43 ) ? $tools43 : '/Developer/Tools';

sub get_flags {
  my $this = shift;
  my %config = $this->SUPER::get_flags;
  
  if ($config{CC} =~ /clang\+\+/ || $config{LD} =~ /clang\+\+/) {
	my $sdkrepl = '';
    # Get ahead with the xcode versions. It'll be wrong, but better than not
    # finding at all.
	for my $sdkversion ( qw( 10.14 10.13 10.12 10.11 10.10 10.9 10.8 10.7 10.6 ) ) {
	  my $macossdk = qq(/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX${sdkversion}.sdk);
	  if( -d $macossdk ) {
		$sdkrepl = 'clang++ -isysroot ' . $macossdk . ' -stdlib=libc++';
		last;
	  }
	}
	if ( $sdkrepl ) {
	  $config{CC} =~ s/clang\+\+/$sdkrepl/g;
	  $config{LD} =~ s/clang\+\+/$sdkrepl/g;
	}
  }
  return %config;
}

sub configure_core {
  my $this = shift;
  my %config = $this->SUPER::configure_core( @_ );

  $config{dynamic_lib}{OTHERLDFLAGS} .= ' -framework ApplicationServices ';

  if(    $Config{ptrsize} == 8
      && Alien::wxWidgets->version < 2.009 ) {
    print <<EOT;
=======================================================================
The 2.8.x wxWidgets for OS X does not support 64-bit. In order to build
wxPerl you will need to either recompile Perl as a 32-bit binary or (if
using the Apple-provided Perl) force it to run in 32-bit mode (see "man
perl").  Alpha 64-bit wx for OS X is in 2.9.x, but untested in wxPerl.
=======================================================================
EOT
    exit 1;
  }

  return %config;
}

sub const_config {
    my $text = shift->SUPER::const_config( @_ );
    $text =~ s{^([A-Z_]+FLAGS\s*=.*?)-nostdinc?}{$1}mg;
    return $text;
}

1;

# local variables:
# mode: cperl
# end:

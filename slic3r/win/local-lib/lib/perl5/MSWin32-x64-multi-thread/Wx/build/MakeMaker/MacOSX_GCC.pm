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
	for my $sdkversion ( qw( 10.9 10.8 10.7 10.6 ) ) {
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

  $config{depend}{'$(INST_STATIC)'} .= ' wxPerl';
  $config{depend}{'$(INST_DYNAMIC)'} .= ' wxPerl';
  $config{clean}{FILES} .= " wxPerl cpp/wxPerl.osx/build cpp/wxPerl.osx/wxPerl.c cpp/wxPerl.osx/wxPerl.r";
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

sub install_core {
  my $this = shift;
  my $text = $this->SUPER::install_core( @_ );

  $text =~ m/^(install\s*:+)/m and
    $text .= "\n\n$1 install_wxperl\n\n";

  return $text;
}

sub postamble_core {
  my $this = shift;
  my $text = $this->SUPER::postamble_core( @_ );
  my $wx_config = $ENV{WX_CONFIG} || 'wx-config';
  my $rfile;

  return '' unless $Wx::build::MakeMaker::Core::has_alien;

  if(    $Wx::build::MakeMaker::Core::has_alien
      && Alien::wxWidgets->version < 2.006 ) {
    my $rsrc = join ' ', grep { /wx/ } split ' ', `$wx_config --rezflags`;
    $rfile = sprintf <<EOR, $rsrc;
	echo '#include <Carbon.r>' > cpp/wxPerl.osx/wxPerl.r
	cat %s >> cpp/wxPerl.osx/wxPerl.r
EOR
  } else {
    $rfile = <<EOE;
	echo '#include <Carbon.r>' > cpp/wxPerl.osx/wxPerl.r
EOE
  }

  my $arch = $this->{INSTALLSITEARCH};
  $arch =~ s/\$\(SITEPREFIX\)/$this->{PREFIX}/e;
  $arch =~ s/\$\(INSTALL_BASE\)/$this->{INSTALL_BASE}/e;
  write_string( 'cpp/wxPerl.osx/wxPerl.c', sprintf <<EOT, $arch );
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

int main( int argc, char **argv )
{
    argv[0] = "%s/auto/Wx/wxPerl.app/Contents/MacOS/wxPerl";
    execv( argv[0], argv );
    perror( "wxPerl: execv" );
    exit( 1 );
}
EOT

  my $arch_flags = join ' ',
                        ( Alien::wxWidgets->c_flags =~ /(^|\s)(-arch\s+\w+)/g );

  $text .= sprintf <<'EOT', $rfile, $restoolpath, $arch_flags, $arch_flags;

wxPerl : Makefile
%s	cd cpp/wxPerl.osx && make RESTOOLDIR='%s' ARCH_FLAGS='%s'
	cp -p $(PERL) `find cpp -name wxPerl.app`/Contents/MacOS/wxPerl
	mkdir -p $(INST_ARCHLIB)/auto/Wx
	cp -rp `find cpp -name wxPerl.app` $(INST_ARCHLIB)/auto/Wx
	$(CC) %s cpp/wxPerl.osx/wxPerl.c -o wxPerl

install_wxperl :
	mkdir -p $(DESTINSTALLBIN)
	cp -p wxPerl $(DESTINSTALLBIN)

EOT

  return $text;
}

1;

# local variables:
# mode: cperl
# end:

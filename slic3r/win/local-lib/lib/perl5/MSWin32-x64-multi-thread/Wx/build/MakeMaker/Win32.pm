package Wx::build::MakeMaker::Win32;

use strict;
use base 'Wx::build::MakeMaker::Any_OS';
use Wx::build::Utils;
use Config;

sub is_mingw() { $Config{cc} =~ /gcc/ }
sub is_msvc() { $Config{cc} =~ /cl/ }

sub get_flags {
  my $this = shift;
  my %config = $this->SUPER::get_flags;

  $config{CC} = Alien::wxWidgets->compiler;
  $config{LD} = Alien::wxWidgets->linker;
  # used to be CCFLAGS, but overrode CCFLAGS from MakeMaker
  $config{CC} .= ' ' . Alien::wxWidgets->c_flags . ' ';
#  $config{dynamic_lib}{OTHERLDFLAGS} = Alien::wxWidgets->link_flags;
  $config{clean}{FILES} .= is_mingw ? ' dll.base dll.exp '
                                    :' *.pdb *.pdb *_def.old ';
  $config{DEFINE} .= Alien::wxWidgets->defines . ' ';
  $config{INC} .= Alien::wxWidgets->include_path;

  if( $this->_debug ) {
    $config{OPTIMIZE} = ' ';
  }

  if( is_mingw() ) {
      # add $MINGWDIR/lib to lib search path, to stop perl from complaining...
      my $path = Wx::build::Utils::path_search( 'gcc.exe' )
        or warn "Unable to find gcc";
      $path =~ s{bin[\\/]gcc\.exe$}{}i;
      $config{LIBS} = "-L${path}lib " . ( $config{LIBS} || '' );
  } else {
      $config{DEFINE} .= '-D_CRT_SECURE_NO_DEPRECATE ';
  }

  return %config;
}

sub configure_core {
  my $this = shift;
  my %config = $this->SUPER::configure_core( @_ );

  my $res = $this->_res_file;
  $config{depend}      = { $res => 'Wx.rc ' };
  $config{LDFROM}     .= "\$(OBJECT) $res ";
  $config{dynamic_lib}{INST_DYNAMIC_DEP} .= " $res";
  $config{clean}{FILES} .= " $res Wx_def.old";

  return %config;
}

sub postamble_core {
  my $this = shift;
  my $text = $this->SUPER::postamble_core( @_ );

  return $text unless $Wx::build::MakeMaker::Core::has_alien;

  my $wxdir = Alien::wxWidgets->wx_base_directory;
  my $command = $this->_res_command;
  my $res_file = $this->_res_file;

  $command =~ s/%incdir/$wxdir\\include/;
  $command =~ s/%src/Wx.rc/;
  $command =~ s/%dest/$res_file/;
  my $strip = $this->_strip_command;

  $text .= sprintf <<'EOT', $res_file, $command, $strip, $^X;

%s : Wx.rc
	%s

# for compatibility
ppmdist : ppm

ppm : pure_all
%s
	%s script/make_ppm.pl

EOT
}

1;

# local variables:
# mode: cperl
# end:

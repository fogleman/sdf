package Wx::build::MakeMaker::Any_wx_config;

use strict;
use base 'Wx::build::MakeMaker::Any_OS';
use Wx::build::MakeMaker::Hacks 'hijack';

require ExtUtils::Liblist;
my $save = hijack( 'MM', 'ext', \&my_ext );
sub my_ext {
  my $this = shift;
  my $libs = shift;
  my $full; if( $libs =~ m{(?:\s+|^)(/\S+)} )
    { $full = $1; $libs =~ s{(?:\s+|^)/\S+}{}g }
  my @libs = &{$save}( $this, $libs, @_ );
  if( defined $full ) {
    $libs[0] = "$libs[0] $full $libs[0]" if $libs[0];
    $libs[2] = "$libs[2] $full $libs[2]" if $libs[2];
  }

  return @libs;
}

sub get_flags {
  my $this = shift;
  my %config = $this->SUPER::get_flags;

  $config{CC} = $ENV{CXX} || Alien::wxWidgets->compiler;
  $config{LD} = $ENV{CXX} || Alien::wxWidgets->linker;
  # used to be CCFLAGS, but overrode CCFLAGS from MakeMaker
  $config{CC} .= ' ' . Alien::wxWidgets->c_flags . ' ';
  $config{dynamic_lib}{OTHERLDFLAGS} .= Alien::wxWidgets->link_flags . ' ';
  $config{DEFINE} .= Alien::wxWidgets->defines . ' ';
  $config{INC} .= Alien::wxWidgets->include_path;

  if( $this->_debug ) {
    $config{OPTIMIZE} = ' ';
  }

  return %config;
}

sub const_config {
    my $text = shift->SUPER::const_config( @_ );

    $text =~ s{^(LD(?:DL)?FLAGS\s*=.*?)-L/usr/local/lib64/?}{$1}mg;
    $text =~ s{^(LD(?:DL)?FLAGS\s*=.*?)-L/usr/local/lib/?}{$1}mg;

    return $text;
}

1;

# local variables:
# mode: cperl
# end:


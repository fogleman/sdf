package Wx::build::MakeMaker;

use strict;
use ExtUtils::MakeMaker;
use base 'Exporter';
use Config;
use vars qw(@EXPORT $VERSION);
use FindBin;
use File::Basename qw();

$VERSION = '0.28';
@EXPORT = 'wxWriteMakefile';

# get rid of suffix in MakeMaker version to be able treat it like a number in
# comparisons
my $MAKEMAKER_VERSION = $ExtUtils::MakeMaker::VERSION;
$MAKEMAKER_VERSION =~ s/_\d+$//;

# sanitize File::Find on filesystems where nlink of directories is < 2
use File::Find;
$File::Find::dont_use_nlink = 1 if ( stat('.') )[3] < 2;

=head1 NAME

Wx::build::MakeMaker - ExtUtils::MakeMaker specialisation for wxPerl modules

=head1 SYNOPSIS

use Wx::build::MakeMaker;

wxWriteMakefile( NAME         => 'My::Module',
                 VERSION_FROM => 'Module.pm' );

=head1 FUNCTIONS

=head2 wxWriteMakefile

  wxWriteMakefile( arameter => value, ... );

This functions is meant to be used exactly as
ExtUtils::MakeMaker::WriteMakefile (see). It accepts all WriteMakefile's
parameters, plus:

=over 4

=item * WX_CORE_LIB

  WX_CORE_LIB => 'xrc core base'

link libraries from wxWidgets' core or contrib directory.
If not spedified, defaults to 'adv html core net base' for compatibility.

=item * WX_LIB

  WX_LIB => '-lxrc'

Link additional libraries from wxWidgets' contrib directory.

=item * REQUIRE_WX

  REQUIRE_WX => 2.003002  # wxWidgets 2.3.2

Do not build this module if wxWidgets' version is lower than the version
specified.

=item * NO_WX_PLATFORMS

  NO_WX_PLATFORMS => [ 'x11', 'msw' ]

Do not build this module on the specified platform(s).

=item * ON_WX_PLATFORMs

  ON_WX_PLATFORMS => [ 'gtk' ]

only build this module on the specified platform(s).

=back

=head1 PRIVATE FUNCTIONS

These functions are here for reference, do not use them.

=head2 is_core

  if( is_core ) { ... }

True if it is building the wxPerl core (Wx.dll), false otherwise.

=head2 is_wxPerl_tree

  if( is_wxPerl_tree ) { ... }

True if it is building any part of wxPerl, false otherwise.

=cut

my $is_wxperl_tree = 0;

sub is_core() { -f 'Wx.pm' }
sub _set_is_wxPerl_tree { $is_wxperl_tree = $_[0] ? 1 : 0 }
sub is_wxPerl_tree { $is_wxperl_tree }

#   _call_method( 'method', $this, @args );
# calls the _core or _ext version of a method;
sub _call_method {
  my $name = shift;
  my $this = shift;
  $name .= is_core ? '_core' : '_ext';

  return $this->$name( @_ );
}

=head2 set_hook_package

  Wx::build::MakeMaker::set_hook_package( 'package_name' );

Package to be hooked into the MakeMaker inheritance chain.

=cut

# this is the default
my $hook_package;

BEGIN {
  my $package_to_use;
 SWITCH: {
    local $_ = $Config{osname};

    # Win32
    m/MSWin32/ and do {
      local $_ = File::Basename::basename( $Config{cc} );

      m/^cl/i  and $package_to_use = 'Win32_MSVC'  and last SWITCH;
      m/^gcc/i and $package_to_use = 'Win32_MinGW' and last SWITCH;

      # default
      die "Your compiler is not currently supported on Win32"
    };

    # MacOS X is slightly different...
    m/darwin/ and do {
      $package_to_use = 'MacOSX_GCC';
      last SWITCH;
    };

    # default
    $package_to_use = 'Any_wx_config';
    last SWITCH;
  }
  $hook_package = 'Wx::build::MakeMaker::' . $package_to_use;
}

sub set_hook_package {
  $hook_package = shift;
}

# this is a crude hack (at best), we put an arbitrary package
# into ExtUtils::MakeMaker inheritance chain in order to be able
# to customise it
sub import {
  undef *MY::libscan;
  *MY::libscan = _make_hook( 'libscan' );

  Wx::build::MakeMaker->export_to_level( 1, @_ );
}

=head1 METHODS

=head2 get_api_directory

  my $dir = $cfg->get_api_directory;

=head2 get_arch_directory

  my $dir = $cfg->get_arch_directory;

=cut

sub get_api_directory {
  if( is_wxPerl_tree() ) {
    return Wx::build::Utils::src_dir( 'Wx.pm' );
  } else {
    my $path = $INC{'Wx/build/MakeMaker.pm'};
    my( $vol, $dir, $file ) = File::Spec->splitpath( $path );
    my @dirs = File::Spec->splitdir( $dir ); pop @dirs; pop @dirs;
    return File::Spec->catpath( $vol, File::Spec->catdir( @dirs ) );
  }
}

sub get_arch_directory {
  if( is_wxPerl_tree() ) {
    require Carp;
    Carp::confess( "Should not be called!" );
  } else {
    my $path = $INC{'Wx/build/Opt.pm'};
    my( $vol, $dir, $file ) = File::Spec->splitpath( $path );
    my @dirs = File::Spec->splitdir( $dir ); pop @dirs; pop @dirs; pop @dirs;
    return File::Spec->catpath( $vol, File::Spec->catdir( @dirs ) );
  }
}

sub check_core_lib {
  my( $this, @libs ) = @_;

  return eval { Alien::wxWidgets->libraries( @libs ); 1 } ? 1 : 0;
}

sub get_core_lib {
  my( $this, @libs ) = @_;

  return join ' ', Alien::wxWidgets->libraries( @libs );
}

our $is_core = 0;

sub get_wx_platform { Alien::wxWidgets->config->{toolkit} }
sub get_wx_version { Alien::wxWidgets->version }
sub _unicode { Alien::wxWidgets->config->{unicode} }
sub _mslu    { Alien::wxWidgets->config->{mslu} }
sub _debug   { Alien::wxWidgets->config->{debug} }
sub _core    { $is_core }
sub _static  { Alien::wxWidgets->config->{static} }

sub _make_hook {
  my $hook_sub = shift;

  return sub {
    my $this = $_[0];
    my $class = ref $this;
    ( my $file = $hook_package ) =~ s{::}{/}g;
    no strict 'refs';
    require "$file.pm";
    undef *{"${class}::${hook_sub}"};
    unshift @{"${class}::ISA"}, $hook_package;

    shift->$hook_sub( @_ );
  }
}

# this method calls ->configure
# in the appropriate Wx::build::MakeMaker::PACKAGE,
# and merges the results with its inputs
use vars qw(%cfg1 %cfg2);

sub _libs($) { ref( $_[0] ) ? @{$_[0]} : ( $_[0] ) }

# removes the -L/path from the imput and returns them and
# the cleaned input
sub _split_lib($) {
  my $str = shift || '';
  my @paths = $str =~ m/(-L[^ ]+)/g;
  $str =~ s/-L[^ ]+ +//g;

  return ( $str, @paths );
}

sub merge_config {
  my( $cfg1, $cfg2 ) = @_;
  local *cfg1 = $cfg1;
  local *cfg2 = $cfg2;
  my %cfg = %cfg1;

  foreach my $i ( keys %cfg2 ) {
    if( exists $cfg{$i} ) {
      # merging libraries is always a mess; the hope is that
      # this will work in all cases, but there are no guarantees...
      if( $i eq 'LIBS' ) {
        my @a = _libs(  $cfg{LIBS} );
        my @b = _libs( $cfg2{LIBS} );

        my @c;
        foreach my $i ( @b ) {
          my( $mi, @ipaths ) = _split_lib( $i );
          foreach my $j ( @a ) {
            my( $mj, @jpaths ) = _split_lib( $j );
            push @c, " @ipaths @jpaths $mj $mi ";
          }
        }

        $cfg{LIBS} = \@c;
        next;
      }

      if( $i eq 'clean' || $i eq 'realclean' ) {
        $cfg{$i}{FILES} .= ' ' . $cfg{$i}{FILES};
        next;
      }

      if( ref($cfg{$i}) || ref($cfg2{$i}) ) {
        die "non scalar key '$i' while merging configuration information";
        $cfg{$i} = $cfg2{$i};
      } else {
        $cfg{$i} .= " $cfg2{$i}";
      }
    } else {
      $cfg{$i} = $cfg2{$i};
    }
  }

  return %cfg;
}

sub configure {
  ( my $file = $hook_package ) =~ s{::}{/}g;
  require "$file.pm";

  # do it at runtime
  require Alien::wxWidgets;
  Alien::wxWidgets->VERSION( 0.04 );

  my $this = $_[0];
  my %cfg1 = %{$_[1]};
  my %cfg2 = _call_method( 'configure', $hook_package );
  my %cfg = merge_config( \%cfg1, \%cfg2 );

  return \%cfg;
}

sub _make_override {
  my $name = shift;
  my $sub = sub {
    package MY;
    my $this = shift;
    my $full = "SUPER::$name";
    $this->$full( @_ );
  };
  no strict 'refs';
  *{"${name}_core"} = $sub;
  *{"${name}_ext"}  = $sub;
  *{"${name}"}      = sub { _call_method( $name, @_ ) };
}

_make_override( 'subdirs' );
_make_override( 'postamble' );
_make_override( 'depend' );
_make_override( 'install' );
_make_override( 'libscan' );
_make_override( 'constants' );
_make_override( 'metafile_target' );
_make_override( 'manifypods' );
sub ppd { package MY; shift->SUPER::ppd( @_ ) }
sub dynamic_lib { package MY; shift->SUPER::dynamic_lib( @_ ) }
sub const_config { package MY; shift->SUPER::const_config( @_ ) }

use vars qw(%args %additional_arguments $wx_top_file);
sub _process_mm_arguments {
  my( $args, $has_alien ) = @_;
  local *args = $args;
  my $build = 1;
  my %options =
    Wx::build::Options->get_makemaker_options( is_wxPerl_tree()
                                               ? () : ( 'saved' ) );

  $additional_arguments{WX_TOP} = $wx_top_file if $wx_top_file;
  unless( $has_alien ) {
      $args{depend} = { '$(FIRST_MAKEFILE)' => 'alien_wxwidgets_missing' };
      delete $args{$_} foreach grep /WX_|_WX/, keys %args;
      return 1;
  }
  my $platform = Alien::wxWidgets->config->{toolkit};

  $args{CCFLAGS} .= $options{extra_cflags} ? ' ' . $options{extra_cflags} : '';
  $args{LIBS} .=  $options{extra_libs} ? ' ' . $options{extra_libs} : '';
  $args{WX_CORE_LIB} ||= 'adv html core net base';

  foreach ( keys %args ) {
    my $v = $args{$_};

    m/^(NO|ON)_WX_PLATFORMS$/ and do {
      my $on = $1 eq 'ON';

      if( $on ) {
        # build if platform is explicitly listed
        $build &&= grep { $_ eq $platform } @$v;
      } else {
        # build unless platform is explicitly listed
        $build &&= !grep { $_ eq $platform } @$v;
      }

      delete $args{$_};
    };

    m/^REQUIRE_WX$/ and do {
      $build &&= __PACKAGE__->get_wx_version() >= $v;
      delete $args{$_};
    };

    m/^REQUIRE_WX_LIB$/ and do {
      my @libs = split ' ', $v;
      $build &&= __PACKAGE__->check_core_lib( @libs ) if $v=~/\S/;
      delete $args{$_};
    };
  }

  return $build unless $build;

  foreach ( keys %args ) {
    my $v = $args{$_};

    m/^WX_CORE_LIB_MAYBE$/ and do {
      my @libs = split ' ', $v;
      $args{LIBS} .= ' ' . join ' ',
                           map  { __PACKAGE__->get_core_lib( $_ ) }
                           grep { __PACKAGE__->check_core_lib( $_ ) }
                                ( $v=~/\S/ ? @libs : () );
      delete $args{$_};
    };

    m/^WX_CORE_LIB$/ and do {
      my @libs = split ' ', $v;
      $args{LIBS} .= ' ' . join ' ', __PACKAGE__->get_core_lib( @libs ) if $v=~/\S/;
      delete $args{$_};
    };

    m/^WX_LIB$/ and do {
      die "Please use WX_CORE_LIB instead of WX_LIB";
    };

    m/^(?:ABSTRACT_FROM|AUTHOR)/ and do {
      # args not known prior to Perl 5.005_03 (the check is a bit conservative)
      delete $args{$_} if $MAKEMAKER_VERSION < 5.43;
    };

    m/^(?:LICENSE)/ and do {
      # args not known prior to MakeMaker 6.32
      delete $args{$_} if $MAKEMAKER_VERSION < 6.32;
    };

    m/^WX_TOP$/ and do {
      $wx_top_file = $args{$_};
    };

    m/^WX_/ and do {
      $additional_arguments{$_} = delete $args{$_};
    };
  }

  return $build;
}

sub wxWriteMakefile {
  my %params = @_;
  local $is_core = 0;

  my $has_alien = $Wx::build::MakeMaker::Core::has_alien;
  $has_alien = defined( $has_alien ) ? $has_alien : 1;

  $params{XSOPT}     = ' -noprototypes' .
    ( is_wxPerl_tree() ? ' -nolinenumbers ' : ' ' );
  if( $has_alien ) {
    $params{CONFIGURE} = \&Wx::build::MakeMaker::configure;
    require Wx::build::MakeMaker::Any_OS;
    push @{$params{TYPEMAPS} ||= []},
      File::Spec->catfile( __PACKAGE__->get_api_directory, 'typemap' );
    ( $params{PREREQ_PM} ||= {} )->{Wx} ||= '0.19' unless is_wxPerl_tree();
  }

  my $build = Wx::build::MakeMaker::_process_mm_arguments( \%params, $has_alien );

  if( $build ) {
    WriteMakefile( %params );
  } else {
    ExtUtils::MakeMaker::WriteEmptyMakefile( %params );
  }
}

1;

# local variables:
# mode: cperl
# end:

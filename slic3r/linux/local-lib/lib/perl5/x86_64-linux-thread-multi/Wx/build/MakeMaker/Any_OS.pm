package Wx::build::MakeMaker::Any_OS;

use strict;
use base 'Wx::build::MakeMaker';
use File::Spec::Functions qw(curdir);
use Wx::build::Options;
use Wx::build::Utils qw(xs_dependencies lib_file);

my $exp = lib_file( 'Wx/Wx_Exp.pm' );
my @generated_xs = qw(XS/ItemContainer.xs XS/ItemContainerImmutable.xs
                      XS/VarScrollHelperBase.xs XS/VarVScrollHelper.xs
                      XS/VarHScrollHelper.xs XS/VarHVScrollHelper.xs);
sub get_flags {
  my $this = shift;
  my %config;

  if( %Wx::build::MakeMaker::additional_arguments ) {
    $config{WX}{lc $_} = $Wx::build::MakeMaker::additional_arguments{$_}
      foreach keys %Wx::build::MakeMaker::additional_arguments;
    $ExtUtils::MakeMaker::Recognized_Att_Keys{WX} = 1;
    %Wx::build::MakeMaker::additional_arguments = ();
  }

  if( $config{WX}{wx_overload} ) {
      $_ = File::Spec->catfile( split /\//, $_ )
        foreach values %{$config{WX}{wx_overload}};
  }

  $config{INC} .= '-I' . curdir . ' ';
  $config{INC} .= '-I' . $this->get_api_directory . ' ';

  unless( $this->_core ) {
    $config{DEFINE} .= " -DWXPL_EXT ";
  }

  if( $this->_static ) {
    $config{DEFINE} .= " -DWXPL_STATIC ";
  }

  return %config;
}

sub metafile_target_ext {
    return '' if Wx::build::MakeMaker::is_wxPerl_tree;
    return shift->MM::metafile_target( @_ );
}

sub metafile_target_core {
    return shift->MM::metafile_target( @_ );
}

sub configure_core {
  my $this = shift;
  my %config = $this->get_flags;

  $config{clean} =
    { FILES => "$config{WX}{wx_overload}{source}" .
               " $config{WX}{wx_overload}{header} Opt" .
               " files.lst cpp/setup.h cpp/v_cback_def.h" .
               " " . join( " ", @generated_xs ) .
               " overload.lst xspp wxt_*" };

  return %config;
}

sub configure_ext {
  my $this = shift;
  my %config = $this->get_flags;

  my( $ovlc, $ovlh ) = $config{WX}{wx_overload} ?
    @{$config{WX}{wx_overload}}{qw(source header)} : ();
  if( $ovlc && $ovlh ) {
    $config{clean} =
      { FILES => "$config{WX}{wx_overload}{source}" .
                 " $config{WX}{wx_overload}{header} wxt_overload" };
  }
  $config{clean}{FILES} .= " xspp";

  return %config;
}

sub files_with_constants {
  my( $this ) = @_;
  return @{$this->{wx_files_with_constants}}
    if $this->{wx_files_with_constants};
  return @{$this->{wx_files_with_constants} =
             [ Wx::build::Utils::files_with_constants ]};
}

sub files_with_overload {
  my( $this ) = @_;
  return @{$this->{wx_files_with_overload}}
    if $this->{wx_files_with_overload};
  return @{$this->{wx_files_with_overload} =
             [ Wx::build::Utils::files_with_overload ]};

}

sub _depend_common {
  my $this = shift;

  my $top_file =    $this->{WX}{wx_top}
                 || $this->{ARGS}{VERSION_FROM}
                 || $this->{ARGS}{ABSTRACT_FROM}
                 || 'Wx.pm';
  my( $ovlc, $ovlh ) = $this->{WX}{wx_overload} ?
    @{$this->{WX}{wx_overload}}{qw(source header)} : ();
  return ( xs_dependencies( $this, [ curdir, $this->get_api_directory
                                     ],
                            Wx::build::Utils::src_dir( $top_file ) ),
           # overload
           ( $ovlc && $ovlh ?
             ( $ovlc             => 'wxt_overload',
               $ovlh             => $ovlc,
               ) :
             ( ) ),
           );
}

sub depend_core {
  my $this = shift;

  my %files = $this->files_to_install();
  my %depend = ( _depend_common( $this ),
                 $exp              => join( ' ', $this->files_with_constants, ),
                 'wxt_fix_alien'   => 'pm_to_blib',
                 'pm_to_blib'      => 'wxt_copy_files',
                 'blibdirs'        => 'wxt_copy_files',
                 'blibdirs.ts'     => 'wxt_copy_files',
                 'wxt_copy_files'  => join( ' ', keys %files ),
               );
  my %this_depend = @_;

  foreach ( keys %depend ) {
    $this_depend{$_} .= ' ' . $depend{$_};
  }

  $this->SUPER::depend_core( %this_depend );
}

sub depend_ext {
  my $this = shift;

  my %depend = _depend_common( $this );
  my %this_depend = @_;

  foreach ( keys %depend ) {
    $this_depend{$_} .= ' ' . $depend{$_};
  }

  $this->SUPER::depend_ext( %this_depend );
}

sub subdirs_core {
  my $this = shift;
  my $text = $this->SUPER::subdirs_core( @_ );

  return <<EOT . $text;
subdirs :: wxt_overload

EOT
}

sub subdirs_ext {
  my $this = shift;
  my $text = $this->SUPER::subdirs_core( @_ );

  return ( $this->{WX}{wx_overload} ? <<EOT : '' ) . $text;
subdirs :: wxt_overload

EOT
}

sub postamble_overload {
  my( $this ) = @_;

  # command line length workaround
  if(    !Wx::build::MakeMaker::is_wxPerl_tree
      || Wx::build::MakeMaker::is_core ) {
    Wx::build::Utils::write_string( 'overload.lst',
                                    join "\n", $this->files_with_overload );
  }
  my $ovl_script = Wx::build::MakeMaker::is_wxPerl_tree() ?
      'script/wxperl_overload' : "-S wxperl_overload";
  my( $ovlc, $ovlh ) = $this->{WX}{wx_overload} ?
    @{$this->{WX}{wx_overload}}{qw(source header)} : ();
  return ( $this->{WX}{wx_overload} ? <<EOT : '' );
wxt_overload :
\t\$(PERL) $ovl_script $ovlc $ovlh overload.lst
\t\$(TOUCH) wxt_overload

EOT
}

sub postamble_core {
  my $this = shift;
  my %files = $this->files_to_install();

  # not all the dependencies added in Utils.pm for Wx_Exp.pm are
  # strictly necessary, but it's better to keep them in case the
  # dependencies here are changed
  require Data::Dumper;
  Wx::build::Utils::write_string( 'files.lst',
                                  Data::Dumper->Dump( [ \%files ] ) );
  # $exp and fix_alien depend on wxt_copy_files to ensure that blib/lib/Wx
  # has been created
  my $text = <<EOT . $this->postamble_overload;

$exp : wxt_copy_files wxt_binary_\$(LINKTYPE)
\t\$(PERL) script/make_exp_list.pl $exp @{[$this->files_with_constants]} xspp/*.h ext/*/xspp/*.h

\$(LINKTYPE) :: wxt_fix_alien $exp

wxt_binary_static : \$(INST_STATIC)
	\$(NOECHO) \$(TOUCH) wxt_binary_static

wxt_binary_dynamic : \$(INST_DYNAMIC)
	\$(NOECHO) \$(TOUCH) wxt_binary_dynamic

wxt_copy_files :
\t\$(PERL) script/copy_files.pl files.lst
\t\$(TOUCH) wxt_copy_files

wxt_fix_alien : wxt_copy_files lib/Wx/Mini.pm
\t\$(PERL) script/fix_alien_path.pl lib/Wx/Mini.pm blib/lib/Wx/Mini.pm
\t\$(TOUCH) wxt_fix_alien

parser :
	yapp -v -s -m Wx::XSP::Grammar -o build/Wx/XSP/Grammar.pm build/Wx/XSP/XSP.yp

typemap : typemap.tmpl script/make_typemap.pl
	\$(PERL) script/make_typemap.pl typemap.tmpl typemap

cpp/v_cback_def.h : script/make_v_cback.pl
	\$(PERL) script/make_v_cback.pl > cpp/v_cback_def.h

EOT

  foreach my $f ( @generated_xs ) {
      my $file = File::Spec->canonpath( $f );
      $text .= sprintf <<EOT, $file, $file, $file, $file;
%s : %sp typemap.xsp
	\$(PERL) -MExtUtils::XSpp::Cmd -e xspp -- -t typemap.xsp %sp > %s

EOT
  }

  $text .= sprintf <<EOT, join( ' ', @generated_xs );
generated : cpp/v_cback_def.h typemap %s wxt_overload

EOT

  $text;
}

sub postamble_ext {
    my( $this ) = @_;

    return $this->postamble_overload;
}

# here because File::Find::find chdirs, and our is_core is,
# er, quite limited
sub libscan_ext {
  my( $this, $inst ) = @_;

  $inst =~ s/(\W+)build\W+Wx/$1Wx/i && return $inst;

  return $this->SUPER::libscan_core( $inst );
}

sub constants_core {
  my $this = shift;

  foreach my $k ( grep { m/~$/ } keys %{$this->{PM}} ) {
    delete $this->{PM}{$k};
  }

  return $this->SUPER::constants_core( @_ );
}

# returns an hash of files to be copied
sub files_to_install {
  my @api = qw(cpp/chkconfig.h
               cpp/compat.h
               cpp/constants.h
               cpp/event.h
               cpp/e_cback.h
               cpp/helpers.h
               cpp/overload.h
               cpp/setup.h
               cpp/streams.h
               cpp/v_cback.h
               cpp/v_cback_def.h
               cpp/wxapi.h
               typemap
              );
  # in arch, so $INC{'Opt.pm'} will tell where arch is
  return ( 'Opt', Wx::build::Utils::arch_file( 'Wx/build/Opt.pm' ),
           ( map { ( $_ => Wx::build::Utils::lib_file( "Wx/$_" ) ) } @api ),
         );
}

sub manifypods_core {
    my( $self ) = @_;

    s{([\\/])build::}{$1} foreach values %{$self->{MAN3PODS}};

    return $self->SUPER::manifypods_core;
}

1;

# local variables:
# mode: cperl
# end:

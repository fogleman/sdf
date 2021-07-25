#############################################################################
## Name:        build/Wx/Overload/Driver.pm
## Purpose:     builds overload constants
## Author:      Mattia Barbon
## Modified by:
## Created:     17/08/2001
## RCS-ID:      $Id: Driver.pm 2927 2010-06-06 08:06:10Z mbarbon $
## Copyright:   (c) 2001-2003, 2005-2008, 2010 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Overload::Driver;

use strict;

use Symbol qw(gensym);

use Wx::Overload::Handle;

my %_name2type =
  (
   wimg => 'Wx::Image',
   wbmp => 'Wx::Bitmap',
   wico => 'Wx::Icon',
   wmen => 'Wx::Menu',
   wmit => 'Wx::MenuItem',
   wrec => 'Wx::Rect',
   wreg => 'Wx::Region',
   wszr => 'Wx::Sizer',
   wtip => 'Wx::ToolTip',
   wwin => 'Wx::Window',
   wcol => 'Wx::Colour',
   wlci => 'Wx::ListItem',
   wgco => 'Wx::GridCellCoords',
   wdat => 'Wx::DataObject',
   wcur => 'Wx::Cursor',
   wehd => 'Wx::EvtHandler',
   wfon => 'Wx::Font',
   wdc  => 'Wx::DC',
   wfrm => 'Wx::Frame',
   wsiz => 1,
   wpoi => 1,
   wist => 1,
   wost => 1,
   num  => 1,
   str  => 1,
   bool => 1,
   arr  => 1,
   wpos => 1,
   zzz  => 1,
   );

my %name2type = %_name2type;
my %constants;

sub new {
  my( $class, %args ) = @_;
  my $self = bless \%args, $class;

  return $self;
}

sub process {
  my( $self ) = @_;

  $self->_parse;
  $self->_write;
}

sub _parse {
  my( $self ) = @_;

  foreach my $i ( $self->files ) {
    my %namedecl = %_name2type;
    open my $fh, '<', $i or die "open '$i': $!";

    while( <$fh> ) {
      if( m/DECLARE_OVERLOAD\(\s*(\w+)\s*,\s*(\S+)\s*\)/ ) {
        $namedecl{$1} = $2;
        next if exists $name2type{$1} && $name2type{$1} eq $2;
        die "Clashing type: '$1' was '$name2type{$1}', redeclared as '$2'"
          if exists $name2type{$1};
        $name2type{$1} = $2;
      }
      if( m/Wx::_match\(\s*\@_\s*,\s*\$Wx::_(\w+)\s*\,/ ||
          m/wxPliOvl_(\w+)/ ) {
        my $const = $1;
        my @const = split /_/, $const;
        foreach my $j ( @const ) {
          $j = 'num' if $j eq 'n';
          $j = 'str' if $j eq 's';
          $j = 'bool' if $j eq 'b';

          die "unrecognized type '$j' in file '$i'"
            unless $namedecl{$j};
          $constants{$const} = \@const;
        }
      }
    }
  }
}

sub _write {
  my( $self ) = @_;

  my @keys = ( ( sort grep { $name2type{$_} eq '1' } keys %name2type ),
               ( sort grep { $name2type{$_} ne '1' } keys %name2type ) );

  my $vars_comma = join ", ",
                   map  "\$$_",
                        @keys;
  my $vars = $vars_comma; $vars =~ s/,//g;
  my $types = join ", ",
              map  "'$name2type{$_}'",
              grep $name2type{$_} ne '1',
                   @keys;
  my $cpp_types = $types; $cpp_types =~ s/\'/\"/g;

  # header
  {
    my $out = gensym;
    tie *$out, 'Wx::Overload::Handle', $self->header;

    my $enum = join ",\n",
               map  "    wxPliOvl$_",
                    @keys;

    print $out <<EOT;
// GENERATED FILE, DO NOT EDIT

EOT

    foreach my $i ( sort keys %constants ) {
      print $out "extern const wxPliPrototype wxPliOvl_${i};\n";
    }

    close $out;
  }

  # write source
  {
    my $out = gensym;
    tie *$out, 'Wx::Overload::Handle', $self->source;

    print $out <<EOT;
// GENERATED FILE, DO NOT EDIT

#include "cpp/overload.h"

extern void wxPli_set_ovl_constant( const char* name,
                                    const wxPliPrototype* value );
EOT

    print $out <<EOT;

#ifndef WXPL_EXT

void SetOvlConstants()
{
    dTHX;
EOT

    foreach my $i ( sort keys %constants ) {
      print $out <<EOT
    wxPli_set_ovl_constant( \"$i\", &wxPliOvl_${i} );
EOT
    }

    print $out <<EOT;
}

#endif // WXPL_EXT

EOT

    foreach my $i ( grep { $name2type{$_} ne '1' } keys %name2type ) {
      print $out <<EOT;
#define wxPliOvl${i} "$name2type{$i}"
EOT
    }

    foreach my $i ( sort keys %constants ) {
      my $count = scalar @{$constants{$i}};
      print $out "const char* wxPliOvl_${i}_datadef\[\] = { ";
      print $out join ", ", map { "wxPliOvl$_" } @{$constants{$i}};
      print $out " };\n";
      print $out <<EOT;
const wxPliPrototype wxPliOvl_${i}
    ( wxPliOvl_${i}_datadef, $count );
EOT
    }

    close $out;
  }
}

sub source { $_[0]->{source} }
sub header { $_[0]->{header} }
sub files  { @{$_[0]->{files}} }

1;

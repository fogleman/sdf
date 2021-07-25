#############################################################################
## Name:        ext/grid/lib/Wx/Grid.pm
## Purpose:     Wx::Grid (pulls in all Wx::Grid* stuff)
## Author:      Mattia Barbon
## Modified by:
## Created:     04/12/2001
## RCS-ID:      $Id: Grid.pm 3316 2012-07-14 02:05:19Z mdootson $
## Copyright:   (c) 2001-2002, 2004-2007 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Grid;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::load_dll( 'adv' );
Wx::wx_boot( 'Wx::Grid', $VERSION );

SetEvents();

#
# properly setup inheritance tree
#

no strict;

package Wx::Grid; @ISA = qw(Wx::ScrolledWindow);
package Wx::GridWindow; @ISA = qw(Wx::Grid);
package Wx::GridEvent; @ISA = qw(Wx::NotifyEvent);
package Wx::GridSizeEvent; @ISA = qw(Wx::NotifyEvent);
package Wx::GridRangeSelectEvent; @ISA = qw(Wx::NotifyEvent);
package Wx::GridEditorCreatedEvent; @ISA = qw(Wx::CommandEvent);

package Wx::GridCellRenderer;
package Wx::GridCellStringRenderer; @ISA = qw(Wx::GridCellRenderer);
package Wx::GridCellNumberRenderer; @ISA = qw(Wx::GridCellRenderer);
package Wx::GridCellFloatRenderer; @ISA = qw(Wx::GridCellRenderer);
package Wx::GridCellBoolRenderer; @ISA = qw(Wx::GridCellRenderer);
package Wx::GridCellAutoWrapStringRenderer; @ISA = qw(Wx::GridCellStringRenderer);
package Wx::GridCellEnumRenderer; @ISA = qw(Wx::GridCellStringRenderer);
package Wx::GridCellDateTimeRenderer; @ISA = qw(Wx::GridCellStringRenderer);
package Wx::PlGridCellRenderer; @ISA = qw(Wx::GridCellRenderer);

package Wx::GridCellEditor;
package Wx::GridCellEditorEvtHandler; @ISA = qw(Wx::EvtHandler);
package Wx::GridCellBoolEditor; @ISA = qw(Wx::GridCellEditor);
package Wx::GridCellTextEditor; @ISA = qw(Wx::GridCellEditor);
package Wx::GridCellFloatEditor; @ISA = qw(Wx::GridCellEditor);
package Wx::GridCellNumberEditor; @ISA = qw(Wx::GridCellEditor);
package Wx::GridCellChoiceEditor; @ISA = qw(Wx::GridCellEditor);
package Wx::GridCellAutoWrapStringEditor; @ISA = qw(Wx::GridCellTextEditor);
package Wx::GridCellEnumEditor; @ISA = qw(Wx::GridCellChoiceEditor);
package Wx::PlGridCellEditor; @ISA = qw(Wx::GridCellEditor);

package Wx::GridTableBase;
package Wx::PlGridTable; @ISA = qw(Wx::GridTableBase);

package Wx::Event;
# allow 2.8 / 2.9 event name changes compatibility
if(defined(&Wx::Event::EVT_GRID_CELL_CHANGED)) {
  *Wx::Event::EVT_GRID_CELL_CHANGE = \&Wx::Event::EVT_GRID_CELL_CHANGED;
  *Wx::Event::EVT_GRID_CMD_CELL_CHANGE = \&Wx::Event::EVT_GRID_CMD_CELL_CHANGED;
} else {
  *Wx::Event::EVT_GRID_CELL_CHANGED = \&Wx::Event::EVT_GRID_CELL_CHANGE;
  *Wx::Event::EVT_GRID_CMD_CELL_CHANGED = \&Wx::Event::EVT_GRID_CMD_CELL_CHANGE;
}

package Wx::Grid;

use strict;

# this is for make_ovl_list to find constants
sub CellToRect {
  my $this = shift;

  Wx::_match( @_, $Wx::_wgco, 1 ) && return $this->CellToRectCo( @_ );
  Wx::_match( @_, $Wx::_n_n, 2 )  && return $this->CellToRectXY( @_ );
  Wx::_croak Wx::_ovl_error;
}

sub _create_ovls {
  my $name = shift;

  no strict;
  die $name unless defined &{$name . 'XY'} && defined &{$name . 'Co'};
  use strict;

  eval <<EOT;
sub ${name} {
  my \$this = shift;

  Wx::_match( \@_, \$Wx::_wgco, 1 ) && return \$this->${name}Co( \@_ );
  Wx::_match( \@_, \$Wx::_n_n, 2 )  && return \$this->${name}XY( \@_ );
  Wx::_croak Wx::_ovl_error;
}
EOT

  die $@ if $@;
}

# for copytex.pl
#!sub GetCellValue
#!sub IsInSelection
#!sub IsVisible
#!sub MakeCellVisible
#!sub GetDefaultEditorForCell

foreach my $i ( qw(GetCellValue IsInSelection IsVisible MakeCellVisible
                   GetDefaultEditorForCell) )
  { _create_ovls( $i ); }

sub SelectBlock {
  my $this = shift;

  Wx::_match( @_, $Wx::_wgco_wgco_b, 3 ) && return $this->SelectBlockPP( @_ );
  Wx::_match( @_, $Wx::_n_n_n_n_b, 5 )  && return $this->SelectBlockXYWH( @_ );
  Wx::_croak Wx::_ovl_error;
}

sub SetCellValue {
  my $this = shift;

  Wx::_match( @_, $Wx::_wgco_s, 2 ) && return $this->SetCellValueCo( @_ );
  Wx::_match( @_, $Wx::_n_n_s, 3 )  && return $this->SetCellValueXY( @_ );
  Wx::_croak Wx::_ovl_error;
}

1;

# Local variables: #
# mode: cperl #
# End: #

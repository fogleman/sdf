#############################################################################
## Name:        lib/Wx/RadioBox.pm
## Purpose:     Wx::RadioBox class
## Author:      Mattia Barbon
## Modified by:
## Created:     28/10/2000
## RCS-ID:      $Id: RadioBox.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2000-2002 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::RadioBox;

use strict;

sub Enable {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_b, 1 )   && ( $this->SUPER::Enable( @_ ), return );
  Wx::_match( @_, $Wx::_n_b, 2 ) && ( $this->EnableItem( @_ ), return );
  Wx::_croak Wx::_ovl_error;
}

sub GetLabel {
  my( $this ) = shift;

  @_ == 0                  && return $this->SUPER::GetLabel();
  Wx::_match( @_, $Wx::_n, 1 ) && return $this->GetItemLabel( @_ );
  Wx::_croak Wx::_ovl_error;
}

sub SetLabel {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_s, 1 )   && ( $this->SUPER::SetLabel( @_ ), return );
  Wx::_match( @_, $Wx::_n_s, 2 ) && ( $this->SetItemLabel( @_ ), return );
  Wx::_croak Wx::_ovl_error;
}

sub Show {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_n, 1 )   && ( $this->SUPER::Show( @_ ), return );
  Wx::_match( @_, $Wx::_n_n, 2 ) && ( $this->ShowItem( @_ ), return );
  Wx::_croak Wx::_ovl_error;
}

1;

# Local variables: #
# mode: cperl #
# End: #

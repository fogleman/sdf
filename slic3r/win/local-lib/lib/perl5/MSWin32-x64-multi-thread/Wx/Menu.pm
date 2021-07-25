#############################################################################
## Name:        lib/Wx/Menu.pm
## Purpose:     Wx::Menu class
## Author:      Mattia Barbon
## Modified by:
## Created:     25/11/2000
## RCS-ID:      $Id: Menu.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2000-2003, 2005-2006 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Menu;

use strict;

sub Append {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_n_s_wmen, 3, 1 ) && ( return $this->AppendSubMenu_( @_ ) );
  Wx::_match( @_, $Wx::_n_s, 2, 1 )      && ( return $this->AppendString( @_ ) );
  Wx::_match( @_, $Wx::_wmit, 1 )        && ( return $this->AppendItem( @_ ) );
  Wx::_croak Wx::_ovl_error;
}

sub Delete {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_wmit, 1 ) && ( $this->DeleteItem( @_ ), return );
  Wx::_match( @_, $Wx::_n, 1 )    && ( $this->DeleteId( @_ ), return );
  Wx::_croak Wx::_ovl_error;
}

sub Destroy {
  my( $this ) = shift;

  @_ == 0                     && ( $this->DestroyMenu(), return );
  Wx::_match( @_, $Wx::_wmit, 1 ) && ( $this->DestroyItem( @_ ), return );
  Wx::_match( @_, $Wx::_n, 1 )    && ( $this->DestroyId( @_ ), return );
  Wx::_croak Wx::_ovl_error;
}

sub Remove {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_wmit, 1 ) && return $this->RemoveItem( @_ );
  Wx::_match( @_, $Wx::_n, 1 )    && return $this->RemoveId( @_ );
  Wx::_croak Wx::_ovl_error;
}

sub Prepend {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_n_s_wmen, 3, 1 ) && ( $this->PrependSubMenu( @_ ), return );
  Wx::_match( @_, $Wx::_n_s, 2, 1 )      && ( $this->PrependString( @_ ), return );
  Wx::_match( @_, $Wx::_wmit, 1 )        && ( $this->PrependItem( @_ ), return );
  Wx::_croak Wx::_ovl_error;
}

sub Insert {
  my( $this ) = shift;

  Wx::_match( @_, $Wx::_n_n_s_wmen, 4, 1 ) && ( $this->InsertSubMenu( @_ ), return );
  Wx::_match( @_, $Wx::_n_n_s, 3, 1 )      && ( $this->InsertString( @_ ), return );
  Wx::_match( @_, $Wx::_n_wmit, 2 )        && ( $this->InsertItem( @_ ), return );
  Wx::_croak Wx::_ovl_error;
}


1;

# Local variables: #
# mode: cperl #
# End: #

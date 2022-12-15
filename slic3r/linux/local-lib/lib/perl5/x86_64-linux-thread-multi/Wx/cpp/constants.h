/////////////////////////////////////////////////////////////////////////////
// Name:        cpp/constants.h
// Purpose:     module to allow modularity in constant() function
// Author:      Mattia Barbon
// Modified by:
// Created:     17/03/2001
// RCS-ID:      $Id: constants.h 2498 2008-11-05 19:45:38Z mbarbon $
// Copyright:   (c) 2001-2002, 2005, 2008 Mattia Barbon
// Licence:     This program is free software; you can redistribute it and/or
//              modify it under the same terms as Perl itself
/////////////////////////////////////////////////////////////////////////////

#ifndef _WXPERL_CONSTANTS_H
#define _WXPERL_CONSTANTS_H

typedef double (*PL_CONST_FUNC)( const char*, int );

#define WX_PL_CONSTANT_INIT() \
  errno = 0;                \
  char fl = name[0];        \
                            \
  if( tolower( name[0] ) == 'w' && tolower( name[1] ) == 'x' ) \
    fl = toupper( name[2] );

#define WX_PL_CONSTANT_CLEANUP() \
  errno = EINVAL;                \
  return 0;

// implementation for OnInit/OnExit in Constants.xs
class wxPlConstants
{
public:
    wxPlConstants( PL_CONST_FUNC function );
    ~wxPlConstants();
private:
    PL_CONST_FUNC m_function;
};

// duplicated from helpers.h
extern void FUNCPTR( wxPli_add_constant_function )
    ( double (**)( const char*, int ) );
extern void FUNCPTR( wxPli_remove_constant_function )
    ( double (**)( const char*, int ) );

inline wxPlConstants::wxPlConstants( PL_CONST_FUNC function )
    :m_function( function )
{
#if NEEDS_PLI_HELPERS_STRUCT()
    dTHX;
    // GRR! init helpers...
    SV* wxpli_tmp = get_sv( "Wx::_exports", 1 );
    wxPliHelpers* name = INT2PTR( wxPliHelpers*, SvIV( wxpli_tmp ) );
    wxPli_add_constant_function = name->m_wxPli_add_constant_function;
#endif
    wxPli_add_constant_function( &m_function );
}

inline wxPlConstants::~wxPlConstants()
    { wxPli_remove_constant_function( &m_function ); }

#endif
    // _WXPERL_CONSTANTS_H

// Local variables: //
// mode: c++ //
// End: //




/////////////////////////////////////////////////////////////////////////////
// Name:        cpp/compat.h
// Purpose:     some compatibility macros
// Author:      Mattia Barbon
// Modified by:
// Created:     29/10/2000
// RCS-ID:      $Id: compat.h 2532 2009-02-21 08:51:16Z mbarbon $
// Copyright:   (c) 2000-2003, 2006, 2008-2009 Mattia Barbon
// Licence:     This program is free software; you can redistribute it and/or
//              modify it under the same terms as Perl itself
/////////////////////////////////////////////////////////////////////////////

#if !defined( PERL_REVISION ) && !defined( PATCHLEVEL )
#include <patchlevel.h>
#endif

// version < 5.6 does not define PERL_
#ifdef PERL_REVISION
#define WXPERL_P_VERSION_EQ( V, S, P ) \
 ( ( PERL_REVISION == (V) ) && ( PERL_VERSION == (S) ) && ( PERL_SUBVERSION == (P) ) )
#define WXPERL_P_VERSION_GE( V, S, P ) \
 ( ( PERL_REVISION > (V) ) || \
   ( PERL_REVISION == (V) && PERL_VERSION > (S) ) || \
   ( PERL_REVISION == (V) && PERL_VERSION == (S) && PERL_SUBVERSION >= (P) ) )

#else
#define WXPERL_P_VERSION_EQ( V, S, P ) \
 ( ( 5 == (V) ) && ( PATCHLEVEL == (S) ) && ( SUBVERSION == (P) ) )
#define WXPERL_P_VERSION_GE( V, S, P ) \
 ( ( 5 > (V) ) || \
   ( 5 == (V) && PATCHLEVEL > (S) ) || \
   ( 5 == (V) && PATCHLEVEL == (S) && SUBVERSION >= (P) ) )

#endif
#define WXPERL_P_VERSION_LT( V, S, P ) !WXPERL_P_VERSION_GE( V, S, P )

#define WXPERL_W_VERSION_EQ( V, S, P ) \
 ( wxMAJOR_VERSION == (V) && wxMINOR_VERSION == (S) && wxRELEASE_NUMBER == (P) )
#define WXPERL_W_VERSION_GE( V, S, P ) \
 ( ( wxMAJOR_VERSION > (V) ) || \
   ( wxMAJOR_VERSION == (V) && wxMINOR_VERSION > (S) ) || \
   ( wxMAJOR_VERSION == (V) && wxMINOR_VERSION == (S) && wxRELEASE_NUMBER >= (P) ) )
#define WXPERL_W_VERSION_LE( V, S, P ) \
 ( ( wxMAJOR_VERSION < (V) ) || \
   ( wxMAJOR_VERSION == (V) && wxMINOR_VERSION < (S) ) || \
   ( wxMAJOR_VERSION == (V) && wxMINOR_VERSION == (S) && wxRELEASE_NUMBER <= (P) ) )
#define WXPERL_W_VERSION_LT( V, S, P ) !WXPERL_W_VERSION_GE( V, S, P )

#if WXPERL_P_VERSION_GE( 5, 5, 0 ) && !WXPERL_P_VERSION_GE( 5, 6, 0 )

#define CHAR_P (char*)
#define get_sv perl_get_sv
#define get_av perl_get_av
#define call_sv perl_call_sv
#define eval_pv perl_eval_pv
#define call_method perl_call_method
#define require_pv perl_require_pv
#define call_argv perl_call_argv

#define newSVuv( val ) newSViv( (IV)(UV)val )
#define SvPV_nolen( s ) SvPV( (s), PL_na )

#endif

#if WXPERL_P_VERSION_GE( 5, 6, 0 )

#define CHAR_P

#else

#define vTHX
#define pTHX
#define aTHX
#define dTHX
#define pTHX_
#define aTHX_

#endif

#if WXPERL_P_VERSION_GE( 5, 8, 0 )

// XXX this is an hack
#include <config.h>
#undef HAS_CRYPT_R
#undef HAS_LOCALTIME_R

#endif

#ifndef PTR2IV

// from perl.h
/*
 *  The macros INT2PTR and NUM2PTR are (despite their names)
 *  bi-directional: they will convert int/float to or from pointers.
 *  However the conversion to int/float are named explicitly:
 *  PTR2IV, PTR2UV, PTR2NV.
 *
 *  For int conversions we do not need two casts if pointers are
 *  the same size as IV and UV.   Otherwise we need an explicit
 *  cast (PTRV) to avoid compiler warnings.
 */
#if (IVSIZE == PTRSIZE) && (UVSIZE == PTRSIZE)
#  define PTRV			UV
#  define INT2PTR(any,d)	(any)(d)
#else
#  if PTRSIZE == LONGSIZE
#    define PTRV		unsigned long
#  else
#    define PTRV		unsigned
#  endif
#  define INT2PTR(any,d)	(any)(PTRV)(d)
#endif
#define NUM2PTR(any,d)	(any)(PTRV)(d)
#define PTR2IV(p)	INT2PTR(IV,p)
#define PTR2UV(p)	INT2PTR(UV,p)
#define PTR2NV(p)	NUM2PTR(NV,p)

#endif

#define WXINTL_NO_GETTEXT_MACRO 1

#if defined(__WXMSW__)
#  if WXPERL_P_VERSION_GE( 5, 6, 0 )
#    define WXXS( name ) __declspec(dllexport) void name( pTHXo_ CV* cv )
#  else
#    ifdef PERL_OBJECT
#      define WXXS( name ) __declspec( dllexport ) void name(CV* cv, CPerlObj* pPerl)
#    else
#      define WXXS( name ) __declspec( dllexport ) void name(CV* cv)
#    endif
#  endif
#endif

#define WXPLDLL
#define NEEDS_PLI_HELPERS_STRUCT() \
  defined( WXPL_EXT ) && !defined( WXPL_STATIC ) && !defined(__WXMAC__)
#if NEEDS_PLI_HELPERS_STRUCT()
#  define FUNCPTR( name ) ( * name )
#else
#  define FUNCPTR( name ) name
#endif

// puts extern "C" around perl headers
#if defined(__CYGWIN__)
#define WXPL_EXTERN_C_START extern "C" {
#define WXPL_EXTERN_C_END   }
#else
#define WXPL_EXTERN_C_START
#define WXPL_EXTERN_C_END
#endif


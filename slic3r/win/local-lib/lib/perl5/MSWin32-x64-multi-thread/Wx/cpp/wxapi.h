/////////////////////////////////////////////////////////////////////////////
// Name:        cpp/wxapi.h
// Purpose:     Magic to be included to get access to wxPerl API
// Author:      Mattia Barbon
// Modified by:
// Created:     21/09/2002
// RCS-ID:      $Id: wxapi.h 3532 2015-03-11 01:27:54Z mdootson $
// Copyright:   (c) 2002-2003, 2005-2011 Mattia Barbon
// Licence:     This program is free software; you can redistribute it and/or
//              modify it under the same terms as Perl itself
/////////////////////////////////////////////////////////////////////////////

#ifdef __CPP_WXAPI_H
#error cpp/wxapi.h must be included only once!
#endif

#define __CPP_WXAPI_H

#undef bool

#if defined( __WXMSW__ )
#define STRICT
#undef NO_STRICT
#endif

#include <wx/defs.h>
#include <stdio.h>

// used to restore PerlIO-inflicted damage
inline FILE* _wxPli_stdin() { return stdin; }
inline FILE* _wxPli_stdout() { return stdout; }
inline FILE* _wxPli_stderr() { return stderr; }

#include "cpp/compat.h"

#if WXPERL_W_VERSION_LT( 2, 5, 3 ) || WXPERL_W_VERSION_EQ( 2, 7, 0 ) || \
    WXPERL_W_VERSION_EQ( 2, 7, 1 )
#error wxWidgets 2.4.x, 2.5.0, 2.5.1, 2.5.2, 2.7.0, 2.7.1 are no longer supported by wxPerl
#endif

#if WXPERL_W_VERSION_LE( 2, 5, 1 )
#define compatibility_iterator Node*
#endif

#include "cpp/chkconfig.h"

#if defined(__WXWINCE__)
#undef __WINDOWS__
#endif

#if defined(__VISUALC__) || defined(__DIGITALMARS__)
#define mode_t mode_avoid_redefinition_t
#endif

WXPL_EXTERN_C_START
#include <EXTERN.h>
#include <perl.h>

#if WXPERL_P_VERSION_GE( 5, 16, 0 ) && WXPERL_P_VERSION_LT( 5, 18, 0 ) && defined(__WXOSX_COCOA__)
#ifdef dNOOP
#undef dNOOP
#endif
#ifdef __cplusplus 
#define dNOOP (void)0 
#else 
#define dNOOP extern int Perl___notused(void) 
#endif 
#endif

#include <XSUB.h>
WXPL_EXTERN_C_END

#if WXPERL_P_VERSION_LT( 5, 10, 0 )

// fix newXS type for perl 5.8
inline CV* wxPli_newXS(pTHX_ const char* name, XSUBADDR_t addr,
                       const char* file)
{
    return newXS( (char*)name, addr, (char*)file );
}

#undef newXS
#define newXS( a, b, c ) wxPli_newXS( aTHX_ a, b, c )

#endif

#if defined(__VISUALC__) || defined(__DIGITALMARS__)
#undef mode_t
#endif

#if WXPERL_P_VERSION_GE( 5, 9, 0 ) || WXPERL_P_VERSION_GE( 5, 8, 1 )

// XXX this is an hack
#undef assert_not_ROK
#define assert_not_ROK(sv)

#endif

#undef bool
#undef bind
#undef strtoll
#undef strtoull
#undef Move
#undef Copy
#undef New
#undef Pause
#undef Mkdir
#undef Seek
#undef Stat
#undef Error
#undef do_open
#undef do_close
#undef utf8_length
#if defined( PERL_IMPLICIT_SYS )
#undef abort
#undef clearerr
#undef close
#undef eof
#undef exit
#undef fclose
#undef feof
#undef ferror
#undef fflush
#undef fgetpos
#undef fopen
#undef form
#undef fputc
#undef fputs
#undef fread
#undef free
#undef freopen
#undef fseek
#undef fsetpos
#undef ftell
#undef fwrite
#undef getc
#undef getenv
#undef malloc
#undef open
#undef read
#undef realloc
#undef rename
#undef seekdir
#undef setbuf
#undef setvbuf
#undef tmpfile
#undef tmpnam
#undef ungetc
#undef vform
#undef vfprintf
#undef write
#undef fgets
#undef stdin
#undef stdout
#undef stderr
#define stdin (_wxPli_stdin())
#define stdout (_wxPli_stdout())
#define stderr (_wxPli_stderr())
#endif

#if __VISUALC__
#pragma warning ( disable: 4800 )
#pragma warning ( disable: 4100 ) // unreferenced formal parameter
#pragma warning ( disable: 4101 ) // unreferenced local variable
#pragma warning ( disable: 4706 ) // assignment within conditional expression
#endif

#ifdef __WXMSW__
#include <wx/msw/winundef.h>
#endif // __WXMSW__

// some helper functions/classes/macros
#include "cpp/helpers.h"

// 0.01 -> 0010; 1.01 -> 1010, etc
#define WXPL_API_VERSION 0150

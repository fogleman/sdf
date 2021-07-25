/////////////////////////////////////////////////////////////////////////////
// Name:        cpp/helpers.h
// Purpose:     some helper functions/classes
// Author:      Mattia Barbon
// Modified by:
// Created:     29/10/2000
// RCS-ID:      $Id: helpers.h 3499 2013-05-02 01:46:04Z mdootson $
// Copyright:   (c) 2000-2011 Mattia Barbon
// Licence:     This program is free software; you can redistribute it and/or
//              modify it under the same terms as Perl itself
/////////////////////////////////////////////////////////////////////////////

#ifndef __CPP_HELPERS_H
#define __CPP_HELPERS_H

#include <wx/object.h>
#include <wx/list.h>
#include <wx/gdicmn.h>
#include <wx/variant.h>

#include <wx/dynarray.h>
#include <wx/arrstr.h>

class wxPliUserDataCD;
class wxPliTreeItemData;
class wxPliSelfRef;
struct wxPliEventDescription;

#ifndef WXDLLIMPEXP_FWD_CORE
#define WXDLLIMPEXP_FWD_CORE WXDLLEXPORT
#endif

// forward declare Wx_*Stream
class WXDLLIMPEXP_FWD_CORE wxInputStream;
class WXDLLIMPEXP_FWD_CORE wxOutputStream;
class WXDLLIMPEXP_FWD_CORE wxEvtHandler;
class WXDLLIMPEXP_FWD_CORE wxClientDataContainer;
class WXDLLIMPEXP_FWD_CORE wxPoint2DDouble;
typedef wxInputStream Wx_InputStream;
typedef wxOutputStream Wx_OutputStream;
typedef const char* PlClassName; // for typemap

#include <stdarg.h>

I32 my_looks_like_number( pTHX_ SV* sv );

// helpers for UTF8 <-> wxString/wxChar
// because xsubpp does not allow preprocessor commands in typemaps

SV* wxPli_wxChar_2_sv( pTHX_ const wxChar* str, SV* out );
SV* wxPli_wxString_2_sv( pTHX_ const wxString& str, SV* out );

#if defined(wxUSE_UNICODE_UTF8) && wxUSE_UNICODE_UTF8

inline SV* wxPli_wxChar_2_sv( pTHX_ const wxChar* str, SV* out )
{
    sv_setpv( out, wxString( str ).wx_str() );
    SvUTF8_on( out );

    return out;
}

inline SV* wxPli_wxString_2_sv( pTHX_ const wxString& str, SV* out )
{
    sv_setpv( out, str.wx_str() );
    SvUTF8_on( out );

    return out;
}

#define WXCHAR_INPUT( var, type, arg ) \
  const wxWCharBuffer var##_tmp = ( wxString( SvPVutf8_nolen( arg ), wxConvUTF8 ) ).wc_str(); \
  var = const_cast<type>( var##_tmp.data() );

#define WXCHAR_OUTPUT( var, arg ) \
  wxPli_wxChar_2_sv( aTHX_ var, arg )

#define WXSTRING_INPUT( var, type, arg ) \
  var = wxString( SvPVutf8_nolen( arg ), wxConvUTF8 );

#define WXSTRING_OUTPUT( var, arg ) \
  wxPli_wxString_2_sv( aTHX_ var, arg )

#elif wxUSE_UNICODE

inline SV* wxPli_wxChar_2_sv( pTHX_ const wxChar* str, SV* out )
{
    sv_setpv( out, wxConvUTF8.cWC2MB( str ? str : wxEmptyString ) );
    SvUTF8_on( out );

    return out;
}

inline SV* wxPli_wxString_2_sv( pTHX_ const wxString& str, SV* out )
{
    sv_setpv( out, str.mb_str( wxConvUTF8 ) );
    SvUTF8_on( out );

    return out;
}

#define WXCHAR_INPUT( var, type, arg ) \
  const wxString var##_tmp = ( wxString( SvPVutf8_nolen( arg ), wxConvUTF8 ) ); \
  var = const_cast<type>( static_cast<const type>( var##_tmp.wc_str() ) );

#define WXCHAR_OUTPUT( var, arg ) \
  wxPli_wxChar_2_sv( aTHX_ var, arg )

#define WXSTRING_INPUT( var, type, arg ) \
  var =  wxString( SvPVutf8_nolen( arg ), wxConvUTF8 );

#define WXSTRING_OUTPUT( var, arg ) \
  wxPli_wxString_2_sv( aTHX_ var, arg )

#else

#if NEEDS_PLI_HELPERS_STRUCT()
bool* wxPli_always_utf8;
#else
extern bool wxPli_always_utf8;
#endif

inline SV* wxPli_wxChar_2_sv( pTHX_ const wxChar* str, SV* out )
{
#if NEEDS_PLI_HELPERS_STRUCT()
    if( *wxPli_always_utf8 )
#else
    if( wxPli_always_utf8 )
#endif
    {
        sv_setpv( out, wxConvUTF8.cWC2MB( wxConvLibc.cWX2WC( str ? str : wxEmptyString ) ) );
        SvUTF8_on( out );
    }
    else
    {
        sv_setpv( out, str );
    }

    return out;
}

inline SV* wxPli_wxString_2_sv( pTHX_ const wxString& str, SV* out )
{
#if NEEDS_PLI_HELPERS_STRUCT()
    if( *wxPli_always_utf8 )
#else
    if( wxPli_always_utf8 )
#endif
    {
        sv_setpv( out, wxConvUTF8.cWC2MB( wxConvLibc.cWX2WC( str.c_str() ) ) );
        SvUTF8_on( out );
    }
    else
    {
        sv_setpvn( out, str.c_str(), str.size() );
    }

    return out;
}

#define WXCHAR_INPUT( var, type, arg ) \
  const wxString var##_tmp = ( SvUTF8( arg ) ) ? \
            ( wxString( wxConvUTF8.cMB2WC( SvPVutf8_nolen( arg ) ), wxConvLocal ) ) \
          : ( wxString( SvPV_nolen( arg ) ) ); \
  var = const_cast<type>( static_cast<const type>( var##_tmp.c_str() ) );

#define WXCHAR_OUTPUT( var, arg ) \
  wxPli_wxChar_2_sv( aTHX_ var, arg )

#define WXSTRING_INPUT( var, type, arg ) \
  var =  ( SvUTF8( arg ) ) ? \
           wxString( wxConvUTF8.cMB2WC( SvPVutf8_nolen( arg ) ), wxConvLocal ) \
         : wxString( SvPV_nolen( arg ) );

#define WXSTRING_OUTPUT( var, arg ) \
  wxPli_wxString_2_sv( aTHX_ var, arg )

#endif

inline wxString wxPli_sv_2_wxString( pTHX_ SV* sv )
{
    wxString ret;
    WXSTRING_INPUT( ret, wxString , sv );

    return ret;
}

// some utility functions

inline AV* wxPli_avref_2_av( SV* sv )
{
    if( SvROK( sv ) )
    {
        SV* rv = SvRV( sv );
        return SvTYPE( rv ) == SVt_PVAV ? (AV*)rv : NULL;
    }

    return NULL;
}

#define wxPli_push_2ints( i1, i2 ) \
    EXTEND( SP, 2 );                                                         \
    PUSHs( sv_2mortal( newSViv( (IV) (i1) ) ) );                             \
    PUSHs( sv_2mortal( newSViv( (IV) (i2) ) ) );                             \

//

const int WXPL_BUF_SIZE = 120;
const char* FUNCPTR( wxPli_cpp_class_2_perl )( const wxChar* className,
                                               char buffer[WXPL_BUF_SIZE] );
// argtypes is a string; each character describes the C++ argument
// type and how it should be used (i.e. a valid string is "ii", assuming
// you pass two integers as additional parameters
// b - a boolean value
// i - an 'int' value
// I - an 'unsigned int' value
// l - a 'long' value
// L - an 'unsigned long' value
// d - a 'double' value
// p - a char*
// w - a wxChar*
// P - a wxString*
// S - an SV*; a _COPY_ of the SV is passed
// s - an SV*; _the SV_ is passed (any modifications made by the function
//             will affect the SV, unlike in the previous case)
// O - a wxObject*; this will use wxPli_object_2_sv and push the result
// o - a void* followed by a char*; will use wxPli_non_object_2_sv
//     and push the result
// Q, q - same as O and o, but does not call delete() on the object
void FUNCPTR( wxPli_push_arguments )( pTHX_ SV*** stack,
                                      const char* argtypes, ... );
void wxPli_push_args( pTHX_ SV*** stack, const char* argtypes, va_list &list );

void* FUNCPTR( wxPli_sv_2_object )( pTHX_ SV* scalar, const char* classname );
SV* FUNCPTR( wxPli_object_2_sv )( pTHX_ SV* var, const wxObject* object );
SV* FUNCPTR( wxPli_clientdatacontainer_2_sv )( pTHX_ SV* var,
                                               wxClientDataContainer* cdc,
                                               const char* klass );
SV* FUNCPTR( wxPli_evthandler_2_sv )( pTHX_ SV* var, wxEvtHandler* evth );
SV* FUNCPTR( wxPli_non_object_2_sv )( pTHX_ SV* var, const void* data,
                                      const char* package );

SV* FUNCPTR( wxPli_make_object )( void* object, const char* cname );
SV* FUNCPTR( wxPli_create_evthandler )( pTHX_ wxEvtHandler* object,
                                        const char* classn );

bool FUNCPTR( wxPli_object_is_deleteable )( pTHX_ SV* object );
void FUNCPTR( wxPli_object_set_deleteable )( pTHX_ SV* object,
                                             bool deleteable );
// in both attach and detach, object is a _reference_ to a
// blessed thing
void FUNCPTR( wxPli_attach_object )( pTHX_ SV* object, void* ptr );
void* FUNCPTR( wxPli_detach_object )( pTHX_ SV* object );

const char* FUNCPTR( wxPli_get_class )( pTHX_ SV* ref );

wxWindowID FUNCPTR( wxPli_get_wxwindowid )( pTHX_ SV* var );
int FUNCPTR( wxPli_av_2_stringarray )( pTHX_ SV* avref, wxString** array );
int wxPli_av_2_charparray( pTHX_ SV* avref, char*** array );
int wxPli_av_2_wxcharparray( pTHX_ SV* avref, wxChar*** array );
int wxPli_av_2_uchararray( pTHX_ SV* avref, unsigned char** array );
int wxPli_av_2_svarray( pTHX_ SV* avref, SV*** array );
int FUNCPTR( wxPli_av_2_intarray )( pTHX_ SV* avref, int** array );
int wxPli_av_2_userdatacdarray( pTHX_ SV* avref, wxPliUserDataCD*** array );
int FUNCPTR( wxPli_av_2_arraystring )( pTHX_ SV* avref, wxArrayString* array );
int FUNCPTR( wxPli_av_2_arrayint )( pTHX_ SV* avref, wxArrayInt* array );

// pushes the elements of the array into the stack
// the caller _MUST_ call PUTBACK; before the function
// and SPAGAIN; after the function
template<class A>
void wxPli_non_objarray_push( pTHX_ const A& things, const char* package )
{
    dSP;

    size_t mx = things.GetCount();
    EXTEND( SP, int(mx) );
    for( size_t i = 0; i < mx; ++i )
    {
        PUSHs( wxPli_non_object_2_sv( aTHX_ sv_newmortal(),
                                      &things[i], package ) );
    }

    PUTBACK;
}

void FUNCPTR( wxPli_stringarray_push )( pTHX_ const wxArrayString& strings );
void FUNCPTR( wxPli_intarray_push )( pTHX_ const wxArrayInt& ints );
#if WXPERL_W_VERSION_GE( 2, 7, 2 )
void wxPli_doublearray_push( pTHX_ const wxArrayDouble& doubles );
#endif
AV* wxPli_stringarray_2_av( pTHX_ const wxArrayString& strings );
AV* wxPli_uchararray_2_av( pTHX_ const unsigned char* array, int count );
AV* FUNCPTR( wxPli_objlist_2_av )( pTHX_ const wxList& objs );
void FUNCPTR( wxPli_objlist_push )( pTHX_ const wxList& objs );

template<class A, class E>
void wxPli_nonobjarray_push( pTHX_ const A& objs, const char* klass )
{
    dSP;

    size_t mx = objs.GetCount();
    EXTEND( SP, IV(mx) );
    for( size_t i = 0; i < mx; ++i )
    {
        PUSHs( wxPli_non_object_2_sv( aTHX_ sv_newmortal(),
               new E( objs[i] ), klass ) );
    }

    PUTBACK;
}

void wxPli_delete_argv( void*** argv, bool unicode );
int wxPli_get_args_argc_argv( void*** argv, bool unicode );
void wxPli_get_args_objectarray( pTHX_ SV** sp, int items,
                                         void** array, const char* package );

wxPoint FUNCPTR( wxPli_sv_2_wxpoint_test )( pTHX_ SV* scalar, bool* ispoint );
wxPoint FUNCPTR( wxPli_sv_2_wxpoint )( pTHX_ SV* scalar );
wxSize FUNCPTR( wxPli_sv_2_wxsize )( pTHX_ SV* scalar );
#if WXPERL_W_VERSION_GE( 2, 6, 0 )
class WXDLLIMPEXP_FWD_CORE wxGBPosition; class WXDLLIMPEXP_FWD_CORE wxGBSpan;
wxGBPosition wxPli_sv_2_wxgbposition( pTHX_ SV* scalar );
wxGBSpan wxPli_sv_2_wxgbspan( pTHX_ SV* scalar );
#endif
#if WXPERL_W_VERSION_GE( 2, 9, 0 )
class wxPosition;
wxPosition wxPli_sv_2_wxposition( pTHX_ SV* scalar );
#endif
wxVariant FUNCPTR( wxPli_sv_2_wxvariant )( pTHX_ SV* scalar );

wxKeyCode wxPli_sv_2_keycode( pTHX_ SV* scalar );

#if WXPERL_W_VERSION_GE( 2, 9, 0 )
int wxPli_av_2_pointlist( pTHX_ SV* array, wxPointList *points, wxPoint** tmp );
#else
int wxPli_av_2_pointlist( pTHX_ SV* array, wxList *points, wxPoint** tmp );
#endif
int wxPli_av_2_pointarray( pTHX_ SV* array, wxPoint** points );
int wxPli_av_2_point2ddoublearray( pTHX_ SV* array, wxPoint2DDouble** points );

template<class E>
class wxPliArrayGuard
{
private:
    E* m_array;
public:
    wxPliArrayGuard( E* els = NULL ) : m_array( els ) {}

    ~wxPliArrayGuard()
    {
        delete[] m_array;
    }

    E** lvalue() { return &m_array; }
    E* rvalue() { return m_array; }
    operator E*() { return m_array; }

    E* disarm()
    {
        E* oldvalue = m_array;
        m_array = NULL;

        return oldvalue;
    }
};

// thread helpers
#if wxPERL_USE_THREADS
typedef void (* wxPliCloneSV)( pTHX_ SV* scalar );
void FUNCPTR( wxPli_thread_sv_register )( pTHX_ const char* package,
                                          const void* ptr, SV* sv );
void FUNCPTR( wxPli_thread_sv_unregister )( pTHX_ const char* package,
                                            const void* ptr, SV* sv );
void FUNCPTR( wxPli_thread_sv_clone )( pTHX_ const char* package,
                                       wxPliCloneSV clonefn );
#else // if !wxPERL_USE_THREADS
#define wxPli_thread_sv_register( package, ptr, sv )
#define wxPli_thread_sv_unregister( package, ptr, sv )
#define wxPli_thread_sv_clone( package, clonefn )
#endif // !wxPERL_USE_THREADS

// stream wrappers
class wxPliInputStream;
class wxPliOutputStream;
class wxStreamBase;

void wxPli_sv_2_istream( pTHX_ SV* scalar, wxPliInputStream& stream );
void wxPli_sv_2_ostream( pTHX_ SV* scalar, wxPliOutputStream& stream );
void FUNCPTR( wxPli_stream_2_sv )( pTHX_ SV* scalar, wxStreamBase* stream,
                                   const char* package );
wxPliInputStream* FUNCPTR( wxPliInputStream_ctor )( SV* sv );
wxPliOutputStream* FUNCPTR( wxPliOutputStream_ctor )( SV* sv );

void FUNCPTR( wxPli_set_events )( const wxPliEventDescription* events );

// defined in Constants.xs
void FUNCPTR( wxPli_add_constant_function )( double (**)( const char*, int ) );
void FUNCPTR( wxPli_remove_constant_function )( double (**)( const char*,
                                                             int ) );

// defined in v_cback.cpp
class wxPliVirtualCallback;

bool FUNCPTR( wxPliVirtualCallback_FindCallback )
    ( pTHX_ const wxPliVirtualCallback* cb, const char* name );
// see wxPli_push_args for a description of argtypes
SV* FUNCPTR( wxPliVirtualCallback_CallCallback )
    ( pTHX_ const wxPliVirtualCallback* cb, I32 flags,
      const char* argtypes, ... );

// used in overload.cpp
struct wxPliPrototype
{
    wxPliPrototype( const char** const proto,
                    const size_t proto_size )
      : args( proto ), count( proto_size ) { }

    const char** const args;
    const size_t count;
};

bool wxPli_match_arguments( pTHX_ const wxPliPrototype& prototype,
                            int required = -1,
                            bool allow_more = false );
bool FUNCPTR( wxPli_match_arguments_skipfirst )( pTHX_ const wxPliPrototype& p,
                                                 int required,
                                                 bool allow_more );
void FUNCPTR( wxPli_overload_error )( pTHX_ const char* function,
                                      wxPliPrototype* prototypes[] );
SV* FUNCPTR( wxPli_create_virtual_evthandler )( pTHX_ wxEvtHandler* object,
                                        const char* classn, bool forcevirtual );
wxPliSelfRef* FUNCPTR( wxPli_get_selfref )( pTHX_ wxObject* object, bool forcevirtual );
SV* FUNCPTR( wxPli_object_2_scalarsv )( pTHX_ SV* var, const wxObject* object );
SV* FUNCPTR( wxPli_namedobject_2_sv )( pTHX_ SV* var, const wxObject* object, const char* package );

#define WXPLI_BOOT_ONCE_( name, xs ) \
bool name##_booted = false; \
extern "C" XS(wxPli_boot_##name); \
extern "C" \
xs(boot_##name) \
{ \
    if( name##_booted ) return; \
    name##_booted = true; \
    wxPli_boot_##name( aTHX_ cv ); \
}

#define WXPLI_BOOT_ONCE( name ) WXPLI_BOOT_ONCE_( name, XS )
#if defined(WIN32) || defined(__CYGWIN__)
#  define WXPLI_BOOT_ONCE_EXP( name ) WXPLI_BOOT_ONCE_( name, WXXS )
#else
#  define WXPLI_BOOT_ONCE_EXP WXPLI_BOOT_ONCE
#endif

#if WXPERL_W_VERSION_GE( 2, 5, 1 )
#define WXPLI_INIT_CLASSINFO()
#else
#define WXPLI_INIT_CLASSINFO() \
  wxClassInfo::CleanUpClasses(); \
  wxClassInfo::InitializeClasses()
#endif

struct wxPliHelpers
{
    void* ( * m_wxPli_sv_2_object )( pTHX_ SV*, const char* );
    SV* ( * m_wxPli_evthandler_2_sv )( pTHX_ SV* var, wxEvtHandler* evth );
    SV* ( * m_wxPli_object_2_sv )( pTHX_ SV*, const wxObject* );
    SV* ( * m_wxPli_non_object_2_sv )( pTHX_ SV* , const void*, const char* );
    SV* ( * m_wxPli_make_object )( void*, const char* );
    wxPoint ( * m_wxPli_sv_2_wxpoint_test )( pTHX_ SV*, bool* );
    wxPoint ( * m_wxPli_sv_2_wxpoint )( pTHX_ SV* );
    wxSize ( * m_wxPli_sv_2_wxsize )( pTHX_ SV* );
    int ( * m_wxPli_av_2_intarray )( pTHX_ SV*, int** );
    void ( * m_wxPli_stream_2_sv )( pTHX_ SV*, wxStreamBase*, const char* );

    void ( * m_wxPli_add_constant_function )
        ( double (**)( const char*, int ) );
    void ( * m_wxPli_remove_constant_function )
        ( double (**)( const char*, int ) );

    bool ( * m_wxPliVirtualCallback_FindCallback )( pTHX_ 
                                                   const wxPliVirtualCallback*,
                                                    const char* );
    SV* ( * m_wxPliVirtualCallback_CallCallback )
        ( pTHX_ const wxPliVirtualCallback*, I32,
          const char*, ... );
    bool ( * m_wxPli_object_is_deleteable )( pTHX_ SV* );
    void ( * m_wxPli_object_set_deleteable )( pTHX_ SV*, bool );
    const char* ( * m_wxPli_get_class )( pTHX_ SV* );
    wxWindowID ( * m_wxPli_get_wxwindowid )( pTHX_ SV* );
    int ( * m_wxPli_av_2_stringarray )( pTHX_ SV*, wxString** );
    wxPliInputStream* ( * m_wxPliInputStream_ctor )( SV* );
    const char* ( * m_wxPli_cpp_class_2_perl )( const wxChar*,
                                                char buffer[WXPL_BUF_SIZE] );
    void ( * m_wxPli_push_arguments )( pTHX_ SV*** stack,
                                       const char* argtypes, ... );
    void ( * m_wxPli_attach_object )( pTHX_ SV* object, void* ptr );
    void* ( * m_wxPli_detach_object )( pTHX_ SV* object );
    SV* ( * m_wxPli_create_evthandler )( pTHX_ wxEvtHandler* object,
                                         const char* cln );
    bool (* m_wxPli_match_arguments_skipfirst )( pTHX_ const wxPliPrototype&,
                                                 int required,
                                                 bool allow_more );
    AV* (* m_wxPli_objlist_2_av )( pTHX_ const wxList& objs );
    void (* m_wxPli_intarray_push )( pTHX_ const wxArrayInt& );
    SV* (* m_wxPli_clientdatacontainer_2_sv )( pTHX_ SV* var,
                                               wxClientDataContainer* cdc,
                                               const char* klass );
#if wxPERL_USE_THREADS
    void (* m_wxPli_thread_sv_register )( pTHX_ const char* package,
                                          const void* ptr, SV* sv );
    void (* m_wxPli_thread_sv_unregister )( pTHX_ const char* package,
                                            const void* ptr, SV* sv );
    void (* m_wxPli_thread_sv_clone )( pTHX_ const char* package,
                                       wxPliCloneSV clonefn );
#endif
#if !wxUSE_UNICODE
    bool *m_wxPli_always_utf8;
#endif
    int (* m_wxPli_av_2_arrayint )( pTHX_ SV* avref, wxArrayInt* array );
    void (* m_wxPli_set_events )( const wxPliEventDescription* events );
    int (* m_wxPli_av_2_arraystring )( pTHX_ SV* avref, wxArrayString* array );
    void (* m_wxPli_objlist_push )( pTHX_ const wxList& objs );
    wxPliOutputStream* ( * m_wxPliOutputStream_ctor )( SV* );
    void (* m_wxPli_stringarray_push )( pTHX_ const wxArrayString& );
    void (* m_wxPli_overload_error )( pTHX_ const char* function,
                                      wxPliPrototype* prototypes[] );
    wxVariant (* m_wxPli_sv_2_wxvariant )( pTHX_ SV* scalar );
    SV* ( * m_wxPli_create_virtual_evthandler )( pTHX_ wxEvtHandler* object,
                                        const char* cln, bool forcevirtual );
    wxPliSelfRef* ( * m_wxPli_get_selfref )( pTHX_ wxObject*, bool);
    SV* ( * m_wxPli_object_2_scalarsv )( pTHX_ SV* var, const wxObject* object );
    SV* ( * m_wxPli_namedobject_2_sv )( pTHX_ SV* var, const wxObject* object, const char* package );
};

#if wxPERL_USE_THREADS
#   define wxDEFINE_PLI_HELPER_THREADS() \
 &wxPli_thread_sv_register, \
 &wxPli_thread_sv_unregister, &wxPli_thread_sv_clone,
#   define wxINIT_PLI_HELPER_THREADS( name ) \
  wxPli_thread_sv_register = name->m_wxPli_thread_sv_register; \
  wxPli_thread_sv_unregister = name->m_wxPli_thread_sv_unregister; \
  wxPli_thread_sv_clone = name->m_wxPli_thread_sv_clone;
#else
#   define wxDEFINE_PLI_HELPER_THREADS()
#   define wxINIT_PLI_HELPER_THREADS( name )
#endif

#if !wxUSE_UNICODE
#   define wxDEFINE_PLI_HELPER_UNICODE() \
 &wxPli_always_utf8,
#   define wxINIT_PLI_HELPER_UNICODE( name ) \
  wxPli_always_utf8 = name->m_wxPli_always_utf8;
#else
#   define wxDEFINE_PLI_HELPER_UNICODE()
#   define wxINIT_PLI_HELPER_UNICODE( name )
#endif

#define DEFINE_PLI_HELPERS( name ) \
wxPliHelpers name = { &wxPli_sv_2_object, \
 &wxPli_evthandler_2_sv, &wxPli_object_2_sv, \
 &wxPli_non_object_2_sv, &wxPli_make_object, &wxPli_sv_2_wxpoint_test, \
 &wxPli_sv_2_wxpoint, \
 &wxPli_sv_2_wxsize, &wxPli_av_2_intarray, wxPli_stream_2_sv, \
 &wxPli_add_constant_function, &wxPli_remove_constant_function, \
 &wxPliVirtualCallback_FindCallback, &wxPliVirtualCallback_CallCallback, \
 &wxPli_object_is_deleteable, &wxPli_object_set_deleteable, &wxPli_get_class, \
 &wxPli_get_wxwindowid, &wxPli_av_2_stringarray, &wxPliInputStream_ctor, \
 &wxPli_cpp_class_2_perl, &wxPli_push_arguments, &wxPli_attach_object, \
 &wxPli_detach_object, &wxPli_create_evthandler, \
 &wxPli_match_arguments_skipfirst, &wxPli_objlist_2_av, &wxPli_intarray_push, \
 &wxPli_clientdatacontainer_2_sv, \
 wxDEFINE_PLI_HELPER_THREADS() \
 wxDEFINE_PLI_HELPER_UNICODE() \
 &wxPli_av_2_arrayint, &wxPli_set_events, &wxPli_av_2_arraystring, \
 &wxPli_objlist_push, &wxPliOutputStream_ctor, &wxPli_stringarray_push, \
 &wxPli_overload_error, &wxPli_sv_2_wxvariant, \
 &wxPli_create_virtual_evthandler, &wxPli_get_selfref, &wxPli_object_2_scalarsv, \
 &wxPli_namedobject_2_sv \
 }

#if NEEDS_PLI_HELPERS_STRUCT()

#define INIT_PLI_HELPERS( name ) \
  SV* wxpli_tmp = get_sv( "Wx::_exports", 1 ); \
  wxPliHelpers* name = INT2PTR( wxPliHelpers*, SvIV( wxpli_tmp ) ); \
  wxPli_sv_2_object = name->m_wxPli_sv_2_object; \
  wxPli_evthandler_2_sv = name->m_wxPli_evthandler_2_sv; \
  wxPli_object_2_sv = name->m_wxPli_object_2_sv; \
  wxPli_non_object_2_sv = name->m_wxPli_non_object_2_sv; \
  wxPli_make_object = name->m_wxPli_make_object; \
  wxPli_sv_2_wxpoint_test = name->m_wxPli_sv_2_wxpoint_test; \
  wxPli_sv_2_wxpoint = name->m_wxPli_sv_2_wxpoint; \
  wxPli_sv_2_wxsize = name->m_wxPli_sv_2_wxsize; \
  wxPli_av_2_intarray = name->m_wxPli_av_2_intarray; \
  wxPli_stream_2_sv = name->m_wxPli_stream_2_sv; \
  wxPli_add_constant_function = name->m_wxPli_add_constant_function; \
  wxPli_remove_constant_function = name->m_wxPli_remove_constant_function; \
  wxPliVirtualCallback_FindCallback = name->m_wxPliVirtualCallback_FindCallback; \
  wxPliVirtualCallback_CallCallback = name->m_wxPliVirtualCallback_CallCallback; \
  wxPli_object_is_deleteable = name->m_wxPli_object_is_deleteable; \
  wxPli_object_set_deleteable = name->m_wxPli_object_set_deleteable; \
  wxPli_get_class = name->m_wxPli_get_class; \
  wxPli_get_wxwindowid = name->m_wxPli_get_wxwindowid; \
  wxPli_av_2_stringarray = name->m_wxPli_av_2_stringarray; \
  wxPliInputStream_ctor = name->m_wxPliInputStream_ctor; \
  wxPli_cpp_class_2_perl = name->m_wxPli_cpp_class_2_perl; \
  wxPli_push_arguments = name->m_wxPli_push_arguments; \
  wxPli_attach_object = name->m_wxPli_attach_object; \
  wxPli_detach_object = name->m_wxPli_detach_object; \
  wxPli_create_evthandler = name->m_wxPli_create_evthandler; \
  wxPli_match_arguments_skipfirst = name->m_wxPli_match_arguments_skipfirst; \
  wxPli_objlist_2_av = name->m_wxPli_objlist_2_av; \
  wxPli_intarray_push = name->m_wxPli_intarray_push; \
  wxPli_clientdatacontainer_2_sv = name->m_wxPli_clientdatacontainer_2_sv; \
  wxINIT_PLI_HELPER_THREADS( name ) \
  wxINIT_PLI_HELPER_UNICODE( name ) \
  wxPli_av_2_arrayint = name->m_wxPli_av_2_arrayint; \
  wxPli_set_events = name->m_wxPli_set_events; \
  wxPli_av_2_arraystring = name->m_wxPli_av_2_arraystring; \
  wxPli_objlist_push = name->m_wxPli_objlist_push; \
  wxPliOutputStream_ctor = name->m_wxPliOutputStream_ctor; \
  wxPli_av_2_stringarray = name->m_wxPli_av_2_stringarray; \
  wxPli_overload_error = name->m_wxPli_overload_error; \
  wxPli_sv_2_wxvariant = name->m_wxPli_sv_2_wxvariant; \
  wxPli_create_virtual_evthandler = name->m_wxPli_create_virtual_evthandler; \
  wxPli_get_selfref = name->m_wxPli_get_selfref; \
  wxPli_object_2_scalarsv = name->m_wxPli_object_2_scalarsv; \
  wxPli_namedobject_2_sv = name->m_wxPli_namedobject_2_sv; \
  WXPLI_INIT_CLASSINFO();

#else

#define INIT_PLI_HELPERS( name )

#endif

#if WXPERL_W_VERSION_GE( 2, 9, 0 )
int wxCALLBACK ListCtrlCompareFn( long item1, long item2, wxIntPtr comparefn );
#else
int wxCALLBACK ListCtrlCompareFn( long item1, long item2, long comparefn );
#endif

class wxPliUserDataO : public wxObject
{
public:
    wxPliUserDataO( SV* data )
    {
        dTHX;
        m_data = data ? newSVsv( data ) : NULL;
    }

    ~wxPliUserDataO()
    {
        dTHX;
        SvREFCNT_dec( m_data );
    }

    SV* GetData() { return m_data; }
private:
    SV* m_data;
};
typedef wxPliUserDataO   Wx_UserDataO;

class wxPliSelfRef
{
public:
    wxPliSelfRef( const char* unused = 0 ) {}
    virtual ~wxPliSelfRef()
        { dTHX; if( m_self ) SvREFCNT_dec( m_self ); }

    void SetSelf( SV* self, bool increment = true )
    {
        dTHX;
        m_self = self;
        if( m_self && increment )       
            SvREFCNT_inc( m_self );
    }

    SV* GetSelf() const { return m_self; }
    void DeleteSelf( bool fromDestroy );
public:
    SV* m_self;
};

typedef wxPliSelfRef* (* wxPliGetCallbackObjectFn)(wxObject* object);

class wxPliClassInfo : public wxClassInfo
{
public:
#if wxUSE_EXTENDED_RTTI
    wxPliClassInfo( const wxClassInfo **_Parents,
                    const wxChar *_ClassName,
                    int size, wxObjectConstructorFn ctor,
                    wxPliGetCallbackObjectFn fn )
        :wxClassInfo( _Parents, NULL, _ClassName, size, ctor, NULL, NULL,
                      NULL, NULL, 0, NULL, NULL, NULL )
    {
        m_func = fn;
    }
#else
    wxPliClassInfo( wxChar *cName, const wxClassInfo *baseInfo1,
                    const wxClassInfo *baseInfo2, 
                    int sz, wxObjectConstructorFn ctor,
                    wxPliGetCallbackObjectFn fn )
        :wxClassInfo( cName, baseInfo1, baseInfo2, sz, ctor)
    {
        m_func = fn;
    }
#endif
public:
    wxPliGetCallbackObjectFn m_func;
};

#if wxUSE_EXTENDED_RTTI
#define WXPLI_DECLARE_DYNAMIC_CLASS(name) \
public:\
  static wxPliClassInfo ms_classInfo;\
  static const wxClassInfo* ms_classParents[] ;\
  virtual wxClassInfo *GetClassInfo() const \
   { return &ms_classInfo; }
#else
#define WXPLI_DECLARE_DYNAMIC_CLASS(name) \
public:\
  static wxPliClassInfo ms_classInfo;\
  virtual wxClassInfo *GetClassInfo() const \
   { return &ms_classInfo; }
#endif
#define WXPLI_DECLARE_DYNAMIC_CLASS_CTOR(name) \
  WXPLI_DECLARE_DYNAMIC_CLASS(name) \
  static wxObject* wxCreateObject()

#define WXPLI_DECLARE_SELFREF() \
public:\
  wxPliSelfRef m_callback

#define WXPLI_DECLARE_V_CBACK() \
public:\
  wxPliVirtualCallback m_callback

#if wxUSE_EXTENDED_RTTI
#define WXPLI_IMPLEMENT_DYNAMIC_CLASS_(name, basename, fn)                   \
    wxPliSelfRef* wxPliGetSelfFor##name(wxObject* object)                    \
        { return &((name *)object)->m_callback; }                            \
    const wxClassInfo* name::ms_classParents[] =                             \
        { &basename::ms_classInfo , NULL };                                  \
    wxPliClassInfo name::ms_classInfo( ms_classParents,                      \
        (wxChar *) wxT(#name), (int) sizeof(name), fn,                       \
        (wxPliGetCallbackObjectFn) wxPliGetSelfFor##name);
#else
#define WXPLI_IMPLEMENT_DYNAMIC_CLASS_(name, basename, fn)                   \
    wxPliSelfRef* wxPliGetSelfFor##name(wxObject* object)                    \
        { return &((name *)object)->m_callback; }                            \
    wxPliClassInfo name::ms_classInfo((wxChar *) wxT(#name),                 \
        &basename::ms_classInfo, NULL, (int) sizeof(name), fn,               \
        (wxPliGetCallbackObjectFn) wxPliGetSelfFor##name);
#endif
#define WXPLI_IMPLEMENT_DYNAMIC_CLASS(name, basename)                        \
    WXPLI_IMPLEMENT_DYNAMIC_CLASS_(name, basename, NULL)
#define WXPLI_IMPLEMENT_DYNAMIC_CLASS_CTOR(name, basename)                   \
    WXPLI_IMPLEMENT_DYNAMIC_CLASS_(name, basename, name::wxCreateObject)     \
    wxObject* name::wxCreateObject() { return new name(); }

#define WXPLI_DEFAULT_CONSTRUCTOR_NC( name, packagename, incref ) \
    name( const char* package )                                   \
        : m_callback( packagename )                               \
    {                                                             \
        m_callback.SetSelf( wxPli_make_object( this, package ), incref );\
    }

#define WXPLI_DEFAULT_CONSTRUCTOR( name, packagename, incref ) \
    name( const char* package )                                \
        :m_callback( packagename )                             \
    {                                                          \
        m_callback.SetSelf( wxPli_make_object( this, package ), incref );\
    }

#define WXPLI_CONSTRUCTOR_1_NC( name, base, packagename, incref, argt1 ) \
    name( const char* package, argt1 _arg1 )                       \
        : base( _arg1 ),                                           \
          m_callback( packagename )                                \
    {                                                              \
        m_callback.SetSelf( wxPli_make_object( this, package ), incref );\
    }

#define WXPLI_CONSTRUCTOR_2( name, packagename, incref, argt1, argt2 )     \
     name( const char* package, argt1 _arg1, argt2 _arg2 )                 \
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2 );                                           \
     }

#define WXPLI_CONSTRUCTOR_5( name, packagename, incref, argt1, argt2, argt3, argt4, argt5 ) \
     name( const char* package, argt1 _arg1, argt2 _arg2, argt3 _arg3,     \
           argt4 _arg4, argt5 _arg5 )                                      \
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2, _arg3, _arg4, _arg5 );                      \
     }

#define WXPLI_CONSTRUCTOR_6( name, packagename, incref, argt1, argt2, argt3, argt4, argt5, argt6 ) \
     name( const char* package, argt1 _arg1, argt2 _arg2, argt3 _arg3,     \
           argt4 _arg4, argt5 _arg5, argt6 _arg6 )                          \
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2, _arg3, _arg4, _arg5, _arg6 );               \
     }

#define WXPLI_CONSTRUCTOR_7( name, packagename, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7 ) \
     name( const char* package, argt1 _arg1, argt2 _arg2, argt3 _arg3,     \
           argt4 _arg4, argt5 _arg5, argt6 _arg6, argt7 _arg7)             \
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _arg7 );        \
     }

#define WXPLI_CONSTRUCTOR_8( name, packagename, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7, argt8 ) \
     name( const char* package, argt1 _arg1, argt2 _arg2, argt3 _arg3,     \
           argt4 _arg4, argt5 _arg5, argt6 _arg6, argt7 _arg7, argt8 _arg8)\
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _arg7, _arg8 ); \
     }

#define WXPLI_CONSTRUCTOR_9( name, packagename, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7, argt8, argt9 ) \
     name( const char* package, argt1 _arg1, argt2 _arg2, argt3 _arg3,     \
           argt4 _arg4, argt5 _arg5, argt6 _arg6, argt7 _arg7,             \
           argt8 _arg8, argt9 _arg9 )                                      \
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _arg7, _arg8,   \
                 _arg9 );                                                  \
     }

#define WXPLI_CONSTRUCTOR_10( name, packagename, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7, argt8, argt9, argt10 ) \
     name( const char* package, argt1 _arg1, argt2 _arg2, argt3 _arg3,     \
           argt4 _arg4, argt5 _arg5, argt6 _arg6, argt7 _arg7,             \
           argt8 _arg8, argt9 _arg9, argt10 _arg10 )                       \
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _arg7, _arg8,   \
                 _arg9, _arg10 );                                          \
     }

#define WXPLI_CONSTRUCTOR_11( name, packagename, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7, argt8, argt9, argt10, argt11 ) \
     name( const char* package, argt1 _arg1, argt2 _arg2, argt3 _arg3,     \
           argt4 _arg4, argt5 _arg5, argt6 _arg6, argt7 _arg7,             \
           argt8 _arg8, argt9 _arg9, argt10 _arg10, argt11 _arg11 )        \
         :m_callback( packagename )                                        \
     {                                                                     \
         m_callback.SetSelf( wxPli_make_object( this, package ), incref ); \
         Create( _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _arg7, _arg8,   \
                 _arg9, _arg10, _arg11 );                                  \
     }

#define WXPLI_DECLARE_CLASS_6( name, incref, argt1, argt2, argt3, argt4, argt5, argt6 ) \
class wxPli##name:public wx##name                                       \
{                                                                       \
    WXPLI_DECLARE_DYNAMIC_CLASS( wxPli##name );                         \
    WXPLI_DECLARE_SELFREF();                                            \
public:                                                                 \
    WXPLI_DEFAULT_CONSTRUCTOR( wxPli##name, "Wx::" #name, incref );     \
    WXPLI_CONSTRUCTOR_6( wxPli##name, "Wx::" #name, incref,             \
                         argt1, argt2, argt3, argt4, argt5, argt6 );    \
};

#define WXPLI_DECLARE_CLASS_7( name, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7 ) \
class wxPli##name:public wx##name                                       \
{                                                                       \
    WXPLI_DECLARE_DYNAMIC_CLASS( wxPli##name );                         \
    WXPLI_DECLARE_SELFREF();                                            \
public:                                                                 \
    WXPLI_DEFAULT_CONSTRUCTOR( wxPli##name, "Wx::" #name, incref );     \
    WXPLI_CONSTRUCTOR_7( wxPli##name, "Wx::" #name, incref,             \
                         argt1, argt2, argt3, argt4, argt5, argt6,      \
                         argt7 );                                       \
};

#define WXPLI_DECLARE_CLASS_8( name, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7, argt8 ) \
class wxPli##name:public wx##name                                       \
{                                                                       \
    WXPLI_DECLARE_DYNAMIC_CLASS( wxPli##name );                         \
    WXPLI_DECLARE_SELFREF();                                            \
public:                                                                 \
    WXPLI_DEFAULT_CONSTRUCTOR( wxPli##name, "Wx::" #name, incref );     \
    WXPLI_CONSTRUCTOR_8( wxPli##name, "Wx::" #name, incref,             \
                         argt1, argt2, argt3, argt4, argt5, argt6,      \
                         argt7, argt8 );                                \
};

#define WXPLI_DECLARE_CLASS_9( name, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7, argt8, argt9 ) \
class wxPli##name:public wx##name                                       \
{                                                                       \
    WXPLI_DECLARE_DYNAMIC_CLASS( wxPli##name );                         \
    WXPLI_DECLARE_SELFREF();                                            \
public:                                                                 \
    WXPLI_DEFAULT_CONSTRUCTOR( wxPli##name, "Wx::" #name, incref );     \
    WXPLI_CONSTRUCTOR_9( wxPli##name, "Wx::" #name, incref,             \
                         argt1, argt2, argt3, argt4, argt5, argt6,      \
                         argt7, argt8, argt9 );                         \
};

#define WXPLI_DECLARE_CLASS_10( name, incref, argt1, argt2, argt3, argt4, argt5, argt6, argt7, argt8, argt9, argt10 ) \
class wxPli##name:public wx##name                                       \
{                                                                       \
    WXPLI_DECLARE_DYNAMIC_CLASS( wxPli##name );                         \
    WXPLI_DECLARE_SELFREF();                                            \
public:                                                                 \
    WXPLI_DEFAULT_CONSTRUCTOR( wxPli##name, "Wx::" #name, incref );     \
    WXPLI_CONSTRUCTOR_10( wxPli##name, "Wx::" #name, incref,            \
                         argt1, argt2, argt3, argt4, argt5, argt6,      \
                         argt7, argt8, argt9, argt10 );                 \
};


#define WXPLI_DEFINE_CLASS( name ) \
WXPLI_IMPLEMENT_DYNAMIC_CLASS( wxPli##name, wx##name );

typedef SV SV_null; // equal to SV except that maps C++ 0 <-> Perl undef

// helpers for declaring event macros
struct wxPliEventDescription
{
    const char* name;
    // 2 - only THIS and function
    // 3 - THIS, function, one ID
    // 4 - THIS, function, two ids
    // 5 - THIS, function, two ids, event id
    unsigned char args;
    int evtID;    
};

#define wxPli_StdEvent( NAME, ARGS )  { #NAME, ARGS, wx##NAME },
#define wxPli_Event( NAME, ARGS, ID ) { #NAME, ARGS, ID },

#endif // __CPP_HELPERS_H

#if defined( _WX_CLNTDATAH__ )
#ifndef __CPP_HELPERS_H_UDCD
#define __CPP_HELPERS_H_UDCD

class wxPliUserDataCD : public wxClientData
{
public:
    wxPliUserDataCD( SV* data )
    {
        dTHX;
        m_data = data ? newSVsv( data ) : NULL;
    }

    ~wxPliUserDataCD()
    {
        dTHX;
        SvREFCNT_dec( m_data );
    }

    SV* GetData() { return m_data; }
private:
    SV* m_data;
};
typedef wxPliUserDataCD  Wx_UserDataCD;

#endif // __CPP_HELPERS_H_UDCD
#endif // defined( _WX_CLNTDATAH__ )

#if defined( _WX_TREEBASE_H_ ) || defined( _WX_TREECTRL_H_BASE_ )
#ifndef __CPP_HELPERS_H_TID
#define __CPP_HELPERS_H_TID

class wxPliTreeItemData:public wxTreeItemData
{
public:
    wxPliTreeItemData( SV* data )
        : m_data( NULL )
    {
        SetData( data );
    }

    ~wxPliTreeItemData()
    {
        SetData( NULL );
    }

    void SetData( SV* data )
    {
        dTHX;
        if( m_data )
            SvREFCNT_dec( m_data );
        m_data = data ? newSVsv( data ) : NULL;
    }
public:
    SV* m_data;
};

#endif // __CPP_HELPERS_H_TID
#endif // defined( _WX_TREEBASE_H_ ) || defined( _WX_TREECTRL_H_BASE_ )

// Local variables:
// mode: c++
// End:

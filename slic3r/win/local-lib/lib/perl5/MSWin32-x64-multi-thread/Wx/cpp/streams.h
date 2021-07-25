/////////////////////////////////////////////////////////////////////////////
// Name:        cpp/streams.h
// Purpose:     wrappers to pass streams from Perl to wxWidgets
//              (see also XS/Streams.xs)
// Author:      Mattia Barbon
// Modified by:
// Created:     30/03/2001
// RCS-ID:      $Id: streams.h 2057 2007-06-18 23:03:00Z mbarbon $
// Copyright:   (c) 2001-2002, 2004, 2006 Mattia Barbon
// Licence:     This program is free software; you can redistribute it and/or
//              modify it under the same terms as Perl itself
/////////////////////////////////////////////////////////////////////////////

#ifndef _WXPERL_STREAMS_H
#define _WXPERL_STREAMS_H

#include <wx/stream.h>

// for wxWidgets use: store a Perl object and
// read from/write to it using wxWidgets functions

class wxPliInputStream:public wxInputStream
{
public:
    wxPliInputStream():m_fh( 0 ) {}
    wxPliInputStream( SV* fh );
    wxPliInputStream( const wxPliInputStream& stream );

    ~wxPliInputStream();

    const wxPliInputStream& operator =( const wxPliInputStream& stream );
protected:
    wxFileOffset GetLength() const;
    size_t OnSysRead( void* buffer, size_t bufsize );

    size_t GetSize() const;

#if WXPERL_W_VERSION_GE( 2, 5, 3 )
    wxFileOffset OnSysSeek(wxFileOffset seek, wxSeekMode mode);
    wxFileOffset OnSysTell() const;
#else
    off_t OnSysSeek(off_t seek, wxSeekMode mode);
    off_t OnSysTell() const;
#endif
protected:
    SV* m_fh;
};

class wxPliOutputStream:public wxOutputStream
{
public:
    wxPliOutputStream():m_fh( 0 ) {}
    wxPliOutputStream( SV* fh );
    wxPliOutputStream( const wxPliOutputStream& stream );
    ~wxPliOutputStream();

    const wxPliOutputStream& operator = ( const wxPliOutputStream& stream );
protected:
    wxFileOffset GetLength() const;
    size_t OnSysWrite( const void* buffer, size_t size );

    size_t GetSize() const;

#if WXPERL_W_VERSION_GE( 2, 5, 3 )
    wxFileOffset OnSysSeek(wxFileOffset seek, wxSeekMode mode);
    wxFileOffset OnSysTell() const;
#else
    off_t OnSysSeek(off_t seek, wxSeekMode mode);
    off_t OnSysTell() const;
#endif
protected:
    SV* m_fh;
};

#endif
    // _WXPERL_STREAMS_H

// Local variables: //
// mode: c++ //
// End: //

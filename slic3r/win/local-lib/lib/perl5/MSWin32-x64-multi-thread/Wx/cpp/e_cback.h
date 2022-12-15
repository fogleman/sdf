/////////////////////////////////////////////////////////////////////////////
// Name:        cpp/e_cback.h
// Purpose:     callback helper class for events
// Author:      Mattia Barbon
// Modified by:
// Created:     29/10/2000
// RCS-ID:      $Id: e_cback.h 3374 2012-09-26 11:37:03Z mdootson $
// Copyright:   (c) 2000-2001, 2005, 2008 Mattia Barbon
// Licence:     This program is free software; you can redistribute it and/or
//              modify it under the same terms as Perl itself
/////////////////////////////////////////////////////////////////////////////

#ifndef _WXPERL_E_CBACK_H
#define _WXPERL_E_CBACK_H

#if WXPERL_W_VERSION_GE( 2, 5, 4 )
typedef void (wxObject::* wxPliObjectEventFunction)(wxEvent&);

#define wxPliCastEvtHandler( e ) \
    ((wxObjectEventFunction)(wxPliObjectEventFunction) e)
#else
#define wxPliCastEvtHandler( e ) \
    ((wxObjectEventFunction) e)
#endif

class wxPliGuard
{
public:
    wxPliGuard()
    {
        m_sv = NULL;
    }

    ~wxPliGuard()
    {
        if( m_sv )
        {
            dTHX;

            wxPli_thread_sv_unregister( aTHX_ wxPli_get_class( aTHX_ m_sv ),
                                        (void*)SvIV( m_sv ), m_sv );
            sv_setiv( m_sv, 0 );
        }
    }

    void SetSV( SV* sv ) { m_sv = sv; }
private:
    SV* m_sv;
};

class wxPliEventCallback : public wxObject
{
public:
    wxPliEventCallback( SV* method, SV* self );
    ~wxPliEventCallback();

    void Handler( wxEvent& event );
private:
    bool m_is_method;
    SV* m_method;
    SV* m_self;
};

#endif // _WXPERL_E_CBACK_H

// Local variables: //
// mode: c++ //
// End: //

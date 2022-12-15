// GENERATED FILE, DO NOT EDIT

#ifndef _WXPERL_V_CBACK_DEF_H
#define _WXPERL_V_CBACK_DEF_H

#define DEC_V_CBACK_ANY__BOOL_( RET, METHOD, CONST ) \
    RET METHOD( bool p1 ) CONST

#define DEF_V_CBACK_ANY__BOOL_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( bool p1 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "b", p1 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__INT_( RET, METHOD, CONST ) \
    RET METHOD( int p1 ) CONST

#define DEF_V_CBACK_ANY__INT_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( int p1 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "i", p1 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__WXVARIANT_UINT_UINT_( RET, METHOD, CONST ) \
    RET METHOD( const wxVariant& p1, unsigned int p2, unsigned int p3 ) CONST

#define DEF_V_CBACK_ANY__WXVARIANT_UINT_UINT_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( const wxVariant& p1, unsigned int p2, unsigned int p3 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "qII", &p1, "Wx::Variant", p2, p3 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__SIZET_( RET, METHOD, CONST ) \
    RET METHOD( size_t p1 ) CONST

#define DEF_V_CBACK_ANY__SIZET_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( size_t p1 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "L", p1 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__SIZET_SIZET_( RET, METHOD, CONST ) \
    RET METHOD( size_t p1, size_t p2 ) CONST

#define DEF_V_CBACK_ANY__SIZET_SIZET_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( size_t p1, size_t p2 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "LL", p1, p2 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__VOID_( RET, METHOD, CONST ) \
    RET METHOD() CONST

#define DEF_V_CBACK_ANY__VOID_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD() CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             NULL ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__INT_INT_( RET, METHOD, CONST ) \
    RET METHOD( int p1, int p2 ) CONST

#define DEF_V_CBACK_ANY__INT_INT_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( int p1, int p2 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "ii", p1, p2 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__LONG_LONG_( RET, METHOD, CONST ) \
    RET METHOD( long p1, long p2 ) CONST

#define DEF_V_CBACK_ANY__LONG_LONG_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( long p1, long p2 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "ll", p1, p2 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_VOID__INT_INT_LONG_( RET, METHOD, CONST ) \
    void METHOD( int p1, int p2, long p3 ) CONST

#define DEF_V_CBACK_VOID__INT_INT_LONG_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    void CLASS::METHOD( int p1, int p2, long p3 ) CONST \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxPliCCback( aTHX_ &m_callback, G_SCALAR|G_DISCARD,               \
                         "iil", p1, p2, p3 );                              \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_VOID__mWXVARIANT_UINT_UINT_( RET, METHOD, CONST ) \
    void METHOD( wxVariant& p1, unsigned int p2, unsigned int p3 ) CONST

#define DEF_V_CBACK_VOID__mWXVARIANT_UINT_UINT_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    void CLASS::METHOD( wxVariant& p1, unsigned int p2, unsigned int p3 ) CONST \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxPliCCback( aTHX_ &m_callback, G_SCALAR|G_DISCARD,               \
                         "qII", &p1, "Wx::Variant", p2, p3 );                              \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_VOID__SIZET_SIZET_( RET, METHOD, CONST ) \
    void METHOD( size_t p1, size_t p2 ) CONST

#define DEF_V_CBACK_VOID__SIZET_SIZET_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    void CLASS::METHOD( size_t p1, size_t p2 ) CONST \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxPliCCback( aTHX_ &m_callback, G_SCALAR|G_DISCARD,               \
                         "LL", p1, p2 );                              \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__WXSTRING_( RET, METHOD, CONST ) \
    RET METHOD( const wxString& p1 ) CONST

#define DEF_V_CBACK_ANY__WXSTRING_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( const wxString& p1 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "P", &p1 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__UINT_( RET, METHOD, CONST ) \
    RET METHOD( unsigned int p1 ) CONST

#define DEF_V_CBACK_ANY__UINT_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( unsigned int p1 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "I", p1 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_ANY__INT_INT_WXATTRKIND_( RET, METHOD, CONST ) \
    RET METHOD( int p1, int p2, wxGridCellAttr::wxAttrKind p3 ) CONST

#define DEF_V_CBACK_ANY__INT_INT_WXATTRKIND_( RET, CVT, CLASS, CALLBASE, METHOD, CONST ) \
    RET CLASS::METHOD( int p1, int p2, wxGridCellAttr::wxAttrKind p3 ) CONST                           \
    {                                                                         \
        dTHX;                                                                 \
        if( wxPliFCback( aTHX_ &m_callback, #METHOD ) )                       \
        {                                                                     \
            wxAutoSV ret( aTHX_ wxPliCCback( aTHX_ &m_callback, G_SCALAR,     \
                                             "iii", p1, p2, p3 ) );                      \
            return CVT;                                                       \
        }                                                                     \
        else                                                                  \
            CALLBASE;                                                         \
    }

#define DEC_V_CBACK_BOOL__BOOL( METHOD ) \
    DEC_V_CBACK_ANY__BOOL_( bool, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__BOOL( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__BOOL_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(p1), METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__INT( METHOD ) \
    DEC_V_CBACK_ANY__INT_( bool, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__INT( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(p1), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__INT_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_( bool, SvTRUE( ret ), CLASS, return false, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__WXVARIANT_UINT_UINT( METHOD ) \
    DEC_V_CBACK_ANY__WXVARIANT_UINT_UINT_( bool, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__WXVARIANT_UINT_UINT_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__WXVARIANT_UINT_UINT_( bool, SvTRUE( ret ), CLASS, return false, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__SIZET( METHOD ) \
    DEC_V_CBACK_ANY__SIZET_( bool, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__SIZET( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(p1), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__SIZET_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_( bool, SvTRUE( ret ), CLASS, return false, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__SIZET_SIZET( METHOD ) \
    DEC_V_CBACK_ANY__SIZET_SIZET_( bool, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__SIZET_SIZET( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_SIZET_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__SIZET_SIZET_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_SIZET_( bool, SvTRUE( ret ), CLASS, return false, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__VOID( METHOD ) \
    DEC_V_CBACK_ANY__VOID_( bool, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__VOID_const( METHOD ) \
    DEC_V_CBACK_ANY__VOID_( bool, METHOD, wxPli_CONST )

#define DEF_V_CBACK_BOOL__VOID( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__VOID_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(), METHOD, wxPli_CONST )

#define DEF_V_CBACK_BOOL__VOID_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( bool, SvTRUE( ret ), CLASS, return false, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__INT_INT( METHOD ) \
    DEC_V_CBACK_ANY__INT_INT_( bool, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_BOOL__INT_INT_const( METHOD ) \
    DEC_V_CBACK_ANY__INT_INT_( bool, METHOD, wxPli_CONST )

#define DEF_V_CBACK_BOOL__INT_INT( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__INT_INT_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( bool, SvTRUE( ret ), CLASS, return false, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_BOOL__INT_INT_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( bool, SvTRUE( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_CONST )

#define DEF_V_CBACK_BOOL__INT_INT_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( bool, SvTRUE( ret ), CLASS, return false, METHOD, wxPli_CONST )

#define DEC_V_CBACK_DOUBLE__INT_INT( METHOD ) \
    DEC_V_CBACK_ANY__INT_INT_( double, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_DOUBLE__INT_INT_const( METHOD ) \
    DEC_V_CBACK_ANY__INT_INT_( double, METHOD, wxPli_CONST )

#define DEF_V_CBACK_DOUBLE__INT_INT( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( double, SvNV( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_DOUBLE__INT_INT_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( double, SvNV( ret ), CLASS, return 0.0, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_DOUBLE__INT_INT_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( double, SvNV( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_CONST )

#define DEF_V_CBACK_DOUBLE__INT_INT_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( double, SvNV( ret ), CLASS, return 0.0, METHOD, wxPli_CONST )

#define DEC_V_CBACK_INT__LONG_LONG( METHOD ) \
    DEC_V_CBACK_ANY__LONG_LONG_( int, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_INT__LONG_LONG_const( METHOD ) \
    DEC_V_CBACK_ANY__LONG_LONG_( int, METHOD, wxPli_CONST )

#define DEF_V_CBACK_INT__LONG_LONG( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__LONG_LONG_( int, SvIV( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_INT__LONG_LONG_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__LONG_LONG_( int, SvIV( ret ), CLASS, return 0, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_INT__LONG_LONG_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__LONG_LONG_( int, SvIV( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_CONST )

#define DEC_V_CBACK_INT__VOID( METHOD ) \
    DEC_V_CBACK_ANY__VOID_( int, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_INT__VOID( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( int, SvIV( ret ), CLASS, return BASE::METHOD(), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_INT__VOID_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( int, SvIV( ret ), CLASS, return 0, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_LONG__INT_INT( METHOD ) \
    DEC_V_CBACK_ANY__INT_INT_( long, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_LONG__INT_INT_const( METHOD ) \
    DEC_V_CBACK_ANY__INT_INT_( long, METHOD, wxPli_CONST )

#define DEF_V_CBACK_LONG__INT_INT( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( long, SvIV( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_LONG__INT_INT_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( long, SvIV( ret ), CLASS, return 0, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_LONG__INT_INT_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( long, SvIV( ret ), CLASS, return BASE::METHOD(p1, p2), METHOD, wxPli_CONST )

#define DEF_V_CBACK_LONG__INT_INT_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_( long, SvIV( ret ), CLASS, return 0, METHOD, wxPli_CONST )

#define DEC_V_CBACK_UINT__VOID( METHOD ) \
    DEC_V_CBACK_ANY__VOID_( unsigned int, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_UINT__VOID_const( METHOD ) \
    DEC_V_CBACK_ANY__VOID_( unsigned int, METHOD, wxPli_CONST )

#define DEF_V_CBACK_UINT__VOID( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( unsigned int, SvUV( ret ), CLASS, return BASE::METHOD(), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_UINT__VOID_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( unsigned int, SvUV( ret ), CLASS, return BASE::METHOD(), METHOD, wxPli_CONST )

#define DEF_V_CBACK_UINT__VOID_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( unsigned int, SvUV( ret ), CLASS, return 0, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_UINT__VOID_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( unsigned int, SvUV( ret ), CLASS, return 0, METHOD, wxPli_CONST )

#define DEC_V_CBACK_VOID__INT_INT_LONG( METHOD ) \
    DEC_V_CBACK_VOID__INT_INT_LONG_( void, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_VOID__INT_INT_LONG( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_VOID__INT_INT_LONG_( void, ;, CLASS, BASE::METHOD(p1, p2, p3), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_VOID__INT_INT_LONG_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_VOID__INT_INT_LONG_( void, ;, CLASS, return, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_VOID__mWXVARIANT_UINT_UINT_const( METHOD ) \
    DEC_V_CBACK_VOID__mWXVARIANT_UINT_UINT_( void, METHOD, wxPli_CONST )

#define DEF_V_CBACK_VOID__mWXVARIANT_UINT_UINT_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_VOID__mWXVARIANT_UINT_UINT_( void, ;, CLASS, return, METHOD, wxPli_CONST )

#define DEC_V_CBACK_VOID__SIZET_SIZET_const( METHOD ) \
    DEC_V_CBACK_VOID__SIZET_SIZET_( void, METHOD, wxPli_CONST )

#define DEF_V_CBACK_VOID__SIZET_SIZET_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_VOID__SIZET_SIZET_( void, ;, CLASS, BASE::METHOD(p1, p2), METHOD, wxPli_CONST )

#define DEC_V_CBACK_WXCOORD__VOID_const( METHOD ) \
    DEC_V_CBACK_ANY__VOID_( wxCoord, METHOD, wxPli_CONST )

#define DEF_V_CBACK_WXCOORD__VOID_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( wxCoord, SvIV( ret ), CLASS, return BASE::METHOD(), METHOD, wxPli_CONST )

#define DEF_V_CBACK_WXCOORD__VOID_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__VOID_( wxCoord, SvIV( ret ), CLASS, return 0, METHOD, wxPli_CONST )

#define DEC_V_CBACK_WXCOORD__SIZET( METHOD ) \
    DEC_V_CBACK_ANY__SIZET_( wxCoord, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_WXCOORD__SIZET_const( METHOD ) \
    DEC_V_CBACK_ANY__SIZET_( wxCoord, METHOD, wxPli_CONST )

#define DEF_V_CBACK_WXCOORD__SIZET( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_( wxCoord, SvIV( ret ), CLASS, return BASE::METHOD(p1), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_WXCOORD__SIZET_const( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_( wxCoord, SvIV( ret ), CLASS, return BASE::METHOD(p1), METHOD, wxPli_CONST )

#define DEF_V_CBACK_WXCOORD__SIZET_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_( wxCoord, SvIV( ret ), CLASS, return 0, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_WXCOORD__SIZET_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__SIZET_( wxCoord, SvIV( ret ), CLASS, return 0, METHOD, wxPli_CONST )

#define DEC_V_CBACK_WXSTRING__WXSTRING( METHOD ) \
    DEC_V_CBACK_ANY__WXSTRING_( wxString, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_WXSTRING__WXSTRING( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__WXSTRING_( wxString, wxPli_sv_2_wxString( aTHX_ ret ), CLASS, return BASE::METHOD(p1), METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_WXSTRING__UINT( METHOD ) \
    DEC_V_CBACK_ANY__UINT_( wxString, METHOD, wxPli_NOCONST )

#define DEC_V_CBACK_WXSTRING__UINT_const( METHOD ) \
    DEC_V_CBACK_ANY__UINT_( wxString, METHOD, wxPli_CONST )

#define DEF_V_CBACK_WXSTRING__UINT( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__UINT_( wxString, wxPli_sv_2_wxString( aTHX_ ret ), CLASS, return BASE::METHOD(p1), METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_WXSTRING__UINT_const_pure( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__UINT_( wxString, wxPli_sv_2_wxString( aTHX_ ret ), CLASS, return wxEmptyString, METHOD, wxPli_CONST )

#define DEC_V_CBACK_WXGRIDATTR__INT_INT_WXATTRKIND( METHOD ) \
    DEC_V_CBACK_ANY__INT_INT_WXATTRKIND_( wxGridCellAttr*, METHOD, wxPli_NOCONST )

#define DEF_V_CBACK_WXGRIDATTR__INT_INT_WXATTRKIND( CLASS, BASE, METHOD ) \
    DEF_V_CBACK_ANY__INT_INT_WXATTRKIND_( wxGridCellAttr*, (wxGridCellAttr*)wxPli_sv_2_object( aTHX_ ret, "Wx::GridCellAttr" ), CLASS, return BASE::METHOD(p1, p2, p3), METHOD, wxPli_NOCONST )


#endif


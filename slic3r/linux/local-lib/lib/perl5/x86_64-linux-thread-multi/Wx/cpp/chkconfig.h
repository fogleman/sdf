/////////////////////////////////////////////////////////////////////////////
// Name:        cpp/chkconfig.h
// Purpose:     checks if desired configurations for wxPerl and wxWidgets
//              are compatible
// Author:      Mattia Barbon
// Modified by:
// Created:     05/11/2001
// RCS-ID:      $Id: chkconfig.h 2252 2007-10-17 22:55:25Z mbarbon $
// Copyright:   (c) 2001-2004, 2006-2007 Mattia Barbon
// Licence:     This program is free software; you can redistribute it and/or
//              modify it under the same terms as Perl itself
/////////////////////////////////////////////////////////////////////////////

#include <wx/setup.h>
#include "cpp/setup.h"

#if 0
#define wxPERL_USE_PRINTING_ARCHITECTURE 1
#define wxPERL_USE_MDI_ARCHITECTURE 1
#define wxPERL_USE_SNGLINST_CHECKER 1
// #define wxPERL_USE_DRAG_AND_DROP 1
// #define wxPERL_USE_TOGGLEBTN 1
// #define wxPERL_USE_MS_HTML_HELP
// #define wxPERL_USE_HELPBEST
#endif
// missing
// UNICODE, LOG, CMDLINE_PARSER, LOGWINDOW, LOGGUI, LOGDIALOG
// WCHAR_T, STREAMS, INTL, DATETIME, TIMER, STOPWATCH, CONFIG,
// CONFIG_NATIVE, DIALUP_MANAGER, FILESYSTEM, FS_ZIP, FS_INET, JOYSTICK,
// FONTMAP, MIMETYPE, SYSTEM_OPTIONS, POPUPWIN, BUTTON,
// BMPBUTTON, CALENDARCTRL, CHECKBOX, CHECKLISTBOX, CHOICE,
// COMBOBOX, GAUGE, LISTBOX, LISTCTRL, RADIOBOX, RADIOBTN, 
// SCROLLBAR, SLIDER, SPINBTN, SPINCTRL, STATBOX, STATLINE,
// STATTEXT, STATBMP, TEXTCTRL, TOGGLEBTN, TREECTRL
// STATUSBAR, TOOLBAR, TOOLBAR_SIMPLE, NOTEBOOK, GRID, ACCEL
// CARET, IMAGLIST, MENUS, SASH, SPLITTER, VALIDATORS,
// BUSYINFO, CHOICEDLG, COLOURDLG, DIRDLG, FILEDLG, FINDREPLDLG
// MSGDLG, PROGRESSDLG, STARTUP_TIPS, TEXTDLG, NUMBERDLG,
// SPLASH, WIZARDDLG, HTML, CLIPBOARD, DATAOBJ, HELP,
// WXHTML_HELP, RESOURCES, CONSTRAINTS, MOUSEWHEEL, IMAGE,
// LIBPNG, LIBJPEG, GIF, PNM, PCX, XPM, PALETTE

#ifdef wxPERL_USE_DRAG_AND_DROP
#   if wxPERL_USE_DRAG_AND_DROP && !wxUSE_DRAG_AND_DROP
#       error "Recompile wxWidgets with wxUSE_DRAG_AND_DROP"
#   endif
#else
#   define wxPERL_USE_DRAG_AND_DROP wxUSE_DRAG_AND_DROP
#endif

#ifdef wxPERL_USE_FONTDLG
#   if wxPERL_USE_FONTDLG && !wxUSE_FONTDLG
#       error "Recompile wxWidgets with wxUSE_FONTDLG"
#   endif
#else
#   ifndef wxUSE_FONTDLG
#       define wxUSE_FONTDLG 1
#   endif
#   define wxPERL_USE_FONTDLG wxUSE_FONTDLG
#endif

#ifdef wxPERL_USE_IFF
#   if wxPERL_USE_IFF && !wxUSE_IFF
#       error "Recompile wxWidgets with wxUSE_IFF"
#   endif
#else
#   define wxPERL_USE_IFF wxUSE_IFF
#endif

#ifdef wxPERL_USE_LIBTIFF
#   if wxPERL_USE_LIBTIFF && !wxUSE_LIBTIFF
#       error "Recompile wxWidgets with wxUSE_LIBTIFF"
#   endif
#else
#   define wxPERL_USE_LIBTIFF wxUSE_LIBTIFF
#endif

#ifdef wxPERL_USE_MDI_ARCHITECTURE
#   if wxPERL_USE_MDI_ARCHITECTURE && !wxUSE_MDI_ARCHITECTURE
#       error "Recompile wxWidgets with wxUSE_MDI_ARCHITECTURE"
#   endif
#else
#   define wxPERL_USE_MDI_ARCHITECTURE wxUSE_MDI_ARCHITECTURE
#endif

#ifdef __WXUNIVERSAL__
#   define wxPERL_USE_MINIFRAME 0
#else
#   define wxPERL_USE_MINIFRAME 1
#endif

#ifdef wxPERL_USE_MS_HTML_HELP
#   if wxPERL_USE_MS_HTML_HELP && !wxUSE_MS_HTML_HELP
#       error "Recompile wxWidgets with wxUSE_MS_HTML_HELP"
#   endif
#else
#   define wxPERL_USE_MS_HTML_HELP wxUSE_MS_HTML_HELP
#endif

#ifdef wxPERL_USE_PRINTING_ARCHITECTURE
#   if wxPERL_USE_PRINTING_ARCHITECTURE && !wxUSE_PRINTING_ARCHITECTURE
#       error "Recompile wxWidgets with wxUSE_PRINTING_ARCHITECTURE"
#   endif
#else
#   define wxPERL_USE_PRINTING_ARCHITECTURE wxUSE_PRINTING_ARCHITECTURE
#endif

#ifdef wxPERL_USE_TOOLTIPS
#   if wxPERL_USE_TOOLTIPS && !wxUSE_TOOLTIPS
#       error "Recompile wxWidgets with wxUSE_TOOLTIPS"
#   endif
#else
#   define wxPERL_USE_TOOLTIPS wxUSE_TOOLTIPS
#endif

#ifdef wxPERL_USE_WAVE
#   if wxPERL_USE_WAVE && !wxUSE_WAVE
#       error "Recompile wxWidgets with wxUSE_WAVE"
#   endif
#else
#   define wxPERL_USE_WAVE wxUSE_WAVE
#endif

#ifdef wxPERL_USE_BESTHELP
#   if wxPERL_USE_BESTHELP && !( wxUSE_MS_HTML_HELP && wxUSE_WXHTML_HELP )
#       error "Recompile wxWidgets with wxUSE_MS_HTML_HELP and wxUSE_WXHTML_HELP"
#   endif
#else
#   define wxPERL_USE_BESTHELP ( wxUSE_MS_HTML_HELP && wxUSE_WXHTML_HELP )
#endif

#ifdef wxPERL_USE_ICO_CUR
#   if wxPERL_USE_ICO_CUR && !wxUSE_ICO_CUR
#       error "Recompile wxWidgets with wxUSE_ICO_CUR"
#   endif
#else
#   define wxPERL_USE_ICO_CUR wxUSE_ICO_CUR
#endif
 
#ifdef wxPERL_USE_SNGLINST_CHECKER
#   if wxPERL_USE_SNGLINST_CHECKER && !wxUSE_SNGLINST_CHECKER
#       error "Recompile wxWidgets with wxUSE_SNGLINST_CHECKER"
#   endif
#else
#   define wxPERL_USE_SNGLINST_CHECKER wxUSE_SNGLINST_CHECKER
#endif

#ifdef wxPERL_USE_TOGGLEBTN
#   if wxPERL_USE_TOGGLEBTN && !wxUSE_TOGGLEBTN
#       error "Recompile wxWidgets with wxUSE_TOGGLEBTN"
#   endif
#else
#   define wxPERL_USE_TOGGLEBTN wxUSE_TOGGLEBTN
#endif

#if wxUSE_THREADS && defined(USE_ITHREADS)
#   define wxPERL_USE_THREADS 1
#else
#   define wxPERL_USE_THREADS 0
#endif

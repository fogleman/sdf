#############################################################################
## Name:        ext/webview/lib/Wx/WebView.pm
## Purpose:     Wx::WebView and related classes
## Author:      Mark Dootson
## Created:     17/03/2012
## SVN-ID:      $Id: WebView.pm 3220 2012-03-18 03:02:46Z mdootson $
## Copyright:   (c) 2012 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################
BEGIN {
    package Wx::WebView;
    our $__wx_webview_present = Wx::_wx_optmod_webview();
}

package Wx::WebView;
use strict;

our $VERSION = '0.01';

our $__wx_webview_present;

if( $__wx_webview_present ) {
    Wx::load_dll( 'webview' );
    Wx::wx_boot( 'Wx::WebView', $VERSION );
}

#
# properly setup inheritance tree
#

no strict;

package Wx::WebViewHandler;
package Wx::WebViewArchiveHandler;  @ISA = qw( Wx::WebViewHandler );
package Wx::WebViewEvent;           @ISA = qw( Wx::NotifyEvent );
package Wx::WebView;                @ISA = qw( Wx::Control );

1;

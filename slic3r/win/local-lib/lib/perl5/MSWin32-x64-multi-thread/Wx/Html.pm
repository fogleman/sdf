#############################################################################
## Name:        ext/html/lib/Wx/Html.pm
## Purpose:     Wx::Html (pulls in all Wx::Html* stuff)
## Author:      Mattia Barbon
## Modified by:
## Created:     17/03/2001
## RCS-ID:      $Id: Html.pm 2084 2007-07-18 21:34:14Z vadz $
## Copyright:   (c) 2001-2007 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Html;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::load_dll( 'net' );
Wx::load_dll( 'html' );
Wx::wx_boot( 'Wx::Html', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::HelpControllerBase; # warning fix
package Wx::HtmlWindow;         @ISA = qw(Wx::ScrolledWindow);
package Wx::HtmlHelpController; @ISA = qw(Wx::HelpControllerBase);
package Wx::HtmlParser;
package Wx::HtmlWinParser;      @ISA = qw(Wx::HtmlParser);
package Wx::HtmlTag;
package Wx::PlHtmlTag;          @ISA = qw(Wx::HtmlTag);
package Wx::HtmlTagHandler;
package Wx::PlHtmlTagHandler;   @ISA = qw(Wx::HtmlTagHandler);
package Wx::HtmlWinTagHandler;  @ISA = qw(Wx::HtmlTagHandler);
package Wx::PlHtmlWinTagHandler;@ISA = qw(Wx::HtmlWinTagHandler);
package Wx::HtmlCell;
package Wx::HtmlWordCell;       @ISA = qw(Wx::HtmlCell);
package Wx::HtmlContainerCell;  @ISA = qw(Wx::HtmlCell);
package Wx::HtmlFontCell;       @ISA = qw(Wx::HtmlCell);
package Wx::HtmlColourCell;     @ISA = qw(Wx::HtmlCell);
package Wx::HtmlWidgetCell;     @ISA = qw(Wx::HtmlCell);
package Wx::HtmlListBox;        @ISA = qw(Wx::VListBox);
package Wx::PlHtmlListBox;      @ISA = qw(Wx::HtmlListBox);
package Wx::SimpleHtmlListBox;  @ISA = qw(Wx::HtmlListBox);
package Wx::HtmlCellEvent;      @ISA = qw(Wx::CommandEvent);
package Wx::HtmlLinkEvent;      @ISA = qw(Wx::CommandEvent);

package Wx::Event;

use strict;

sub EVT_HTML_CELL_CLICKED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_HTML_CELL_CLICKED, $_[2] ) }
sub EVT_HTML_CELL_HOVER($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_HTML_CELL_HOVER, $_[2] ) }
sub EVT_HTML_LINK_CLICKED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_HTML_LINK_CLICKED, $_[2] ) }

1;

# Local variables:
# mode: cperl
# End:

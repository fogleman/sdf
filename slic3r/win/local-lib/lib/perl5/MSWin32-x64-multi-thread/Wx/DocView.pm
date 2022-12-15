#############################################################################
## Name:        ext/docview/lib/Wx/DocView.pm
## Purpose:     Wx::DocView
## Author:      Simon Flack
## Modified by:
## Created:     11/09/2002
## RCS-ID:      $Id: DocView.pm 2188 2007-08-20 19:21:29Z mbarbon $
## Copyright:   (c) 2002, 2004, 2007 Simon Flack
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::DocView;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::wx_boot( 'Wx::DocView', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::Printout;                   # avoid warning
package Wx::MDIChildFrame;              # avoid warning
package Wx::MDIParentFrame;             # avoid warning
package Wx::DocManager;                 @ISA = qw(Wx::EvtHandler);
package Wx::View;                       @ISA = qw(Wx::EvtHandler);
package Wx::Document;                   @ISA = qw(Wx::EvtHandler);
package Wx::DocPrintout;                @ISA = qw(Wx::Printout);
package Wx::DocChildFrame;              @ISA = qw(Wx::Frame);
package Wx::DocParentFrame;             @ISA = qw(Wx::Frame);
package Wx::DocMDIChildFrame;           @ISA = qw(Wx::MDIChildFrame);
package Wx::DocMDIParentFrame;          @ISA = qw(Wx::MDIParentFrame);
package Wx::PlCommand;                  @ISA = qw(Wx::Command);

1;

# Local variables: #
# mode: cperl #
# End: #

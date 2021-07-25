#############################################################################
## Name:        ext/print/lib/Wx/Print.pm
## Purpose:     Wx::Print ( pulls in all Print framework )
## Author:      Mattia Barbon
## Modified by:
## Created:     04/05/2001
## RCS-ID:      $Id: Print.pm 3295 2012-05-22 14:46:54Z mdootson $
## Copyright:   (c) 2001-2002, 2004-2006 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Print;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::wx_boot( 'Wx::Print', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::GenericPageSetupDialog; @ISA = qw(Wx::Dialog);
package Wx::GenericPrintDialog; @ISA = qw(Wx::Dialog);
package Wx::PageSetupDialog;    @ISA = qw(Wx::Dialog);
package Wx::PostScriptDC; @ISA = qw(Wx::DC);
package Wx::PostScriptPrintPreview; @ISA = qw(Wx::PrintPreview);
package Wx::PostScriptPrinter; @ISA = qw(Wx::Printer);
package Wx::PreviewCanvas; @ISA = qw(Wx::Window);
package Wx::PreviewControlBar; @ISA = qw(Wx::Window);
package Wx::PreviewFrame; @ISA = qw(Wx::Frame);
package Wx::PrintDialog;  @ISA = qw(Wx::Dialog);
package Wx::PrintDialog;  @ISA = qw(Wx::Dialog);
package Wx::PrintPreviewBase;
package Wx::PrintPreview; @ISA = qw(Wx::PrintPreviewBase);
package Wx::PrinterDC;    @ISA = qw(Wx::DC);
package Wx::GnomePrintDC; @ISA = qw(Wx::DC);
package Wx::WindowsPrintPreview; @ISA = qw(Wx::PrintPreview);
package Wx::WindowsPrinter; @ISA = qw(Wx::Printer);
package Wx::PlPreviewFrame; @ISA = qw(Wx::PreviewFrame);
package Wx::PlPreviewControlBar; @ISA = qw(Wx::PreviewControlBar);
package Wx::PrintPaperType; @ISA = qw(Wx::Object);

use strict;

1;

# Local variables: #
# mode: cperl #
# End: #

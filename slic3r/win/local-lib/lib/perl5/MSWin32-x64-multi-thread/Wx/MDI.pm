#############################################################################
## Name:        ext/mdi/lib/Wx/MDI.pm
## Purpose:     Wx::MDI (pulls in all MDI)
## Author:      Mattia Barbon
## Modified by:
## Created:     06/09/2001
## RCS-ID:      $Id: MDI.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2001-2002, 2004 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::MDI;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::wx_boot( 'Wx::MDI', $VERSION );

# init wxModules

#
# properly setup inheritance tree
#

no strict;

package Wx::MDIParentFrame;     @ISA = qw(Wx::Frame);
package Wx::MDIChildFrame;      @ISA = qw(Wx::Frame);
package Wx::MDIClientWindow;

@ISA = Wx::wxMOTIF ? 'Wx::Notebook' : 'Wx::Window';

package Wx::GenericMDIParentFrame;     @ISA = qw(Wx::MDIParentFrame);
package Wx::GenericMDIChildFrame;      @ISA = qw(Wx::MDIChildFrame);
package Wx::GenericMDIClientWindow;    @ISA = qw(Wx::MDIClientWindow);

use strict;

1;

# Local variables: #
# mode: cperl #
# End: #


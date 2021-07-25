#############################################################################
## Name:        ext/help/lib/Wx/Help.pm
## Purpose:     Wx::Help ( pulls in all Wx::Help* stuff )
## Author:      Mattia Barbon
## Modified by:
## Created:     18/03/2001
## RCS-ID:      $Id: Help.pm 2148 2007-08-15 17:10:50Z mbarbon $
## Copyright:   (c) 2001-2002, 2007 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Help;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::wx_boot( 'Wx::Help', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::HelpController;     @ISA = qw(Wx::HelpControllerBase);
package Wx::WinHelpController;  @ISA = qw(Wx::HelpControllerBase);
package Wx::HelpControllerHtml; @ISA = qw(Wx::HelpControllerBase);
package Wx::CHMHelpController;  @ISA = qw(Wx::HelpControllerBase);
package Wx::ExtHelpController;  @ISA = qw(Wx::HelpControllerBase);
package Wx::BesthelpController; @ISA = qw(Wx::HelpControllerBase);

package Wx::ContextHelpButton;  @ISA = qw(Wx::BitmapButton);
package Wx::SimpleHelpProvider; @ISA = qw(Wx::HelpProvider);
package Wx::HelpControllerHelpProvider; @ISA = qw(Wx::HelpProvider);

use strict;

1;

# Local variables: #
# mode: cperl #
# End: #

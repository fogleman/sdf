#############################################################################
## Name:        ext/dnd/lib/Wx/DND.pm
## Purpose:     Wx::DND pulls in all wxWidgets Drag'n'Drop and Clipboard
## Author:      Mattia Barbon
## Modified by:
## Created:     12/08/2001
## RCS-ID:      $Id: DND.pm 3538 2015-03-11 02:36:34Z mdootson $
## Copyright:   (c) 2001-2004, 2007 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::DND;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::wx_boot( 'Wx::DND', $VERSION );

use Wx::DropSource;

#
# properly setup inheritance tree
#

no strict;

package Wx::DropTarget;
package Wx::DropFilesEvent;     @ISA = qw(Wx::Event);
package Wx::DataObject;
package Wx::DataObjectSimple;   @ISA = qw(Wx::DataObject);
package Wx::PlDataObjectSimple; @ISA = qw(Wx::DataObjectSimple);
package Wx::DataObjectComposite;@ISA = qw(Wx::DataObject);
package Wx::FileDataObject;     @ISA = qw(Wx::DataObjectSimple);
package Wx::TextDataObject;     @ISA = qw(Wx::DataObjectSimple);
package Wx::BitmapDataObject;   @ISA = qw(Wx::DataObjectSimple);

package Wx::PlDropTarget;       @ISA = qw(Wx::DropTarget);
package Wx::TextDropTarget;     @ISA = qw(Wx::DropTarget);
package Wx::FileDropTarget;     @ISA = qw(Wx::DropTarget);
package Wx::URLDataObject;      @ISA = qw(Wx::DataObject);

use strict;

#
# constants
#

package Wx;

use vars qw($_df_invalid $_df_bitmap $_df_text $_df_unicodetext $_df_metafile $_df_filename);

# !parser: sub { $_[0] =~ m/^\s*\#\s*sub\s+(wx\w+)/ }
# !package: Wx
# !tag: dnd clipboard

# sub wxDF_INVALID
# sub wxDF_TEXT
# sub wxDF_UNICODETEXT
# sub wxDF_BITMAP
# sub wxDF_METAFILE
# sub wxDF_FILENAME

1;

# Local variables: #
# mode: cperl #
# End: #



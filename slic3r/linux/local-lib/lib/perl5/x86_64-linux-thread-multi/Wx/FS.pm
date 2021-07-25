#############################################################################
## Name:        ext/filesys/lib/Wx/FS.pm
## Purpose:     Wx::FS ( pulls in all Wx::FileSystem stuff )
## Author:      Mattia Barbon
## Modified by:
## Created:     28/04/2001
## RCS-ID:      $Id: FS.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2001-2002, 2004, 2006 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::FS;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::load_dll( 'net' );
Wx::wx_boot( 'Wx::FS', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::FileSystemHandler;
package Wx::InternetFSHandler;  @ISA = qw(Wx::FileSystemHandler);
package Wx::PlFileSystemHandler; @ISA = qw(Wx::FileSystemHandler);
package Wx::PlFSFile;           @ISA = qw(Wx::FSFile);
package Wx::ArchiveFSHandler;   @ISA = qw(Wx::FileSystemHandler);
package Wx::ZipFSHandler;

@ISA = Wx::wxVERSION() < 2.007002 ? qw(Wx::FileSystemHandler) :
                                    qw(Wx::ArchiveFSHandler);

use strict;

1;

# Local variables: #
# mode: cperl #
# End: #


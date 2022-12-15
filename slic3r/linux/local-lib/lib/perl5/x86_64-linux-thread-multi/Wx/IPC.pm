#############################################################################
## Name:        ext/ipc/lib/Wx/IPC.pm
## Purpose:     Wx::IPC ( Iter-Process Communication framework )
## Author:      Mark Dootson
## Modified by:
## Created:     13 Apr 2013
## RCS-ID:      $Id: IPC.pm 3470 2013-04-13 08:38:19Z mdootson $
## Copyright:   (c) 2013 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::IPC;

use Wx;
use strict;

our $VERSION = '0.01';

Wx::load_dll( 'net' ) if !Wx::wxMSW;
Wx::wx_boot( 'Wx::IPC', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::Connection; @ISA = qw(Wx::Object);
package Wx::Server; @ISA = qw(Wx::Object);
package Wx::Client; @ISA = qw(Wx::Object);
package Wx::Connectionbase; @ISA = qw(Wx::Connection);
package Wx::DDEConnection; @ISA = qw(Wx::Connection);
package Wx::DDEServer; @ISA = qw(Wx::Server);
package Wx::DDEClient; @ISA = qw(Wx::Client);
package Wx::TCPConnection; @ISA = qw(Wx::Connection);
package Wx::TCPServer; @ISA = qw(Wx::Server);
package Wx::TCPClient; @ISA = qw(Wx::Client);
package Wx::PlConnection; @ISA = ( Wx::wxMSW ) ? qw(Wx::DDEConnection) : qw(Wx::TCPConnection);
package Wx::PlServer;     @ISA = ( Wx::wxMSW ) ? qw(Wx::DDEServer) : qw(Wx::TCPServer);
package Wx::PlClient;     @ISA = ( Wx::wxMSW ) ? qw(Wx::DDEClient) : qw(Wx::TCPClient);

use strict;

1;

# Local variables: #
# mode: cperl #
# End: #

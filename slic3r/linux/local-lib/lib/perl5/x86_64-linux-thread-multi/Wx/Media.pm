#############################################################################
## Name:        ext/media/lib/Wx/Media.pm
## Purpose:     Wx::Media (pulls in Wx::MediaCtrl)
## Author:      Mattia Barbon
## Modified by:
## Created:     04/03/2006
## RCS-ID:      $Id: Media.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2006 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Media;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::load_dll( 'media' );
Wx::wx_boot( 'Wx::Media', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::MediaCtrl; @ISA = qw(Wx::Control);
package Wx::MediaEvent; @ISA = qw(Wx::NotifyEvent);

use strict;

package Wx::Event;

use strict;

# !parser: sub { $_[0] =~ m/sub (EVT_\w+)/ }
# !package: Wx::Event

sub EVT_MEDIA_LOADED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_MEDIA_LOADED, $_[2] ) };
sub EVT_MEDIA_FINISHED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_MEDIA_FINISHED, $_[2] ) };
sub EVT_MEDIA_STOP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_MEDIA_STOP, $_[2] ) };
sub EVT_MEDIA_PAUSE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_MEDIA_PAUSE, $_[2] ) };
sub EVT_MEDIA_PLAY($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_MEDIA_PLAY, $_[2] ) };
sub EVT_MEDIA_STATECHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_MEDIA_STATECHANGED, $_[2] ) };

1;

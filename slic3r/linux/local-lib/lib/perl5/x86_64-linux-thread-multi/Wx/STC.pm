#############################################################################
## Name:        ext/stc/lib/Wx/STC.pm
## Purpose:     Wx::STC
## Author:      Mattia Barbon
## Modified by:
## Created:     23/05/2002
## RCS-ID:      $Id: STC.pm 3404 2012-10-01 15:44:18Z mdootson $
## Copyright:   (c) 2002-2005 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::STC;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::load_dll( 'stc' );
Wx::wx_boot( 'Wx::STC', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::StyledTextCtrl;   @ISA = qw(Wx::Control);
package Wx::StyledTextEvent;  @ISA = qw(Wx::CommandEvent);

package Wx::Event;

use strict;

# !parser: sub { $_[0] =~ m/sub (EVT_\w+)/ }
# !package: Wx::Event

sub EVT_STC_CHANGE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_CHANGE, $_[2] ) };
sub EVT_STC_STYLENEEDED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_STYLENEEDED, $_[2] ) };
sub EVT_STC_CHARADDED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_CHARADDED, $_[2] ) };
sub EVT_STC_SAVEPOINTREACHED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_SAVEPOINTREACHED, $_[2] ) };
sub EVT_STC_SAVEPOINTLEFT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_SAVEPOINTLEFT, $_[2] ) };
sub EVT_STC_ROMODIFYATTEMPT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_ROMODIFYATTEMPT, $_[2] ) };
sub EVT_STC_KEY($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_KEY, $_[2] ) };
sub EVT_STC_DOUBLECLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_DOUBLECLICK, $_[2] ) };
sub EVT_STC_UPDATEUI($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_UPDATEUI, $_[2] ) };
sub EVT_STC_MODIFIED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_MODIFIED, $_[2] ) };
sub EVT_STC_MACRORECORD($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_MACRORECORD, $_[2] ) };
sub EVT_STC_MARGINCLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_MARGINCLICK, $_[2] ) };
sub EVT_STC_NEEDSHOWN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_NEEDSHOWN, $_[2] ) };
sub EVT_STC_POSCHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_POSCHANGED, $_[2] ) };
sub EVT_STC_PAINTED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_PAINTED, $_[2] ) };
sub EVT_STC_USERLISTSELECTION($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_USERLISTSELECTION, $_[2] ) };
sub EVT_STC_URIDROPPED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_URIDROPPED, $_[2] ) };
sub EVT_STC_DWELLSTART($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_DWELLSTART, $_[2] ) };
sub EVT_STC_DWELLEND($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_DWELLEND, $_[2] ) };
sub EVT_STC_START_DRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_START_DRAG, $_[2] ) };
sub EVT_STC_DRAG_OVER($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_DRAG_OVER, $_[2] ) };
sub EVT_STC_DO_DROP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_DO_DROP, $_[2] ) };
sub EVT_STC_ZOOM($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_ZOOM, $_[2] ) };
sub EVT_STC_HOTSPOT_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_HOTSPOT_CLICK, $_[2] ) };
sub EVT_STC_HOTSPOT_DCLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_HOTSPOT_DCLICK, $_[2] ) };
sub EVT_STC_CALLTIP_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_CALLTIP_CLICK, $_[2] ) };
sub EVT_STC_AUTOCOMP_SELECTION($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_AUTOCOMP_SELECTION, $_[2] ) };
sub EVT_STC_INDICATOR_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_INDICATOR_CLICK, $_[2] ) };
sub EVT_STC_INDICATOR_RELEASE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_INDICATOR_RELEASE, $_[2] ) };
sub EVT_STC_AUTOCOMP_CANCELLED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_AUTOCOMP_CANCELLED, $_[2] ) };
sub EVT_STC_AUTOCOMP_CHAR_DELETED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_STC_AUTOCOMP_CHAR_DELETED, $_[2] ) };

1;

# local variables:
# mode: cperl
# end:

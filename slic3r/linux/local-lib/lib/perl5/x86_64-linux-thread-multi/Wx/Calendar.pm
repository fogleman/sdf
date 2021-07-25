#############################################################################
## Name:        ext/calendar/Calendar.pm
## Purpose:     Wx::CalendarCtrl
## Author:      Mattia Barbon
## Modified by:
## Created:     05/10/2002
## RCS-ID:      $Id: Calendar.pm 3224 2012-03-18 05:19:08Z mdootson $
## Copyright:   (c) 2002, 2005-2006 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Calendar;

use Wx::DateTime;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::load_dll( 'adv' );
Wx::wx_boot( 'Wx::Calendar', $VERSION );

#
# properly setup inheritance tree
#

no strict;

package Wx::CalendarCtrl;    @ISA = qw(Wx::Control);
package Wx::DatePickerCtrl;  @ISA = qw(Wx::Control);
package Wx::TimePickerCtrl;  @ISA = qw(Wx::Control);
package Wx::DateEvent;       @ISA = qw(Wx::CommandEvent);
package Wx::CalendarEvent;   @ISA = qw(Wx::DateEvent);

package Wx::Event;

use strict;

# !parser: sub { $_[0] =~ m/sub (EVT_\w+)/ }
# !package: Wx::Event

sub EVT_CALENDAR($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_CALENDAR_DOUBLECLICKED, $_[2] ) }
sub EVT_CALENDAR_SEL_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_CALENDAR_SEL_CHANGED, $_[2] ) }
sub EVT_CALENDAR_DAY($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_CALENDAR_DAY_CHANGED, $_[2] ) }
sub EVT_CALENDAR_MONTH($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_CALENDAR_MONTH_CHANGED, $_[2] ) }
sub EVT_CALENDAR_YEAR($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_CALENDAR_YEAR_CHANGED, $_[2] ) }
sub EVT_CALENDAR_WEEKDAY_CLICKED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_CALENDAR_WEEKDAY_CLICKED, $_[2] ) }
sub EVT_DATE_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_DATE_CHANGED, $_[2] ) }
sub EVT_TIME_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_TIME_CHANGED, $_[2] ) }

1;

# local variables:
# mode: cperl
# end:

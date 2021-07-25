#############################################################################
## Name:        lib/Wx/Timer.pm
## Purpose:     Wx::Timer and Wx::TimerRunner
## Author:      Mattia Barbon
## Modified by:
## Created:     14/02/2001
## RCS-ID:      $Id: Timer.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2001-2002 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Timer;

use strict;

sub new {
  my $class = shift;

  @_ == 0                              && return Wx::Timer::newDefault( $class, );
  Wx::_match( @_, $Wx::_wehd_n, 1, 1 ) && return Wx::Timer::newEH( $class, @_ );
  Wx::_croak Wx::_ovl_error;
}

package Wx::TimerRunner;

use strict;

sub new {
  my $class = shift;
  my $this = { TIMER => shift };

  if( @_ > 0 ) { $this->{TIMER}->Start( @_ ) }

  bless $this, $class;

  $this;
}

sub DESTROY {
  my $this = shift;

  $this->{TIMER}->Stop if $this->{TIMER}->IsRunning;
}

sub Start {
  my( $this, $milliseconds, $oneshot ) = @_;

  $this->{TIMER}->Start( $milliseconds, $oneshot );
}

1;

# Local variables: #
# mode: cperl #
# End: #

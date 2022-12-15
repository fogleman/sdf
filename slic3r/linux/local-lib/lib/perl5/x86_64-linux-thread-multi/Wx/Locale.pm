#############################################################################
## Name:        lib/Wx/Locale.pm
## Purpose:     Wx::Locale
## Author:      Mattia Barbon
## Modified by:
## Created:     02/02/2001
## RCS-ID:      $Id: Locale.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2001-2002 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Locale;

use strict;

*Wx::gettext = \&Wx::GetTranslation;
*Wx::gettext_noop = sub { $_[0] };

@Wx::Locale::T::ISA = qw(Exporter);

sub import {
  my $temp = shift;

  require Exporter;

  package Wx::Locale::T;
  no strict;

  my( $from, $to, @export );
  if( @_ == 1 && $_[0] eq ':default' ) {
    @_ = ( 'gettext', 'gettext', 'gettext_noop', 'gettext_noop' )
  }

  while( @_ ) {
    $from = shift;
    $to = shift;

    *{"Wx::Locale::T::$to"} = *{"Wx::$from"};
    push @export, $to;
  }

  push @Wx::Locale::T::EXPORT_OK, @export;
  Wx::Locale::T->export_to_level( 1, $temp, @export );
}

sub new {
  shift;

  # this should be conditionally defined, but it does no harm to leave
  # like it is
  Wx::_match( @_, $Wx::_n_n, 1, 1 )       && return Wx::Locale::newShort( @_ );
  Wx::_match( @_, $Wx::_s_s_s_b_b, 1, 1 ) && return Wx::Locale::newLong( @_ );
  Wx::_croak Wx::_ovl_error;
}

1;

# Local variables: #
# mode: cperl #
# End: #

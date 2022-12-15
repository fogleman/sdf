#############################################################################
## Name:        ext/ribbon/lib/Wx/Ribbon.pm
## Purpose:     Wx::Ribbon and related classes
## Author:      Mark Dootson
## Created:     01/03/2012
## SVN-ID:      $Id: Ribbon.pm 3342 2012-09-14 14:03:27Z mdootson $
## Copyright:   (c) 2012 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################
BEGIN {
    package Wx::Ribbon;
    our $__wx_ribbon_present = Wx::_wx_optmod_ribbon();
}

package Wx::Ribbon;
use strict;

our $VERSION = '0.01';

our $__wx_ribbon_present;

if( $__wx_ribbon_present ) {
    Wx::load_dll( 'adv' );
    Wx::load_dll( 'ribbon' );
    Wx::wx_boot( 'Wx::Ribbon', $VERSION );
}

#
# properly setup inheritance tree
#

no strict;

package Wx::RibbonArtProvider;
package Wx::RibbonMSWArtProvider; @ISA = qw( Wx::RibbonArtProvider );
package Wx::RibbonAUIArtProvider; @ISA = qw( Wx::RibbonMSWArtProvider );
package Wx::RibbonDefaultArtProvider; @ISA = ( Wx::wxMSW() ) ? qw( Wx::RibbonMSWArtProvider ) : qw( Wx::RibbonAUIArtProvider ) ;

1;




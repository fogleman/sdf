#############################################################################
## Name:        ext/test/lib/Wx/PerlTest.pm
## Purpose:     Wx::PerlTest  various tests
## Author:      Mark Dootson
## Modified by:
## Created:     2012-09-28
## RCS-ID:      $Id: PerlTest.pm 3395 2012-09-29 02:01:49Z mdootson $
## Copyright:   (c) 2012 Mark Dootson
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::PerlTest;

use Wx;
use strict;

use vars qw($VERSION);

$VERSION = '0.01';

Wx::wx_boot( 'Wx::PerlTest', $VERSION );

#
# properly setup inheritance tree
#

no strict;


use strict;

1;

# Local variables: #
# mode: cperl #
# End: #

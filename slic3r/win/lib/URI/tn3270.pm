#line 1 "URI/tn3270.pm"
package URI::tn3270;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::_login';

sub default_port { 23 }

1;

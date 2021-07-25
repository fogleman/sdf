#line 1 "URI/mms.pm"
package URI::mms;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::http';

sub default_port { 1755 }

1;

#line 1 "URI/https.pm"
package URI::https;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::http';

sub default_port { 443 }

sub secure { 1 }

1;

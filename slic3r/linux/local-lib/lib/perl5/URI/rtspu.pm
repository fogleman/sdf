package URI::rtspu;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::rtsp';

sub default_port { 554 }

1;

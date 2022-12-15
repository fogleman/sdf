package URI::sips;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::sip';

sub default_port { 5061 }

sub secure { 1 }

1;

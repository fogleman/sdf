#line 1 "URI/snews.pm"
package URI::snews;  # draft-gilman-news-url-01

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::news';

sub default_port { 563 }

sub secure { 1 }

1;

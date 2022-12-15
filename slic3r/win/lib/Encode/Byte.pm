#line 1 "Encode/Byte.pm"
package Encode::Byte;
use strict;
use warnings;
use Encode;
our $VERSION = do { my @r = ( q$Revision: 2.4 $ =~ /\d+/g ); sprintf "%d." . "%02d" x $#r, @r };

use XSLoader;
XSLoader::load( __PACKAGE__, $VERSION );

1;
__END__

#line 121

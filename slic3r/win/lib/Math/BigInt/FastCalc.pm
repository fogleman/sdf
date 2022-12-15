#line 1 "Math/BigInt/FastCalc.pm"
package Math::BigInt::FastCalc;

use 5.006;
use strict;
use warnings;

use Math::BigInt::Calc 1.999801;

our @ISA = qw< Math::BigInt::Calc >;

our $VERSION = '0.5006';

##############################################################################
# global constants, flags and accessory

# announce that we are compatible with MBI v1.83 and up
sub api_version () { 2; }

# use Calc to override the methods that we do not provide in XS

require XSLoader;
XSLoader::load(__PACKAGE__, $VERSION, Math::BigInt::Calc->_base_len());

##############################################################################
##############################################################################

1;

__END__

#line 169

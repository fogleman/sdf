package URI::_login;

use strict;
use warnings;

use parent qw(URI::_server URI::_userpass);

our $VERSION = '1.71';
$VERSION = eval $VERSION;

# Generic terminal logins.  This is used as a base class for 'telnet',
# 'tn3270', and 'rlogin' URL schemes.

1;

#line 1 "mro.pm"
#      mro.pm
#
#      Copyright (c) 2007 Brandon L Black
#      Copyright (c) 2008,2009 Larry Wall and others
#
#      You may distribute under the terms of either the GNU General Public
#      License or the Artistic License, as specified in the README file.
#
package mro;
use strict;
use warnings;

# mro.pm versions < 1.00 reserved for MRO::Compat
#  for partial back-compat to 5.[68].x
our $VERSION = '1.18';

sub import {
    mro::set_mro(scalar(caller), $_[1]) if $_[1];
}

package # hide me from PAUSE
    next;

sub can { mro::_nextcan($_[0], 0) }

sub method {
    my $method = mro::_nextcan($_[0], 1);
    goto &$method;
}

package # hide me from PAUSE
    maybe::next;

sub method {
    my $method = mro::_nextcan($_[0], 0);
    goto &$method if defined $method;
    return;
}

require XSLoader;
XSLoader::load('mro');

1;

__END__

#line 354

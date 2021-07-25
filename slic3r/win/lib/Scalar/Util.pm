#line 1 "Scalar/Util.pm"
# Copyright (c) 1997-2007 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.
#
# Maintained since 2013 by Paul Evans <leonerd@leonerd.org.uk>

package Scalar::Util;

use strict;
use warnings;
require Exporter;

our @ISA       = qw(Exporter);
our @EXPORT_OK = qw(
  blessed refaddr reftype weaken unweaken isweak

  dualvar isdual isvstring looks_like_number openhandle readonly set_prototype
  tainted
);
our $VERSION    = "1.47";
$VERSION   = eval $VERSION;

require List::Util; # List::Util loads the XS
List::Util->VERSION( $VERSION ); # Ensure we got the right XS version (RT#100863)

our @EXPORT_FAIL;

unless (defined &weaken) {
  push @EXPORT_FAIL, qw(weaken);
}
unless (defined &isweak) {
  push @EXPORT_FAIL, qw(isweak isvstring);
}
unless (defined &isvstring) {
  push @EXPORT_FAIL, qw(isvstring);
}

sub export_fail {
  if (grep { /^(?:weaken|isweak)$/ } @_ ) {
    require Carp;
    Carp::croak("Weak references are not implemented in the version of perl");
  }

  if (grep { /^isvstring$/ } @_ ) {
    require Carp;
    Carp::croak("Vstrings are not implemented in the version of perl");
  }

  @_;
}

# set_prototype has been moved to Sub::Util with a different interface
sub set_prototype(&$)
{
  my ( $code, $proto ) = @_;
  return Sub::Util::set_prototype( $proto, $code );
}

1;

__END__

#line 84

#line 361

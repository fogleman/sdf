#line 1 "Moo/_strictures.pm"
package Moo::_strictures;
use strict;
use warnings;

sub import {
  if ($ENV{MOO_FATAL_WARNINGS}) {
    require strictures;
    strictures->VERSION(2);
    @_ = ('strictures');
    goto &strictures::import;
  }
  else {
    strict->import;
    warnings->import;
    warnings->unimport('once');
  }
}

1;

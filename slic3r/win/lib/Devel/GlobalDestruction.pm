#line 1 "Devel/GlobalDestruction.pm"
package Devel::GlobalDestruction;

use strict;
use warnings;

our $VERSION = '0.14';

use Sub::Exporter::Progressive -setup => {
  exports => [ qw(in_global_destruction) ],
  groups  => { default => [ -all ] },
};

# we run 5.14+ - everything is in core
#
if (defined ${^GLOBAL_PHASE}) {
  eval 'sub in_global_destruction () { ${^GLOBAL_PHASE} eq q[DESTRUCT] }; 1'
    or die $@;
}
# try to load the xs version if it was compiled
#
elsif (eval {
  require Devel::GlobalDestruction::XS;
  no warnings 'once';
  *in_global_destruction = \&Devel::GlobalDestruction::XS::in_global_destruction;
  1;
}) {
  # the eval already installed everything, nothing to do
}
else {
  # internally, PL_main_cv is set to Nullcv immediately before entering
  # global destruction and we can use B to detect that.  B::main_cv will
  # only ever be a B::CV or a B::SPECIAL that is a reference to 0
  require B;
  eval 'sub in_global_destruction () { ${B::main_cv()} == 0 }; 1'
    or die $@;
}

1;  # keep require happy


__END__

#line 111

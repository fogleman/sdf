package Wx::build::MakeMaker::Hacks;

use strict;
use base 'Exporter';
use vars '@EXPORT_OK';

@EXPORT_OK = qw(hijack);

sub _find_name($$) {
  my( $package, $method ) = @_;

  no strict 'refs';
  return $package if defined &{"${package}::${method}"};
  my @isa = @{$package . '::ISA'};
  use strict 'refs';

  foreach my $i ( @isa ) {
    my $p = &_find_name( $i, $method );
    return $p if $p;
  }

  return;
}

sub hijack($$$) {
  my( $obj, $method, $replace ) = @_;
  my $spackage = ref( $obj ) || $obj;
  my $rpackage = _find_name( $spackage, $method );

  die "Can't hijack method '$method' from package '$spackage'",
    unless $rpackage;

  my $fqn = "${rpackage}::$method";
  no strict 'refs';
  my $save = \&{$fqn};
  undef *{$fqn};
  *{$fqn} = $replace;

  return $save;
}

1;

# local variables:
# mode: cperl
# end:

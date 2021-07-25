#line 1 "Math/Trig.pm"
#
# Trigonometric functions, mostly inherited from Math::Complex.
# -- Jarkko Hietaniemi, since April 1997
# -- Raphael Manfredi, September 1996 (indirectly: because of Math::Complex)
#

package Math::Trig;

{ use 5.006; }
use strict;

use Math::Complex 1.59;
use Math::Complex qw(:trig :pi);
require Exporter;

our @ISA = qw(Exporter);

our $VERSION = 1.23;

my @angcnv = qw(rad2deg rad2grad
		deg2rad deg2grad
		grad2rad grad2deg);

my @areal = qw(asin_real acos_real);

our @EXPORT = (@{$Math::Complex::EXPORT_TAGS{'trig'}},
	   @angcnv, @areal);

my @rdlcnv = qw(cartesian_to_cylindrical
		cartesian_to_spherical
		cylindrical_to_cartesian
		cylindrical_to_spherical
		spherical_to_cartesian
		spherical_to_cylindrical);

my @greatcircle = qw(
		     great_circle_distance
		     great_circle_direction
		     great_circle_bearing
		     great_circle_waypoint
		     great_circle_midpoint
		     great_circle_destination
		    );

my @pi = qw(pi pi2 pi4 pip2 pip4);

our @EXPORT_OK = (@rdlcnv, @greatcircle, @pi, 'Inf');

# See e.g. the following pages:
# http://www.movable-type.co.uk/scripts/LatLong.html
# http://williams.best.vwh.net/avform.htm

our %EXPORT_TAGS = ('radial' => [ @rdlcnv ],
	        'great_circle' => [ @greatcircle ],
	        'pi'     => [ @pi ]);

sub _DR  () { pi2/360 }
sub _RD  () { 360/pi2 }
sub _DG  () { 400/360 }
sub _GD  () { 360/400 }
sub _RG  () { 400/pi2 }
sub _GR  () { pi2/400 }

#
# Truncating remainder.
#

sub _remt ($$) {
    # Oh yes, POSIX::fmod() would be faster. Possibly. If it is available.
    $_[0] - $_[1] * int($_[0] / $_[1]);
}

#
# Angle conversions.
#

sub rad2rad($)     { _remt($_[0], pi2) }

sub deg2deg($)     { _remt($_[0], 360) }

sub grad2grad($)   { _remt($_[0], 400) }

sub rad2deg ($;$)  { my $d = _RD * $_[0]; $_[1] ? $d : deg2deg($d) }

sub deg2rad ($;$)  { my $d = _DR * $_[0]; $_[1] ? $d : rad2rad($d) }

sub grad2deg ($;$) { my $d = _GD * $_[0]; $_[1] ? $d : deg2deg($d) }

sub deg2grad ($;$) { my $d = _DG * $_[0]; $_[1] ? $d : grad2grad($d) }

sub rad2grad ($;$) { my $d = _RG * $_[0]; $_[1] ? $d : grad2grad($d) }

sub grad2rad ($;$) { my $d = _GR * $_[0]; $_[1] ? $d : rad2rad($d) }

#
# acos and asin functions which always return a real number
#

sub acos_real {
    return 0  if $_[0] >=  1;
    return pi if $_[0] <= -1;
    return acos($_[0]);
}

sub asin_real {
    return  &pip2 if $_[0] >=  1;
    return -&pip2 if $_[0] <= -1;
    return asin($_[0]);
}

sub cartesian_to_spherical {
    my ( $x, $y, $z ) = @_;

    my $rho = sqrt( $x * $x + $y * $y + $z * $z );

    return ( $rho,
             atan2( $y, $x ),
             $rho ? acos_real( $z / $rho ) : 0 );
}

sub spherical_to_cartesian {
    my ( $rho, $theta, $phi ) = @_;

    return ( $rho * cos( $theta ) * sin( $phi ),
             $rho * sin( $theta ) * sin( $phi ),
             $rho * cos( $phi   ) );
}

sub spherical_to_cylindrical {
    my ( $x, $y, $z ) = spherical_to_cartesian( @_ );

    return ( sqrt( $x * $x + $y * $y ), $_[1], $z );
}

sub cartesian_to_cylindrical {
    my ( $x, $y, $z ) = @_;

    return ( sqrt( $x * $x + $y * $y ), atan2( $y, $x ), $z );
}

sub cylindrical_to_cartesian {
    my ( $rho, $theta, $z ) = @_;

    return ( $rho * cos( $theta ), $rho * sin( $theta ), $z );
}

sub cylindrical_to_spherical {
    return ( cartesian_to_spherical( cylindrical_to_cartesian( @_ ) ) );
}

sub great_circle_distance {
    my ( $theta0, $phi0, $theta1, $phi1, $rho ) = @_;

    $rho = 1 unless defined $rho; # Default to the unit sphere.

    my $lat0 = pip2 - $phi0;
    my $lat1 = pip2 - $phi1;

    return $rho *
	acos_real( cos( $lat0 ) * cos( $lat1 ) * cos( $theta0 - $theta1 ) +
		   sin( $lat0 ) * sin( $lat1 ) );
}

sub great_circle_direction {
    my ( $theta0, $phi0, $theta1, $phi1 ) = @_;

    my $lat0 = pip2 - $phi0;
    my $lat1 = pip2 - $phi1;

    return rad2rad(pi2 -
	atan2(sin($theta0-$theta1) * cos($lat1),
		cos($lat0) * sin($lat1) -
		    sin($lat0) * cos($lat1) * cos($theta0-$theta1)));
}

*great_circle_bearing         = \&great_circle_direction;

sub great_circle_waypoint {
    my ( $theta0, $phi0, $theta1, $phi1, $point ) = @_;

    $point = 0.5 unless defined $point;

    my $d = great_circle_distance( $theta0, $phi0, $theta1, $phi1 );

    return undef if $d == pi;

    my $sd = sin($d);

    return ($theta0, $phi0) if $sd == 0;

    my $A = sin((1 - $point) * $d) / $sd;
    my $B = sin(     $point  * $d) / $sd;

    my $lat0 = pip2 - $phi0;
    my $lat1 = pip2 - $phi1;

    my $x = $A * cos($lat0) * cos($theta0) + $B * cos($lat1) * cos($theta1);
    my $y = $A * cos($lat0) * sin($theta0) + $B * cos($lat1) * sin($theta1);
    my $z = $A * sin($lat0)                + $B * sin($lat1);

    my $theta = atan2($y, $x);
    my $phi   = acos_real($z);

    return ($theta, $phi);
}

sub great_circle_midpoint {
    great_circle_waypoint(@_[0..3], 0.5);
}

sub great_circle_destination {
    my ( $theta0, $phi0, $dir0, $dst ) = @_;

    my $lat0 = pip2 - $phi0;

    my $phi1   = asin_real(sin($lat0)*cos($dst) +
			   cos($lat0)*sin($dst)*cos($dir0));

    my $theta1 = $theta0 + atan2(sin($dir0)*sin($dst)*cos($lat0),
				 cos($dst)-sin($lat0)*sin($phi1));

    my $dir1 = great_circle_bearing($theta1, $phi1, $theta0, $phi0) + pi;

    $dir1 -= pi2 if $dir1 > pi2;

    return ($theta1, $phi1, $dir1);
}

1;

__END__
#line 760

# eof

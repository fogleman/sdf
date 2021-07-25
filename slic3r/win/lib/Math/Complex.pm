#line 1 "Math/Complex.pm"
#
# Complex numbers and associated mathematical functions
# -- Raphael Manfredi	Since Sep 1996
# -- Jarkko Hietaniemi	Since Mar 1997
# -- Daniel S. Lewart	Since Sep 1997
#

package Math::Complex;

{ use 5.006; }
use strict;

our $VERSION = 1.59;

use Config;

our($Inf, $ExpInf);
BEGIN {
    my %DBL_MAX =
	(
	  4  => '1.70141183460469229e+38',
	  8  => '1.7976931348623157e+308',
	 # AFAICT the 10, 12, and 16-byte long doubles
	 # all have the same maximum.
	 10 => '1.1897314953572317650857593266280070162E+4932',
	 12 => '1.1897314953572317650857593266280070162E+4932',
	 16 => '1.1897314953572317650857593266280070162E+4932',
	);
    my $nvsize = $Config{nvsize} ||
	        ($Config{uselongdouble} && $Config{longdblsize}) ||
                 $Config{doublesize};
    die "Math::Complex: Could not figure out nvsize\n"
	unless defined $nvsize;
    die "Math::Complex: Cannot not figure out max nv (nvsize = $nvsize)\n"
	unless defined $DBL_MAX{$nvsize};
    my $DBL_MAX = eval $DBL_MAX{$nvsize};
    die "Math::Complex: Could not figure out max nv (nvsize = $nvsize)\n"
	unless defined $DBL_MAX;
    my $BIGGER_THAN_THIS = 1e30;  # Must find something bigger than this.
    if ($^O eq 'unicosmk') {
	$Inf = $DBL_MAX;
    } else {
	local $SIG{FPE} = { };
        local $!;
	# We do want an arithmetic overflow, Inf INF inf Infinity.
	for my $t (
	    'exp(99999)',  # Enough even with 128-bit long doubles.
	    'inf',
	    'Inf',
	    'INF',
	    'infinity',
	    'Infinity',
	    'INFINITY',
	    '1e99999',
	    ) {
	    local $^W = 0;
	    my $i = eval "$t+1.0";
	    if (defined $i && $i > $BIGGER_THAN_THIS) {
		$Inf = $i;
		last;
	    }
	}
	$Inf = $DBL_MAX unless defined $Inf;  # Oh well, close enough.
	die "Math::Complex: Could not get Infinity"
	    unless $Inf > $BIGGER_THAN_THIS;
	$ExpInf = exp(99999);
    }
    # print "# On this machine, Inf = '$Inf'\n";
}

use Scalar::Util qw(set_prototype);

use warnings;
no warnings 'syntax';  # To avoid the (_) warnings.

BEGIN {
    # For certain functions that we override, in 5.10 or better
    # we can set a smarter prototype that will handle the lexical $_
    # (also a 5.10+ feature).
    if ($] >= 5.010000) {
        set_prototype \&abs, '_';
        set_prototype \&cos, '_';
        set_prototype \&exp, '_';
        set_prototype \&log, '_';
        set_prototype \&sin, '_';
        set_prototype \&sqrt, '_';
    }
}

my $i;
my %LOGN;

# Regular expression for floating point numbers.
# These days we could use Scalar::Util::lln(), I guess.
my $gre = qr'\s*([\+\-]?(?:(?:(?:\d+(?:_\d+)*(?:\.\d*(?:_\d+)*)?|\.\d+(?:_\d+)*)(?:[eE][\+\-]?\d+(?:_\d+)*)?))|inf)'i;

require Exporter;

our @ISA = qw(Exporter);

my @trig = qw(
	      pi
	      tan
	      csc cosec sec cot cotan
	      asin acos atan
	      acsc acosec asec acot acotan
	      sinh cosh tanh
	      csch cosech sech coth cotanh
	      asinh acosh atanh
	      acsch acosech asech acoth acotanh
	     );

our @EXPORT = (qw(
	     i Re Im rho theta arg
	     sqrt log ln
	     log10 logn cbrt root
	     cplx cplxe
	     atan2
	     ),
	   @trig);

my @pi = qw(pi pi2 pi4 pip2 pip4 Inf);

our @EXPORT_OK = @pi;

our %EXPORT_TAGS = (
    'trig' => [@trig],
    'pi' => [@pi],
);

use overload
	'='	=> \&_copy,
	'+='	=> \&_plus,
	'+'	=> \&_plus,
	'-='	=> \&_minus,
	'-'	=> \&_minus,
	'*='	=> \&_multiply,
	'*'	=> \&_multiply,
	'/='	=> \&_divide,
	'/'	=> \&_divide,
	'**='	=> \&_power,
	'**'	=> \&_power,
	'=='	=> \&_numeq,
	'<=>'	=> \&_spaceship,
	'neg'	=> \&_negate,
	'~'	=> \&_conjugate,
	'abs'	=> \&abs,
	'sqrt'	=> \&sqrt,
	'exp'	=> \&exp,
	'log'	=> \&log,
	'sin'	=> \&sin,
	'cos'	=> \&cos,
	'atan2'	=> \&atan2,
        '""'    => \&_stringify;

#
# Package "privates"
#

my %DISPLAY_FORMAT = ('style' => 'cartesian',
		      'polar_pretty_print' => 1);
my $eps            = 1e-14;		# Epsilon

#
# Object attributes (internal):
#	cartesian	[real, imaginary] -- cartesian form
#	polar		[rho, theta] -- polar form
#	c_dirty		cartesian form not up-to-date
#	p_dirty		polar form not up-to-date
#	display		display format (package's global when not set)
#

# Die on bad *make() arguments.

sub _cannot_make {
    die "@{[(caller(1))[3]]}: Cannot take $_[0] of '$_[1]'.\n";
}

sub _make {
    my $arg = shift;
    my ($p, $q);

    if ($arg =~ /^$gre$/) {
	($p, $q) = ($1, 0);
    } elsif ($arg =~ /^(?:$gre)?$gre\s*i\s*$/) {
	($p, $q) = ($1 || 0, $2);
    } elsif ($arg =~ /^\s*\(\s*$gre\s*(?:,\s*$gre\s*)?\)\s*$/) {
	($p, $q) = ($1, $2 || 0);
    }

    if (defined $p) {
	$p =~ s/^\+//;
	$p =~ s/^(-?)inf$/"${1}9**9**9"/e;
	$q =~ s/^\+//;
	$q =~ s/^(-?)inf$/"${1}9**9**9"/e;
    }

    return ($p, $q);
}

sub _emake {
    my $arg = shift;
    my ($p, $q);

    if ($arg =~ /^\s*\[\s*$gre\s*(?:,\s*$gre\s*)?\]\s*$/) {
	($p, $q) = ($1, $2 || 0);
    } elsif ($arg =~ m!^\s*\[\s*$gre\s*(?:,\s*([-+]?\d*\s*)?pi(?:/\s*(\d+))?\s*)?\]\s*$!) {
	($p, $q) = ($1, ($2 eq '-' ? -1 : ($2 || 1)) * pi() / ($3 || 1));
    } elsif ($arg =~ /^\s*\[\s*$gre\s*\]\s*$/) {
	($p, $q) = ($1, 0);
    } elsif ($arg =~ /^\s*$gre\s*$/) {
	($p, $q) = ($1, 0);
    }

    if (defined $p) {
	$p =~ s/^\+//;
	$q =~ s/^\+//;
	$p =~ s/^(-?)inf$/"${1}9**9**9"/e;
	$q =~ s/^(-?)inf$/"${1}9**9**9"/e;
    }

    return ($p, $q);
}

sub _copy {
    my $self = shift;
    my $clone = {%$self};
    if ($self->{'cartesian'}) {
	$clone->{'cartesian'} = [@{$self->{'cartesian'}}];
    }
    if ($self->{'polar'}) {
	$clone->{'polar'} = [@{$self->{'polar'}}];
    }
    bless $clone,__PACKAGE__;
    return $clone;
}

#
# ->make
#
# Create a new complex number (cartesian form)
#
sub make {
    my $self = bless {}, shift;
    my ($re, $im);
    if (@_ == 0) {
	($re, $im) = (0, 0);
    } elsif (@_ == 1) {
	return (ref $self)->emake($_[0])
	    if ($_[0] =~ /^\s*\[/);
	($re, $im) = _make($_[0]);
    } elsif (@_ == 2) {
	($re, $im) = @_;
    }
    if (defined $re) {
	_cannot_make("real part",      $re) unless $re =~ /^$gre$/;
    }
    $im ||= 0;
    _cannot_make("imaginary part", $im) unless $im =~ /^$gre$/;
    $self->_set_cartesian([$re, $im ]);
    $self->display_format('cartesian');

    return $self;
}

#
# ->emake
#
# Create a new complex number (exponential form)
#
sub emake {
    my $self = bless {}, shift;
    my ($rho, $theta);
    if (@_ == 0) {
	($rho, $theta) = (0, 0);
    } elsif (@_ == 1) {
	return (ref $self)->make($_[0])
	    if ($_[0] =~ /^\s*\(/ || $_[0] =~ /i\s*$/);
	($rho, $theta) = _emake($_[0]);
    } elsif (@_ == 2) {
	($rho, $theta) = @_;
    }
    if (defined $rho && defined $theta) {
	if ($rho < 0) {
	    $rho   = -$rho;
	    $theta = ($theta <= 0) ? $theta + pi() : $theta - pi();
	}
    }
    if (defined $rho) {
	_cannot_make("rho",   $rho)   unless $rho   =~ /^$gre$/;
    }
    $theta ||= 0;
    _cannot_make("theta", $theta) unless $theta =~ /^$gre$/;
    $self->_set_polar([$rho, $theta]);
    $self->display_format('polar');

    return $self;
}

sub new { &make }		# For backward compatibility only.

#
# cplx
#
# Creates a complex number from a (re, im) tuple.
# This avoids the burden of writing Math::Complex->make(re, im).
#
sub cplx {
	return __PACKAGE__->make(@_);
}

#
# cplxe
#
# Creates a complex number from a (rho, theta) tuple.
# This avoids the burden of writing Math::Complex->emake(rho, theta).
#
sub cplxe {
	return __PACKAGE__->emake(@_);
}

#
# pi
#
# The number defined as pi = 180 degrees
#
sub pi () { 4 * CORE::atan2(1, 1) }

#
# pi2
#
# The full circle
#
sub pi2 () { 2 * pi }

#
# pi4
#
# The full circle twice.
#
sub pi4 () { 4 * pi }

#
# pip2
#
# The quarter circle
#
sub pip2 () { pi / 2 }

#
# pip4
#
# The eighth circle.
#
sub pip4 () { pi / 4 }

#
# _uplog10
#
# Used in log10().
#
sub _uplog10 () { 1 / CORE::log(10) }

#
# i
#
# The number defined as i*i = -1;
#
sub i () {
        return $i if ($i);
	$i = bless {};
	$i->{'cartesian'} = [0, 1];
	$i->{'polar'}     = [1, pip2];
	$i->{c_dirty} = 0;
	$i->{p_dirty} = 0;
	return $i;
}

#
# _ip2
#
# Half of i.
#
sub _ip2 () { i / 2 }

#
# Attribute access/set routines
#

sub _cartesian {$_[0]->{c_dirty} ?
		   $_[0]->_update_cartesian : $_[0]->{'cartesian'}}
sub _polar     {$_[0]->{p_dirty} ?
		   $_[0]->_update_polar : $_[0]->{'polar'}}

sub _set_cartesian { $_[0]->{p_dirty}++; $_[0]->{c_dirty} = 0;
		     $_[0]->{'cartesian'} = $_[1] }
sub _set_polar     { $_[0]->{c_dirty}++; $_[0]->{p_dirty} = 0;
		     $_[0]->{'polar'} = $_[1] }

#
# ->_update_cartesian
#
# Recompute and return the cartesian form, given accurate polar form.
#
sub _update_cartesian {
	my $self = shift;
	my ($r, $t) = @{$self->{'polar'}};
	$self->{c_dirty} = 0;
	return $self->{'cartesian'} = [$r * CORE::cos($t), $r * CORE::sin($t)];
}

#
#
# ->_update_polar
#
# Recompute and return the polar form, given accurate cartesian form.
#
sub _update_polar {
	my $self = shift;
	my ($x, $y) = @{$self->{'cartesian'}};
	$self->{p_dirty} = 0;
	return $self->{'polar'} = [0, 0] if $x == 0 && $y == 0;
	return $self->{'polar'} = [CORE::sqrt($x*$x + $y*$y),
				   CORE::atan2($y, $x)];
}

#
# (_plus)
#
# Computes z1+z2.
#
sub _plus {
	my ($z1, $z2, $regular) = @_;
	my ($re1, $im1) = @{$z1->_cartesian};
	$z2 = cplx($z2) unless ref $z2;
	my ($re2, $im2) = ref $z2 ? @{$z2->_cartesian} : ($z2, 0);
	unless (defined $regular) {
		$z1->_set_cartesian([$re1 + $re2, $im1 + $im2]);
		return $z1;
	}
	return (ref $z1)->make($re1 + $re2, $im1 + $im2);
}

#
# (_minus)
#
# Computes z1-z2.
#
sub _minus {
	my ($z1, $z2, $inverted) = @_;
	my ($re1, $im1) = @{$z1->_cartesian};
	$z2 = cplx($z2) unless ref $z2;
	my ($re2, $im2) = @{$z2->_cartesian};
	unless (defined $inverted) {
		$z1->_set_cartesian([$re1 - $re2, $im1 - $im2]);
		return $z1;
	}
	return $inverted ?
		(ref $z1)->make($re2 - $re1, $im2 - $im1) :
		(ref $z1)->make($re1 - $re2, $im1 - $im2);

}

#
# (_multiply)
#
# Computes z1*z2.
#
sub _multiply {
        my ($z1, $z2, $regular) = @_;
	if ($z1->{p_dirty} == 0 and ref $z2 and $z2->{p_dirty} == 0) {
	    # if both polar better use polar to avoid rounding errors
	    my ($r1, $t1) = @{$z1->_polar};
	    my ($r2, $t2) = @{$z2->_polar};
	    my $t = $t1 + $t2;
	    if    ($t >   pi()) { $t -= pi2 }
	    elsif ($t <= -pi()) { $t += pi2 }
	    unless (defined $regular) {
		$z1->_set_polar([$r1 * $r2, $t]);
		return $z1;
	    }
	    return (ref $z1)->emake($r1 * $r2, $t);
	} else {
	    my ($x1, $y1) = @{$z1->_cartesian};
	    if (ref $z2) {
		my ($x2, $y2) = @{$z2->_cartesian};
		return (ref $z1)->make($x1*$x2-$y1*$y2, $x1*$y2+$y1*$x2);
	    } else {
		return (ref $z1)->make($x1*$z2, $y1*$z2);
	    }
	}
}

#
# _divbyzero
#
# Die on division by zero.
#
sub _divbyzero {
    my $mess = "$_[0]: Division by zero.\n";

    if (defined $_[1]) {
	$mess .= "(Because in the definition of $_[0], the divisor ";
	$mess .= "$_[1] " unless ("$_[1]" eq '0');
	$mess .= "is 0)\n";
    }

    my @up = caller(1);

    $mess .= "Died at $up[1] line $up[2].\n";

    die $mess;
}

#
# (_divide)
#
# Computes z1/z2.
#
sub _divide {
	my ($z1, $z2, $inverted) = @_;
	if ($z1->{p_dirty} == 0 and ref $z2 and $z2->{p_dirty} == 0) {
	    # if both polar better use polar to avoid rounding errors
	    my ($r1, $t1) = @{$z1->_polar};
	    my ($r2, $t2) = @{$z2->_polar};
	    my $t;
	    if ($inverted) {
		_divbyzero "$z2/0" if ($r1 == 0);
		$t = $t2 - $t1;
		if    ($t >   pi()) { $t -= pi2 }
		elsif ($t <= -pi()) { $t += pi2 }
		return (ref $z1)->emake($r2 / $r1, $t);
	    } else {
		_divbyzero "$z1/0" if ($r2 == 0);
		$t = $t1 - $t2;
		if    ($t >   pi()) { $t -= pi2 }
		elsif ($t <= -pi()) { $t += pi2 }
		return (ref $z1)->emake($r1 / $r2, $t);
	    }
	} else {
	    my ($d, $x2, $y2);
	    if ($inverted) {
		($x2, $y2) = @{$z1->_cartesian};
		$d = $x2*$x2 + $y2*$y2;
		_divbyzero "$z2/0" if $d == 0;
		return (ref $z1)->make(($x2*$z2)/$d, -($y2*$z2)/$d);
	    } else {
		my ($x1, $y1) = @{$z1->_cartesian};
		if (ref $z2) {
		    ($x2, $y2) = @{$z2->_cartesian};
		    $d = $x2*$x2 + $y2*$y2;
		    _divbyzero "$z1/0" if $d == 0;
		    my $u = ($x1*$x2 + $y1*$y2)/$d;
		    my $v = ($y1*$x2 - $x1*$y2)/$d;
		    return (ref $z1)->make($u, $v);
		} else {
		    _divbyzero "$z1/0" if $z2 == 0;
		    return (ref $z1)->make($x1/$z2, $y1/$z2);
		}
	    }
	}
}

#
# (_power)
#
# Computes z1**z2 = exp(z2 * log z1)).
#
sub _power {
	my ($z1, $z2, $inverted) = @_;
	if ($inverted) {
	    return 1 if $z1 == 0 || $z2 == 1;
	    return 0 if $z2 == 0 && Re($z1) > 0;
	} else {
	    return 1 if $z2 == 0 || $z1 == 1;
	    return 0 if $z1 == 0 && Re($z2) > 0;
	}
	my $w = $inverted ? &exp($z1 * &log($z2))
	                  : &exp($z2 * &log($z1));
	# If both arguments cartesian, return cartesian, else polar.
	return $z1->{c_dirty} == 0 &&
	       (not ref $z2 or $z2->{c_dirty} == 0) ?
	       cplx(@{$w->_cartesian}) : $w;
}

#
# (_spaceship)
#
# Computes z1 <=> z2.
# Sorts on the real part first, then on the imaginary part. Thus 2-4i < 3+8i.
#
sub _spaceship {
	my ($z1, $z2, $inverted) = @_;
	my ($re1, $im1) = ref $z1 ? @{$z1->_cartesian} : ($z1, 0);
	my ($re2, $im2) = ref $z2 ? @{$z2->_cartesian} : ($z2, 0);
	my $sgn = $inverted ? -1 : 1;
	return $sgn * ($re1 <=> $re2) if $re1 != $re2;
	return $sgn * ($im1 <=> $im2);
}

#
# (_numeq)
#
# Computes z1 == z2.
#
# (Required in addition to _spaceship() because of NaNs.)
sub _numeq {
	my ($z1, $z2, $inverted) = @_;
	my ($re1, $im1) = ref $z1 ? @{$z1->_cartesian} : ($z1, 0);
	my ($re2, $im2) = ref $z2 ? @{$z2->_cartesian} : ($z2, 0);
	return $re1 == $re2 && $im1 == $im2 ? 1 : 0;
}

#
# (_negate)
#
# Computes -z.
#
sub _negate {
	my ($z) = @_;
	if ($z->{c_dirty}) {
		my ($r, $t) = @{$z->_polar};
		$t = ($t <= 0) ? $t + pi : $t - pi;
		return (ref $z)->emake($r, $t);
	}
	my ($re, $im) = @{$z->_cartesian};
	return (ref $z)->make(-$re, -$im);
}

#
# (_conjugate)
#
# Compute complex's _conjugate.
#
sub _conjugate {
	my ($z) = @_;
	if ($z->{c_dirty}) {
		my ($r, $t) = @{$z->_polar};
		return (ref $z)->emake($r, -$t);
	}
	my ($re, $im) = @{$z->_cartesian};
	return (ref $z)->make($re, -$im);
}

#
# (abs)
#
# Compute or set complex's norm (rho).
#
sub abs {
	my ($z, $rho) = @_ ? @_ : $_;
	unless (ref $z) {
	    if (@_ == 2) {
		$_[0] = $_[1];
	    } else {
		return CORE::abs($z);
	    }
	}
	if (defined $rho) {
	    $z->{'polar'} = [ $rho, ${$z->_polar}[1] ];
	    $z->{p_dirty} = 0;
	    $z->{c_dirty} = 1;
	    return $rho;
	} else {
	    return ${$z->_polar}[0];
	}
}

sub _theta {
    my $theta = $_[0];

    if    ($$theta >   pi()) { $$theta -= pi2 }
    elsif ($$theta <= -pi()) { $$theta += pi2 }
}

#
# arg
#
# Compute or set complex's argument (theta).
#
sub arg {
	my ($z, $theta) = @_;
	return $z unless ref $z;
	if (defined $theta) {
	    _theta(\$theta);
	    $z->{'polar'} = [ ${$z->_polar}[0], $theta ];
	    $z->{p_dirty} = 0;
	    $z->{c_dirty} = 1;
	} else {
	    $theta = ${$z->_polar}[1];
	    _theta(\$theta);
	}
	return $theta;
}

#
# (sqrt)
#
# Compute sqrt(z).
#
# It is quite tempting to use wantarray here so that in list context
# sqrt() would return the two solutions.  This, however, would
# break things like
#
#	print "sqrt(z) = ", sqrt($z), "\n";
#
# The two values would be printed side by side without no intervening
# whitespace, quite confusing.
# Therefore if you want the two solutions use the root().
#
sub sqrt {
	my ($z) = @_ ? $_[0] : $_;
	my ($re, $im) = ref $z ? @{$z->_cartesian} : ($z, 0);
	return $re < 0 ? cplx(0, CORE::sqrt(-$re)) : CORE::sqrt($re)
	    if $im == 0;
	my ($r, $t) = @{$z->_polar};
	return (ref $z)->emake(CORE::sqrt($r), $t/2);
}

#
# cbrt
#
# Compute cbrt(z) (cubic root).
#
# Why are we not returning three values?  The same answer as for sqrt().
#
sub cbrt {
	my ($z) = @_;
	return $z < 0 ?
	    -CORE::exp(CORE::log(-$z)/3) :
		($z > 0 ? CORE::exp(CORE::log($z)/3): 0)
	    unless ref $z;
	my ($r, $t) = @{$z->_polar};
	return 0 if $r == 0;
	return (ref $z)->emake(CORE::exp(CORE::log($r)/3), $t/3);
}

#
# _rootbad
#
# Die on bad root.
#
sub _rootbad {
    my $mess = "Root '$_[0]' illegal, root rank must be positive integer.\n";

    my @up = caller(1);

    $mess .= "Died at $up[1] line $up[2].\n";

    die $mess;
}

#
# root
#
# Computes all nth root for z, returning an array whose size is n.
# `n' must be a positive integer.
#
# The roots are given by (for k = 0..n-1):
#
# z^(1/n) = r^(1/n) (cos ((t+2 k pi)/n) + i sin ((t+2 k pi)/n))
#
sub root {
	my ($z, $n, $k) = @_;
	_rootbad($n) if ($n < 1 or int($n) != $n);
	my ($r, $t) = ref $z ?
	    @{$z->_polar} : (CORE::abs($z), $z >= 0 ? 0 : pi);
	my $theta_inc = pi2 / $n;
	my $rho = $r ** (1/$n);
	my $cartesian = ref $z && $z->{c_dirty} == 0;
	if (@_ == 2) {
	    my @root;
	    for (my $i = 0, my $theta = $t / $n;
		 $i < $n;
		 $i++, $theta += $theta_inc) {
		my $w = cplxe($rho, $theta);
		# Yes, $cartesian is loop invariant.
		push @root, $cartesian ? cplx(@{$w->_cartesian}) : $w;
	    }
	    return @root;
	} elsif (@_ == 3) {
	    my $w = cplxe($rho, $t / $n + $k * $theta_inc);
	    return $cartesian ? cplx(@{$w->_cartesian}) : $w;
	}
}

#
# Re
#
# Return or set Re(z).
#
sub Re {
	my ($z, $Re) = @_;
	return $z unless ref $z;
	if (defined $Re) {
	    $z->{'cartesian'} = [ $Re, ${$z->_cartesian}[1] ];
	    $z->{c_dirty} = 0;
	    $z->{p_dirty} = 1;
	} else {
	    return ${$z->_cartesian}[0];
	}
}

#
# Im
#
# Return or set Im(z).
#
sub Im {
	my ($z, $Im) = @_;
	return 0 unless ref $z;
	if (defined $Im) {
	    $z->{'cartesian'} = [ ${$z->_cartesian}[0], $Im ];
	    $z->{c_dirty} = 0;
	    $z->{p_dirty} = 1;
	} else {
	    return ${$z->_cartesian}[1];
	}
}

#
# rho
#
# Return or set rho(w).
#
sub rho {
    Math::Complex::abs(@_);
}

#
# theta
#
# Return or set theta(w).
#
sub theta {
    Math::Complex::arg(@_);
}

#
# (exp)
#
# Computes exp(z).
#
sub exp {
    my ($z) = @_ ? @_ : $_;
    return CORE::exp($z) unless ref $z;
    my ($x, $y) = @{$z->_cartesian};
    return (ref $z)->emake(CORE::exp($x), $y);
}

#
# _logofzero
#
# Die on logarithm of zero.
#
sub _logofzero {
    my $mess = "$_[0]: Logarithm of zero.\n";

    if (defined $_[1]) {
	$mess .= "(Because in the definition of $_[0], the argument ";
	$mess .= "$_[1] " unless ($_[1] eq '0');
	$mess .= "is 0)\n";
    }

    my @up = caller(1);

    $mess .= "Died at $up[1] line $up[2].\n";

    die $mess;
}

#
# (log)
#
# Compute log(z).
#
sub log {
	my ($z) = @_ ? @_ : $_;
	unless (ref $z) {
	    _logofzero("log") if $z == 0;
	    return $z > 0 ? CORE::log($z) : cplx(CORE::log(-$z), pi);
	}
	my ($r, $t) = @{$z->_polar};
	_logofzero("log") if $r == 0;
	if    ($t >   pi()) { $t -= pi2 }
	elsif ($t <= -pi()) { $t += pi2 }
	return (ref $z)->make(CORE::log($r), $t);
}

#
# ln
#
# Alias for log().
#
sub ln { Math::Complex::log(@_) }

#
# log10
#
# Compute log10(z).
#

sub log10 {
	return Math::Complex::log($_[0]) * _uplog10;
}

#
# logn
#
# Compute logn(z,n) = log(z) / log(n)
#
sub logn {
	my ($z, $n) = @_;
	$z = cplx($z, 0) unless ref $z;
	my $logn = $LOGN{$n};
	$logn = $LOGN{$n} = CORE::log($n) unless defined $logn;	# Cache log(n)
	return &log($z) / $logn;
}

#
# (cos)
#
# Compute cos(z) = (exp(iz) + exp(-iz))/2.
#
sub cos {
	my ($z) = @_ ? @_ : $_;
	return CORE::cos($z) unless ref $z;
	my ($x, $y) = @{$z->_cartesian};
	my $ey = CORE::exp($y);
	my $sx = CORE::sin($x);
	my $cx = CORE::cos($x);
	my $ey_1 = $ey ? 1 / $ey : Inf();
	return (ref $z)->make($cx * ($ey + $ey_1)/2,
			      $sx * ($ey_1 - $ey)/2);
}

#
# (sin)
#
# Compute sin(z) = (exp(iz) - exp(-iz))/2.
#
sub sin {
	my ($z) = @_ ? @_ : $_;
	return CORE::sin($z) unless ref $z;
	my ($x, $y) = @{$z->_cartesian};
	my $ey = CORE::exp($y);
	my $sx = CORE::sin($x);
	my $cx = CORE::cos($x);
	my $ey_1 = $ey ? 1 / $ey : Inf();
	return (ref $z)->make($sx * ($ey + $ey_1)/2,
			      $cx * ($ey - $ey_1)/2);
}

#
# tan
#
# Compute tan(z) = sin(z) / cos(z).
#
sub tan {
	my ($z) = @_;
	my $cz = &cos($z);
	_divbyzero "tan($z)", "cos($z)" if $cz == 0;
	return &sin($z) / $cz;
}

#
# sec
#
# Computes the secant sec(z) = 1 / cos(z).
#
sub sec {
	my ($z) = @_;
	my $cz = &cos($z);
	_divbyzero "sec($z)", "cos($z)" if ($cz == 0);
	return 1 / $cz;
}

#
# csc
#
# Computes the cosecant csc(z) = 1 / sin(z).
#
sub csc {
	my ($z) = @_;
	my $sz = &sin($z);
	_divbyzero "csc($z)", "sin($z)" if ($sz == 0);
	return 1 / $sz;
}

#
# cosec
#
# Alias for csc().
#
sub cosec { Math::Complex::csc(@_) }

#
# cot
#
# Computes cot(z) = cos(z) / sin(z).
#
sub cot {
	my ($z) = @_;
	my $sz = &sin($z);
	_divbyzero "cot($z)", "sin($z)" if ($sz == 0);
	return &cos($z) / $sz;
}

#
# cotan
#
# Alias for cot().
#
sub cotan { Math::Complex::cot(@_) }

#
# acos
#
# Computes the arc cosine acos(z) = -i log(z + sqrt(z*z-1)).
#
sub acos {
	my $z = $_[0];
	return CORE::atan2(CORE::sqrt(1-$z*$z), $z)
	    if (! ref $z) && CORE::abs($z) <= 1;
	$z = cplx($z, 0) unless ref $z;
	my ($x, $y) = @{$z->_cartesian};
	return 0 if $x == 1 && $y == 0;
	my $t1 = CORE::sqrt(($x+1)*($x+1) + $y*$y);
	my $t2 = CORE::sqrt(($x-1)*($x-1) + $y*$y);
	my $alpha = ($t1 + $t2)/2;
	my $beta  = ($t1 - $t2)/2;
	$alpha = 1 if $alpha < 1;
	if    ($beta >  1) { $beta =  1 }
	elsif ($beta < -1) { $beta = -1 }
	my $u = CORE::atan2(CORE::sqrt(1-$beta*$beta), $beta);
	my $v = CORE::log($alpha + CORE::sqrt($alpha*$alpha-1));
	$v = -$v if $y > 0 || ($y == 0 && $x < -1);
	return (ref $z)->make($u, $v);
}

#
# asin
#
# Computes the arc sine asin(z) = -i log(iz + sqrt(1-z*z)).
#
sub asin {
	my $z = $_[0];
	return CORE::atan2($z, CORE::sqrt(1-$z*$z))
	    if (! ref $z) && CORE::abs($z) <= 1;
	$z = cplx($z, 0) unless ref $z;
	my ($x, $y) = @{$z->_cartesian};
	return 0 if $x == 0 && $y == 0;
	my $t1 = CORE::sqrt(($x+1)*($x+1) + $y*$y);
	my $t2 = CORE::sqrt(($x-1)*($x-1) + $y*$y);
	my $alpha = ($t1 + $t2)/2;
	my $beta  = ($t1 - $t2)/2;
	$alpha = 1 if $alpha < 1;
	if    ($beta >  1) { $beta =  1 }
	elsif ($beta < -1) { $beta = -1 }
	my $u =  CORE::atan2($beta, CORE::sqrt(1-$beta*$beta));
	my $v = -CORE::log($alpha + CORE::sqrt($alpha*$alpha-1));
	$v = -$v if $y > 0 || ($y == 0 && $x < -1);
	return (ref $z)->make($u, $v);
}

#
# atan
#
# Computes the arc tangent atan(z) = i/2 log((i+z) / (i-z)).
#
sub atan {
	my ($z) = @_;
	return CORE::atan2($z, 1) unless ref $z;
	my ($x, $y) = ref $z ? @{$z->_cartesian} : ($z, 0);
	return 0 if $x == 0 && $y == 0;
	_divbyzero "atan(i)"  if ( $z == i);
	_logofzero "atan(-i)" if (-$z == i); # -i is a bad file test...
	my $log = &log((i + $z) / (i - $z));
	return _ip2 * $log;
}

#
# asec
#
# Computes the arc secant asec(z) = acos(1 / z).
#
sub asec {
	my ($z) = @_;
	_divbyzero "asec($z)", $z if ($z == 0);
	return acos(1 / $z);
}

#
# acsc
#
# Computes the arc cosecant acsc(z) = asin(1 / z).
#
sub acsc {
	my ($z) = @_;
	_divbyzero "acsc($z)", $z if ($z == 0);
	return asin(1 / $z);
}

#
# acosec
#
# Alias for acsc().
#
sub acosec { Math::Complex::acsc(@_) }

#
# acot
#
# Computes the arc cotangent acot(z) = atan(1 / z)
#
sub acot {
	my ($z) = @_;
	_divbyzero "acot(0)"  if $z == 0;
	return ($z >= 0) ? CORE::atan2(1, $z) : CORE::atan2(-1, -$z)
	    unless ref $z;
	_divbyzero "acot(i)"  if ($z - i == 0);
	_logofzero "acot(-i)" if ($z + i == 0);
	return atan(1 / $z);
}

#
# acotan
#
# Alias for acot().
#
sub acotan { Math::Complex::acot(@_) }

#
# cosh
#
# Computes the hyperbolic cosine cosh(z) = (exp(z) + exp(-z))/2.
#
sub cosh {
	my ($z) = @_;
	my $ex;
	unless (ref $z) {
	    $ex = CORE::exp($z);
            return $ex ? ($ex == $ExpInf ? Inf() : ($ex + 1/$ex)/2) : Inf();
	}
	my ($x, $y) = @{$z->_cartesian};
	$ex = CORE::exp($x);
	my $ex_1 = $ex ? 1 / $ex : Inf();
	return (ref $z)->make(CORE::cos($y) * ($ex + $ex_1)/2,
			      CORE::sin($y) * ($ex - $ex_1)/2);
}

#
# sinh
#
# Computes the hyperbolic sine sinh(z) = (exp(z) - exp(-z))/2.
#
sub sinh {
	my ($z) = @_;
	my $ex;
	unless (ref $z) {
	    return 0 if $z == 0;
	    $ex = CORE::exp($z);
            return $ex ? ($ex == $ExpInf ? Inf() : ($ex - 1/$ex)/2) : -Inf();
	}
	my ($x, $y) = @{$z->_cartesian};
	my $cy = CORE::cos($y);
	my $sy = CORE::sin($y);
	$ex = CORE::exp($x);
	my $ex_1 = $ex ? 1 / $ex : Inf();
	return (ref $z)->make(CORE::cos($y) * ($ex - $ex_1)/2,
			      CORE::sin($y) * ($ex + $ex_1)/2);
}

#
# tanh
#
# Computes the hyperbolic tangent tanh(z) = sinh(z) / cosh(z).
#
sub tanh {
	my ($z) = @_;
	my $cz = cosh($z);
	_divbyzero "tanh($z)", "cosh($z)" if ($cz == 0);
	my $sz = sinh($z);
	return  1 if $cz ==  $sz;
	return -1 if $cz == -$sz;
	return $sz / $cz;
}

#
# sech
#
# Computes the hyperbolic secant sech(z) = 1 / cosh(z).
#
sub sech {
	my ($z) = @_;
	my $cz = cosh($z);
	_divbyzero "sech($z)", "cosh($z)" if ($cz == 0);
	return 1 / $cz;
}

#
# csch
#
# Computes the hyperbolic cosecant csch(z) = 1 / sinh(z).
#
sub csch {
	my ($z) = @_;
	my $sz = sinh($z);
	_divbyzero "csch($z)", "sinh($z)" if ($sz == 0);
	return 1 / $sz;
}

#
# cosech
#
# Alias for csch().
#
sub cosech { Math::Complex::csch(@_) }

#
# coth
#
# Computes the hyperbolic cotangent coth(z) = cosh(z) / sinh(z).
#
sub coth {
	my ($z) = @_;
	my $sz = sinh($z);
	_divbyzero "coth($z)", "sinh($z)" if $sz == 0;
	my $cz = cosh($z);
	return  1 if $cz ==  $sz;
	return -1 if $cz == -$sz;
	return $cz / $sz;
}

#
# cotanh
#
# Alias for coth().
#
sub cotanh { Math::Complex::coth(@_) }

#
# acosh
#
# Computes the area/inverse hyperbolic cosine acosh(z) = log(z + sqrt(z*z-1)).
#
sub acosh {
	my ($z) = @_;
	unless (ref $z) {
	    $z = cplx($z, 0);
	}
	my ($re, $im) = @{$z->_cartesian};
	if ($im == 0) {
	    return CORE::log($re + CORE::sqrt($re*$re - 1))
		if $re >= 1;
	    return cplx(0, CORE::atan2(CORE::sqrt(1 - $re*$re), $re))
		if CORE::abs($re) < 1;
	}
	my $t = &sqrt($z * $z - 1) + $z;
	# Try Taylor if looking bad (this usually means that
	# $z was large negative, therefore the sqrt is really
	# close to abs(z), summing that with z...)
	$t = 1/(2 * $z) - 1/(8 * $z**3) + 1/(16 * $z**5) - 5/(128 * $z**7)
	    if $t == 0;
	my $u = &log($t);
	$u->Im(-$u->Im) if $re < 0 && $im == 0;
	return $re < 0 ? -$u : $u;
}

#
# asinh
#
# Computes the area/inverse hyperbolic sine asinh(z) = log(z + sqrt(z*z+1))
#
sub asinh {
	my ($z) = @_;
	unless (ref $z) {
	    my $t = $z + CORE::sqrt($z*$z + 1);
	    return CORE::log($t) if $t;
	}
	my $t = &sqrt($z * $z + 1) + $z;
	# Try Taylor if looking bad (this usually means that
	# $z was large negative, therefore the sqrt is really
	# close to abs(z), summing that with z...)
	$t = 1/(2 * $z) - 1/(8 * $z**3) + 1/(16 * $z**5) - 5/(128 * $z**7)
	    if $t == 0;
	return &log($t);
}

#
# atanh
#
# Computes the area/inverse hyperbolic tangent atanh(z) = 1/2 log((1+z) / (1-z)).
#
sub atanh {
	my ($z) = @_;
	unless (ref $z) {
	    return CORE::log((1 + $z)/(1 - $z))/2 if CORE::abs($z) < 1;
	    $z = cplx($z, 0);
	}
	_divbyzero 'atanh(1)',  "1 - $z" if (1 - $z == 0);
	_logofzero 'atanh(-1)'           if (1 + $z == 0);
	return 0.5 * &log((1 + $z) / (1 - $z));
}

#
# asech
#
# Computes the area/inverse hyperbolic secant asech(z) = acosh(1 / z).
#
sub asech {
	my ($z) = @_;
	_divbyzero 'asech(0)', "$z" if ($z == 0);
	return acosh(1 / $z);
}

#
# acsch
#
# Computes the area/inverse hyperbolic cosecant acsch(z) = asinh(1 / z).
#
sub acsch {
	my ($z) = @_;
	_divbyzero 'acsch(0)', $z if ($z == 0);
	return asinh(1 / $z);
}

#
# acosech
#
# Alias for acosh().
#
sub acosech { Math::Complex::acsch(@_) }

#
# acoth
#
# Computes the area/inverse hyperbolic cotangent acoth(z) = 1/2 log((1+z) / (z-1)).
#
sub acoth {
	my ($z) = @_;
	_divbyzero 'acoth(0)'            if ($z == 0);
	unless (ref $z) {
	    return CORE::log(($z + 1)/($z - 1))/2 if CORE::abs($z) > 1;
	    $z = cplx($z, 0);
	}
	_divbyzero 'acoth(1)',  "$z - 1" if ($z - 1 == 0);
	_logofzero 'acoth(-1)', "1 + $z" if (1 + $z == 0);
	return &log((1 + $z) / ($z - 1)) / 2;
}

#
# acotanh
#
# Alias for acot().
#
sub acotanh { Math::Complex::acoth(@_) }

#
# (atan2)
#
# Compute atan(z1/z2), minding the right quadrant.
#
sub atan2 {
	my ($z1, $z2, $inverted) = @_;
	my ($re1, $im1, $re2, $im2);
	if ($inverted) {
	    ($re1, $im1) = ref $z2 ? @{$z2->_cartesian} : ($z2, 0);
	    ($re2, $im2) = ref $z1 ? @{$z1->_cartesian} : ($z1, 0);
	} else {
	    ($re1, $im1) = ref $z1 ? @{$z1->_cartesian} : ($z1, 0);
	    ($re2, $im2) = ref $z2 ? @{$z2->_cartesian} : ($z2, 0);
	}
	if ($im1 || $im2) {
	    # In MATLAB the imaginary parts are ignored.
	    # warn "atan2: Imaginary parts ignored";
	    # http://documents.wolfram.com/mathematica/functions/ArcTan
	    # NOTE: Mathematica ArcTan[x,y] while atan2(y,x)
	    my $s = $z1 * $z1 + $z2 * $z2;
	    _divbyzero("atan2") if $s == 0;
	    my $i = &i;
	    my $r = $z2 + $z1 * $i;
	    return -$i * &log($r / &sqrt( $s ));
	}
	return CORE::atan2($re1, $re2);
}

#
# display_format
# ->display_format
#
# Set (get if no argument) the display format for all complex numbers that
# don't happen to have overridden it via ->display_format
#
# When called as an object method, this actually sets the display format for
# the current object.
#
# Valid object formats are 'c' and 'p' for cartesian and polar. The first
# letter is used actually, so the type can be fully spelled out for clarity.
#
sub display_format {
	my $self  = shift;
	my %display_format = %DISPLAY_FORMAT;

	if (ref $self) {			# Called as an object method
	    if (exists $self->{display_format}) {
		my %obj = %{$self->{display_format}};
		@display_format{keys %obj} = values %obj;
	    }
	}
	if (@_ == 1) {
	    $display_format{style} = shift;
	} else {
	    my %new = @_;
	    @display_format{keys %new} = values %new;
	}

	if (ref $self) { # Called as an object method
	    $self->{display_format} = { %display_format };
	    return
		wantarray ?
		    %{$self->{display_format}} :
		    $self->{display_format}->{style};
	}

        # Called as a class method
	%DISPLAY_FORMAT = %display_format;
	return
	    wantarray ?
		%DISPLAY_FORMAT :
		    $DISPLAY_FORMAT{style};
}

#
# (_stringify)
#
# Show nicely formatted complex number under its cartesian or polar form,
# depending on the current display format:
#
# . If a specific display format has been recorded for this object, use it.
# . Otherwise, use the generic current default for all complex numbers,
#   which is a package global variable.
#
sub _stringify {
	my ($z) = shift;

	my $style = $z->display_format;

	$style = $DISPLAY_FORMAT{style} unless defined $style;

	return $z->_stringify_polar if $style =~ /^p/i;
	return $z->_stringify_cartesian;
}

#
# ->_stringify_cartesian
#
# Stringify as a cartesian representation 'a+bi'.
#
sub _stringify_cartesian {
	my $z  = shift;
	my ($x, $y) = @{$z->_cartesian};
	my ($re, $im);

	my %format = $z->display_format;
	my $format = $format{format};

	if ($x) {
	    if ($x =~ /^NaN[QS]?$/i) {
		$re = $x;
	    } else {
		if ($x =~ /^-?\Q$Inf\E$/oi) {
		    $re = $x;
		} else {
		    $re = defined $format ? sprintf($format, $x) : $x;
		}
	    }
	} else {
	    undef $re;
	}

	if ($y) {
	    if ($y =~ /^(NaN[QS]?)$/i) {
		$im = $y;
	    } else {
		if ($y =~ /^-?\Q$Inf\E$/oi) {
		    $im = $y;
		} else {
		    $im =
			defined $format ?
			    sprintf($format, $y) :
			    ($y == 1 ? "" : ($y == -1 ? "-" : $y));
		}
	    }
	    $im .= "i";
	} else {
	    undef $im;
	}

	my $str = $re;

	if (defined $im) {
	    if ($y < 0) {
		$str .= $im;
	    } elsif ($y > 0 || $im =~ /^NaN[QS]?i$/i)  {
		$str .= "+" if defined $re;
		$str .= $im;
	    }
	} elsif (!defined $re) {
	    $str = "0";
	}

	return $str;
}


#
# ->_stringify_polar
#
# Stringify as a polar representation '[r,t]'.
#
sub _stringify_polar {
	my $z  = shift;
	my ($r, $t) = @{$z->_polar};
	my $theta;

	my %format = $z->display_format;
	my $format = $format{format};

	if ($t =~ /^NaN[QS]?$/i || $t =~ /^-?\Q$Inf\E$/oi) {
	    $theta = $t; 
	} elsif ($t == pi) {
	    $theta = "pi";
	} elsif ($r == 0 || $t == 0) {
	    $theta = defined $format ? sprintf($format, $t) : $t;
	}

	return "[$r,$theta]" if defined $theta;

	#
	# Try to identify pi/n and friends.
	#

	$t -= int(CORE::abs($t) / pi2) * pi2;

	if ($format{polar_pretty_print} && $t) {
	    my ($a, $b);
	    for $a (2..9) {
		$b = $t * $a / pi;
		if ($b =~ /^-?\d+$/) {
		    $b = $b < 0 ? "-" : "" if CORE::abs($b) == 1;
		    $theta = "${b}pi/$a";
		    last;
		}
	    }
	}

        if (defined $format) {
	    $r     = sprintf($format, $r);
	    $theta = sprintf($format, $t) unless defined $theta;
	} else {
	    $theta = $t unless defined $theta;
	}

	return "[$r,$theta]";
}

sub Inf {
    return $Inf;
}

1;
__END__

#line 2109

1;

# eof

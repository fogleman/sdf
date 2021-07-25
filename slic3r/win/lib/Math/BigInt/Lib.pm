#line 1 "Math/BigInt/Lib.pm"
package Math::BigInt::Lib;

use 5.006001;
use strict;
use warnings;

our $VERSION = '1.999811';

use Carp;

use overload

  # overload key: with_assign

  '+'    => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _add($x, $y);
            },

  '-'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _sub($x, $y);
            },

  '*'    => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _mul($x, $y);
            },

  '/'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _div($x, $y);
            },

  '%'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _mod($x, $y);
            },

  '**'   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _pow($x, $y);
            },

  '<<'   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $class -> _num($_[0]);
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $_[0];
                    $y = ref($_[1]) ? $class -> _num($_[1]) : $_[1];
                }
                return $class -> _blsft($x, $y);
            },

  '>>'   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _brsft($x, $y);
            },

  # overload key: num_comparison

  '<'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) < 0;
            },

  '<='   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) <= 0;
            },

  '>'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) > 0;
            },

  '>='   => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y) >= 0;
          },

  '=='   => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _acmp($x, $y) == 0;
            },

  '!='   => sub {
                my $class = ref $_[0];
                my $x = $class -> _copy($_[0]);
                my $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                return $class -> _acmp($x, $y) != 0;
            },

  # overload key: 3way_comparison

  '<=>'  => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _acmp($x, $y);
            },

  # overload key: binary

  '&'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _and($x, $y);
            },

  '|'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _or($x, $y);
            },

  '^'    => sub {
                my $class = ref $_[0];
                my ($x, $y);
                if ($_[2]) {            # if swapped
                    $y = $_[0];
                    $x = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                } else {
                    $x = $class -> _copy($_[0]);
                    $y = ref($_[1]) ? $_[1] : $class -> _new($_[1]);
                }
                return $class -> _xor($x, $y);
            },

  # overload key: func

  'abs'  => sub { $_[0] },

  'sqrt' => sub {
                my $class = ref $_[0];
                return $class -> _sqrt($class -> _copy($_[0]));
            },

  'int'  => sub { $_[0] },

  # overload key: conversion

  'bool' => sub { ref($_[0]) -> _is_zero($_[0]) ? '' : 1; },

  '""'   => sub { ref($_[0]) -> _str($_[0]); },

  '0+'   => sub { ref($_[0]) -> _num($_[0]); },

  '='    => sub { ref($_[0]) -> _copy($_[0]); },

  ;

# Do we need api_version() at all, now that we have a virtual parent class that
# will provide any missing methods? Fixme!

sub api_version () {
    croak "@{[(caller 0)[3]]} method not implemented";
}

sub _new {
    croak "@{[(caller 0)[3]]} method not implemented";
}

sub _zero {
    my $class = shift;
    return $class -> _new("0");
}

sub _one {
    my $class = shift;
    return $class -> _new("1");
}

sub _two {
    my $class = shift;
    return $class -> _new("2");

}
sub _ten {
    my $class = shift;
    return $class -> _new("10");
}

sub _1ex {
    my ($class, $exp) = @_;
    $exp = $class -> _num($exp) if ref($exp);
    return $class -> _new("1" . ("0" x $exp));
}

sub _copy {
    my ($class, $x) = @_;
    return $class -> _new($class -> _str($x));
}

# catch and throw away
sub import { }

##############################################################################
# convert back to string and number

sub _str {
    # Convert number from internal base 1eN format to string format. Internal
    # format is always normalized, i.e., no leading zeros.
    croak "@{[(caller 0)[3]]} method not implemented";
}

sub _num {
    my ($class, $x) = @_;
    0 + $class -> _str($x);
}

##############################################################################
# actual math code

sub _add {
    croak "@{[(caller 0)[3]]} method not implemented";
}

sub _sub {
    croak "@{[(caller 0)[3]]} method not implemented";
}

sub _mul {
    my ($class, $x, $y) = @_;
    my $sum = $class -> _zero();
    my $i   = $class -> _zero();
    while ($class -> _acmp($i, $y) < 0) {
        $sum = $class -> _add($sum, $x);
        $i   = $class -> _inc($i);
    }
    return $sum;
}

sub _div {
    my ($class, $x, $y) = @_;

    croak "@{[(caller 0)[3]]} requires non-zero divisor"
      if $class -> _is_zero($y);

    my $r = $class -> _copy($x);
    my $q = $class -> _zero();
    while ($class -> _acmp($r, $y) >= 0) {
        $q = $class -> _inc($q);
        $r = $class -> _sub($r, $y);
    }

    return $q, $r if wantarray;
    return $q;
}

sub _inc {
    my ($class, $x) = @_;
    $class -> _add($x, $class -> _one());
}

sub _dec {
    my ($class, $x) = @_;
    $class -> _sub($x, $class -> _one());
}

##############################################################################
# testing

sub _acmp {
    # Compare two (absolute) values. Return -1, 0, or 1.
    my ($class, $x, $y) = @_;
    my $xstr = $class -> _str($x);
    my $ystr = $class -> _str($y);

    length($xstr) <=> length($ystr) || $xstr cmp $ystr;
}

sub _len {
    my ($class, $x) = @_;
    CORE::length($class -> _str($x));
}

sub _alen {
    my ($class, $x) = @_;
    $class -> _len($x);
}

sub _digit {
    my ($class, $x, $n) = @_;
    substr($class ->_str($x), -($n+1), 1);
}

sub _zeros {
    my ($class, $x) = @_;
    my $str = $class -> _str($x);
    $str =~ /[^0](0*)\z/ ? CORE::length($1) : 0;
}

##############################################################################
# _is_* routines

sub _is_zero {
    # return true if arg is zero
    my ($class, $x) = @_;
    $class -> _str($x) == 0;
}

sub _is_even {
    # return true if arg is even
    my ($class, $x) = @_;
    substr($class -> _str($x), -1, 1) % 2 == 0;
}

sub _is_odd {
    # return true if arg is odd
    my ($class, $x) = @_;
    substr($class -> _str($x), -1, 1) % 2 != 0;
}

sub _is_one {
    # return true if arg is one
    my ($class, $x) = @_;
    $class -> _str($x) == 1;
}

sub _is_two {
    # return true if arg is two
    my ($class, $x) = @_;
    $class -> _str($x) == 2;
}

sub _is_ten {
    # return true if arg is ten
    my ($class, $x) = @_;
    $class -> _str($x) == 10;
}

###############################################################################
# check routine to test internal state for corruptions

sub _check {
    # used by the test suite
    my ($class, $x) = @_;
    return "Input is undefined" unless defined $x;
    return "$x is not a reference" unless ref($x);
    return 0;
}

###############################################################################

sub _mod {
    # modulus
    my ($class, $x, $y) = @_;

    croak "@{[(caller 0)[3]]} requires non-zero second operand"
      if $class -> _is_zero($y);

    if ($class -> can('_div')) {
        $x = $class -> _copy($x);
        my ($q, $r) = $class -> _div($x, $y);
        return $r;
    } else {
        my $r = $class -> _copy($x);
        while ($class -> _acmp($r, $y) >= 0) {
            $r = $class -> _sub($r, $y);
        }
        return $r;
    }
}

##############################################################################
# shifts

sub _rsft {
    my ($class, $x, $n, $b) = @_;
    $b = $class -> _new($b) unless ref $b;
    return scalar $class -> _div($x, $class -> _pow($class -> _copy($b), $n));
}

sub _lsft {
    my ($class, $x, $n, $b) = @_;
    $b = $class -> _new($b) unless ref $b;
    return $class -> _mul($x, $class -> _pow($class -> _copy($b), $n));
}

sub _pow {
    # power of $x to $y
    my ($class, $x, $y) = @_;

    if ($class -> _is_zero($y)) {
        return $class -> _one();        # y == 0 => x => 1
    }

    if (($class -> _is_one($x)) ||      #    x == 1
        ($class -> _is_one($y)))        # or y == 1
    {
        return $x;
    }

    if ($class -> _is_zero($x)) {
        return $class -> _zero();       # 0 ** y => 0 (if not y <= 0)
    }

    my $pow2 = $class -> _one();

    my $y_bin = $class -> _as_bin($y);
    $y_bin =~ s/^0b//;
    my $len = length($y_bin);

    while (--$len > 0) {
        $pow2 = $class -> _mul($pow2, $x) if substr($y_bin, $len, 1) eq '1';
        $x = $class -> _mul($x, $x);
    }

    $x = $class -> _mul($x, $pow2);
    return $x;
}

sub _nok {
    # Return binomial coefficient (n over k).
    my ($class, $n, $k) = @_;

    # If k > n/2, or, equivalently, 2*k > n, compute nok(n, k) as
    # nok(n, n-k), to minimize the number if iterations in the loop.

    {
        my $twok = $class -> _mul($class -> _two(), $class -> _copy($k));
        if ($class -> _acmp($twok, $n) > 0) {
            $k = $class -> _sub($class -> _copy($n), $k);
        }
    }

    # Example:
    #
    # / 7 \       7!       1*2*3*4 * 5*6*7   5 * 6 * 7
    # |   | = --------- =  --------------- = --------- = ((5 * 6) / 2 * 7) / 3
    # \ 3 /   (7-3)! 3!    1*2*3*4 * 1*2*3   1 * 2 * 3
    #
    # Equivalently, _nok(11, 5) is computed as
    #
    # (((((((7 * 8) / 2) * 9) / 3) * 10) / 4) * 11) / 5

    if ($class -> _is_zero($k)) {
        return $class -> _one();
    }

    # Make a copy of the original n, in case the subclass modifies n in-place.

    my $n_orig = $class -> _copy($n);

    # n = 5, f = 6, d = 2 (cf. example above)

    $n = $class -> _sub($n, $k);
    $n = $class -> _inc($n);

    my $f = $class -> _copy($n);
    $f = $class -> _inc($f);

    my $d = $class -> _two();

    # while f <= n (the original n, that is) ...

    while ($class -> _acmp($f, $n_orig) <= 0) {
        $n = $class -> _mul($n, $f);
        $n = $class -> _div($n, $d);
        $f = $class -> _inc($f);
        $d = $class -> _inc($d);
    }

    return $n;
}

sub _fac {
    # factorial
    my ($class, $x) = @_;

    my $two = $class -> _two();

    if ($class -> _acmp($x, $two) < 0) {
        return $class -> _one();
    }

    my $i = $class -> _copy($x);
    while ($class -> _acmp($i, $two) > 0) {
        $i = $class -> _dec($i);
        $x = $class -> _mul($x, $i);
    }

    return $x;
}

sub _dfac {
    # double factorial
    my ($class, $x) = @_;

    my $two = $class -> _two();

    if ($class -> _acmp($x, $two) < 0) {
        return $class -> _one();
    }

    my $i = $class -> _copy($x);
    while ($class -> _acmp($i, $two) > 0) {
        $i = $class -> _sub($i, $two);
        $x = $class -> _mul($x, $i);
    }

    return $x;
}

sub _log_int {
    # calculate integer log of $x to base $base
    # calculate integer log of $x to base $base
    # ref to array, ref to array - return ref to array
    my ($class, $x, $base) = @_;

    # X == 0 => NaN
    return if $class -> _is_zero($x);

    $base = $class -> _new(2)     unless defined($base);
    $base = $class -> _new($base) unless ref($base);

    # BASE 0 or 1 => NaN
    return if $class -> _is_zero($base) || $class -> _is_one($base);

    # X == 1 => 0 (is exact)
    if ($class -> _is_one($x)) {
        return $class -> _zero(), 1;
    }

    my $cmp = $class -> _acmp($x, $base);

    # X == BASE => 1 (is exact)
    if ($cmp == 0) {
        return $class -> _one(), 1;
    }

    # 1 < X < BASE => 0 (is truncated)
    if ($cmp < 0) {
        return $class -> _zero(), 0;
    }

    my $y;

    # log(x) / log(b) = log(xm * 10^xe) / log(bm * 10^be)
    #                 = (log(xm) + xe*(log(10))) / (log(bm) + be*log(10))

    {
        my $x_str = $class -> _str($x);
        my $b_str = $class -> _str($base);
        my $xm    = "." . $x_str;
        my $bm    = "." . $b_str;
        my $xe    = length($x_str);
        my $be    = length($b_str);
        my $log10 = log(10);
        my $guess = int((log($xm) + $xe * $log10) / (log($bm) + $be * $log10));
        $y = $class -> _new($guess);
    }

    my $trial = $class -> _pow($class -> _copy($base), $y);
    my $acmp  = $class -> _acmp($trial, $x);

    # Did we get the exact result?

    return $y, 1 if $acmp == 0;

    # Too small?

    while ($acmp < 0) {
        $trial = $class -> _mul($trial, $base);
        $y     = $class -> _inc($y);
        $acmp  = $class -> _acmp($trial, $x);
    }

    # Too big?

    while ($acmp > 0) {
        $trial = $class -> _div($trial, $base);
        $y     = $class -> _dec($y);
        $acmp  = $class -> _acmp($trial, $x);
    }

    return $y, 1 if $acmp == 0;         # result is exact
    return $y, 0;                       # result is too small
}

sub _sqrt {
    # square-root of $y in place
    my ($class, $y) = @_;

    return $y if $class -> _is_zero($y);

    my $y_str = $class -> _str($y);
    my $y_len = length($y_str);

    # Compute the guess $x.

    my $xm;
    my $xe;
    if ($y_len % 2 == 0) {
        $xm = sqrt("." . $y_str);
        $xe = $y_len / 2;
        $xm = sprintf "%.0f", int($xm * 1e15);
        $xe -= 15;
    } else {
        $xm = sqrt(".0" . $y_str);
        $xe = ($y_len + 1) / 2;
        $xm = sprintf "%.0f", int($xm * 1e16);
        $xe -= 16;
    }

    my $x;
    if ($xe < 0) {
        $x = substr $xm, 0, length($xm) + $xe;
    } else {
        $x = $xm . ("0" x $xe);
    }

    $x = $class -> _new($x);

    # Newton's method for computing square root of y
    #
    # x(i+1) = x(i) - f(x(i)) / f'(x(i))
    #        = x(i) - (x(i)^2 - y) / (2 * x(i))     # use if x(i)^2 > y
    #        = y(i) + (y - x(i)^2) / (2 * x(i))     # use if x(i)^2 < y

    # Determine if x, our guess, is too small, correct, or too large.

    my $xsq = $class -> _mul($class -> _copy($x), $x);          # x(i)^2
    my $acmp = $class -> _acmp($xsq, $y);                       # x(i)^2 <=> y

    # Only assign a value to this variable if we will be using it.

    my $two;
    $two = $class -> _two() if $acmp != 0;

    # If x is too small, do one iteration of Newton's method. Since the
    # function f(x) = x^2 - y is concave and monotonically increasing, the next
    # guess for x will either be correct or too large.

    if ($acmp < 0) {

        # x(i+1) = x(i) + (y - x(i)^2) / (2 * x(i))

        my $numer = $class -> _sub($class -> _copy($y), $xsq);  # y - x(i)^2
        my $denom = $class -> _mul($class -> _copy($two), $x);  # 2 * x(i)
        my $delta = $class -> _div($numer, $denom);

        unless ($class -> _is_zero($delta)) {
            $x    = $class -> _add($x, $delta);
            $xsq  = $class -> _mul($class -> _copy($x), $x);    # x(i)^2
            $acmp = $class -> _acmp($xsq, $y);                  # x(i)^2 <=> y
        }
    }

    # If our guess for x is too large, apply Newton's method repeatedly until
    # we either have got the correct value, or the delta is zero.

    while ($acmp > 0) {

        # x(i+1) = x(i) - (x(i)^2 - y) / (2 * x(i))

        my $numer = $class -> _sub($xsq, $y);                   # x(i)^2 - y
        my $denom = $class -> _mul($class -> _copy($two), $x);  # 2 * x(i)
        my $delta = $class -> _div($numer, $denom);
        last if $class -> _is_zero($delta);

        $x    = $class -> _sub($x, $delta);
        $xsq  = $class -> _mul($class -> _copy($x), $x);        # x(i)^2
        $acmp = $class -> _acmp($xsq, $y);                      # x(i)^2 <=> y
    }

    # When the delta is zero, our value for x might still be too large. We
    # require that the outout is either exact or too small (i.e., rounded down
    # to the nearest integer), so do a final check.

    while ($acmp > 0) {
        $x    = $class -> _dec($x);
        $xsq  = $class -> _mul($class -> _copy($x), $x);        # x(i)^2
        $acmp = $class -> _acmp($xsq, $y);                      # x(i)^2 <=> y
    }

    return $x;
}

sub _root {
    my ($class, $y, $n) = @_;

    return $y if $class -> _is_zero($y) || $class -> _is_one($y) ||
                 $class -> _is_one($n);

    # If y <= n, the result is always (truncated to) 1.

    return $class -> _one() if $class -> _acmp($y, $n) <= 0;

    # Compute the initial guess x of y^(1/n). When n is large, Newton's method
    # converges slowly if the "guess" (initial value) is poor, so we need a
    # good guess. It the guess is too small, the next guess will be too large,
    # and from then on all guesses are too large.

    my $DEBUG = 0;

    # Split y into mantissa and exponent in base 10, so that
    #
    #   y = xm * 10^xe, where 0 < xm < 1 and xe is an integer

    my $y_str  = $class -> _str($y);
    my $ym = "." . $y_str;
    my $ye = length($y_str);

    # From this compute the approximate base 10 logarithm of y
    #
    #   log_10(y) = log_10(ym) + log_10(ye^10)
    #             = log(ym)/log(10) + ye

    my $log10y = log($ym) / log(10) + $ye;

    # And from this compute the approximate base 10 logarithm of x, where
    # x = y^(1/n)
    #
    #   log_10(x) = log_10(y)/n

    my $log10x = $log10y / $class -> _num($n);

    # From this compute xm and xe, the mantissa and exponent (in base 10) of x,
    # where 1 < xm <= 10 and xe is an integer.

    my $xe = int $log10x;
    my $xm = 10 ** ($log10x - $xe);

    # Scale the mantissa and exponent to increase the integer part of ym, which
    # gives us better accuracy.

    if ($DEBUG) {
        print "\n";
        print "y_str  = $y_str\n";
        print "ym     = $ym\n";
        print "ye     = $ye\n";
        print "log10y = $log10y\n";
        print "log10x = $log10x\n";
        print "xm     = $xm\n";
        print "xe     = $xe\n";
    }

    my $d = $xe < 15 ? $xe : 15;
    $xm *= 10 ** $d;
    $xe -= $d;

    if ($DEBUG) {
        print "\n";
        print "xm     = $xm\n";
        print "xe     = $xe\n";
    }

    # If the mantissa is not an integer, round up to nearest integer, and then
    # convert the number to a string. It is important to always round up due to
    # how Newton's method behaves in this case. If the initial guess is too
    # small, the next guess will be too large, after which every succeeding
    # guess converges the correct value from above. Now, if the initial guess
    # is too small and n is large, the next guess will be much too large and
    # require a large number of iterations to get close to the solution.
    # Because of this, we are likely to find the solution faster if we make
    # sure the initial guess is not too small.

    my $xm_int = int($xm);
    my $x_str = sprintf '%.0f', $xm > $xm_int ? $xm_int + 1 : $xm_int;
    $x_str .= "0" x $xe;

    my $x = $class -> _new($x_str);

    if ($DEBUG) {
        print "xm     = $xm\n";
        print "xe     = $xe\n";
        print "\n";
        print "x_str  = $x_str (initial guess)\n";
        print "\n";
    }

    # Use Newton's method for computing n'th root of y.
    #
    # x(i+1) = x(i) - f(x(i)) / f'(x(i))
    #        = x(i) - (x(i)^n - y) / (n * x(i)^(n-1))   # use if x(i)^n > y
    #        = x(i) + (y - x(i)^n) / (n * x(i)^(n-1))   # use if x(i)^n < y

    # Determine if x, our guess, is too small, correct, or too large. Rather
    # than computing x(i)^n and x(i)^(n-1) directly, compute x(i)^(n-1) and
    # then the same value multiplied by x.

    my $nm1     = $class -> _dec($class -> _copy($n));           # n-1
    my $xpownm1 = $class -> _pow($class -> _copy($x), $nm1);     # x(i)^(n-1)
    my $xpown   = $class -> _mul($class -> _copy($xpownm1), $x); # x(i)^n
    my $acmp    = $class -> _acmp($xpown, $y);                   # x(i)^n <=> y

    if ($DEBUG) {
        print "\n";
        print "x      = ", $class -> _str($x), "\n";
        print "x^n    = ", $class -> _str($xpown), "\n";
        print "y      = ", $class -> _str($y), "\n";
        print "acmp   = $acmp\n";
    }

    # If x is too small, do one iteration of Newton's method. Since the
    # function f(x) = x^n - y is concave and monotonically increasing, the next
    # guess for x will either be correct or too large.

    if ($acmp < 0) {

        # x(i+1) = x(i) + (y - x(i)^n) / (n * x(i)^(n-1))

        my $numer = $class -> _sub($class -> _copy($y), $xpown);    # y - x(i)^n
        my $denom = $class -> _mul($class -> _copy($n), $xpownm1);  # n * x(i)^(n-1)
        my $delta = $class -> _div($numer, $denom);

        if ($DEBUG) {
            print "\n";
            print "numer  = ", $class -> _str($numer), "\n";
            print "denom  = ", $class -> _str($denom), "\n";
            print "delta  = ", $class -> _str($delta), "\n";
        }

        unless ($class -> _is_zero($delta)) {
            $x       = $class -> _add($x, $delta);
            $xpownm1 = $class -> _pow($class -> _copy($x), $nm1);     # x(i)^(n-1)
            $xpown   = $class -> _mul($class -> _copy($xpownm1), $x); # x(i)^n
            $acmp    = $class -> _acmp($xpown, $y);                   # x(i)^n <=> y

            if ($DEBUG) {
                print "\n";
                print "x      = ", $class -> _str($x), "\n";
                print "x^n    = ", $class -> _str($xpown), "\n";
                print "y      = ", $class -> _str($y), "\n";
                print "acmp   = $acmp\n";
            }
        }
    }

    # If our guess for x is too large, apply Newton's method repeatedly until
    # we either have got the correct value, or the delta is zero.

    while ($acmp > 0) {

        # x(i+1) = x(i) - (x(i)^n - y) / (n * x(i)^(n-1))

        my $numer = $class -> _sub($class -> _copy($xpown), $y);    # x(i)^n - y
        my $denom = $class -> _mul($class -> _copy($n), $xpownm1);  # n * x(i)^(n-1)

        if ($DEBUG) {
            print "numer  = ", $class -> _str($numer), "\n";
            print "denom  = ", $class -> _str($denom), "\n";
        }

        my $delta = $class -> _div($numer, $denom);

        if ($DEBUG) {
            print "delta  = ", $class -> _str($delta), "\n";
        }

        last if $class -> _is_zero($delta);

        $x       = $class -> _sub($x, $delta);
        $xpownm1 = $class -> _pow($class -> _copy($x), $nm1);     # x(i)^(n-1)
        $xpown   = $class -> _mul($class -> _copy($xpownm1), $x); # x(i)^n
        $acmp    = $class -> _acmp($xpown, $y);                   # x(i)^n <=> y

        if ($DEBUG) {
            print "\n";
            print "x      = ", $class -> _str($x), "\n";
            print "x^n    = ", $class -> _str($xpown), "\n";
            print "y      = ", $class -> _str($y), "\n";
            print "acmp   = $acmp\n";
        }
    }

    # When the delta is zero, our value for x might still be too large. We
    # require that the outout is either exact or too small (i.e., rounded down
    # to the nearest integer), so do a final check.

    while ($acmp > 0) {
        $x     = $class -> _dec($x);
        $xpown = $class -> _pow($class -> _copy($x), $n);     # x(i)^n
        $acmp  = $class -> _acmp($xpown, $y);                 # x(i)^n <=> y
    }

    return $x;
}

##############################################################################
# binary stuff

sub _and {
    my ($class, $x, $y) = @_;

    return $x if $class -> _acmp($x, $y) == 0;

    my $m    = $class -> _one();
    my $mask = $class -> _new("32768");

    my ($xr, $yr);                # remainders after division

    my $xc = $class -> _copy($x);
    my $yc = $class -> _copy($y);
    my $z  = $class -> _zero();

    until ($class -> _is_zero($xc) || $class -> _is_zero($yc)) {
        ($xc, $xr) = $class -> _div($xc, $mask);
        ($yc, $yr) = $class -> _div($yc, $mask);
        my $bits = $class -> _new($class -> _num($xr) & $class -> _num($yr));
        $z = $class -> _add($z, $class -> _mul($bits, $m));
        $m = $class -> _mul($m, $mask);
    }

    return $z;
}

sub _xor {
    my ($class, $x, $y) = @_;

    return $class -> _zero() if $class -> _acmp($x, $y) == 0;

    my $m    = $class -> _one();
    my $mask = $class -> _new("32768");

    my ($xr, $yr);                # remainders after division

    my $xc = $class -> _copy($x);
    my $yc = $class -> _copy($y);
    my $z  = $class -> _zero();

    until ($class -> _is_zero($xc) || $class -> _is_zero($yc)) {
        ($xc, $xr) = $class -> _div($xc, $mask);
        ($yc, $yr) = $class -> _div($yc, $mask);
        my $bits = $class -> _new($class -> _num($xr) ^ $class -> _num($yr));
        $z = $class -> _add($z, $class -> _mul($bits, $m));
        $m = $class -> _mul($m, $mask);
    }

    # The loop above stops when the smallest of the two numbers is exhausted.
    # The remainder of the longer one will survive bit-by-bit, so we simple
    # multiply-add it in.

    $z = $class -> _add($z, $class -> _mul($xc, $m))
      unless $class -> _is_zero($xc);
    $z = $class -> _add($z, $class -> _mul($yc, $m))
      unless $class -> _is_zero($yc);

    return $z;
}

sub _or {
    my ($class, $x, $y) = @_;

    return $x if $class -> _acmp($x, $y) == 0; # shortcut (see _and)

    my $m    = $class -> _one();
    my $mask = $class -> _new("32768");

    my ($xr, $yr);                # remainders after division

    my $xc = $class -> _copy($x);
    my $yc = $class -> _copy($y);
    my $z  = $class -> _zero();

    until ($class -> _is_zero($xc) || $class -> _is_zero($yc)) {
        ($xc, $xr) = $class -> _div($xc, $mask);
        ($yc, $yr) = $class -> _div($yc, $mask);
        my $bits = $class -> _new($class -> _num($xr) | $class -> _num($yr));
        $z = $class -> _add($z, $class -> _mul($bits, $m));
        $m = $class -> _mul($m, $mask);
    }

    # The loop above stops when the smallest of the two numbers is exhausted.
    # The remainder of the longer one will survive bit-by-bit, so we simple
    # multiply-add it in.

    $z = $class -> _add($z, $class -> _mul($xc, $m))
      unless $class -> _is_zero($xc);
    $z = $class -> _add($z, $class -> _mul($yc, $m))
      unless $class -> _is_zero($yc);

    return $z;
}

sub _to_bin {
    # convert the number to a string of binary digits without prefix
    my ($class, $x) = @_;
    my $str    = '';
    my $tmp    = $class -> _copy($x);
    my $chunk = $class -> _new("16777216");     # 2^24 = 24 binary digits
    my $rem;
    until ($class -> _acmp($tmp, $chunk) < 0) {
        ($tmp, $rem) = $class -> _div($tmp, $chunk);
        $str = sprintf("%024b", $class -> _num($rem)) . $str;
    }
    unless ($class -> _is_zero($tmp)) {
        $str = sprintf("%b", $class -> _num($tmp)) . $str;
    }
    return length($str) ? $str : '0';
}

sub _to_oct {
    # convert the number to a string of octal digits without prefix
    my ($class, $x) = @_;
    my $str    = '';
    my $tmp    = $class -> _copy($x);
    my $chunk = $class -> _new("16777216");     # 2^24 = 8 octal digits
    my $rem;
    until ($class -> _acmp($tmp, $chunk) < 0) {
        ($tmp, $rem) = $class -> _div($tmp, $chunk);
        $str = sprintf("%08o", $class -> _num($rem)) . $str;
    }
    unless ($class -> _is_zero($tmp)) {
        $str = sprintf("%o", $class -> _num($tmp)) . $str;
    }
    return length($str) ? $str : '0';
}

sub _to_hex {
    # convert the number to a string of hexadecimal digits without prefix
    my ($class, $x) = @_;
    my $str    = '';
    my $tmp    = $class -> _copy($x);
    my $chunk = $class -> _new("16777216");     # 2^24 = 6 hexadecimal digits
    my $rem;
    until ($class -> _acmp($tmp, $chunk) < 0) {
        ($tmp, $rem) = $class -> _div($tmp, $chunk);
        $str = sprintf("%06x", $class -> _num($rem)) . $str;
    }
    unless ($class -> _is_zero($tmp)) {
        $str = sprintf("%x", $class -> _num($tmp)) . $str;
    }
    return length($str) ? $str : '0';
}

sub _as_bin {
    # convert the number to a string of binary digits with prefix
    my ($class, $x) = @_;
    return '0b' . $class -> _to_bin($x);
}

sub _as_oct {
    # convert the number to a string of octal digits with prefix
    my ($class, $x) = @_;
    return '0' . $class -> _to_oct($x);         # yes, 0 becomes "00"
}

sub _as_hex {
    # convert the number to a string of hexadecimal digits with prefix
    my ($class, $x) = @_;
    return '0x' . $class -> _to_hex($x);
}

sub _to_bytes {
    # convert the number to a string of bytes
    my ($class, $x) = @_;
    my $str    = '';
    my $tmp    = $class -> _copy($x);
    my $chunk = $class -> _new("65536");
    my $rem;
    until ($class -> _is_zero($tmp)) {
        ($tmp, $rem) = $class -> _div($tmp, $chunk);
        $str = pack('n', $class -> _num($rem)) . $str;
    }
    $str =~ s/^\0+//;
    return length($str) ? $str : "\x00";
}

*_as_bytes = \&_to_bytes;

sub _from_hex {
    # Convert a string of hexadecimal digits to a number.

    my ($class, $hex) = @_;
    $hex =~ s/^0[xX]//;

    # Find the largest number of hexadecimal digits that we can safely use with
    # 32 bit integers. There are 4 bits pr hexadecimal digit, and we use only
    # 31 bits to play safe. This gives us int(31 / 4) = 7.

    my $len = length $hex;
    my $rem = 1 + ($len - 1) % 7;

    # Do the first chunk.

    my $ret = $class -> _new(int hex substr $hex, 0, $rem);
    return $ret if $rem == $len;

    # Do the remaining chunks, if any.

    my $shift = $class -> _new(1 << (4 * 7));
    for (my $offset = $rem ; $offset < $len ; $offset += 7) {
        my $part = int hex substr $hex, $offset, 7;
        $ret = $class -> _mul($ret, $shift);
        $ret = $class -> _add($ret, $class -> _new($part));
    }

    return $ret;
}

sub _from_oct {
    # Convert a string of octal digits to a number.

    my ($class, $oct) = @_;

    # Find the largest number of octal digits that we can safely use with 32
    # bit integers. There are 3 bits pr octal digit, and we use only 31 bits to
    # play safe. This gives us int(31 / 3) = 10.

    my $len = length $oct;
    my $rem = 1 + ($len - 1) % 10;

    # Do the first chunk.

    my $ret = $class -> _new(int oct substr $oct, 0, $rem);
    return $ret if $rem == $len;

    # Do the remaining chunks, if any.

    my $shift = $class -> _new(1 << (3 * 10));
    for (my $offset = $rem ; $offset < $len ; $offset += 10) {
        my $part = int oct substr $oct, $offset, 10;
        $ret = $class -> _mul($ret, $shift);
        $ret = $class -> _add($ret, $class -> _new($part));
    }

    return $ret;
}

sub _from_bin {
    # Convert a string of binary digits to a number.

    my ($class, $bin) = @_;
    $bin =~ s/^0[bB]//;

    # The largest number of binary digits that we can safely use with 32 bit
    # integers is 31. We use only 31 bits to play safe.

    my $len = length $bin;
    my $rem = 1 + ($len - 1) % 31;

    # Do the first chunk.

    my $ret = $class -> _new(int oct '0b' . substr $bin, 0, $rem);
    return $ret if $rem == $len;

    # Do the remaining chunks, if any.

    my $shift = $class -> _new(1 << 31);
    for (my $offset = $rem ; $offset < $len ; $offset += 31) {
        my $part = int oct '0b' . substr $bin, $offset, 31;
        $ret = $class -> _mul($ret, $shift);
        $ret = $class -> _add($ret, $class -> _new($part));
    }

    return $ret;
}

sub _from_bytes {
    # convert string of bytes to a number
    my ($class, $str) = @_;
    my $x    = $class -> _zero();
    my $base = $class -> _new("256");
    my $n    = length($str);
    for (my $i = 0 ; $i < $n ; ++$i) {
        $x = $class -> _mul($x, $base);
        my $byteval = $class -> _new(unpack 'C', substr($str, $i, 1));
        $x = $class -> _add($x, $byteval);
    }
    return $x;
}

##############################################################################
# special modulus functions

sub _modinv {
    # modular multiplicative inverse
    my ($class, $x, $y) = @_;

    # modulo zero
    if ($class -> _is_zero($y)) {
        return (undef, undef);
    }

    # modulo one
    if ($class -> _is_one($y)) {
        return ($class -> _zero(), '+');
    }

    my $u = $class -> _zero();
    my $v = $class -> _one();
    my $a = $class -> _copy($y);
    my $b = $class -> _copy($x);

    # Euclid's Algorithm for bgcd().

    my $q;
    my $sign = 1;
    {
        ($a, $q, $b) = ($b, $class -> _div($a, $b));
        last if $class -> _is_zero($b);

        my $vq = $class -> _mul($class -> _copy($v), $q);
        my $t = $class -> _add($vq, $u);
        $u = $v;
        $v = $t;
        $sign = -$sign;
        redo;
    }

    # if the gcd is not 1, there exists no modular multiplicative inverse
    return (undef, undef) unless $class -> _is_one($a);

    ($v, $sign == 1 ? '+' : '-');
}

sub _modpow {
    # modulus of power ($x ** $y) % $z
    my ($class, $num, $exp, $mod) = @_;

    # a^b (mod 1) = 0 for all a and b
    if ($class -> _is_one($mod)) {
        return $class -> _zero();
    }

    # 0^a (mod m) = 0 if m != 0, a != 0
    # 0^0 (mod m) = 1 if m != 0
    if ($class -> _is_zero($num)) {
        return $class -> _is_zero($exp) ? $class -> _one()
                                        : $class -> _zero();
    }

    #  $num = $class -> _mod($num, $mod);   # this does not make it faster

    my $acc = $class -> _copy($num);
    my $t   = $class -> _one();

    my $expbin = $class -> _as_bin($exp);
    $expbin =~ s/^0b//;
    my $len = length($expbin);

    while (--$len >= 0) {
        if (substr($expbin, $len, 1) eq '1') {
            $t = $class -> _mul($t, $acc);
            $t = $class -> _mod($t, $mod);
        }
        $acc = $class -> _mul($acc, $acc);
        $acc = $class -> _mod($acc, $mod);
    }
    return $t;
}

sub _gcd {
    # Greatest common divisor.

    my ($class, $x, $y) = @_;

    # gcd(0, 0) = 0
    # gcd(0, a) = a, if a != 0

    if ($class -> _acmp($x, $y) == 0) {
        return $class -> _copy($x);
    }

    if ($class -> _is_zero($x)) {
        if ($class -> _is_zero($y)) {
            return $class -> _zero();
        } else {
            return $class -> _copy($y);
        }
    } else {
        if ($class -> _is_zero($y)) {
            return $class -> _copy($x);
        } else {

            # Until $y is zero ...

            $x = $class -> _copy($x);
            until ($class -> _is_zero($y)) {

                # Compute remainder.

                $x = $class -> _mod($x, $y);

                # Swap $x and $y.

                my $tmp = $x;
                $x = $class -> _copy($y);
                $y = $tmp;
            }

            return $x;
        }
    }
}

sub _lcm {
    # Least common multiple.

    my ($class, $x, $y) = @_;

    # lcm(0, x) = 0 for all x

    return $class -> _zero()
      if ($class -> _is_zero($x) ||
          $class -> _is_zero($y));

    my $gcd = $class -> _gcd($class -> _copy($x), $y);
    $x = $class -> _div($x, $gcd);
    $x = $class -> _mul($x, $y);
    return $x;
}

sub _lucas {
    my ($class, $n) = @_;

    $n = $class -> _num($n) if ref $n;

    # In list context, use lucas(n) = lucas(n-1) + lucas(n-2)

    if (wantarray) {
        my @y;

        push @y, $class -> _two();
        return @y if $n == 0;

        push @y, $class -> _one();
        return @y if $n == 1;

        for (my $i = 2 ; $i <= $n ; ++ $i) {
            $y[$i] = $class -> _add($class -> _copy($y[$i - 1]), $y[$i - 2]);
        }

        return @y;
    }

    require Scalar::Util;

    # In scalar context use that lucas(n) = fib(n-1) + fib(n+1).
    #
    # Remember that _fib() behaves differently in scalar context and list
    # context, so we must add scalar() to get the desired behaviour.

    return $class -> _two() if $n == 0;

    return $class -> _add(scalar $class -> _fib($n - 1),
                          scalar $class -> _fib($n + 1));
}

sub _fib {
    my ($class, $n) = @_;

    $n = $class -> _num($n) if ref $n;

    # In list context, use fib(n) = fib(n-1) + fib(n-2)

    if (wantarray) {
        my @y;

        push @y, $class -> _zero();
        return @y if $n == 0;

        push @y, $class -> _one();
        return @y if $n == 1;

        for (my $i = 2 ; $i <= $n ; ++ $i) {
            $y[$i] = $class -> _add($class -> _copy($y[$i - 1]), $y[$i - 2]);
        }

        return @y;
    }

    # In scalar context use a fast algorithm that is much faster than the
    # recursive algorith used in list context.

    my $cache = {};
    my $two = $class -> _two();
    my $fib;

    $fib = sub {
        my $n = shift;
        return $class -> _zero() if $n <= 0;
        return $class -> _one()  if $n <= 2;
        return $cache -> {$n}    if exists $cache -> {$n};

        my $k = int($n / 2);
        my $a = $fib -> ($k + 1);
        my $b = $fib -> ($k);
        my $y;

        if ($n % 2 == 1) {
            # a*a + b*b
            $y = $class -> _add($class -> _mul($class -> _copy($a), $a),
                                $class -> _mul($class -> _copy($b), $b));
        } else {
            # (2*a - b)*b
            $y = $class -> _mul($class -> _sub($class -> _mul(
                   $class -> _copy($two), $a), $b), $b);
        }

        $cache -> {$n} = $y;
        return $y;
    };

    return $fib -> ($n);
}

##############################################################################
##############################################################################

1;

__END__

#line 2071

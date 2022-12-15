#line 1 "Math/BigInt.pm"
package Math::BigInt;

#
# "Mike had an infinite amount to do and a negative amount of time in which
# to do it." - Before and After
#

# The following hash values are used:
#   value: unsigned int with actual value (as a Math::BigInt::Calc or similar)
#   sign : +, -, NaN, +inf, -inf
#   _a   : accuracy
#   _p   : precision

# Remember not to take shortcuts ala $xs = $x->{value}; $CALC->foo($xs); since
# underlying lib might change the reference!

use 5.006001;
use strict;
use warnings;

use Carp ();

our $VERSION = '1.999811';

our @ISA = qw(Exporter);
our @EXPORT_OK = qw(objectify bgcd blcm);

my $class = "Math::BigInt";

# Inside overload, the first arg is always an object. If the original code had
# it reversed (like $x = 2 * $y), then the third parameter is true.
# In some cases (like add, $x = $x + 2 is the same as $x = 2 + $x) this makes
# no difference, but in some cases it does.

# For overloaded ops with only one argument we simple use $_[0]->copy() to
# preserve the argument.

# Thus inheritance of overload operators becomes possible and transparent for
# our subclasses without the need to repeat the entire overload section there.

use overload

  # overload key: with_assign

  '+'     =>      sub { $_[0] -> copy() -> badd($_[1]); },

  '-'     =>      sub { my $c = $_[0] -> copy;
                        $_[2] ? $c -> bneg() -> badd($_[1])
                              : $c -> bsub($_[1]); },

  '*'     =>      sub { $_[0] -> copy() -> bmul($_[1]); },

  '/'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bdiv($_[0])
                              : $_[0] -> copy -> bdiv($_[1]); },

  '%'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bmod($_[0])
                              : $_[0] -> copy -> bmod($_[1]); },

  '**'    =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bpow($_[0])
                              : $_[0] -> copy -> bpow($_[1]); },

  '<<'    =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> blsft($_[0])
                              : $_[0] -> copy -> blsft($_[1]); },

  '>>'    =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> brsft($_[0])
                              : $_[0] -> copy -> brsft($_[1]); },

  # overload key: assign

  '+='    =>      sub { $_[0]->badd($_[1]); },

  '-='    =>      sub { $_[0]->bsub($_[1]); },

  '*='    =>      sub { $_[0]->bmul($_[1]); },

  '/='    =>      sub { scalar $_[0]->bdiv($_[1]); },

  '%='    =>      sub { $_[0]->bmod($_[1]); },

  '**='   =>      sub { $_[0]->bpow($_[1]); },


  '<<='   =>      sub { $_[0]->blsft($_[1]); },

  '>>='   =>      sub { $_[0]->brsft($_[1]); },

#  'x='    =>      sub { },

#  '.='    =>      sub { },

  # overload key: num_comparison

  '<'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> blt($_[0])
                              : $_[0] -> blt($_[1]); },

  '<='    =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> ble($_[0])
                              : $_[0] -> ble($_[1]); },

  '>'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bgt($_[0])
                              : $_[0] -> bgt($_[1]); },

  '>='    =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bge($_[0])
                              : $_[0] -> bge($_[1]); },

  '=='    =>      sub { $_[0] -> beq($_[1]); },

  '!='    =>      sub { $_[0] -> bne($_[1]); },

  # overload key: 3way_comparison

  '<=>'   =>      sub { my $cmp = $_[0] -> bcmp($_[1]);
                        defined($cmp) && $_[2] ? -$cmp : $cmp; },

  'cmp'   =>      sub { $_[2] ? "$_[1]" cmp $_[0] -> bstr()
                              : $_[0] -> bstr() cmp "$_[1]"; },

  # overload key: str_comparison

#  'lt'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bstrlt($_[0])
#                              : $_[0] -> bstrlt($_[1]); },
#
#  'le'    =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bstrle($_[0])
#                              : $_[0] -> bstrle($_[1]); },
#
#  'gt'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bstrgt($_[0])
#                              : $_[0] -> bstrgt($_[1]); },
#
#  'ge'    =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bstrge($_[0])
#                              : $_[0] -> bstrge($_[1]); },
#
#  'eq'    =>      sub { $_[0] -> bstreq($_[1]); },
#
#  'ne'    =>      sub { $_[0] -> bstrne($_[1]); },

  # overload key: binary

  '&'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> band($_[0])
                              : $_[0] -> copy -> band($_[1]); },

  '&='    =>      sub { $_[0] -> band($_[1]); },

  '|'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bior($_[0])
                              : $_[0] -> copy -> bior($_[1]); },

  '|='    =>      sub { $_[0] -> bior($_[1]); },

  '^'     =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> bxor($_[0])
                              : $_[0] -> copy -> bxor($_[1]); },

  '^='    =>      sub { $_[0] -> bxor($_[1]); },

#  '&.'    =>      sub { },

#  '&.='   =>      sub { },

#  '|.'    =>      sub { },

#  '|.='   =>      sub { },

#  '^.'    =>      sub { },

#  '^.='   =>      sub { },

  # overload key: unary

  'neg'   =>      sub { $_[0] -> copy() -> bneg(); },

#  '!'     =>      sub { },

  '~'     =>      sub { $_[0] -> copy() -> bnot(); },

#  '~.'    =>      sub { },

  # overload key: mutators

  '++'    =>      sub { $_[0] -> binc() },

  '--'    =>      sub { $_[0] -> bdec() },

  # overload key: func

  'atan2' =>      sub { $_[2] ? ref($_[0]) -> new($_[1]) -> batan2($_[0])
                              : $_[0] -> copy() -> batan2($_[1]); },

  'cos'   =>      sub { $_[0] -> copy -> bcos(); },

  'sin'   =>      sub { $_[0] -> copy -> bsin(); },

  'exp'   =>      sub { $_[0] -> copy() -> bexp($_[1]); },

  'abs'   =>      sub { $_[0] -> copy() -> babs(); },

  'log'   =>      sub { $_[0] -> copy() -> blog(); },

  'sqrt'  =>      sub { $_[0] -> copy() -> bsqrt(); },

  'int'   =>      sub { $_[0] -> copy() -> bint(); },

  # overload key: conversion

  'bool'  =>      sub { $_[0] -> is_zero() ? '' : 1; },

  '""'    =>      sub { $_[0] -> bstr(); },

  '0+'    =>      sub { $_[0] -> numify(); },

  '='     =>      sub { $_[0]->copy(); },

  ;

##############################################################################
# global constants, flags and accessory

# These vars are public, but their direct usage is not recommended, use the
# accessor methods instead

our $round_mode = 'even'; # one of 'even', 'odd', '+inf', '-inf', 'zero', 'trunc' or 'common'
our $accuracy   = undef;
our $precision  = undef;
our $div_scale  = 40;
our $upgrade    = undef;                    # default is no upgrade
our $downgrade  = undef;                    # default is no downgrade

# These are internally, and not to be used from the outside at all

our $_trap_nan = 0;                         # are NaNs ok? set w/ config()
our $_trap_inf = 0;                         # are infs ok? set w/ config()

my $nan = 'NaN';                        # constants for easier life

my $CALC = 'Math::BigInt::Calc';        # module to do the low level math
                                        # default is Calc.pm
my $IMPORT = 0;                         # was import() called yet?
                                        # used to make require work
my %WARN;                               # warn only once for low-level libs
my %CAN;                                # cache for $CALC->can(...)
my %CALLBACKS;                          # callbacks to notify on lib loads
my $EMU_LIB = 'Math/BigInt/CalcEmu.pm'; # emulate low-level math

##############################################################################
# the old code had $rnd_mode, so we need to support it, too

our $rnd_mode   = 'even';

sub TIESCALAR {
    my ($class) = @_;
    bless \$round_mode, $class;
}

sub FETCH {
    return $round_mode;
}

sub STORE {
    $rnd_mode = $_[0]->round_mode($_[1]);
}

BEGIN {
    # tie to enable $rnd_mode to work transparently
    tie $rnd_mode, 'Math::BigInt';

    # set up some handy alias names
    *as_int = \&as_number;
    *is_pos = \&is_positive;
    *is_neg = \&is_negative;
}

###############################################################################
# Configuration methods
###############################################################################

sub round_mode {
    no strict 'refs';
    # make Class->round_mode() work
    my $self = shift;
    my $class = ref($self) || $self || __PACKAGE__;
    if (defined $_[0]) {
        my $m = shift;
        if ($m !~ /^(even|odd|\+inf|\-inf|zero|trunc|common)$/) {
            Carp::croak("Unknown round mode '$m'");
        }
        return ${"${class}::round_mode"} = $m;
    }
    ${"${class}::round_mode"};
}

sub upgrade {
    no strict 'refs';
    # make Class->upgrade() work
    my $self = shift;
    my $class = ref($self) || $self || __PACKAGE__;
    # need to set new value?
    if (@_ > 0) {
        return ${"${class}::upgrade"} = $_[0];
    }
    ${"${class}::upgrade"};
}

sub downgrade {
    no strict 'refs';
    # make Class->downgrade() work
    my $self = shift;
    my $class = ref($self) || $self || __PACKAGE__;
    # need to set new value?
    if (@_ > 0) {
        return ${"${class}::downgrade"} = $_[0];
    }
    ${"${class}::downgrade"};
}

sub div_scale {
    no strict 'refs';
    # make Class->div_scale() work
    my $self = shift;
    my $class = ref($self) || $self || __PACKAGE__;
    if (defined $_[0]) {
        if ($_[0] < 0) {
            Carp::croak('div_scale must be greater than zero');
        }
        ${"${class}::div_scale"} = $_[0];
    }
    ${"${class}::div_scale"};
}

sub accuracy {
    # $x->accuracy($a);           ref($x) $a
    # $x->accuracy();             ref($x)
    # Class->accuracy();          class
    # Class->accuracy($a);        class $a

    my $x = shift;
    my $class = ref($x) || $x || __PACKAGE__;

    no strict 'refs';
    # need to set new value?
    if (@_ > 0) {
        my $a = shift;
        # convert objects to scalars to avoid deep recursion. If object doesn't
        # have numify(), then hopefully it will have overloading for int() and
        # boolean test without wandering into a deep recursion path...
        $a = $a->numify() if ref($a) && $a->can('numify');

        if (defined $a) {
            # also croak on non-numerical
            if (!$a || $a <= 0) {
                Carp::croak('Argument to accuracy must be greater than zero');
            }
            if (int($a) != $a) {
                Carp::croak('Argument to accuracy must be an integer');
            }
        }
        if (ref($x)) {
            # $object->accuracy() or fallback to global
            $x->bround($a) if $a; # not for undef, 0
            $x->{_a} = $a;        # set/overwrite, even if not rounded
            delete $x->{_p};      # clear P
            $a = ${"${class}::accuracy"} unless defined $a; # proper return value
        } else {
            ${"${class}::accuracy"} = $a; # set global A
            ${"${class}::precision"} = undef; # clear global P
        }
        return $a;              # shortcut
    }

    my $a;
    # $object->accuracy() or fallback to global
    $a = $x->{_a} if ref($x);
    # but don't return global undef, when $x's accuracy is 0!
    $a = ${"${class}::accuracy"} if !defined $a;
    $a;
}

sub precision {
    # $x->precision($p);          ref($x) $p
    # $x->precision();            ref($x)
    # Class->precision();         class
    # Class->precision($p);       class $p

    my $x = shift;
    my $class = ref($x) || $x || __PACKAGE__;

    no strict 'refs';
    if (@_ > 0) {
        my $p = shift;
        # convert objects to scalars to avoid deep recursion. If object doesn't
        # have numify(), then hopefully it will have overloading for int() and
        # boolean test without wandering into a deep recursion path...
        $p = $p->numify() if ref($p) && $p->can('numify');
        if ((defined $p) && (int($p) != $p)) {
            Carp::croak('Argument to precision must be an integer');
        }
        if (ref($x)) {
            # $object->precision() or fallback to global
            $x->bfround($p) if $p; # not for undef, 0
            $x->{_p} = $p;         # set/overwrite, even if not rounded
            delete $x->{_a};       # clear A
            $p = ${"${class}::precision"} unless defined $p; # proper return value
        } else {
            ${"${class}::precision"} = $p; # set global P
            ${"${class}::accuracy"} = undef; # clear global A
        }
        return $p;              # shortcut
    }

    my $p;
    # $object->precision() or fallback to global
    $p = $x->{_p} if ref($x);
    # but don't return global undef, when $x's precision is 0!
    $p = ${"${class}::precision"} if !defined $p;
    $p;
}

sub config {
    # return (or set) configuration data as hash ref
    my $class = shift || __PACKAGE__;

    no strict 'refs';
    if (@_ > 1 || (@_ == 1 && (ref($_[0]) eq 'HASH'))) {
        # try to set given options as arguments from hash

        my $args = $_[0];
        if (ref($args) ne 'HASH') {
            $args = { @_ };
        }
        # these values can be "set"
        my $set_args = {};
        foreach my $key (qw/
                               accuracy precision
                               round_mode div_scale
                               upgrade downgrade
                               trap_inf trap_nan
                           /)
        {
            $set_args->{$key} = $args->{$key} if exists $args->{$key};
            delete $args->{$key};
        }
        if (keys %$args > 0) {
            Carp::croak("Illegal key(s) '", join("', '", keys %$args),
                        "' passed to $class\->config()");
        }
        foreach my $key (keys %$set_args) {
            if ($key =~ /^trap_(inf|nan)\z/) {
                ${"${class}::_trap_$1"} = ($set_args->{"trap_$1"} ? 1 : 0);
                next;
            }
            # use a call instead of just setting the $variable to check argument
            $class->$key($set_args->{$key});
        }
    }

    # now return actual configuration

    my $cfg = {
               lib         => $CALC,
               lib_version => ${"${CALC}::VERSION"},
               class       => $class,
               trap_nan    => ${"${class}::_trap_nan"},
               trap_inf    => ${"${class}::_trap_inf"},
               version     => ${"${class}::VERSION"},
              };
    foreach my $key (qw/
                           accuracy precision
                           round_mode div_scale
                           upgrade downgrade
                       /)
    {
        $cfg->{$key} = ${"${class}::$key"};
    }
    if (@_ == 1 && (ref($_[0]) ne 'HASH')) {
        # calls of the style config('lib') return just this value
        return $cfg->{$_[0]};
    }
    $cfg;
}

sub _scale_a {
    # select accuracy parameter based on precedence,
    # used by bround() and bfround(), may return undef for scale (means no op)
    my ($x, $scale, $mode) = @_;

    $scale = $x->{_a} unless defined $scale;

    no strict 'refs';
    my $class = ref($x);

    $scale = ${ $class . '::accuracy' } unless defined $scale;
    $mode = ${ $class . '::round_mode' } unless defined $mode;

    if (defined $scale) {
        $scale = $scale->can('numify') ? $scale->numify()
                                       : "$scale" if ref($scale);
        $scale = int($scale);
    }

    ($scale, $mode);
}

sub _scale_p {
    # select precision parameter based on precedence,
    # used by bround() and bfround(), may return undef for scale (means no op)
    my ($x, $scale, $mode) = @_;

    $scale = $x->{_p} unless defined $scale;

    no strict 'refs';
    my $class = ref($x);

    $scale = ${ $class . '::precision' } unless defined $scale;
    $mode = ${ $class . '::round_mode' } unless defined $mode;

    if (defined $scale) {
        $scale = $scale->can('numify') ? $scale->numify()
                                       : "$scale" if ref($scale);
        $scale = int($scale);
    }

    ($scale, $mode);
}

###############################################################################
# Constructor methods
###############################################################################

sub new {
    # Create a new Math::BigInt object from a string or another Math::BigInt
    # object. See hash keys documented at top.

    # The argument could be an object, so avoid ||, && etc. on it. This would
    # cause costly overloaded code to be called. The only allowed ops are ref()
    # and defined.

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    # The POD says:
    #
    # "Currently, Math::BigInt->new() defaults to 0, while Math::BigInt->new('')
    # results in 'NaN'. This might change in the future, so use always the
    # following explicit forms to get a zero or NaN:
    #     $zero = Math::BigInt->bzero();
    #     $nan = Math::BigInt->bnan();
    #
    # But although this use has been discouraged for more than 10 years, people
    # apparently still use it, so we still support it.

    return $self->bzero() unless @_;

    my ($wanted, $a, $p, $r) = @_;

    # Always return a new object, so it called as an instance method, copy the
    # invocand, and if called as a class method, initialize a new object.

    $self = $selfref ? $self -> copy()
                     : bless {}, $class;

    unless (defined $wanted) {
        #Carp::carp("Use of uninitialized value in new()");
        return $self->bzero($a, $p, $r);
    }

    if (ref($wanted) && $wanted->isa($class)) {         # MBI or subclass
        # Using "$copy = $wanted -> copy()" here fails some tests. Fixme!
        my $copy = $class -> copy($wanted);
        if ($selfref) {
            %$self = %$copy;
        } else {
            $self = $copy;
        }
        return $self;
    }

    $class->import() if $IMPORT == 0;           # make require work

    # Shortcut for non-zero scalar integers with no non-zero exponent.

    if (!ref($wanted) &&
        $wanted =~ / ^
                     ([+-]?)            # optional sign
                     ([1-9][0-9]*)      # non-zero significand
                     (\.0*)?            # ... with optional zero fraction
                     ([Ee][+-]?0+)?     # optional zero exponent
                     \z
                   /x)
    {
        my $sgn = $1;
        my $abs = $2;
        $self->{sign} = $sgn || '+';
        $self->{value} = $CALC->_new($abs);

        no strict 'refs';
        if (defined($a) || defined($p)
            || defined(${"${class}::precision"})
            || defined(${"${class}::accuracy"}))
        {
            $self->round($a, $p, $r)
              unless @_ >= 3 && !defined $a && !defined $p;
        }

        return $self;
    }

    # Handle Infs.

    if ($wanted =~ /^\s*([+-]?)inf(inity)?\s*\z/i) {
        my $sgn = $1 || '+';
        $self->{sign} = $sgn . 'inf';   # set a default sign for bstr()
        return $class->binf($sgn);
    }

    # Handle explicit NaNs (not the ones returned due to invalid input).

    if ($wanted =~ /^\s*([+-]?)nan\s*\z/i) {
        $self = $class -> bnan();
        $self->round($a, $p, $r) unless @_ >= 3 && !defined $a && !defined $p;
        return $self;
    }

    # Handle hexadecimal numbers.

    if ($wanted =~ /^\s*[+-]?0[Xx]/) {
        $self = $class -> from_hex($wanted);
        $self->round($a, $p, $r) unless @_ >= 3 && !defined $a && !defined $p;
        return $self;
    }

    # Handle binary numbers.

    if ($wanted =~ /^\s*[+-]?0[Bb]/) {
        $self = $class -> from_bin($wanted);
        $self->round($a, $p, $r) unless @_ >= 3 && !defined $a && !defined $p;
        return $self;
    }

    # Split string into mantissa, exponent, integer, fraction, value, and sign.
    my ($mis, $miv, $mfv, $es, $ev) = _split($wanted);
    if (!ref $mis) {
        if ($_trap_nan) {
            Carp::croak("$wanted is not a number in $class");
        }
        $self->{value} = $CALC->_zero();
        $self->{sign} = $nan;
        return $self;
    }

    if (!ref $miv) {
        # _from_hex or _from_bin
        $self->{value} = $mis->{value};
        $self->{sign} = $mis->{sign};
        return $self;   # throw away $mis
    }

    # Make integer from mantissa by adjusting exponent, then convert to a
    # Math::BigInt.
    $self->{sign} = $$mis;           # store sign
    $self->{value} = $CALC->_zero(); # for all the NaN cases
    my $e = int("$$es$$ev");         # exponent (avoid recursion)
    if ($e > 0) {
        my $diff = $e - CORE::length($$mfv);
        if ($diff < 0) {         # Not integer
            if ($_trap_nan) {
                Carp::croak("$wanted not an integer in $class");
            }
            #print "NOI 1\n";
            return $upgrade->new($wanted, $a, $p, $r) if defined $upgrade;
            $self->{sign} = $nan;
        } else {                 # diff >= 0
            # adjust fraction and add it to value
            #print "diff > 0 $$miv\n";
            $$miv = $$miv . ($$mfv . '0' x $diff);
        }
    }

    else {
        if ($$mfv ne '') {       # e <= 0
            # fraction and negative/zero E => NOI
            if ($_trap_nan) {
                Carp::croak("$wanted not an integer in $class");
            }
            #print "NOI 2 \$\$mfv '$$mfv'\n";
            return $upgrade->new($wanted, $a, $p, $r) if defined $upgrade;
            $self->{sign} = $nan;
        } elsif ($e < 0) {
            # xE-y, and empty mfv
            # Split the mantissa at the decimal point. E.g., if
            # $$miv = 12345 and $e = -2, then $frac = 45 and $$miv = 123.

            my $frac = substr($$miv, $e); # $frac is fraction part
            substr($$miv, $e) = "";       # $$miv is now integer part

            if ($frac =~ /[^0]/) {
                if ($_trap_nan) {
                    Carp::croak("$wanted not an integer in $class");
                }
                #print "NOI 3\n";
                return $upgrade->new($wanted, $a, $p, $r) if defined $upgrade;
                $self->{sign} = $nan;
            }
        }
    }

    unless ($self->{sign} eq $nan) {
        $self->{sign} = '+' if $$miv eq '0';            # normalize -0 => +0
        $self->{value} = $CALC->_new($$miv) if $self->{sign} =~ /^[+-]$/;
    }

    # If any of the globals are set, use them to round, and store them inside
    # $self. Do not round for new($x, undef, undef) since that is used by MBF
    # to signal no rounding.

    $self->round($a, $p, $r) unless @_ >= 3 && !defined $a && !defined $p;
    $self;
}

# Create a Math::BigInt from a hexadecimal string.

sub from_hex {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('from_hex');

    my $str = shift;

    # If called as a class method, initialize a new object.

    $self = $class -> bzero() unless $selfref;

    if ($str =~ s/
                     ^
                     \s*
                     ( [+-]? )
                     (0?x)?
                     (
                         [0-9a-fA-F]*
                         ( _ [0-9a-fA-F]+ )*
                     )
                     \s*
                     $
                 //x)
    {
        # Get a "clean" version of the string, i.e., non-emtpy and with no
        # underscores or invalid characters.

        my $sign = $1;
        my $chrs = $3;
        $chrs =~ tr/_//d;
        $chrs = '0' unless CORE::length $chrs;

        # The library method requires a prefix.

        $self->{value} = $CALC->_from_hex('0x' . $chrs);

        # Place the sign.

        $self->{sign} = $sign eq '-' && ! $CALC->_is_zero($self->{value})
                          ? '-' : '+';

        return $self;
    }

    # CORE::hex() parses as much as it can, and ignores any trailing garbage.
    # For backwards compatibility, we return NaN.

    return $self->bnan();
}

# Create a Math::BigInt from an octal string.

sub from_oct {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('from_oct');

    my $str = shift;

    # If called as a class method, initialize a new object.

    $self = $class -> bzero() unless $selfref;

    if ($str =~ s/
                     ^
                     \s*
                     ( [+-]? )
                     (
                         [0-7]*
                         ( _ [0-7]+ )*
                     )
                     \s*
                     $
                 //x)
    {
        # Get a "clean" version of the string, i.e., non-emtpy and with no
        # underscores or invalid characters.

        my $sign = $1;
        my $chrs = $2;
        $chrs =~ tr/_//d;
        $chrs = '0' unless CORE::length $chrs;

        # The library method requires a prefix.

        $self->{value} = $CALC->_from_oct('0' . $chrs);

        # Place the sign.

        $self->{sign} = $sign eq '-' && ! $CALC->_is_zero($self->{value})
                          ? '-' : '+';

        return $self;
    }

    # CORE::oct() parses as much as it can, and ignores any trailing garbage.
    # For backwards compatibility, we return NaN.

    return $self->bnan();
}

# Create a Math::BigInt from a binary string.

sub from_bin {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('from_bin');

    my $str = shift;

    # If called as a class method, initialize a new object.

    $self = $class -> bzero() unless $selfref;

    if ($str =~ s/
                     ^
                     \s*
                     ( [+-]? )
                     (0?b)?
                     (
                         [01]*
                         ( _ [01]+ )*
                     )
                     \s*
                     $
                 //x)
    {
        # Get a "clean" version of the string, i.e., non-emtpy and with no
        # underscores or invalid characters.

        my $sign = $1;
        my $chrs = $3;
        $chrs =~ tr/_//d;
        $chrs = '0' unless CORE::length $chrs;

        # The library method requires a prefix.

        $self->{value} = $CALC->_from_bin('0b' . $chrs);

        # Place the sign.

        $self->{sign} = $sign eq '-' && ! $CALC->_is_zero($self->{value})
                          ? '-' : '+';

        return $self;
    }

    # For consistency with from_hex() and from_oct(), we return NaN when the
    # input is invalid.

    return $self->bnan();
}

# Create a Math::BigInt from a byte string.

sub from_bytes {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('from_bytes');

    Carp::croak("from_bytes() requires a newer version of the $CALC library.")
        unless $CALC->can('_from_bytes');

    my $str = shift;

    # If called as a class method, initialize a new object.

    $self = $class -> bzero() unless $selfref;
    $self -> {sign}  = '+';
    $self -> {value} = $CALC -> _from_bytes($str);
    return $self;
}

sub bzero {
    # create/assign '+0'

    if (@_ == 0) {
        #Carp::carp("Using bzero() as a function is deprecated;",
        #           " use bzero() as a method instead");
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $self->import() if $IMPORT == 0;            # make require work

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('bzero');

    $self = bless {}, $class unless $selfref;

    $self->{sign} = '+';
    $self->{value} = $CALC->_zero();

    if (@_ > 0) {
        if (@_ > 3) {
            # call like: $x->bzero($a, $p, $r, $y, ...);
            ($self, $self->{_a}, $self->{_p}) = $self->_find_round_parameters(@_);
        } else {
            # call like: $x->bzero($a, $p, $r);
            $self->{_a} = $_[0]
              if !defined $self->{_a} || (defined $_[0] && $_[0] > $self->{_a});
            $self->{_p} = $_[1]
              if !defined $self->{_p} || (defined $_[1] && $_[1] > $self->{_p});
        }
    }

    return $self;
}

sub bone {
    # Create or assign '+1' (or -1 if given sign '-').

    if (@_ == 0 || (defined($_[0]) && ($_[0] eq '+' || $_[0] eq '-'))) {
        #Carp::carp("Using bone() as a function is deprecated;",
        #           " use bone() as a method instead");
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    $self->import() if $IMPORT == 0;            # make require work

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('bone');

    my $sign = shift;
    $sign = defined $sign && $sign =~ /^\s*-/ ? "-" : "+";

    $self = bless {}, $class unless $selfref;

    $self->{sign}  = $sign;
    $self->{value} = $CALC->_one();

    if (@_ > 0) {
        if (@_ > 3) {
            # call like: $x->bone($sign, $a, $p, $r, $y, ...);
            ($self, $self->{_a}, $self->{_p}) = $self->_find_round_parameters(@_);
        } else {
            # call like: $x->bone($sign, $a, $p, $r);
            $self->{_a} = $_[0]
              if !defined $self->{_a} || (defined $_[0] && $_[0] > $self->{_a});
            $self->{_p} = $_[1]
              if !defined $self->{_p} || (defined $_[1] && $_[1] > $self->{_p});
        }
    }

    return $self;
}

sub binf {
    # create/assign a '+inf' or '-inf'

    if (@_ == 0 || (defined($_[0]) && !ref($_[0]) &&
                    $_[0] =~ /^\s*[+-](inf(inity)?)?\s*$/))
    {
        #Carp::carp("Using binf() as a function is deprecated;",
        #           " use binf() as a method instead");
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    {
        no strict 'refs';
        if (${"${class}::_trap_inf"}) {
            Carp::croak("Tried to create +-inf in $class->binf()");
        }
    }

    $self->import() if $IMPORT == 0;            # make require work

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('binf');

    my $sign = shift;
    $sign = defined $sign && $sign =~ /^\s*-/ ? "-" : "+";

    $self = bless {}, $class unless $selfref;

    $self -> {sign}  = $sign . 'inf';
    $self -> {value} = $CALC -> _zero();

    return $self;
}

sub bnan {
    # create/assign a 'NaN'

    if (@_ == 0) {
        #Carp::carp("Using bnan() as a function is deprecated;",
        #           " use bnan() as a method instead");
        unshift @_, __PACKAGE__;
    }

    my $self    = shift;
    my $selfref = ref($self);
    my $class   = $selfref || $self;

    {
        no strict 'refs';
        if (${"${class}::_trap_nan"}) {
            Carp::croak("Tried to create NaN in $class->bnan()");
        }
    }

    $self->import() if $IMPORT == 0;            # make require work

    # Don't modify constant (read-only) objects.

    return if $selfref && $self->modify('bnan');

    $self = bless {}, $class unless $selfref;

    $self -> {sign}  = $nan;
    $self -> {value} = $CALC -> _zero();

    return $self;
}

sub bpi {
    # Calculate PI to N digits. Unless upgrading is in effect, returns the
    # result truncated to an integer, that is, always returns '3'.
    my ($self, $n) = @_;
    if (@_ == 1) {
        # called like Math::BigInt::bpi(10);
        $n = $self;
        $self = $class;
    }
    $self = ref($self) if ref($self);

    return $upgrade->new($n) if defined $upgrade;

    # hard-wired to "3"
    $self->new(3);
}

sub copy {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    # If called as a class method, the object to copy is the next argument.

    $self = shift() unless $selfref;

    my $copy = bless {}, $class;

    $copy->{sign}  = $self->{sign};
    $copy->{value} = $CALC->_copy($self->{value});
    $copy->{_a}    = $self->{_a} if exists $self->{_a};
    $copy->{_p}    = $self->{_p} if exists $self->{_p};

    return $copy;
}

sub as_number {
    # An object might be asked to return itself as bigint on certain overloaded
    # operations. This does exactly this, so that sub classes can simple inherit
    # it or override with their own integer conversion routine.
    $_[0]->copy();
}

###############################################################################
# Boolean methods
###############################################################################

sub is_zero {
    # return true if arg (BINT or num_str) is zero (array '+', '0')
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    return 0 if $x->{sign} !~ /^\+$/; # -, NaN & +-inf aren't
    $CALC->_is_zero($x->{value});
}

sub is_one {
    # return true if arg (BINT or num_str) is +1, or -1 if sign is given
    my ($class, $x, $sign) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    $sign = '+' if !defined $sign || $sign ne '-';

    return 0 if $x->{sign} ne $sign; # -1 != +1, NaN, +-inf aren't either
    $CALC->_is_one($x->{value});
}

sub is_finite {
    my $x = shift;
    return $x->{sign} eq '+' || $x->{sign} eq '-';
}

sub is_inf {
    # return true if arg (BINT or num_str) is +-inf
    my ($class, $x, $sign) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    if (defined $sign) {
        $sign = '[+-]inf' if $sign eq ''; # +- doesn't matter, only that's inf
        $sign = "[$1]inf" if $sign =~ /^([+-])(inf)?$/; # extract '+' or '-'
        return $x->{sign} =~ /^$sign$/ ? 1 : 0;
    }
    $x->{sign} =~ /^[+-]inf$/ ? 1 : 0; # only +-inf is infinity
}

sub is_nan {
    # return true if arg (BINT or num_str) is NaN
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    $x->{sign} eq $nan ? 1 : 0;
}

sub is_positive {
    # return true when arg (BINT or num_str) is positive (> 0)
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    return 1 if $x->{sign} eq '+inf'; # +inf is positive

    # 0+ is neither positive nor negative
    ($x->{sign} eq '+' && !$x->is_zero()) ? 1 : 0;
}

sub is_negative {
    # return true when arg (BINT or num_str) is negative (< 0)
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    $x->{sign} =~ /^-/ ? 1 : 0; # -inf is negative, but NaN is not
}

sub is_odd {
    # return true when arg (BINT or num_str) is odd, false for even
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    return 0 if $x->{sign} !~ /^[+-]$/; # NaN & +-inf aren't
    $CALC->_is_odd($x->{value});
}

sub is_even {
    # return true when arg (BINT or num_str) is even, false for odd
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    return 0 if $x->{sign} !~ /^[+-]$/; # NaN & +-inf aren't
    $CALC->_is_even($x->{value});
}

sub is_int {
    # return true when arg (BINT or num_str) is an integer
    # always true for Math::BigInt, but different for Math::BigFloat objects
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    $x->{sign} =~ /^[+-]$/ ? 1 : 0; # inf/-inf/NaN aren't
}

###############################################################################
# Comparison methods
###############################################################################

sub bcmp {
    # Compares 2 values.  Returns one of undef, <0, =0, >0. (suitable for sort)
    # (BINT or num_str, BINT or num_str) return cond_code

    # set up parameters
    my ($class, $x, $y) = ref($_[0]) && ref($_[0]) eq ref($_[1])
                        ? (ref($_[0]), @_)
                        : objectify(2, @_);

    return $upgrade->bcmp($x, $y) if defined $upgrade &&
      ((!$x->isa($class)) || (!$y->isa($class)));

    if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/)) {
        # handle +-inf and NaN
        return undef if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
        return 0 if $x->{sign} eq $y->{sign} && $x->{sign} =~ /^[+-]inf$/;
        return +1 if $x->{sign} eq '+inf';
        return -1 if $x->{sign} eq '-inf';
        return -1 if $y->{sign} eq '+inf';
        return +1;
    }
    # check sign for speed first
    return 1 if $x->{sign} eq '+' && $y->{sign} eq '-'; # does also 0 <=> -y
    return -1 if $x->{sign} eq '-' && $y->{sign} eq '+'; # does also -x <=> 0

    # have same sign, so compare absolute values.  Don't make tests for zero
    # here because it's actually slower than testing in Calc (especially w/ Pari
    # et al)

    # post-normalized compare for internal use (honors signs)
    if ($x->{sign} eq '+') {
        # $x and $y both > 0
        return $CALC->_acmp($x->{value}, $y->{value});
    }

    # $x && $y both < 0
    $CALC->_acmp($y->{value}, $x->{value}); # swapped acmp (lib returns 0, 1, -1)
}

sub bacmp {
    # Compares 2 values, ignoring their signs.
    # Returns one of undef, <0, =0, >0. (suitable for sort)
    # (BINT, BINT) return cond_code

    # set up parameters
    my ($class, $x, $y) = ref($_[0]) && ref($_[0]) eq ref($_[1])
                        ? (ref($_[0]), @_)
                        : objectify(2, @_);

    return $upgrade->bacmp($x, $y) if defined $upgrade &&
      ((!$x->isa($class)) || (!$y->isa($class)));

    if (($x->{sign} !~ /^[+-]$/) || ($y->{sign} !~ /^[+-]$/)) {
        # handle +-inf and NaN
        return undef if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
        return 0 if $x->{sign} =~ /^[+-]inf$/ && $y->{sign} =~ /^[+-]inf$/;
        return 1 if $x->{sign} =~ /^[+-]inf$/ && $y->{sign} !~ /^[+-]inf$/;
        return -1;
    }
    $CALC->_acmp($x->{value}, $y->{value}); # lib does only 0, 1, -1
}

sub beq {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    Carp::croak 'beq() is an instance method, not a class method' unless $selfref;
    Carp::croak 'Wrong number of arguments for beq()' unless @_ == 1;

    my $cmp = $self -> bcmp(shift);
    return defined($cmp) && ! $cmp;
}

sub bne {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    Carp::croak 'bne() is an instance method, not a class method' unless $selfref;
    Carp::croak 'Wrong number of arguments for bne()' unless @_ == 1;

    my $cmp = $self -> bcmp(shift);
    return defined($cmp) && ! $cmp ? '' : 1;
}

sub blt {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    Carp::croak 'blt() is an instance method, not a class method' unless $selfref;
    Carp::croak 'Wrong number of arguments for blt()' unless @_ == 1;

    my $cmp = $self -> bcmp(shift);
    return defined($cmp) && $cmp < 0;
}

sub ble {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    Carp::croak 'ble() is an instance method, not a class method' unless $selfref;
    Carp::croak 'Wrong number of arguments for ble()' unless @_ == 1;

    my $cmp = $self -> bcmp(shift);
    return defined($cmp) && $cmp <= 0;
}

sub bgt {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    Carp::croak 'bgt() is an instance method, not a class method' unless $selfref;
    Carp::croak 'Wrong number of arguments for bgt()' unless @_ == 1;

    my $cmp = $self -> bcmp(shift);
    return defined($cmp) && $cmp > 0;
}

sub bge {
    my $self    = shift;
    my $selfref = ref $self;
    my $class   = $selfref || $self;

    Carp::croak 'bge() is an instance method, not a class method'
        unless $selfref;
    Carp::croak 'Wrong number of arguments for bge()' unless @_ == 1;

    my $cmp = $self -> bcmp(shift);
    return defined($cmp) && $cmp >= 0;
}

###############################################################################
# Arithmetic methods
###############################################################################

sub bneg {
    # (BINT or num_str) return BINT
    # negate number or make a negated number from string
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    return $x if $x->modify('bneg');

    # for +0 do not negate (to have always normalized +0). Does nothing for 'NaN'
    $x->{sign} =~ tr/+-/-+/ unless ($x->{sign} eq '+' && $CALC->_is_zero($x->{value}));
    $x;
}

sub babs {
    # (BINT or num_str) return BINT
    # make number absolute, or return absolute BINT from string
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    return $x if $x->modify('babs');
    # post-normalized abs for internal use (does nothing for NaN)
    $x->{sign} =~ s/^-/+/;
    $x;
}

sub bsgn {
    # Signum function.

    my $self = shift;

    return $self if $self->modify('bsgn');

    return $self -> bone("+") if $self -> is_pos();
    return $self -> bone("-") if $self -> is_neg();
    return $self;               # zero or NaN
}

sub bnorm {
    # (numstr or BINT) return BINT
    # Normalize number -- no-op here
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);
    $x;
}

sub binc {
    # increment arg by one
    my ($class, $x, $a, $p, $r) = ref($_[0]) ? (ref($_[0]), @_) : objectify(1, @_);
    return $x if $x->modify('binc');

    if ($x->{sign} eq '+') {
        $x->{value} = $CALC->_inc($x->{value});
        return $x->round($a, $p, $r);
    } elsif ($x->{sign} eq '-') {
        $x->{value} = $CALC->_dec($x->{value});
        $x->{sign} = '+' if $CALC->_is_zero($x->{value}); # -1 +1 => -0 => +0
        return $x->round($a, $p, $r);
    }
    # inf, nan handling etc
    $x->badd($class->bone(), $a, $p, $r); # badd does round
}

sub bdec {
    # decrement arg by one
    my ($class, $x, @r) = ref($_[0]) ? (ref($_[0]), @_) : objectify(1, @_);
    return $x if $x->modify('bdec');

    if ($x->{sign} eq '-') {
        # x already < 0
        $x->{value} = $CALC->_inc($x->{value});
    } else {
        return $x->badd($class->bone('-'), @r)
          unless $x->{sign} eq '+'; # inf or NaN
        # >= 0
        if ($CALC->_is_zero($x->{value})) {
            # == 0
            $x->{value} = $CALC->_one();
            $x->{sign} = '-'; # 0 => -1
        } else {
            # > 0
            $x->{value} = $CALC->_dec($x->{value});
        }
    }
    $x->round(@r);
}

#sub bstrcmp {
#    my $self    = shift;
#    my $selfref = ref $self;
#    my $class   = $selfref || $self;
#
#    Carp::croak 'bstrcmp() is an instance method, not a class method'
#        unless $selfref;
#    Carp::croak 'Wrong number of arguments for bstrcmp()' unless @_ == 1;
#
#    return $self -> bstr() CORE::cmp shift;
#}
#
#sub bstreq {
#    my $self    = shift;
#    my $selfref = ref $self;
#    my $class   = $selfref || $self;
#
#    Carp::croak 'bstreq() is an instance method, not a class method'
#        unless $selfref;
#    Carp::croak 'Wrong number of arguments for bstreq()' unless @_ == 1;
#
#    my $cmp = $self -> bstrcmp(shift);
#    return defined($cmp) && ! $cmp;
#}
#
#sub bstrne {
#    my $self    = shift;
#    my $selfref = ref $self;
#    my $class   = $selfref || $self;
#
#    Carp::croak 'bstrne() is an instance method, not a class method'
#        unless $selfref;
#    Carp::croak 'Wrong number of arguments for bstrne()' unless @_ == 1;
#
#    my $cmp = $self -> bstrcmp(shift);
#    return defined($cmp) && ! $cmp ? '' : 1;
#}
#
#sub bstrlt {
#    my $self    = shift;
#    my $selfref = ref $self;
#    my $class   = $selfref || $self;
#
#    Carp::croak 'bstrlt() is an instance method, not a class method'
#        unless $selfref;
#    Carp::croak 'Wrong number of arguments for bstrlt()' unless @_ == 1;
#
#    my $cmp = $self -> bstrcmp(shift);
#    return defined($cmp) && $cmp < 0;
#}
#
#sub bstrle {
#    my $self    = shift;
#    my $selfref = ref $self;
#    my $class   = $selfref || $self;
#
#    Carp::croak 'bstrle() is an instance method, not a class method'
#        unless $selfref;
#    Carp::croak 'Wrong number of arguments for bstrle()' unless @_ == 1;
#
#    my $cmp = $self -> bstrcmp(shift);
#    return defined($cmp) && $cmp <= 0;
#}
#
#sub bstrgt {
#    my $self    = shift;
#    my $selfref = ref $self;
#    my $class   = $selfref || $self;
#
#    Carp::croak 'bstrgt() is an instance method, not a class method'
#        unless $selfref;
#    Carp::croak 'Wrong number of arguments for bstrgt()' unless @_ == 1;
#
#    my $cmp = $self -> bstrcmp(shift);
#    return defined($cmp) && $cmp > 0;
#}
#
#sub bstrge {
#    my $self    = shift;
#    my $selfref = ref $self;
#    my $class   = $selfref || $self;
#
#    Carp::croak 'bstrge() is an instance method, not a class method'
#        unless $selfref;
#    Carp::croak 'Wrong number of arguments for bstrge()' unless @_ == 1;
#
#    my $cmp = $self -> bstrcmp(shift);
#    return defined($cmp) && $cmp >= 0;
#}

sub badd {
    # add second arg (BINT or string) to first (BINT) (modifies first)
    # return result as BINT

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('badd');
    return $upgrade->badd($upgrade->new($x), $upgrade->new($y), @r) if defined $upgrade &&
      ((!$x->isa($class)) || (!$y->isa($class)));

    $r[3] = $y;                 # no push!
    # inf and NaN handling
    if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/) {
        # NaN first
        return $x->bnan() if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));
        # inf handling
        if (($x->{sign} =~ /^[+-]inf$/) && ($y->{sign} =~ /^[+-]inf$/)) {
            # +inf++inf or -inf+-inf => same, rest is NaN
            return $x if $x->{sign} eq $y->{sign};
            return $x->bnan();
        }
        # +-inf + something => +inf
        # something +-inf => +-inf
        $x->{sign} = $y->{sign}, return $x if $y->{sign} =~ /^[+-]inf$/;
        return $x;
    }

    my ($sx, $sy) = ($x->{sign}, $y->{sign});  # get signs

    if ($sx eq $sy) {
        $x->{value} = $CALC->_add($x->{value}, $y->{value}); # same sign, abs add
    } else {
        my $a = $CALC->_acmp ($y->{value}, $x->{value}); # absolute compare
        if ($a > 0) {
            $x->{value} = $CALC->_sub($y->{value}, $x->{value}, 1); # abs sub w/ swap
            $x->{sign} = $sy;
        } elsif ($a == 0) {
            # speedup, if equal, set result to 0
            $x->{value} = $CALC->_zero();
            $x->{sign} = '+';
        } else                  # a < 0
        {
            $x->{value} = $CALC->_sub($x->{value}, $y->{value}); # abs sub
        }
    }
    $x->round(@r);
}

sub bsub {
    # (BINT or num_str, BINT or num_str) return BINT
    # subtract second arg from first, modify first

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);

    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x -> modify('bsub');

    return $upgrade -> new($x) -> bsub($upgrade -> new($y), @r)
      if defined $upgrade && (!$x -> isa($class) || !$y -> isa($class));

    return $x -> round(@r) if $y -> is_zero();

    # To correctly handle the lone special case $x -> bsub($x), we note the
    # sign of $x, then flip the sign from $y, and if the sign of $x did change,
    # too, then we caught the special case:

    my $xsign = $x -> {sign};
    $y -> {sign} =~ tr/+-/-+/;  # does nothing for NaN
    if ($xsign ne $x -> {sign}) {
        # special case of $x -> bsub($x) results in 0
        return $x -> bzero(@r) if $xsign =~ /^[+-]$/;
        return $x -> bnan();    # NaN, -inf, +inf
    }
    $x -> badd($y, @r);         # badd does not leave internal zeros
    $y -> {sign} =~ tr/+-/-+/;  # refix $y (does nothing for NaN)
    $x;                         # already rounded by badd() or no rounding
}

sub bmul {
    # multiply the first number by the second number
    # (BINT or num_str, BINT or num_str) return BINT

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('bmul');

    return $x->bnan() if (($x->{sign} eq $nan) || ($y->{sign} eq $nan));

    # inf handling
    if (($x->{sign} =~ /^[+-]inf$/) || ($y->{sign} =~ /^[+-]inf$/)) {
        return $x->bnan() if $x->is_zero() || $y->is_zero();
        # result will always be +-inf:
        # +inf * +/+inf => +inf, -inf * -/-inf => +inf
        # +inf * -/-inf => -inf, -inf * +/+inf => -inf
        return $x->binf() if ($x->{sign} =~ /^\+/ && $y->{sign} =~ /^\+/);
        return $x->binf() if ($x->{sign} =~ /^-/ && $y->{sign} =~ /^-/);
        return $x->binf('-');
    }

    return $upgrade->bmul($x, $upgrade->new($y), @r)
      if defined $upgrade && !$y->isa($class);

    $r[3] = $y;                 # no push here

    $x->{sign} = $x->{sign} eq $y->{sign} ? '+' : '-'; # +1 * +1 or -1 * -1 => +

    $x->{value} = $CALC->_mul($x->{value}, $y->{value}); # do actual math
    $x->{sign} = '+' if $CALC->_is_zero($x->{value});   # no -0

    $x->round(@r);
}

sub bmuladd {
    # multiply two numbers and then add the third to the result
    # (BINT or num_str, BINT or num_str, BINT or num_str) return BINT

    # set up parameters
    my ($class, $x, $y, $z, @r) = objectify(3, @_);

    return $x if $x->modify('bmuladd');

    return $x->bnan() if (($x->{sign} eq $nan) ||
                          ($y->{sign} eq $nan) ||
                          ($z->{sign} eq $nan));

    # inf handling of x and y
    if (($x->{sign} =~ /^[+-]inf$/) || ($y->{sign} =~ /^[+-]inf$/)) {
        return $x->bnan() if $x->is_zero() || $y->is_zero();
        # result will always be +-inf:
        # +inf * +/+inf => +inf, -inf * -/-inf => +inf
        # +inf * -/-inf => -inf, -inf * +/+inf => -inf
        return $x->binf() if ($x->{sign} =~ /^\+/ && $y->{sign} =~ /^\+/);
        return $x->binf() if ($x->{sign} =~ /^-/ && $y->{sign} =~ /^-/);
        return $x->binf('-');
    }
    # inf handling x*y and z
    if (($z->{sign} =~ /^[+-]inf$/)) {
        # something +-inf => +-inf
        $x->{sign} = $z->{sign}, return $x if $z->{sign} =~ /^[+-]inf$/;
    }

    return $upgrade->bmuladd($x, $upgrade->new($y), $upgrade->new($z), @r)
      if defined $upgrade && (!$y->isa($class) || !$z->isa($class) || !$x->isa($class));

    # TODO: what if $y and $z have A or P set?
    $r[3] = $z;                 # no push here

    $x->{sign} = $x->{sign} eq $y->{sign} ? '+' : '-'; # +1 * +1 or -1 * -1 => +

    $x->{value} = $CALC->_mul($x->{value}, $y->{value}); # do actual math
    $x->{sign} = '+' if $CALC->_is_zero($x->{value});   # no -0

    my ($sx, $sz) = ( $x->{sign}, $z->{sign} ); # get signs

    if ($sx eq $sz) {
        $x->{value} = $CALC->_add($x->{value}, $z->{value}); # same sign, abs add
    } else {
        my $a = $CALC->_acmp ($z->{value}, $x->{value}); # absolute compare
        if ($a > 0) {
            $x->{value} = $CALC->_sub($z->{value}, $x->{value}, 1); # abs sub w/ swap
            $x->{sign} = $sz;
        } elsif ($a == 0) {
            # speedup, if equal, set result to 0
            $x->{value} = $CALC->_zero();
            $x->{sign} = '+';
        } else                  # a < 0
        {
            $x->{value} = $CALC->_sub($x->{value}, $z->{value}); # abs sub
        }
    }
    $x->round(@r);
}

sub bdiv {
    # This does floored division, where the quotient is floored, i.e., rounded
    # towards negative infinity. As a consequence, the remainder has the same
    # sign as the divisor.

    # Set up parameters.
    my ($class, $x, $y, @r) = (ref($_[0]), @_);

    # objectify() is costly, so avoid it if we can.
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x -> modify('bdiv');

    my $wantarray = wantarray;          # call only once

    # At least one argument is NaN. Return NaN for both quotient and the
    # modulo/remainder.

    if ($x -> is_nan() || $y -> is_nan()) {
        return $wantarray ? ($x -> bnan(), $class -> bnan()) : $x -> bnan();
    }

    # Divide by zero and modulo zero.
    #
    # Division: Use the common convention that x / 0 is inf with the same sign
    # as x, except when x = 0, where we return NaN. This is also what earlier
    # versions did.
    #
    # Modulo: In modular arithmetic, the congruence relation z = x (mod y)
    # means that there is some integer k such that z - x = k y. If y = 0, we
    # get z - x = 0 or z = x. This is also what earlier versions did, except
    # that 0 % 0 returned NaN.
    #
    #     inf /    0 =  inf                  inf %    0 =  inf
    #       5 /    0 =  inf                    5 %    0 =    5
    #       0 /    0 =  NaN                    0 %    0 =    0
    #      -5 /    0 = -inf                   -5 %    0 =   -5
    #    -inf /    0 = -inf                 -inf %    0 = -inf

    if ($y -> is_zero()) {
        my $rem;
        if ($wantarray) {
            $rem = $x -> copy();
        }
        if ($x -> is_zero()) {
            $x -> bnan();
        } else {
            $x -> binf($x -> {sign});
        }
        return $wantarray ? ($x, $rem) : $x;
    }

    # Numerator (dividend) is +/-inf, and denominator is finite and non-zero.
    # The divide by zero cases are covered above. In all of the cases listed
    # below we return the same as core Perl.
    #
    #     inf / -inf =  NaN                  inf % -inf =  NaN
    #     inf /   -5 = -inf                  inf %   -5 =  NaN
    #     inf /    5 =  inf                  inf %    5 =  NaN
    #     inf /  inf =  NaN                  inf %  inf =  NaN
    #
    #    -inf / -inf =  NaN                 -inf % -inf =  NaN
    #    -inf /   -5 =  inf                 -inf %   -5 =  NaN
    #    -inf /    5 = -inf                 -inf %    5 =  NaN
    #    -inf /  inf =  NaN                 -inf %  inf =  NaN

    if ($x -> is_inf()) {
        my $rem;
        $rem = $class -> bnan() if $wantarray;
        if ($y -> is_inf()) {
            $x -> bnan();
        } else {
            my $sign = $x -> bcmp(0) == $y -> bcmp(0) ? '+' : '-';
            $x -> binf($sign);
        }
        return $wantarray ? ($x, $rem) : $x;
    }

    # Denominator (divisor) is +/-inf. The cases when the numerator is +/-inf
    # are covered above. In the modulo cases (in the right column) we return
    # the same as core Perl, which does floored division, so for consistency we
    # also do floored division in the division cases (in the left column).
    #
    #      -5 /  inf =   -1                   -5 %  inf =  inf
    #       0 /  inf =    0                    0 %  inf =    0
    #       5 /  inf =    0                    5 %  inf =    5
    #
    #      -5 / -inf =    0                   -5 % -inf =   -5
    #       0 / -inf =    0                    0 % -inf =    0
    #       5 / -inf =   -1                    5 % -inf = -inf

    if ($y -> is_inf()) {
        my $rem;
        if ($x -> is_zero() || $x -> bcmp(0) == $y -> bcmp(0)) {
            $rem = $x -> copy() if $wantarray;
            $x -> bzero();
        } else {
            $rem = $class -> binf($y -> {sign}) if $wantarray;
            $x -> bone('-');
        }
        return $wantarray ? ($x, $rem) : $x;
    }

    # At this point, both the numerator and denominator are finite numbers, and
    # the denominator (divisor) is non-zero.

    return $upgrade -> bdiv($upgrade -> new($x), $upgrade -> new($y), @r)
      if defined $upgrade;

    $r[3] = $y;                                   # no push!

    # Inialize remainder.

    my $rem = $class -> bzero();

    # Are both operands the same object, i.e., like $x -> bdiv($x)? If so,
    # flipping the sign of $y also flips the sign of $x.

    my $xsign = $x -> {sign};
    my $ysign = $y -> {sign};

    $y -> {sign} =~ tr/+-/-+/;            # Flip the sign of $y, and see ...
    my $same = $xsign ne $x -> {sign};    # ... if that changed the sign of $x.
    $y -> {sign} = $ysign;                # Re-insert the original sign.

    if ($same) {
        $x -> bone();
    } else {
        ($x -> {value}, $rem -> {value}) =
          $CALC -> _div($x -> {value}, $y -> {value});

        if ($CALC -> _is_zero($rem -> {value})) {
            if ($xsign eq $ysign || $CALC -> _is_zero($x -> {value})) {
                $x -> {sign} = '+';
            } else {
                $x -> {sign} = '-';
            }
        } else {
            if ($xsign eq $ysign) {
                $x -> {sign} = '+';
            } else {
                if ($xsign eq '+') {
                    $x -> badd(1);
                } else {
                    $x -> bsub(1);
                }
                $x -> {sign} = '-';
            }
        }
    }

    $x -> round(@r);

    if ($wantarray) {
        unless ($CALC -> _is_zero($rem -> {value})) {
            if ($xsign ne $ysign) {
                $rem = $y -> copy() -> babs() -> bsub($rem);
            }
            $rem -> {sign} = $ysign;
        }
        $rem -> {_a} = $x -> {_a};
        $rem -> {_p} = $x -> {_p};
        $rem -> round(@r);
        return ($x, $rem);
    }

    return $x;
}

sub btdiv {
    # This does truncated division, where the quotient is truncted, i.e.,
    # rounded towards zero.
    #
    # ($q, $r) = $x -> btdiv($y) returns $q and $r so that $q is int($x / $y)
    # and $q * $y + $r = $x.

    # Set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);

    # objectify is costly, so avoid it if we can.
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x -> modify('btdiv');

    my $wantarray = wantarray;          # call only once

    # At least one argument is NaN. Return NaN for both quotient and the
    # modulo/remainder.

    if ($x -> is_nan() || $y -> is_nan()) {
        return $wantarray ? ($x -> bnan(), $class -> bnan()) : $x -> bnan();
    }

    # Divide by zero and modulo zero.
    #
    # Division: Use the common convention that x / 0 is inf with the same sign
    # as x, except when x = 0, where we return NaN. This is also what earlier
    # versions did.
    #
    # Modulo: In modular arithmetic, the congruence relation z = x (mod y)
    # means that there is some integer k such that z - x = k y. If y = 0, we
    # get z - x = 0 or z = x. This is also what earlier versions did, except
    # that 0 % 0 returned NaN.
    #
    #     inf / 0 =  inf                     inf % 0 =  inf
    #       5 / 0 =  inf                       5 % 0 =    5
    #       0 / 0 =  NaN                       0 % 0 =    0
    #      -5 / 0 = -inf                      -5 % 0 =   -5
    #    -inf / 0 = -inf                    -inf % 0 = -inf

    if ($y -> is_zero()) {
        my $rem;
        if ($wantarray) {
            $rem = $x -> copy();
        }
        if ($x -> is_zero()) {
            $x -> bnan();
        } else {
            $x -> binf($x -> {sign});
        }
        return $wantarray ? ($x, $rem) : $x;
    }

    # Numerator (dividend) is +/-inf, and denominator is finite and non-zero.
    # The divide by zero cases are covered above. In all of the cases listed
    # below we return the same as core Perl.
    #
    #     inf / -inf =  NaN                  inf % -inf =  NaN
    #     inf /   -5 = -inf                  inf %   -5 =  NaN
    #     inf /    5 =  inf                  inf %    5 =  NaN
    #     inf /  inf =  NaN                  inf %  inf =  NaN
    #
    #    -inf / -inf =  NaN                 -inf % -inf =  NaN
    #    -inf /   -5 =  inf                 -inf %   -5 =  NaN
    #    -inf /    5 = -inf                 -inf %    5 =  NaN
    #    -inf /  inf =  NaN                 -inf %  inf =  NaN

    if ($x -> is_inf()) {
        my $rem;
        $rem = $class -> bnan() if $wantarray;
        if ($y -> is_inf()) {
            $x -> bnan();
        } else {
            my $sign = $x -> bcmp(0) == $y -> bcmp(0) ? '+' : '-';
            $x -> binf($sign);
        }
        return $wantarray ? ($x, $rem) : $x;
    }

    # Denominator (divisor) is +/-inf. The cases when the numerator is +/-inf
    # are covered above. In the modulo cases (in the right column) we return
    # the same as core Perl, which does floored division, so for consistency we
    # also do floored division in the division cases (in the left column).
    #
    #      -5 /  inf =    0                   -5 %  inf =  -5
    #       0 /  inf =    0                    0 %  inf =   0
    #       5 /  inf =    0                    5 %  inf =   5
    #
    #      -5 / -inf =    0                   -5 % -inf =  -5
    #       0 / -inf =    0                    0 % -inf =   0
    #       5 / -inf =    0                    5 % -inf =   5

    if ($y -> is_inf()) {
        my $rem;
        $rem = $x -> copy() if $wantarray;
        $x -> bzero();
        return $wantarray ? ($x, $rem) : $x;
    }

    return $upgrade -> btdiv($upgrade -> new($x), $upgrade -> new($y), @r)
      if defined $upgrade;

    $r[3] = $y;                 # no push!

    # Inialize remainder.

    my $rem = $class -> bzero();

    # Are both operands the same object, i.e., like $x -> bdiv($x)? If so,
    # flipping the sign of $y also flips the sign of $x.

    my $xsign = $x -> {sign};
    my $ysign = $y -> {sign};

    $y -> {sign} =~ tr/+-/-+/;            # Flip the sign of $y, and see ...
    my $same = $xsign ne $x -> {sign};    # ... if that changed the sign of $x.
    $y -> {sign} = $ysign;                # Re-insert the original sign.

    if ($same) {
        $x -> bone();
    } else {
        ($x -> {value}, $rem -> {value}) =
          $CALC -> _div($x -> {value}, $y -> {value});

        $x -> {sign} = $xsign eq $ysign ? '+' : '-';
        $x -> {sign} = '+' if $CALC -> _is_zero($x -> {value});
        $x -> round(@r);
    }

    if (wantarray) {
        $rem -> {sign} = $xsign;
        $rem -> {sign} = '+' if $CALC -> _is_zero($rem -> {value});
        $rem -> {_a} = $x -> {_a};
        $rem -> {_p} = $x -> {_p};
        $rem -> round(@r);
        return ($x, $rem);
    }

    return $x;
}

sub bmod {
    # This is the remainder after floored division.

    # Set up parameters.
    my ($class, $x, $y, @r) = (ref($_[0]), @_);

    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x -> modify('bmod');
    $r[3] = $y;                 # no push!

    # At least one argument is NaN.

    if ($x -> is_nan() || $y -> is_nan()) {
        return $x -> bnan();
    }

    # Modulo zero. See documentation for bdiv().

    if ($y -> is_zero()) {
        return $x;
    }

    # Numerator (dividend) is +/-inf.

    if ($x -> is_inf()) {
        return $x -> bnan();
    }

    # Denominator (divisor) is +/-inf.

    if ($y -> is_inf()) {
        if ($x -> is_zero() || $x -> bcmp(0) == $y -> bcmp(0)) {
            return $x;
        } else {
            return $x -> binf($y -> sign());
        }
    }

    # Calc new sign and in case $y == +/- 1, return $x.

    $x -> {value} = $CALC -> _mod($x -> {value}, $y -> {value});
    if ($CALC -> _is_zero($x -> {value})) {
        $x -> {sign} = '+';     # do not leave -0
    } else {
        $x -> {value} = $CALC -> _sub($y -> {value}, $x -> {value}, 1) # $y-$x
          if ($x -> {sign} ne $y -> {sign});
        $x -> {sign} = $y -> {sign};
    }

    $x -> round(@r);
}

sub btmod {
    # Remainder after truncated division.

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);

    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x -> modify('btmod');

    # At least one argument is NaN.

    if ($x -> is_nan() || $y -> is_nan()) {
        return $x -> bnan();
    }

    # Modulo zero. See documentation for btdiv().

    if ($y -> is_zero()) {
        return $x;
    }

    # Numerator (dividend) is +/-inf.

    if ($x -> is_inf()) {
        return $x -> bnan();
    }

    # Denominator (divisor) is +/-inf.

    if ($y -> is_inf()) {
        return $x;
    }

    return $upgrade -> btmod($upgrade -> new($x), $upgrade -> new($y), @r)
      if defined $upgrade;

    $r[3] = $y;                 # no push!

    my $xsign = $x -> {sign};
    my $ysign = $y -> {sign};

    $x -> {value} = $CALC -> _mod($x -> {value}, $y -> {value});

    $x -> {sign} = $xsign;
    $x -> {sign} = '+' if $CALC -> _is_zero($x -> {value});
    $x -> round(@r);
    return $x;
}

sub bmodinv {
    # Return modular multiplicative inverse:
    #
    #   z is the modular inverse of x (mod y) if and only if
    #
    #       x*z ≡ 1  (mod y)
    #
    # If the modulus y is larger than one, x and z are relative primes (i.e.,
    # their greatest common divisor is one).
    #
    # If no modular multiplicative inverse exists, NaN is returned.

    # set up parameters
    my ($class, $x, $y, @r) = (undef, @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('bmodinv');

    # Return NaN if one or both arguments is +inf, -inf, or nan.

    return $x->bnan() if ($y->{sign} !~ /^[+-]$/ ||
                          $x->{sign} !~ /^[+-]$/);

    # Return NaN if $y is zero; 1 % 0 makes no sense.

    return $x->bnan() if $y->is_zero();

    # Return 0 in the trivial case. $x % 1 or $x % -1 is zero for all finite
    # integers $x.

    return $x->bzero() if ($y->is_one() ||
                           $y->is_one('-'));

    # Return NaN if $x = 0, or $x modulo $y is zero. The only valid case when
    # $x = 0 is when $y = 1 or $y = -1, but that was covered above.
    #
    # Note that computing $x modulo $y here affects the value we'll feed to
    # $CALC->_modinv() below when $x and $y have opposite signs. E.g., if $x =
    # 5 and $y = 7, those two values are fed to _modinv(), but if $x = -5 and
    # $y = 7, the values fed to _modinv() are $x = 2 (= -5 % 7) and $y = 7.
    # The value if $x is affected only when $x and $y have opposite signs.

    $x->bmod($y);
    return $x->bnan() if $x->is_zero();

    # Compute the modular multiplicative inverse of the absolute values. We'll
    # correct for the signs of $x and $y later. Return NaN if no GCD is found.

    ($x->{value}, $x->{sign}) = $CALC->_modinv($x->{value}, $y->{value});
    return $x->bnan() if !defined $x->{value};

    # Library inconsistency workaround: _modinv() in Math::BigInt::GMP versions
    # <= 1.32 return undef rather than a "+" for the sign.

    $x->{sign} = '+' unless defined $x->{sign};

    # When one or both arguments are negative, we have the following
    # relations.  If x and y are positive:
    #
    #   modinv(-x, -y) = -modinv(x, y)
    #   modinv(-x, y) = y - modinv(x, y)  = -modinv(x, y) (mod y)
    #   modinv( x, -y) = modinv(x, y) - y  =  modinv(x, y) (mod -y)

    # We must swap the sign of the result if the original $x is negative.
    # However, we must compensate for ignoring the signs when computing the
    # inverse modulo. The net effect is that we must swap the sign of the
    # result if $y is negative.

    $x -> bneg() if $y->{sign} eq '-';

    # Compute $x modulo $y again after correcting the sign.

    $x -> bmod($y) if $x->{sign} ne $y->{sign};

    return $x;
}

sub bmodpow {
    # Modular exponentiation. Raises a very large number to a very large exponent
    # in a given very large modulus quickly, thanks to binary exponentiation.
    # Supports negative exponents.
    my ($class, $num, $exp, $mod, @r) = objectify(3, @_);

    return $num if $num->modify('bmodpow');

    # When the exponent 'e' is negative, use the following relation, which is
    # based on finding the multiplicative inverse 'd' of 'b' modulo 'm':
    #
    #    b^(-e) (mod m) = d^e (mod m) where b*d = 1 (mod m)

    $num->bmodinv($mod) if ($exp->{sign} eq '-');

    # Check for valid input. All operands must be finite, and the modulus must be
    # non-zero.

    return $num->bnan() if ($num->{sign} =~ /NaN|inf/ || # NaN, -inf, +inf
                            $exp->{sign} =~ /NaN|inf/ || # NaN, -inf, +inf
                            $mod->{sign} =~ /NaN|inf/);  # NaN, -inf, +inf

    # Modulo zero. See documentation for Math::BigInt's bmod() method.

    if ($mod -> is_zero()) {
        if ($num -> is_zero()) {
            return $class -> bnan();
        } else {
            return $num -> copy();
        }
    }

    # Compute 'a (mod m)', ignoring the signs on 'a' and 'm'. If the resulting
    # value is zero, the output is also zero, regardless of the signs on 'a' and
    # 'm'.

    my $value = $CALC->_modpow($num->{value}, $exp->{value}, $mod->{value});
    my $sign  = '+';

    # If the resulting value is non-zero, we have four special cases, depending
    # on the signs on 'a' and 'm'.

    unless ($CALC->_is_zero($value)) {

        # There is a negative sign on 'a' (= $num**$exp) only if the number we
        # are exponentiating ($num) is negative and the exponent ($exp) is odd.

        if ($num->{sign} eq '-' && $exp->is_odd()) {

            # When both the number 'a' and the modulus 'm' have a negative sign,
            # use this relation:
            #
            #    -a (mod -m) = -(a (mod m))

            if ($mod->{sign} eq '-') {
                $sign = '-';
            }

            # When only the number 'a' has a negative sign, use this relation:
            #
            #    -a (mod m) = m - (a (mod m))

            else {
                # Use copy of $mod since _sub() modifies the first argument.
                my $mod = $CALC->_copy($mod->{value});
                $value = $CALC->_sub($mod, $value);
                $sign  = '+';
            }

        } else {

            # When only the modulus 'm' has a negative sign, use this relation:
            #
            #    a (mod -m) = (a (mod m)) - m
            #               = -(m - (a (mod m)))

            if ($mod->{sign} eq '-') {
                # Use copy of $mod since _sub() modifies the first argument.
                my $mod = $CALC->_copy($mod->{value});
                $value = $CALC->_sub($mod, $value);
                $sign  = '-';
            }

            # When neither the number 'a' nor the modulus 'm' have a negative
            # sign, directly return the already computed value.
            #
            #    (a (mod m))

        }

    }

    $num->{value} = $value;
    $num->{sign}  = $sign;

    return $num;
}

sub bpow {
    # (BINT or num_str, BINT or num_str) return BINT
    # compute power of two numbers -- stolen from Knuth Vol 2 pg 233
    # modifies first argument

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('bpow');

    return $x->bnan() if $x->{sign} eq $nan || $y->{sign} eq $nan;

    # inf handling
    if (($x->{sign} =~ /^[+-]inf$/) || ($y->{sign} =~ /^[+-]inf$/)) {
        if (($x->{sign} =~ /^[+-]inf$/) && ($y->{sign} =~ /^[+-]inf$/)) {
            # +-inf ** +-inf
            return $x->bnan();
        }
        # +-inf ** Y
        if ($x->{sign} =~ /^[+-]inf/) {
            # +inf ** 0 => NaN
            return $x->bnan() if $y->is_zero();
            # -inf ** -1 => 1/inf => 0
            return $x->bzero() if $y->is_one('-') && $x->is_negative();

            # +inf ** Y => inf
            return $x if $x->{sign} eq '+inf';

            # -inf ** Y => -inf if Y is odd
            return $x if $y->is_odd();
            return $x->babs();
        }
        # X ** +-inf

        # 1 ** +inf => 1
        return $x if $x->is_one();

        # 0 ** inf => 0
        return $x if $x->is_zero() && $y->{sign} =~ /^[+]/;

        # 0 ** -inf => inf
        return $x->binf() if $x->is_zero();

        # -1 ** -inf => NaN
        return $x->bnan() if $x->is_one('-') && $y->{sign} =~ /^[-]/;

        # -X ** -inf => 0
        return $x->bzero() if $x->{sign} eq '-' && $y->{sign} =~ /^[-]/;

        # -1 ** inf => NaN
        return $x->bnan() if $x->{sign} eq '-';

        # X ** inf => inf
        return $x->binf() if $y->{sign} =~ /^[+]/;
        # X ** -inf => 0
        return $x->bzero();
    }

    return $upgrade->bpow($upgrade->new($x), $y, @r)
      if defined $upgrade && (!$y->isa($class) || $y->{sign} eq '-');

    $r[3] = $y;                 # no push!

    # cases 0 ** Y, X ** 0, X ** 1, 1 ** Y are handled by Calc or Emu

    my $new_sign = '+';
    $new_sign = $y->is_odd() ? '-' : '+' if ($x->{sign} ne '+');

    # 0 ** -7 => ( 1 / (0 ** 7)) => 1 / 0 => +inf
    return $x->binf()
      if $y->{sign} eq '-' && $x->{sign} eq '+' && $CALC->_is_zero($x->{value});
    # 1 ** -y => 1 / (1 ** |y|)
    # so do test for negative $y after above's clause
    return $x->bnan() if $y->{sign} eq '-' && !$CALC->_is_one($x->{value});

    $x->{value} = $CALC->_pow($x->{value}, $y->{value});
    $x->{sign} = $new_sign;
    $x->{sign} = '+' if $CALC->_is_zero($y->{value});
    $x->round(@r);
}

sub blog {
    # Return the logarithm of the operand. If a second operand is defined, that
    # value is used as the base, otherwise the base is assumed to be Euler's
    # constant.

    my ($class, $x, $base, @r);

    # Don't objectify the base, since an undefined base, as in $x->blog() or
    # $x->blog(undef) signals that the base is Euler's number.

    if (!ref($_[0]) && $_[0] =~ /^[A-Za-z]|::/) {
        # E.g., Math::BigInt->blog(256, 2)
        ($class, $x, $base, @r) =
          defined $_[2] ? objectify(2, @_) : objectify(1, @_);
    } else {
        # E.g., Math::BigInt::blog(256, 2) or $x->blog(2)
        ($class, $x, $base, @r) =
          defined $_[1] ? objectify(2, @_) : objectify(1, @_);
    }

    return $x if $x->modify('blog');

    # Handle all exception cases and all trivial cases. I have used Wolfram
    # Alpha (http://www.wolframalpha.com) as the reference for these cases.

    return $x -> bnan() if $x -> is_nan();

    if (defined $base) {
        $base = $class -> new($base) unless ref $base;
        if ($base -> is_nan() || $base -> is_one()) {
            return $x -> bnan();
        } elsif ($base -> is_inf() || $base -> is_zero()) {
            return $x -> bnan() if $x -> is_inf() || $x -> is_zero();
            return $x -> bzero();
        } elsif ($base -> is_negative()) {        # -inf < base < 0
            return $x -> bzero() if $x -> is_one(); #     x = 1
            return $x -> bone()  if $x == $base;    #     x = base
            return $x -> bnan();                    #     otherwise
        }
        return $x -> bone() if $x == $base; # 0 < base && 0 < x < inf
    }

    # We now know that the base is either undefined or >= 2 and finite.

    return $x -> binf('+') if $x -> is_inf(); #   x = +/-inf
    return $x -> bnan()    if $x -> is_neg(); #   -inf < x < 0
    return $x -> bzero()   if $x -> is_one(); #   x = 1
    return $x -> binf('-') if $x -> is_zero(); #   x = 0

    # At this point we are done handling all exception cases and trivial cases.

    return $upgrade -> blog($upgrade -> new($x), $base, @r) if defined $upgrade;

    # fix for bug #24969:
    # the default base is e (Euler's number) which is not an integer
    if (!defined $base) {
        require Math::BigFloat;
        my $u = Math::BigFloat->blog(Math::BigFloat->new($x))->as_int();
        # modify $x in place
        $x->{value} = $u->{value};
        $x->{sign} = $u->{sign};
        return $x;
    }

    my ($rc, $exact) = $CALC->_log_int($x->{value}, $base->{value});
    return $x->bnan() unless defined $rc; # not possible to take log?
    $x->{value} = $rc;
    $x->round(@r);
}

sub bexp {
    # Calculate e ** $x (Euler's number to the power of X), truncated to
    # an integer value.
    my ($class, $x, @r) = ref($_[0]) ? (ref($_[0]), @_) : objectify(1, @_);
    return $x if $x->modify('bexp');

    # inf, -inf, NaN, <0 => NaN
    return $x->bnan() if $x->{sign} eq 'NaN';
    return $x->bone() if $x->is_zero();
    return $x if $x->{sign} eq '+inf';
    return $x->bzero() if $x->{sign} eq '-inf';

    my $u;
    {
        # run through Math::BigFloat unless told otherwise
        require Math::BigFloat unless defined $upgrade;
        local $upgrade = 'Math::BigFloat' unless defined $upgrade;
        # calculate result, truncate it to integer
        $u = $upgrade->bexp($upgrade->new($x), @r);
    }

    if (defined $upgrade) {
        $x = $u;
    } else {
        $u = $u->as_int();
        # modify $x in place
        $x->{value} = $u->{value};
        $x->round(@r);
    }
}

sub bnok {
    # Calculate n over k (binomial coefficient or "choose" function) as integer.
    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);

    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('bnok');
    return $x->bnan() if $x->{sign} eq 'NaN' || $y->{sign} eq 'NaN';
    return $x->binf() if $x->{sign} eq '+inf';

    # k > n or k < 0 => 0
    my $cmp = $x->bacmp($y);
    return $x->bzero() if $cmp < 0 || substr($y->{sign}, 0, 1) eq "-";

    if ($CALC->can('_nok')) {
        $x->{value} = $CALC->_nok($x->{value}, $y->{value});
    } else {
        # ( 7 )       7!       1*2*3*4 * 5*6*7   5 * 6 * 7       6   7
        # ( - ) = --------- =  --------------- = --------- = 5 * - * -
        # ( 3 )   (7-3)! 3!    1*2*3*4 * 1*2*3   1 * 2 * 3       2   3

        my $n = $x -> {value};
        my $k = $y -> {value};

        # If k > n/2, or, equivalently, 2*k > n, compute nok(n, k) as
        # nok(n, n-k) to minimize the number if iterations in the loop.

        {
            my $twok = $CALC->_mul($CALC->_two(), $CALC->_copy($k));
            if ($CALC->_acmp($twok, $n) > 0) {
                $k = $CALC->_sub($CALC->_copy($n), $k);
            }
        }

        if ($CALC->_is_zero($k)) {
            $n = $CALC->_one();
        } else {

            # Make a copy of the original n, since we'll be modifying n
            # in-place.

            my $n_orig = $CALC->_copy($n);

            $CALC->_sub($n, $k);
            $CALC->_inc($n);

            my $f = $CALC->_copy($n);
            $CALC->_inc($f);

            my $d = $CALC->_two();

            # while f <= n (the original n, that is) ...

            while ($CALC->_acmp($f, $n_orig) <= 0) {
                $CALC->_mul($n, $f);
                $CALC->_div($n, $d);
                $CALC->_inc($f);
                $CALC->_inc($d);
            }
        }

        $x -> {value} = $n;
    }

    $x->round(@r);
}

sub bsin {
    # Calculate sinus(x) to N digits. Unless upgrading is in effect, returns the
    # result truncated to an integer.
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    return $x if $x->modify('bsin');

    return $x->bnan() if $x->{sign} !~ /^[+-]\z/; # -inf +inf or NaN => NaN

    return $upgrade->new($x)->bsin(@r) if defined $upgrade;

    require Math::BigFloat;
    # calculate the result and truncate it to integer
    my $t = Math::BigFloat->new($x)->bsin(@r)->as_int();

    $x->bone() if $t->is_one();
    $x->bzero() if $t->is_zero();
    $x->round(@r);
}

sub bcos {
    # Calculate cosinus(x) to N digits. Unless upgrading is in effect, returns the
    # result truncated to an integer.
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    return $x if $x->modify('bcos');

    return $x->bnan() if $x->{sign} !~ /^[+-]\z/; # -inf +inf or NaN => NaN

    return $upgrade->new($x)->bcos(@r) if defined $upgrade;

    require Math::BigFloat;
    # calculate the result and truncate it to integer
    my $t = Math::BigFloat->new($x)->bcos(@r)->as_int();

    $x->bone() if $t->is_one();
    $x->bzero() if $t->is_zero();
    $x->round(@r);
}

sub batan {
    # Calculate arcus tangens of x to N digits. Unless upgrading is in effect, returns the
    # result truncated to an integer.
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    return $x if $x->modify('batan');

    return $x->bnan() if $x->{sign} !~ /^[+-]\z/; # -inf +inf or NaN => NaN

    return $upgrade->new($x)->batan(@r) if defined $upgrade;

    # calculate the result and truncate it to integer
    my $t = Math::BigFloat->new($x)->batan(@r);

    $x->{value} = $CALC->_new($x->as_int()->bstr());
    $x->round(@r);
}

sub batan2 {
    # calculate arcus tangens of ($y/$x)

    # set up parameters
    my ($class, $y, $x, @r) = (ref($_[0]), @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $y, $x, @r) = objectify(2, @_);
    }

    return $y if $y->modify('batan2');

    return $y->bnan() if ($y->{sign} eq $nan) || ($x->{sign} eq $nan);

    # Y    X
    # != 0 -inf result is +- pi
    if ($x->is_inf() || $y->is_inf()) {
        # upgrade to Math::BigFloat etc.
        return $upgrade->new($y)->batan2($upgrade->new($x), @r) if defined $upgrade;
        if ($y->is_inf()) {
            if ($x->{sign} eq '-inf') {
                # calculate 3 pi/4 => 2.3.. => 2
                $y->bone(substr($y->{sign}, 0, 1));
                $y->bmul($class->new(2));
            } elsif ($x->{sign} eq '+inf') {
                # calculate pi/4 => 0.7 => 0
                $y->bzero();
            } else {
                # calculate pi/2 => 1.5 => 1
                $y->bone(substr($y->{sign}, 0, 1));
            }
        } else {
            if ($x->{sign} eq '+inf') {
                # calculate pi/4 => 0.7 => 0
                $y->bzero();
            } else {
                # PI => 3.1415.. => 3
                $y->bone(substr($y->{sign}, 0, 1));
                $y->bmul($class->new(3));
            }
        }
        return $y;
    }

    return $upgrade->new($y)->batan2($upgrade->new($x), @r) if defined $upgrade;

    require Math::BigFloat;
    my $r = Math::BigFloat->new($y)
      ->batan2(Math::BigFloat->new($x), @r)
        ->as_int();

    $x->{value} = $r->{value};
    $x->{sign} = $r->{sign};

    $x;
}

sub bsqrt {
    # calculate square root of $x
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    return $x if $x->modify('bsqrt');

    return $x->bnan() if $x->{sign} !~ /^\+/; # -x or -inf or NaN => NaN
    return $x if $x->{sign} eq '+inf';        # sqrt(+inf) == inf

    return $upgrade->bsqrt($x, @r) if defined $upgrade;

    $x->{value} = $CALC->_sqrt($x->{value});
    $x->round(@r);
}

sub broot {
    # calculate $y'th root of $x

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);

    $y = $class->new(2) unless defined $y;

    # objectify is costly, so avoid it
    if ((!ref($x)) || (ref($x) ne ref($y))) {
        ($class, $x, $y, @r) = objectify(2, $class || $class, @_);
    }

    return $x if $x->modify('broot');

    # NaN handling: $x ** 1/0, x or y NaN, or y inf/-inf or y == 0
    return $x->bnan() if $x->{sign} !~ /^\+/ || $y->is_zero() ||
      $y->{sign} !~ /^\+$/;

    return $x->round(@r)
      if $x->is_zero() || $x->is_one() || $x->is_inf() || $y->is_one();

    return $upgrade->new($x)->broot($upgrade->new($y), @r) if defined $upgrade;

    $x->{value} = $CALC->_root($x->{value}, $y->{value});
    $x->round(@r);
}

sub bfac {
    # (BINT or num_str, BINT or num_str) return BINT
    # compute factorial number from $x, modify $x in place
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    return $x if $x->modify('bfac') || $x->{sign} eq '+inf'; # inf => inf
    return $x->bnan() if $x->{sign} ne '+'; # NaN, <0 etc => NaN

    $x->{value} = $CALC->_fac($x->{value});
    $x->round(@r);
}

sub bdfac {
    # compute double factorial, modify $x in place
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    return $x if $x->modify('bdfac') || $x->{sign} eq '+inf'; # inf => inf
    return $x->bnan() if $x->{sign} ne '+'; # NaN, <0 etc => NaN

    Carp::croak("bdfac() requires a newer version of the $CALC library.")
        unless $CALC->can('_dfac');

    $x->{value} = $CALC->_dfac($x->{value});
    $x->round(@r);
}

sub bfib {
    # compute Fibonacci number(s)
    my ($class, $x, @r) = objectify(1, @_);

    Carp::croak("bfib() requires a newer version of the $CALC library.")
        unless $CALC->can('_fib');

    return $x if $x->modify('bfib');

    # List context.

    if (wantarray) {
        return () if $x ->  is_nan();
        Carp::croak("bfib() can't return an infinitely long list of numbers")
            if $x -> is_inf();

        # Use the backend library to compute the first $x Fibonacci numbers.

        my @values = $CALC->_fib($x->{value});

        # Make objects out of them. The last element in the array is the
        # invocand.

        for (my $i = 0 ; $i < $#values ; ++ $i) {
            my $fib =  $class -> bzero();
            $fib -> {value} = $values[$i];
            $values[$i] = $fib;
        }

        $x -> {value} = $values[-1];
        $values[-1] = $x;

        # If negative, insert sign as appropriate.

        if ($x -> is_neg()) {
            for (my $i = 2 ; $i <= $#values ; $i += 2) {
                $values[$i]{sign} = '-';
            }
        }

        @values = map { $_ -> round(@r) } @values;
        return @values;
    }

    # Scalar context.

    else {
        return $x if $x->modify('bdfac') || $x ->  is_inf('+');
        return $x->bnan() if $x -> is_nan() || $x -> is_inf('-');

        $x->{sign}  = $x -> is_neg() && $x -> is_even() ? '-' : '+';
        $x->{value} = $CALC->_fib($x->{value});
        return $x->round(@r);
    }
}

sub blucas {
    # compute Lucas number(s)
    my ($class, $x, @r) = objectify(1, @_);

    Carp::croak("blucas() requires a newer version of the $CALC library.")
        unless $CALC->can('_lucas');

    return $x if $x->modify('blucas');

    # List context.

    if (wantarray) {
        return () if $x -> is_nan();
        Carp::croak("blucas() can't return an infinitely long list of numbers")
            if $x -> is_inf();

        # Use the backend library to compute the first $x Lucas numbers.

        my @values = $CALC->_lucas($x->{value});

        # Make objects out of them. The last element in the array is the
        # invocand.

        for (my $i = 0 ; $i < $#values ; ++ $i) {
            my $lucas =  $class -> bzero();
            $lucas -> {value} = $values[$i];
            $values[$i] = $lucas;
        }

        $x -> {value} = $values[-1];
        $values[-1] = $x;

        # If negative, insert sign as appropriate.

        if ($x -> is_neg()) {
            for (my $i = 2 ; $i <= $#values ; $i += 2) {
                $values[$i]{sign} = '-';
            }
        }

        @values = map { $_ -> round(@r) } @values;
        return @values;
    }

    # Scalar context.

    else {
        return $x if $x ->  is_inf('+');
        return $x->bnan() if $x -> is_nan() || $x -> is_inf('-');

        $x->{sign}  = $x -> is_neg() && $x -> is_even() ? '-' : '+';
        $x->{value} = $CALC->_lucas($x->{value});
        return $x->round(@r);
    }
}

sub blsft {
    # (BINT or num_str, BINT or num_str) return BINT
    # compute x << y, base n, y >= 0

    # set up parameters
    my ($class, $x, $y, $b, @r) = (ref($_[0]), @_);

    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, $b, @r) = objectify(2, @_);
    }

    return $x if $x -> modify('blsft');
    return $x -> bnan() if ($x -> {sign} !~ /^[+-]$/ ||
                            $y -> {sign} !~ /^[+-]$/);
    return $x -> round(@r) if $y -> is_zero();

    $b = 2 if !defined $b;
    return $x -> bnan() if $b <= 0 || $y -> {sign} eq '-';

    $x -> {value} = $CALC -> _lsft($x -> {value}, $y -> {value}, $b);
    $x -> round(@r);
}

sub brsft {
    # (BINT or num_str, BINT or num_str) return BINT
    # compute x >> y, base n, y >= 0

    # set up parameters
    my ($class, $x, $y, $b, @r) = (ref($_[0]), @_);

    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, $b, @r) = objectify(2, @_);
    }

    return $x if $x -> modify('brsft');
    return $x -> bnan() if ($x -> {sign} !~ /^[+-]$/ || $y -> {sign} !~ /^[+-]$/);
    return $x -> round(@r) if $y -> is_zero();
    return $x -> bzero(@r) if $x -> is_zero(); # 0 => 0

    $b = 2 if !defined $b;
    return $x -> bnan() if $b <= 0 || $y -> {sign} eq '-';

    # this only works for negative numbers when shifting in base 2
    if (($x -> {sign} eq '-') && ($b == 2)) {
        return $x -> round(@r) if $x -> is_one('-'); # -1 => -1
        if (!$y -> is_one()) {
            # although this is O(N*N) in calc (as_bin!) it is O(N) in Pari et
            # al but perhaps there is a better emulation for two's complement
            # shift...
            # if $y != 1, we must simulate it by doing:
            # convert to bin, flip all bits, shift, and be done
            $x -> binc();           # -3 => -2
            my $bin = $x -> as_bin();
            $bin =~ s/^-0b//;       # strip '-0b' prefix
            $bin =~ tr/10/01/;      # flip bits
            # now shift
            if ($y >= CORE::length($bin)) {
                $bin = '0';         # shifting to far right creates -1
                                    # 0, because later increment makes
                                    # that 1, attached '-' makes it '-1'
                                    # because -1 >> x == -1 !
            } else {
                $bin =~ s/.{$y}$//; # cut off at the right side
                $bin = '1' . $bin;  # extend left side by one dummy '1'
                $bin =~ tr/10/01/;  # flip bits back
            }
            my $res = $class -> new('0b' . $bin); # add prefix and convert back
            $res -> binc();                       # remember to increment
            $x -> {value} = $res -> {value};      # take over value
            return $x -> round(@r); # we are done now, magic, isn't?
        }

        # x < 0, n == 2, y == 1
        $x -> bdec();           # n == 2, but $y == 1: this fixes it
    }

    $x -> {value} = $CALC -> _rsft($x -> {value}, $y -> {value}, $b);
    $x -> round(@r);
}

###############################################################################
# Bitwise methods
###############################################################################

sub band {
    #(BINT or num_str, BINT or num_str) return BINT
    # compute x & y

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('band');

    $r[3] = $y;                 # no push!

    return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);

    my $sx = $x->{sign} eq '+' ? 1 : -1;
    my $sy = $y->{sign} eq '+' ? 1 : -1;

    if ($sx == 1 && $sy == 1) {
        $x->{value} = $CALC->_and($x->{value}, $y->{value});
        return $x->round(@r);
    }

    if ($CAN{signed_and}) {
        $x->{value} = $CALC->_signed_and($x->{value}, $y->{value}, $sx, $sy);
        return $x->round(@r);
    }

    require $EMU_LIB;
    __emu_band($class, $x, $y, $sx, $sy, @r);
}

sub bior {
    #(BINT or num_str, BINT or num_str) return BINT
    # compute x | y

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('bior');
    $r[3] = $y;                 # no push!

    return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);

    my $sx = $x->{sign} eq '+' ? 1 : -1;
    my $sy = $y->{sign} eq '+' ? 1 : -1;

    # the sign of X follows the sign of X, e.g. sign of Y irrelevant for bior()

    # don't use lib for negative values
    if ($sx == 1 && $sy == 1) {
        $x->{value} = $CALC->_or($x->{value}, $y->{value});
        return $x->round(@r);
    }

    # if lib can do negative values, let it handle this
    if ($CAN{signed_or}) {
        $x->{value} = $CALC->_signed_or($x->{value}, $y->{value}, $sx, $sy);
        return $x->round(@r);
    }

    require $EMU_LIB;
    __emu_bior($class, $x, $y, $sx, $sy, @r);
}

sub bxor {
    #(BINT or num_str, BINT or num_str) return BINT
    # compute x ^ y

    # set up parameters
    my ($class, $x, $y, @r) = (ref($_[0]), @_);
    # objectify is costly, so avoid it
    if ((!ref($_[0])) || (ref($_[0]) ne ref($_[1]))) {
        ($class, $x, $y, @r) = objectify(2, @_);
    }

    return $x if $x->modify('bxor');
    $r[3] = $y;                 # no push!

    return $x->bnan() if ($x->{sign} !~ /^[+-]$/ || $y->{sign} !~ /^[+-]$/);

    my $sx = $x->{sign} eq '+' ? 1 : -1;
    my $sy = $y->{sign} eq '+' ? 1 : -1;

    # don't use lib for negative values
    if ($sx == 1 && $sy == 1) {
        $x->{value} = $CALC->_xor($x->{value}, $y->{value});
        return $x->round(@r);
    }

    # if lib can do negative values, let it handle this
    if ($CAN{signed_xor}) {
        $x->{value} = $CALC->_signed_xor($x->{value}, $y->{value}, $sx, $sy);
        return $x->round(@r);
    }

    require $EMU_LIB;
    __emu_bxor($class, $x, $y, $sx, $sy, @r);
}

sub bnot {
    # (num_str or BINT) return BINT
    # represent ~x as twos-complement number
    # we don't need $class, so undef instead of ref($_[0]) make it slightly faster
    my ($class, $x, $a, $p, $r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    return $x if $x->modify('bnot');
    $x->binc()->bneg();         # binc already does round
}

###############################################################################
# Rounding methods
###############################################################################

sub round {
    # Round $self according to given parameters, or given second argument's
    # parameters or global defaults

    # for speed reasons, _find_round_parameters is embedded here:

    my ($self, $a, $p, $r, @args) = @_;
    # $a accuracy, if given by caller
    # $p precision, if given by caller
    # $r round_mode, if given by caller
    # @args all 'other' arguments (0 for unary, 1 for binary ops)

    my $class = ref($self);       # find out class of argument(s)
    no strict 'refs';

    # now pick $a or $p, but only if we have got "arguments"
    if (!defined $a) {
        foreach ($self, @args) {
            # take the defined one, or if both defined, the one that is smaller
            $a = $_->{_a} if (defined $_->{_a}) && (!defined $a || $_->{_a} < $a);
        }
    }
    if (!defined $p) {
        # even if $a is defined, take $p, to signal error for both defined
        foreach ($self, @args) {
            # take the defined one, or if both defined, the one that is bigger
            # -2 > -3, and 3 > 2
            $p = $_->{_p} if (defined $_->{_p}) && (!defined $p || $_->{_p} > $p);
        }
    }

    # if still none defined, use globals (#2)
    $a = ${"$class\::accuracy"}  unless defined $a;
    $p = ${"$class\::precision"} unless defined $p;

    # A == 0 is useless, so undef it to signal no rounding
    $a = undef if defined $a && $a == 0;

    # no rounding today?
    return $self unless defined $a || defined $p; # early out

    # set A and set P is an fatal error
    return $self->bnan() if defined $a && defined $p;

    $r = ${"$class\::round_mode"} unless defined $r;
    if ($r !~ /^(even|odd|[+-]inf|zero|trunc|common)$/) {
        Carp::croak("Unknown round mode '$r'");
    }

    # now round, by calling either bround or bfround:
    if (defined $a) {
        $self->bround(int($a), $r) if !defined $self->{_a} || $self->{_a} >= $a;
    } else {                  # both can't be undefined due to early out
        $self->bfround(int($p), $r) if !defined $self->{_p} || $self->{_p} <= $p;
    }

    # bround() or bfround() already called bnorm() if nec.
    $self;
}

sub bround {
    # accuracy: +$n preserve $n digits from left,
    #           -$n preserve $n digits from right (f.i. for 0.1234 style in MBF)
    # no-op for $n == 0
    # and overwrite the rest with 0's, return normalized number
    # do not return $x->bnorm(), but $x

    my $x = shift;
    $x = $class->new($x) unless ref $x;
    my ($scale, $mode) = $x->_scale_a(@_);
    return $x if !defined $scale || $x->modify('bround'); # no-op

    if ($x->is_zero() || $scale == 0) {
        $x->{_a} = $scale if !defined $x->{_a} || $x->{_a} > $scale; # 3 > 2
        return $x;
    }
    return $x if $x->{sign} !~ /^[+-]$/; # inf, NaN

    # we have fewer digits than we want to scale to
    my $len = $x->length();
    # convert $scale to a scalar in case it is an object (put's a limit on the
    # number length, but this would already limited by memory constraints), makes
    # it faster
    $scale = $scale->numify() if ref ($scale);

    # scale < 0, but > -len (not >=!)
    if (($scale < 0 && $scale < -$len-1) || ($scale >= $len)) {
        $x->{_a} = $scale if !defined $x->{_a} || $x->{_a} > $scale; # 3 > 2
        return $x;
    }

    # count of 0's to pad, from left (+) or right (-): 9 - +6 => 3, or |-6| => 6
    my ($pad, $digit_round, $digit_after);
    $pad = $len - $scale;
    $pad = abs($scale-1) if $scale < 0;

    # do not use digit(), it is very costly for binary => decimal
    # getting the entire string is also costly, but we need to do it only once
    my $xs = $CALC->_str($x->{value});
    my $pl = -$pad-1;

    # pad:   123: 0 => -1, at 1 => -2, at 2 => -3, at 3 => -4
    # pad+1: 123: 0 => 0, at 1 => -1, at 2 => -2, at 3 => -3
    $digit_round = '0';
    $digit_round = substr($xs, $pl, 1) if $pad <= $len;
    $pl++;
    $pl ++ if $pad >= $len;
    $digit_after = '0';
    $digit_after = substr($xs, $pl, 1) if $pad > 0;

    # in case of 01234 we round down, for 6789 up, and only in case 5 we look
    # closer at the remaining digits of the original $x, remember decision
    my $round_up = 1;           # default round up
    $round_up -- if
      ($mode eq 'trunc')                      ||   # trunc by round down
        ($digit_after =~ /[01234]/)           ||   # round down anyway,
          # 6789 => round up
          ($digit_after eq '5')               &&   # not 5000...0000
            ($x->_scan_for_nonzero($pad, $xs, $len) == 0)   &&
              (
               ($mode eq 'even') && ($digit_round =~ /[24680]/) ||
               ($mode eq 'odd')  && ($digit_round =~ /[13579]/) ||
               ($mode eq '+inf') && ($x->{sign} eq '-')         ||
               ($mode eq '-inf') && ($x->{sign} eq '+')         ||
               ($mode eq 'zero') # round down if zero, sign adjusted below
              );
    my $put_back = 0;           # not yet modified

    if (($pad > 0) && ($pad <= $len)) {
        substr($xs, -$pad, $pad) = '0' x $pad; # replace with '00...'
        $put_back = 1;                         # need to put back
    } elsif ($pad > $len) {
        $x->bzero();            # round to '0'
    }

    if ($round_up) {            # what gave test above?
        $put_back = 1;                               # need to put back
        $pad = $len, $xs = '0' x $pad if $scale < 0; # tlr: whack 0.51=>1.0

        # we modify directly the string variant instead of creating a number and
        # adding it, since that is faster (we already have the string)
        my $c = 0;
        $pad ++;                # for $pad == $len case
        while ($pad <= $len) {
            $c = substr($xs, -$pad, 1) + 1;
            $c = '0' if $c eq '10';
            substr($xs, -$pad, 1) = $c;
            $pad++;
            last if $c != 0;    # no overflow => early out
        }
        $xs = '1'.$xs if $c == 0;

    }
    $x->{value} = $CALC->_new($xs) if $put_back == 1; # put back, if needed

    $x->{_a} = $scale if $scale >= 0;
    if ($scale < 0) {
        $x->{_a} = $len+$scale;
        $x->{_a} = 0 if $scale < -$len;
    }
    $x;
}

sub bfround {
    # precision: round to the $Nth digit left (+$n) or right (-$n) from the '.'
    # $n == 0 || $n == 1 => round to integer
    my $x = shift;
    my $class = ref($x) || $x;
    $x = $class->new($x) unless ref $x;

    my ($scale, $mode) = $x->_scale_p(@_);

    return $x if !defined $scale || $x->modify('bfround'); # no-op

    # no-op for Math::BigInt objects if $n <= 0
    $x->bround($x->length()-$scale, $mode) if $scale > 0;

    delete $x->{_a};            # delete to save memory
    $x->{_p} = $scale;          # store new _p
    $x;
}

sub fround {
    # Exists to make life easier for switch between MBF and MBI (should we
    # autoload fxxx() like MBF does for bxxx()?)
    my $x = shift;
    $x = $class->new($x) unless ref $x;
    $x->bround(@_);
}

sub bfloor {
    # round towards minus infinity; no-op since it's already integer
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    $x->round(@r);
}

sub bceil {
    # round towards plus infinity; no-op since it's already int
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    $x->round(@r);
}

sub bint {
    # round towards zero; no-op since it's already integer
    my ($class, $x, @r) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    $x->round(@r);
}

###############################################################################
# Other mathematical methods
###############################################################################

sub bgcd {
    # (BINT or num_str, BINT or num_str) return BINT
    # does not modify arguments, but returns new object
    # GCD -- Euclid's algorithm, variant C (Knuth Vol 3, pg 341 ff)

    my ($class, @args) = objectify(0, @_);

    my $x = shift @args;
    $x = ref($x) && $x -> isa($class) ? $x -> copy() : $class -> new($x);

    return $class->bnan() if $x->{sign} !~ /^[+-]$/;    # x NaN?

    while (@args) {
        my $y = shift @args;
        $y = $class->new($y) unless ref($y) && $y -> isa($class);
        return $class->bnan() if $y->{sign} !~ /^[+-]$/;    # y NaN?
        $x->{value} = $CALC->_gcd($x->{value}, $y->{value});
        last if $CALC->_is_one($x->{value});
    }

    return $x -> babs();
}

sub blcm {
    # (BINT or num_str, BINT or num_str) return BINT
    # does not modify arguments, but returns new object
    # Least Common Multiple

    my ($class, @args) = objectify(0, @_);

    my $x = shift @args;
    $x = ref($x) && $x -> isa($class) ? $x -> copy() : $class -> new($x);
    return $class->bnan() if $x->{sign} !~ /^[+-]$/;    # x NaN?

    while (@args) {
        my $y = shift @args;
        $y = $class -> new($y) unless ref($y) && $y -> isa($class);
        return $x->bnan() if $y->{sign} !~ /^[+-]$/;     # y not integer
        $x -> {value} = $CALC->_lcm($x -> {value}, $y -> {value});
    }

    return $x -> babs();
}

###############################################################################
# Object property methods
###############################################################################

sub sign {
    # return the sign of the number: +/-/-inf/+inf/NaN
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    $x->{sign};
}

sub digit {
    # return the nth decimal digit, negative values count backward, 0 is right
    my ($class, $x, $n) = ref($_[0]) ? (undef, @_) : objectify(1, @_);

    $n = $n->numify() if ref($n);
    $CALC->_digit($x->{value}, $n || 0);
}

sub length {
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    my $e = $CALC->_len($x->{value});
    wantarray ? ($e, 0) : $e;
}

sub exponent {
    # return a copy of the exponent (here always 0, NaN or 1 for $m == 0)
    my ($class, $x) = ref($_[0]) ? (ref($_[0]), $_[0]) : objectify(1, @_);

    if ($x->{sign} !~ /^[+-]$/) {
        my $s = $x->{sign};
        $s =~ s/^[+-]//; # NaN, -inf, +inf => NaN or inf
        return $class->new($s);
    }
    return $class->bzero() if $x->is_zero();

    # 12300 => 2 trailing zeros => exponent is 2
    $class->new($CALC->_zeros($x->{value}));
}

sub mantissa {
    # return the mantissa (compatible to Math::BigFloat, e.g. reduced)
    my ($class, $x) = ref($_[0]) ? (ref($_[0]), $_[0]) : objectify(1, @_);

    if ($x->{sign} !~ /^[+-]$/) {
        # for NaN, +inf, -inf: keep the sign
        return $class->new($x->{sign});
    }
    my $m = $x->copy();
    delete $m->{_p};
    delete $m->{_a};

    # that's a bit inefficient:
    my $zeros = $CALC->_zeros($m->{value});
    $m->brsft($zeros, 10) if $zeros != 0;
    $m;
}

sub parts {
    # return a copy of both the exponent and the mantissa
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    ($x->mantissa(), $x->exponent());
}

sub sparts {
    my $self  = shift;
    my $class = ref $self;

    Carp::croak("sparts() is an instance method, not a class method")
        unless $class;

    # Not-a-number.

    if ($self -> is_nan()) {
        my $mant = $self -> copy();             # mantissa
        return $mant unless wantarray;          # scalar context
        my $expo = $class -> bnan();            # exponent
        return ($mant, $expo);                  # list context
    }

    # Infinity.

    if ($self -> is_inf()) {
        my $mant = $self -> copy();             # mantissa
        return $mant unless wantarray;          # scalar context
        my $expo = $class -> binf('+');         # exponent
        return ($mant, $expo);                  # list context
    }

    # Finite number.

    my $mant   = $self -> copy();
    my $nzeros = $CALC -> _zeros($mant -> {value});

    $mant -> brsft($nzeros, 10) if $nzeros != 0;
    return $mant unless wantarray;

    my $expo = $class -> new($nzeros);
    return ($mant, $expo);
}

sub nparts {
    my $self  = shift;
    my $class = ref $self;

    Carp::croak("nparts() is an instance method, not a class method")
        unless $class;

    # Not-a-number.

    if ($self -> is_nan()) {
        my $mant = $self -> copy();             # mantissa
        return $mant unless wantarray;          # scalar context
        my $expo = $class -> bnan();            # exponent
        return ($mant, $expo);                  # list context
    }

    # Infinity.

    if ($self -> is_inf()) {
        my $mant = $self -> copy();             # mantissa
        return $mant unless wantarray;          # scalar context
        my $expo = $class -> binf('+');         # exponent
        return ($mant, $expo);                  # list context
    }

    # Finite number.

    my ($mant, $expo) = $self -> sparts();

    if ($mant -> bcmp(0)) {
        my ($ndigtot, $ndigfrac) = $mant -> length();
        my $expo10adj = $ndigtot - $ndigfrac - 1;

        if ($expo10adj != 0) {
            return $upgrade -> new($self) -> nparts() if $upgrade;
            $mant -> bnan();
            return $mant unless wantarray;
            $expo -> badd($expo10adj);
            return ($mant, $expo);
        }
    }

    return $mant unless wantarray;
    return ($mant, $expo);
}

sub eparts {
    my $self  = shift;
    my $class = ref $self;

    Carp::croak("eparts() is an instance method, not a class method")
        unless $class;

    # Not-a-number and Infinity.

    return $self -> sparts() if $self -> is_nan() || $self -> is_inf();

    # Finite number.

    my ($mant, $expo) = $self -> sparts();

    if ($mant -> bcmp(0)) {
        my $ndigmant  = $mant -> length();
        $expo -> badd($ndigmant);

        # $c is the number of digits that will be in the integer part of the
        # final mantissa.

        my $c = $expo -> copy() -> bdec() -> bmod(3) -> binc();
        $expo -> bsub($c);

        if ($ndigmant > $c) {
            return $upgrade -> new($self) -> eparts() if $upgrade;
            $mant -> bnan();
            return $mant unless wantarray;
            return ($mant, $expo);
        }

        $mant -> blsft($c - $ndigmant, 10);
    }

    return $mant unless wantarray;
    return ($mant, $expo);
}

sub dparts {
    my $self  = shift;
    my $class = ref $self;

    Carp::croak("dparts() is an instance method, not a class method")
        unless $class;

    my $int = $self -> copy();
    return $int unless wantarray;

    my $frc = $class -> bzero();
    return ($int, $frc);
}

###############################################################################
# String conversion methods
###############################################################################

sub bstr {
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    if ($x->{sign} ne '+' && $x->{sign} ne '-') {
        return $x->{sign} unless $x->{sign} eq '+inf'; # -inf, NaN
        return 'inf';                                  # +inf
    }
    my $str = $CALC->_str($x->{value});
    return $x->{sign} eq '-' ? "-$str" : $str;
}

# Scientific notation with significand/mantissa as an integer, e.g., "12345" is
# written as "1.2345e+4".

sub bsstr {
    my ($class, $x) = ref($_[0]) ? (undef, $_[0]) : objectify(1, @_);

    if ($x->{sign} ne '+' && $x->{sign} ne '-') {
        return $x->{sign} unless $x->{sign} eq '+inf';  # -inf, NaN
        return 'inf';                                   # +inf
    }
    my ($m, $e) = $x -> parts();
    my $str = $CALC->_str($m->{value}) . 'e+' . $CALC->_str($e->{value});
    return $x->{sign} eq '-' ? "-$str" : $str;
}

# Normalized notation, e.g., "12345" is written as "12345e+0".

sub bnstr {
    my $x = shift;

    if ($x->{sign} ne '+' && $x->{sign} ne '-') {
        return $x->{sign} unless $x->{sign} eq '+inf';  # -inf, NaN
        return 'inf';                                   # +inf
    }

    return $x -> bstr() if $x -> is_nan() || $x -> is_inf();

    my ($mant, $expo) = $x -> parts();

    # The "fraction posision" is the position (offset) for the decimal point
    # relative to the end of the digit string.

    my $fracpos = $mant -> length() - 1;
    if ($fracpos == 0) {
        my $str = $CALC->_str($mant->{value}) . "e+" . $CALC->_str($expo->{value});
        return $x->{sign} eq '-' ? "-$str" : $str;
    }

    $expo += $fracpos;
    my $mantstr = $CALC->_str($mant -> {value});
    substr($mantstr, -$fracpos, 0) = '.';

    my $str = $mantstr . 'e+' . $CALC->_str($expo -> {value});
    return $x->{sign} eq '-' ? "-$str" : $str;
}

# Engineering notation, e.g., "12345" is written as "12.345e+3".

sub bestr {
    my $x = shift;

    if ($x->{sign} ne '+' && $x->{sign} ne '-') {
        return $x->{sign} unless $x->{sign} eq '+inf';  # -inf, NaN
        return 'inf';                                   # +inf
    }

    my ($mant, $expo) = $x -> parts();

    my $sign = $mant -> sign();
    $mant -> babs();

    my $mantstr = $CALC->_str($mant -> {value});
    my $mantlen = CORE::length($mantstr);

    my $dotidx = 1;
    $expo += $mantlen - 1;

    my $c = $expo -> copy() -> bmod(3);
    $expo   -= $c;
    $dotidx += $c;

    if ($mantlen < $dotidx) {
        $mantstr .= "0" x ($dotidx - $mantlen);
    } elsif ($mantlen > $dotidx) {
        substr($mantstr, $dotidx, 0) = ".";
    }

    my $str = $mantstr . 'e+' . $CALC->_str($expo -> {value});
    return $sign eq "-" ? "-$str" : $str;
}

# Decimal notation, e.g., "12345".

sub bdstr {
    my $x = shift;

    if ($x->{sign} ne '+' && $x->{sign} ne '-') {
        return $x->{sign} unless $x->{sign} eq '+inf'; # -inf, NaN
        return 'inf';                                  # +inf
    }

    my $str = $CALC->_str($x->{value});
    return $x->{sign} eq '-' ? "-$str" : $str;
}

sub to_hex {
    # return as hex string, with prefixed 0x
    my $x = shift;
    $x = $class->new($x) if !ref($x);

    return $x->bstr() if $x->{sign} !~ /^[+-]$/; # inf, nan etc

    my $hex = $CALC->_to_hex($x->{value});
    return $x->{sign} eq '-' ? "-$hex" : $hex;
}

sub to_oct {
    # return as octal string, with prefixed 0
    my $x = shift;
    $x = $class->new($x) if !ref($x);

    return $x->bstr() if $x->{sign} !~ /^[+-]$/; # inf, nan etc

    my $oct = $CALC->_to_oct($x->{value});
    return $x->{sign} eq '-' ? "-$oct" : $oct;
}

sub to_bin {
    # return as binary string, with prefixed 0b
    my $x = shift;
    $x = $class->new($x) if !ref($x);

    return $x->bstr() if $x->{sign} !~ /^[+-]$/; # inf, nan etc

    my $bin = $CALC->_to_bin($x->{value});
    return $x->{sign} eq '-' ? "-$bin" : $bin;
}

sub to_bytes {
    # return a byte string
    my $x = shift;
    $x = $class->new($x) if !ref($x);

    Carp::croak("to_bytes() requires a finite, non-negative integer")
        if $x -> is_neg() || ! $x -> is_int();

    Carp::croak("to_bytes() requires a newer version of the $CALC library.")
        unless $CALC->can('_to_bytes');

    return $CALC->_to_bytes($x->{value});
}

sub as_hex {
    # return as hex string, with prefixed 0x
    my $x = shift;
    $x = $class->new($x) if !ref($x);

    return $x->bstr() if $x->{sign} !~ /^[+-]$/; # inf, nan etc

    my $hex = $CALC->_as_hex($x->{value});
    return $x->{sign} eq '-' ? "-$hex" : $hex;
}

sub as_oct {
    # return as octal string, with prefixed 0
    my $x = shift;
    $x = $class->new($x) if !ref($x);

    return $x->bstr() if $x->{sign} !~ /^[+-]$/; # inf, nan etc

    my $oct = $CALC->_as_oct($x->{value});
    return $x->{sign} eq '-' ? "-$oct" : $oct;
}

sub as_bin {
    # return as binary string, with prefixed 0b
    my $x = shift;
    $x = $class->new($x) if !ref($x);

    return $x->bstr() if $x->{sign} !~ /^[+-]$/; # inf, nan etc

    my $bin = $CALC->_as_bin($x->{value});
    return $x->{sign} eq '-' ? "-$bin" : $bin;
}

*as_bytes = \&to_bytes;

###############################################################################
# Other conversion methods
###############################################################################

sub numify {
    # Make a Perl scalar number from a Math::BigInt object.
    my $x = shift;
    $x = $class->new($x) unless ref $x;

    if ($x -> is_nan()) {
        require Math::Complex;
        my $inf = Math::Complex::Inf();
        return $inf - $inf;
    }

    if ($x -> is_inf()) {
        require Math::Complex;
        my $inf = Math::Complex::Inf();
        return $x -> is_negative() ? -$inf : $inf;
    }

    my $num = 0 + $CALC->_num($x->{value});
    return $x->{sign} eq '-' ? -$num : $num;
}

###############################################################################
# Private methods and functions.
###############################################################################

sub objectify {
    # Convert strings and "foreign objects" to the objects we want.

    # The first argument, $count, is the number of following arguments that
    # objectify() looks at and converts to objects. The first is a classname.
    # If the given count is 0, all arguments will be used.

    # After the count is read, objectify obtains the name of the class to which
    # the following arguments are converted. If the second argument is a
    # reference, use the reference type as the class name. Otherwise, if it is
    # a string that looks like a class name, use that. Otherwise, use $class.

    # Caller:                        Gives us:
    #
    # $x->badd(1);                => ref x, scalar y
    # Class->badd(1, 2);           => classname x (scalar), scalar x, scalar y
    # Class->badd(Class->(1), 2);  => classname x (scalar), ref x, scalar y
    # Math::BigInt::badd(1, 2);    => scalar x, scalar y

    # A shortcut for the common case $x->unary_op(), in which case the argument
    # list is (0, $x) or (1, $x).

    return (ref($_[1]), $_[1]) if @_ == 2 && ($_[0] || 0) == 1 && ref($_[1]);

    # Check the context.

    unless (wantarray) {
        Carp::croak("${class}::objectify() needs list context");
    }

    # Get the number of arguments to objectify.

    my $count = shift;

    # Initialize the output array.

    my @a = @_;

    # If the first argument is a reference, use that reference type as our
    # class name. Otherwise, if the first argument looks like a class name,
    # then use that as our class name. Otherwise, use the default class name.

    my $class;
    if (ref($a[0])) {                   # reference?
        $class = ref($a[0]);
    } elsif ($a[0] =~ /^[A-Z].*::/) {   # string with class name?
        $class = shift @a;
    } else {
        $class = __PACKAGE__;           # default class name
    }

    $count ||= @a;
    unshift @a, $class;

    no strict 'refs';

    # What we upgrade to, if anything.

    my $up = ${"$a[0]::upgrade"};

    # Disable downgrading, because Math::BigFloat -> foo('1.0', '2.0') needs
    # floats.

    my $down;
    if (defined ${"$a[0]::downgrade"}) {
        $down = ${"$a[0]::downgrade"};
        ${"$a[0]::downgrade"} = undef;
    }

    for my $i (1 .. $count) {

        my $ref = ref $a[$i];

        # Perl scalars are fed to the appropriate constructor.

        unless ($ref) {
            $a[$i] = $a[0] -> new($a[$i]);
            next;
        }

        # If it is an object of the right class, all is fine.

        next if $ref -> isa($a[0]);

        # Upgrading is OK, so skip further tests if the argument is upgraded.

        if (defined $up && $ref -> isa($up)) {
            next;
        }

        # See if we can call one of the as_xxx() methods. We don't know whether
        # the as_xxx() method returns an object or a scalar, so re-check
        # afterwards.

        my $recheck = 0;

        if ($a[0] -> isa('Math::BigInt')) {
            if ($a[$i] -> can('as_int')) {
                $a[$i] = $a[$i] -> as_int();
                $recheck = 1;
            } elsif ($a[$i] -> can('as_number')) {
                $a[$i] = $a[$i] -> as_number();
                $recheck = 1;
            }
        }

        elsif ($a[0] -> isa('Math::BigFloat')) {
            if ($a[$i] -> can('as_float')) {
                $a[$i] = $a[$i] -> as_float();
                $recheck = $1;
            }
        }

        # If we called one of the as_xxx() methods, recheck.

        if ($recheck) {
            $ref = ref($a[$i]);

            # Perl scalars are fed to the appropriate constructor.

            unless ($ref) {
                $a[$i] = $a[0] -> new($a[$i]);
                next;
            }

            # If it is an object of the right class, all is fine.

            next if $ref -> isa($a[0]);
        }

        # Last resort.

        $a[$i] = $a[0] -> new($a[$i]);
    }

    # Reset the downgrading.

    ${"$a[0]::downgrade"} = $down;

    return @a;
}

sub import {
    my $class = shift;

    $IMPORT++;                  # remember we did import()
    my @a;
    my $l = scalar @_;
    my $warn_or_die = 0;        # 0 - no warn, 1 - warn, 2 - die
    for (my $i = 0; $i < $l ; $i++) {
        if ($_[$i] eq ':constant') {
            # this causes overlord er load to step in
            overload::constant
                integer => sub { $class->new(shift) },
                binary  => sub { $class->new(shift) };
        } elsif ($_[$i] eq 'upgrade') {
            # this causes upgrading
            $upgrade = $_[$i+1]; # or undef to disable
            $i++;
        } elsif ($_[$i] =~ /^(lib|try|only)\z/) {
            # this causes a different low lib to take care...
            $CALC = $_[$i+1] || '';
            # lib => 1 (warn on fallback), try => 0 (no warn), only => 2 (die on fallback)
            $warn_or_die = 1 if $_[$i] eq 'lib';
            $warn_or_die = 2 if $_[$i] eq 'only';
            $i++;
        } else {
            push @a, $_[$i];
        }
    }
    # any non :constant stuff is handled by our parent, Exporter
    if (@a > 0) {
        require Exporter;

        $class->SUPER::import(@a);            # need it for subclasses
        $class->export_to_level(1, $class, @a); # need it for MBF
    }

    # try to load core math lib
    my @c = split /\s*,\s*/, $CALC;
    foreach (@c) {
        $_ =~ tr/a-zA-Z0-9://cd; # limit to sane characters
    }
    push @c, \'Calc'            # if all fail, try these
      if $warn_or_die < 2;      # but not for "only"
    $CALC = '';                 # signal error
    foreach my $l (@c) {
        # fallback libraries are "marked" as \'string', extract string if nec.
        my $lib = $l;
        $lib = $$l if ref($l);

        next if ($lib || '') eq '';
        $lib = 'Math::BigInt::'.$lib if $lib !~ /^Math::BigInt/i;
        $lib =~ s/\.pm$//;
        if ($] < 5.006) {
            # Perl < 5.6.0 dies with "out of memory!" when eval("") and ':constant' is
            # used in the same script, or eval("") inside import().
            my @parts = split /::/, $lib; # Math::BigInt => Math BigInt
            my $file = pop @parts;
            $file .= '.pm';     # BigInt => BigInt.pm
            require File::Spec;
            $file = File::Spec->catfile (@parts, $file);
            eval {
                require "$file";
                $lib->import(@c);
            }
        } else {
            eval "use $lib qw/@c/;";
        }
        if ($@ eq '') {
            my $ok = 1;
            # loaded it ok, see if the api_version() is high enough
            if ($lib->can('api_version') && $lib->api_version() >= 1.0) {
                $ok = 0;
                # api_version matches, check if it really provides anything we need
                for my $method (qw/
                                      one two ten
                                      str num
                                      add mul div sub dec inc
                                      acmp len digit is_one is_zero is_even is_odd
                                      is_two is_ten
                                      zeros new copy check
                                      from_hex from_oct from_bin as_hex as_bin as_oct
                                      rsft lsft xor and or
                                      mod sqrt root fac pow modinv modpow log_int gcd
                                  /) {
                    if (!$lib->can("_$method")) {
                        if (($WARN{$lib} || 0) < 2) {
                            Carp::carp("$lib is missing method '_$method'");
                            $WARN{$lib} = 1; # still warn about the lib
                        }
                        $ok++;
                        last;
                    }
                }
            }
            if ($ok == 0) {
                $CALC = $lib;
                if ($warn_or_die > 0 && ref($l)) {
                    my $msg = "Math::BigInt: couldn't load specified"
                            . " math lib(s), fallback to $lib";
                    Carp::carp($msg)  if $warn_or_die == 1;
                    Carp::croak($msg) if $warn_or_die == 2;
                }
                last;           # found a usable one, break
            } else {
                if (($WARN{$lib} || 0) < 2) {
                    my $ver = eval "\$$lib\::VERSION" || 'unknown';
                    Carp::carp("Cannot load outdated $lib v$ver, please upgrade");
                    $WARN{$lib} = 2; # never warn again
                }
            }
        }
    }
    if ($CALC eq '') {
        if ($warn_or_die == 2) {
            Carp::croak("Couldn't load specified math lib(s)" .
                        " and fallback disallowed");
        } else {
            Carp::croak("Couldn't load any math lib(s), not even fallback to Calc.pm");
        }
    }

    # notify callbacks
    foreach my $class (keys %CALLBACKS) {
        &{$CALLBACKS{$class}}($CALC);
    }

    # Fill $CAN with the results of $CALC->can(...) for emulating lower math lib
    # functions

    %CAN = ();
    for my $method (qw/ signed_and signed_or signed_xor /) {
        $CAN{$method} = $CALC->can("_$method") ? 1 : 0;
    }

    # import done
}

sub _register_callback {
    my ($class, $callback) = @_;

    if (ref($callback) ne 'CODE') {
        Carp::croak("$callback is not a coderef");
    }
    $CALLBACKS{$class} = $callback;
}

sub _split_dec_string {
    my $str = shift;

    if ($str =~ s/
                     ^

                     # leading whitespace
                     ( \s* )

                     # optional sign
                     ( [+-]? )

                     # significand
                     (
                         \d+ (?: _ \d+ )*
                         (?:
                             \.
                             (?: \d+ (?: _ \d+ )* )?
                         )?
                     |
                         \.
                         \d+ (?: _ \d+ )*
                     )

                     # optional exponent
                     (?:
                         [Ee]
                         ( [+-]? )
                         ( \d+ (?: _ \d+ )* )
                     )?

                     # trailing stuff
                     ( \D .*? )?

                     \z
                 //x) {
        my $leading         = $1;
        my $significand_sgn = $2 || '+';
        my $significand_abs = $3;
        my $exponent_sgn    = $4 || '+';
        my $exponent_abs    = $5 || '0';
        my $trailing        = $6;

        # Remove underscores and leading zeros.

        $significand_abs =~ tr/_//d;
        $exponent_abs    =~ tr/_//d;

        $significand_abs =~ s/^0+(.)/$1/;
        $exponent_abs    =~ s/^0+(.)/$1/;

        # If the significand contains a dot, remove it and adjust the exponent
        # accordingly. E.g., "1234.56789e+3" -> "123456789e-2"

        my $idx = index $significand_abs, '.';
        if ($idx > -1) {
            $significand_abs =~ s/0+\z//;
            substr($significand_abs, $idx, 1) = '';
            my $exponent = $exponent_sgn . $exponent_abs;
            $exponent .= $idx - CORE::length($significand_abs);
            $exponent_abs = abs $exponent;
            $exponent_sgn = $exponent < 0 ? '-' : '+';
        }

        return($leading,
               $significand_sgn, $significand_abs,
               $exponent_sgn, $exponent_abs,
               $trailing);
    }

    return undef;
}

sub _split {
    # input: num_str; output: undef for invalid or
    # (\$mantissa_sign, \$mantissa_value, \$mantissa_fraction,
    # \$exp_sign, \$exp_value)
    # Internal, take apart a string and return the pieces.
    # Strip leading/trailing whitespace, leading zeros, underscore and reject
    # invalid input.
    my $x = shift;

    # strip white space at front, also extraneous leading zeros
    $x =~ s/^\s*([-]?)0*([0-9])/$1$2/g; # will not strip '  .2'
    $x =~ s/^\s+//;                     # but this will
    $x =~ s/\s+$//g;                    # strip white space at end

    # shortcut, if nothing to split, return early
    if ($x =~ /^[+-]?[0-9]+\z/) {
        $x =~ s/^([+-])0*([0-9])/$2/;
        my $sign = $1 || '+';
        return (\$sign, \$x, \'', \'', \0);
    }

    # invalid starting char?
    return if $x !~ /^[+-]?(\.?[0-9]|0b[0-1]|0x[0-9a-fA-F])/;

    return Math::BigInt->from_hex($x) if $x =~ /^[+-]?0x/; # hex string
    return Math::BigInt->from_bin($x) if $x =~ /^[+-]?0b/; # binary string

    # strip underscores between digits
    $x =~ s/([0-9])_([0-9])/$1$2/g;
    $x =~ s/([0-9])_([0-9])/$1$2/g; # do twice for 1_2_3

    # some possible inputs:
    # 2.1234 # 0.12        # 1          # 1E1 # 2.134E1 # 434E-10 # 1.02009E-2
    # .2     # 1_2_3.4_5_6 # 1.4E1_2_3  # 1e3 # +.2     # 0e999

    my ($m, $e, $last) = split /[Ee]/, $x;
    return if defined $last;    # last defined => 1e2E3 or others
    $e = '0' if !defined $e || $e eq "";

    # sign, value for exponent, mantint, mantfrac
    my ($es, $ev, $mis, $miv, $mfv);
    # valid exponent?
    if ($e =~ /^([+-]?)0*([0-9]+)$/) # strip leading zeros
    {
        $es = $1;
        $ev = $2;
        # valid mantissa?
        return if $m eq '.' || $m eq '';
        my ($mi, $mf, $lastf) = split /\./, $m;
        return if defined $lastf; # lastf defined => 1.2.3 or others
        $mi = '0' if !defined $mi;
        $mi .= '0' if $mi =~ /^[\-\+]?$/;
        $mf = '0' if !defined $mf || $mf eq '';
        if ($mi =~ /^([+-]?)0*([0-9]+)$/) # strip leading zeros
        {
            $mis = $1 || '+';
            $miv = $2;
            return unless ($mf =~ /^([0-9]*?)0*$/); # strip trailing zeros
            $mfv = $1;
            # handle the 0e999 case here
            $ev = 0 if $miv eq '0' && $mfv eq '';
            return (\$mis, \$miv, \$mfv, \$es, \$ev);
        }
    }
    return;                     # NaN, not a number
}

sub _trailing_zeros {
    # return the amount of trailing zeros in $x (as scalar)
    my $x = shift;
    $x = $class->new($x) unless ref $x;

    return 0 if $x->{sign} !~ /^[+-]$/; # NaN, inf, -inf etc

    $CALC->_zeros($x->{value}); # must handle odd values, 0 etc
}

sub _scan_for_nonzero {
    # internal, used by bround() to scan for non-zeros after a '5'
    my ($x, $pad, $xs, $len) = @_;

    return 0 if $len == 1;      # "5" is trailed by invisible zeros
    my $follow = $pad - 1;
    return 0 if $follow > $len || $follow < 1;

    # use the string form to check whether only '0's follow or not
    substr ($xs, -$follow) =~ /[^0]/ ? 1 : 0;
}

sub _find_round_parameters {
    # After any operation or when calling round(), the result is rounded by
    # regarding the A & P from arguments, local parameters, or globals.

    # !!!!!!! If you change this, remember to change round(), too! !!!!!!!!!!

    # This procedure finds the round parameters, but it is for speed reasons
    # duplicated in round. Otherwise, it is tested by the testsuite and used
    # by bdiv().

    # returns ($self) or ($self, $a, $p, $r) - sets $self to NaN of both A and P
    # were requested/defined (locally or globally or both)

    my ($self, $a, $p, $r, @args) = @_;
    # $a accuracy, if given by caller
    # $p precision, if given by caller
    # $r round_mode, if given by caller
    # @args all 'other' arguments (0 for unary, 1 for binary ops)

    my $class = ref($self);       # find out class of argument(s)
    no strict 'refs';

    # convert to normal scalar for speed and correctness in inner parts
    $a = $a->can('numify') ? $a->numify() : "$a" if defined $a && ref($a);
    $p = $p->can('numify') ? $p->numify() : "$p" if defined $p && ref($p);

    # now pick $a or $p, but only if we have got "arguments"
    if (!defined $a) {
        foreach ($self, @args) {
            # take the defined one, or if both defined, the one that is smaller
            $a = $_->{_a} if (defined $_->{_a}) && (!defined $a || $_->{_a} < $a);
        }
    }
    if (!defined $p) {
        # even if $a is defined, take $p, to signal error for both defined
        foreach ($self, @args) {
            # take the defined one, or if both defined, the one that is bigger
            # -2 > -3, and 3 > 2
            $p = $_->{_p} if (defined $_->{_p}) && (!defined $p || $_->{_p} > $p);
        }
    }

    # if still none defined, use globals (#2)
    $a = ${"$class\::accuracy"}  unless defined $a;
    $p = ${"$class\::precision"} unless defined $p;

    # A == 0 is useless, so undef it to signal no rounding
    $a = undef if defined $a && $a == 0;

    # no rounding today?
    return ($self) unless defined $a || defined $p; # early out

    # set A and set P is an fatal error
    return ($self->bnan()) if defined $a && defined $p; # error

    $r = ${"$class\::round_mode"} unless defined $r;
    if ($r !~ /^(even|odd|[+-]inf|zero|trunc|common)$/) {
        Carp::croak("Unknown round mode '$r'");
    }

    $a = int($a) if defined $a;
    $p = int($p) if defined $p;

    ($self, $a, $p, $r);
}

###############################################################################
# this method returns 0 if the object can be modified, or 1 if not.
# We use a fast constant sub() here, to avoid costly calls. Subclasses
# may override it with special code (f.i. Math::BigInt::Constant does so)

sub modify () { 0; }

1;

__END__

#line 6654

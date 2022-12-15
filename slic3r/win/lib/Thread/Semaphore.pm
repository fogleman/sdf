#line 1 "Thread/Semaphore.pm"
package Thread::Semaphore;

use strict;
use warnings;

our $VERSION = '2.13';
$VERSION = eval $VERSION;

use threads::shared;
use Scalar::Util 1.10 qw(looks_like_number);

# Predeclarations for internal functions
my ($validate_arg);

# Create a new semaphore optionally with specified count (count defaults to 1)
sub new {
    my $class = shift;

    my $val :shared = 1;
    if (@_) {
        $val = shift;
        if (! defined($val) ||
            ! looks_like_number($val) ||
            (int($val) != $val))
        {
            require Carp;
            $val = 'undef' if (! defined($val));
            Carp::croak("Semaphore initializer is not an integer: $val");
        }
    }

    return bless(\$val, $class);
}

# Decrement a semaphore's count (decrement amount defaults to 1)
sub down {
    my $sema = shift;
    my $dec = @_ ? $validate_arg->(shift) : 1;

    lock($$sema);
    cond_wait($$sema) until ($$sema >= $dec);
    $$sema -= $dec;
}

# Decrement a semaphore's count only if count >= decrement value
#  (decrement amount defaults to 1)
sub down_nb {
    my $sema = shift;
    my $dec = @_ ? $validate_arg->(shift) : 1;

    lock($$sema);
    my $ok = ($$sema >= $dec);
    $$sema -= $dec if $ok;
    return $ok;
}

# Decrement a semaphore's count even if the count goes below 0
#  (decrement amount defaults to 1)
sub down_force {
    my $sema = shift;
    my $dec = @_ ? $validate_arg->(shift) : 1;

    lock($$sema);
    $$sema -= $dec;
}

# Decrement a semaphore's count with timeout
#  (timeout in seconds; decrement amount defaults to 1)
sub down_timed {
    my $sema = shift;
    my $timeout = $validate_arg->(shift);
    my $dec = @_ ? $validate_arg->(shift) : 1;

    lock($$sema);
    my $abs = time() + $timeout;
    until ($$sema >= $dec) {
        return if !cond_timedwait($$sema, $abs);
    }
    $$sema -= $dec;
    return 1;
}

# Increment a semaphore's count (increment amount defaults to 1)
sub up {
    my $sema = shift;
    my $inc = @_ ? $validate_arg->(shift) : 1;

    lock($$sema);
    ($$sema += $inc) > 0 and cond_broadcast($$sema);
}

### Internal Functions ###

# Validate method argument
$validate_arg = sub {
    my $arg = shift;

    if (! defined($arg) ||
        ! looks_like_number($arg) ||
        (int($arg) != $arg) ||
        ($arg < 1))
    {
        require Carp;
        my ($method) = (caller(1))[3];
        $method =~ s/Thread::Semaphore:://;
        $arg = 'undef' if (! defined($arg));
        Carp::croak("Argument to semaphore method '$method' is not a positive integer: $arg");
    }

    return $arg;
};

1;

#line 274

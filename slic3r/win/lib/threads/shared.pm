#line 1 "threads/shared.pm"
package threads::shared;

use 5.008;

use strict;
use warnings;

use Scalar::Util qw(reftype refaddr blessed);

our $VERSION = '1.55'; # Please update the pod, too.
my $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

# Declare that we have been loaded
$threads::shared::threads_shared = 1;

# Method of complaint about things we can't clone
$threads::shared::clone_warn = undef;

# Load the XS code, if applicable
if ($threads::threads) {
    require XSLoader;
    XSLoader::load('threads::shared', $XS_VERSION);

    *is_shared = \&_id;

} else {
    # String eval is generally evil, but we don't want these subs to
    # exist at all if 'threads' is not loaded successfully.
    # Vivifying them conditionally this way saves on average about 4K
    # of memory per thread.
    eval <<'_MARKER_';
        sub share          (\[$@%])         { return $_[0] }
        sub is_shared      (\[$@%])         { undef }
        sub cond_wait      (\[$@%];\[$@%])  { undef }
        sub cond_timedwait (\[$@%]$;\[$@%]) { undef }
        sub cond_signal    (\[$@%])         { undef }
        sub cond_broadcast (\[$@%])         { undef }
_MARKER_
}


### Export ###

sub import
{
    # Exported subroutines
    my @EXPORT = qw(share is_shared cond_wait cond_timedwait
                    cond_signal cond_broadcast shared_clone);
    if ($threads::threads) {
        push(@EXPORT, 'bless');
    }

    # Export subroutine names
    my $caller = caller();
    foreach my $sym (@EXPORT) {
        no strict 'refs';
        *{$caller.'::'.$sym} = \&{$sym};
    }
}


# Predeclarations for internal functions
my ($make_shared);


### Methods, etc. ###

sub threads::shared::tie::SPLICE
{
    require Carp;
    Carp::croak('Splice not implemented for shared arrays');
}


# Create a thread-shared clone of a complex data structure or object
sub shared_clone
{
    if (@_ != 1) {
        require Carp;
        Carp::croak('Usage: shared_clone(REF)');
    }

    return $make_shared->(shift, {});
}


### Internal Functions ###

# Used by shared_clone() to recursively clone
#   a complex data structure or object
$make_shared = sub {
    my ($item, $cloned) = @_;

    # Just return the item if:
    # 1. Not a ref;
    # 2. Already shared; or
    # 3. Not running 'threads'.
    return $item if (! ref($item) || is_shared($item) || ! $threads::threads);

    # Check for previously cloned references
    #   (this takes care of circular refs as well)
    my $addr = refaddr($item);
    if (exists($cloned->{$addr})) {
        # Return the already existing clone
        return $cloned->{$addr};
    }

    # Make copies of array, hash and scalar refs and refs of refs
    my $copy;
    my $ref_type = reftype($item);

    # Copy an array ref
    if ($ref_type eq 'ARRAY') {
        # Make empty shared array ref
        $copy = &share([]);
        # Add to clone checking hash
        $cloned->{$addr} = $copy;
        # Recursively copy and add contents
        push(@$copy, map { $make_shared->($_, $cloned) } @$item);
    }

    # Copy a hash ref
    elsif ($ref_type eq 'HASH') {
        # Make empty shared hash ref
        $copy = &share({});
        # Add to clone checking hash
        $cloned->{$addr} = $copy;
        # Recursively copy and add contents
        foreach my $key (keys(%{$item})) {
            $copy->{$key} = $make_shared->($item->{$key}, $cloned);
        }
    }

    # Copy a scalar ref
    elsif ($ref_type eq 'SCALAR') {
        $copy = \do{ my $scalar = $$item; };
        share($copy);
        # Add to clone checking hash
        $cloned->{$addr} = $copy;
    }

    # Copy of a ref of a ref
    elsif ($ref_type eq 'REF') {
        # Special handling for $x = \$x
        if ($addr == refaddr($$item)) {
            $copy = \$copy;
            share($copy);
            $cloned->{$addr} = $copy;
        } else {
            my $tmp;
            $copy = \$tmp;
            share($copy);
            # Add to clone checking hash
            $cloned->{$addr} = $copy;
            # Recursively copy and add contents
            $tmp = $make_shared->($$item, $cloned);
        }

    } else {
        require Carp;
        if (! defined($threads::shared::clone_warn)) {
            Carp::croak("Unsupported ref type: ", $ref_type);
        } elsif ($threads::shared::clone_warn) {
            Carp::carp("Unsupported ref type: ", $ref_type);
        }
        return undef;
    }

    # If input item is an object, then bless the copy into the same class
    if (my $class = blessed($item)) {
        bless($copy, $class);
    }

    # Clone READONLY flag
    if ($ref_type eq 'SCALAR') {
        if (Internals::SvREADONLY($$item)) {
            Internals::SvREADONLY($$copy, 1) if ($] >= 5.008003);
        }
    }
    if (Internals::SvREADONLY($item)) {
        Internals::SvREADONLY($copy, 1) if ($] >= 5.008003);
    }

    return $copy;
};

1;

__END__

#line 680

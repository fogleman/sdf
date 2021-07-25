#line 1 "Thread/Queue.pm"
package Thread::Queue;

use strict;
use warnings;

our $VERSION = '3.12';
$VERSION = eval $VERSION;

use threads::shared 1.21;
use Scalar::Util 1.10 qw(looks_like_number blessed reftype refaddr);

# Carp errors from threads::shared calls should complain about caller
our @CARP_NOT = ("threads::shared");

# Create a new queue possibly pre-populated with items
sub new
{
    my $class = shift;
    my @queue :shared = map { shared_clone($_) } @_;
    my %self :shared = ( 'queue' => \@queue );
    return bless(\%self, $class);
}

# Add items to the tail of a queue
sub enqueue
{
    my $self = shift;
    lock(%$self);

    if ($$self{'ENDED'}) {
        require Carp;
        Carp::croak("'enqueue' method called on queue that has been 'end'ed");
    }

    # Block if queue size exceeds any specified limit
    my $queue = $$self{'queue'};
    cond_wait(%$self) while ($$self{'LIMIT'} && (@$queue >= $$self{'LIMIT'}));

    # Add items to queue, and then signal other threads
    push(@$queue, map { shared_clone($_) } @_)
        and cond_signal(%$self);
}

# Set or return the max. size for a queue
sub limit : lvalue
{
    my $self = shift;
    lock(%$self);
    $$self{'LIMIT'};
}

# Return a count of the number of items on a queue
sub pending
{
    my $self = shift;
    lock(%$self);
    return if ($$self{'ENDED'} && ! @{$$self{'queue'}});
    return scalar(@{$$self{'queue'}});
}

# Indicate that no more data will enter the queue
sub end
{
    my $self = shift;
    lock(%$self);
    # No more data is coming
    $$self{'ENDED'} = 1;

    cond_signal(%$self);  # Unblock possibly waiting threads
}

# Return 1 or more items from the head of a queue, blocking if needed
sub dequeue
{
    my $self = shift;
    lock(%$self);
    my $queue = $$self{'queue'};

    my $count = @_ ? $self->_validate_count(shift) : 1;

    # Wait for requisite number of items
    cond_wait(%$self) while ((@$queue < $count) && ! $$self{'ENDED'});

    # If no longer blocking, try getting whatever is left on the queue
    return $self->dequeue_nb($count) if ($$self{'ENDED'});

    # Return single item
    if ($count == 1) {
        my $item = shift(@$queue);
        cond_signal(%$self);  # Unblock possibly waiting threads
        return $item;
    }

    # Return multiple items
    my @items;
    push(@items, shift(@$queue)) for (1..$count);
    cond_signal(%$self);  # Unblock possibly waiting threads
    return @items;
}

# Return items from the head of a queue with no blocking
sub dequeue_nb
{
    my $self = shift;
    lock(%$self);
    my $queue = $$self{'queue'};

    my $count = @_ ? $self->_validate_count(shift) : 1;

    # Return single item
    if ($count == 1) {
        my $item = shift(@$queue);
        cond_signal(%$self);  # Unblock possibly waiting threads
        return $item;
    }

    # Return multiple items
    my @items;
    for (1..$count) {
        last if (! @$queue);
        push(@items, shift(@$queue));
    }
    cond_signal(%$self);  # Unblock possibly waiting threads
    return @items;
}

# Return items from the head of a queue, blocking if needed up to a timeout
sub dequeue_timed
{
    my $self = shift;
    lock(%$self);
    my $queue = $$self{'queue'};

    # Timeout may be relative or absolute
    my $timeout = @_ ? $self->_validate_timeout(shift) : -1;
    # Convert to an absolute time for use with cond_timedwait()
    if ($timeout < 32000000) {   # More than one year
        $timeout += time();
    }

    my $count = @_ ? $self->_validate_count(shift) : 1;

    # Wait for requisite number of items, or until timeout
    while ((@$queue < $count) && ! $$self{'ENDED'}) {
        last if (! cond_timedwait(%$self, $timeout));
    }

    # Get whatever we need off the queue if available
    return $self->dequeue_nb($count);
}

# Return an item without removing it from a queue
sub peek
{
    my $self = shift;
    lock(%$self);
    my $index = @_ ? $self->_validate_index(shift) : 0;
    return $$self{'queue'}[$index];
}

# Insert items anywhere into a queue
sub insert
{
    my $self = shift;
    lock(%$self);

    if ($$self{'ENDED'}) {
        require Carp;
        Carp::croak("'insert' method called on queue that has been 'end'ed");
    }

    my $queue = $$self{'queue'};

    my $index = $self->_validate_index(shift);

    return if (! @_);   # Nothing to insert

    # Support negative indices
    if ($index < 0) {
        $index += @$queue;
        if ($index < 0) {
            $index = 0;
        }
    }

    # Dequeue items from $index onward
    my @tmp;
    while (@$queue > $index) {
        unshift(@tmp, pop(@$queue))
    }

    # Add new items to the queue
    push(@$queue, map { shared_clone($_) } @_);

    # Add previous items back onto the queue
    push(@$queue, @tmp);

    cond_signal(%$self);  # Unblock possibly waiting threads
}

# Remove items from anywhere in a queue
sub extract
{
    my $self = shift;
    lock(%$self);
    my $queue = $$self{'queue'};

    my $index = @_ ? $self->_validate_index(shift) : 0;
    my $count = @_ ? $self->_validate_count(shift) : 1;

    # Support negative indices
    if ($index < 0) {
        $index += @$queue;
        if ($index < 0) {
            $count += $index;
            return if ($count <= 0);           # Beyond the head of the queue
            return $self->dequeue_nb($count);  # Extract from the head
        }
    }

    # Dequeue items from $index+$count onward
    my @tmp;
    while (@$queue > ($index+$count)) {
        unshift(@tmp, pop(@$queue))
    }

    # Extract desired items
    my @items;
    unshift(@items, pop(@$queue)) while (@$queue > $index);

    # Add back any removed items
    push(@$queue, @tmp);

    cond_signal(%$self);  # Unblock possibly waiting threads

    # Return single item
    return $items[0] if ($count == 1);

    # Return multiple items
    return @items;
}

### Internal Methods ###

# Check value of the requested index
sub _validate_index
{
    my $self = shift;
    my $index = shift;

    if (! defined($index) ||
        ! looks_like_number($index) ||
        (int($index) != $index))
    {
        require Carp;
        my ($method) = (caller(1))[3];
        my $class_name = ref($self);
        $method =~ s/$class_name\:://;
        $index = 'undef' if (! defined($index));
        Carp::croak("Invalid 'index' argument ($index) to '$method' method");
    }

    return $index;
};

# Check value of the requested count
sub _validate_count
{
    my $self = shift;
    my $count = shift;

    if (! defined($count) ||
        ! looks_like_number($count) ||
        (int($count) != $count) ||
        ($count < 1) ||
        ($$self{'LIMIT'} && $count > $$self{'LIMIT'}))
    {
        require Carp;
        my ($method) = (caller(1))[3];
        my $class_name = ref($self);
        $method =~ s/$class_name\:://;
        $count = 'undef' if (! defined($count));
        if ($$self{'LIMIT'} && $count > $$self{'LIMIT'}) {
            Carp::croak("'count' argument ($count) to '$method' method exceeds queue size limit ($$self{'LIMIT'})");
        } else {
            Carp::croak("Invalid 'count' argument ($count) to '$method' method");
        }
    }

    return $count;
};

# Check value of the requested timeout
sub _validate_timeout
{
    my $self = shift;
    my $timeout = shift;

    if (! defined($timeout) ||
        ! looks_like_number($timeout))
    {
        require Carp;
        my ($method) = (caller(1))[3];
        my $class_name = ref($self);
        $method =~ s/$class_name\:://;
        $timeout = 'undef' if (! defined($timeout));
        Carp::croak("Invalid 'timeout' argument ($timeout) to '$method' method");
    }

    return $timeout;
};

1;

#line 658

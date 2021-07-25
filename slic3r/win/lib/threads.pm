#line 1 "threads.pm"
package threads;

use 5.008;

use strict;
use warnings;

our $VERSION = '2.15';
my $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

# Verify this Perl supports threads
require Config;
if (! $Config::Config{useithreads}) {
    die("This Perl not built to support threads\n");
}

# Complain if 'threads' is loaded after 'threads::shared'
if ($threads::shared::threads_shared) {
    warn <<'_MSG_';
Warning, threads::shared has already been loaded.  To
enable shared variables, 'use threads' must be called
before threads::shared or any module that uses it.
_MSG_
}

# Declare that we have been loaded
$threads::threads = 1;

# Load the XS code
require XSLoader;
XSLoader::load('threads', $XS_VERSION);


### Export ###

sub import
{
    my $class = shift;   # Not used

    # Exported subroutines
    my @EXPORT = qw(async);

    # Handle args
    while (my $sym = shift) {
        if ($sym =~ /^(?:stack|exit)/i) {
            if (defined(my $arg = shift)) {
                if ($sym =~ /^stack/i) {
                    threads->set_stack_size($arg);
                } else {
                    $threads::thread_exit_only = $arg =~ /^thread/i;
                }
            } else {
                require Carp;
                Carp::croak("threads: Missing argument for option: $sym");
            }

        } elsif ($sym =~ /^str/i) {
            import overload ('""' => \&tid);

        } elsif ($sym =~ /^(?::all|yield)$/) {
            push(@EXPORT, qw(yield));

        } else {
            require Carp;
            Carp::croak("threads: Unknown import option: $sym");
        }
    }

    # Export subroutine names
    my $caller = caller();
    foreach my $sym (@EXPORT) {
        no strict 'refs';
        *{$caller.'::'.$sym} = \&{$sym};
    }

    # Set stack size via environment variable
    if (exists($ENV{'PERL5_ITHREADS_STACK_SIZE'})) {
        threads->set_stack_size($ENV{'PERL5_ITHREADS_STACK_SIZE'});
    }
}


### Methods, etc. ###

# Exit from a thread (only)
sub exit
{
    my ($class, $status) = @_;
    if (! defined($status)) {
        $status = 0;
    }

    # Class method only
    if (ref($class)) {
        require Carp;
        Carp::croak('Usage: threads->exit(status)');
    }

    $class->set_thread_exit_only(1);
    CORE::exit($status);
}

# 'Constant' args for threads->list()
sub threads::all      { }
sub threads::running  { 1 }
sub threads::joinable { 0 }

# 'new' is an alias for 'create'
*new = \&create;

# 'async' is a function alias for the 'threads->create()' method
sub async (&;@)
{
    unshift(@_, 'threads');
    # Use "goto" trick to avoid pad problems from 5.8.1 (fixed in 5.8.2)
    goto &create;
}

# Thread object equality checking
use overload (
    '==' => \&equal,
    '!=' => sub { ! equal(@_) },
    'fallback' => 1
);

1;

__END__

#line 1147

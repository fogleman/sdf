#line 1 "Time/HiRes.pm"
package Time::HiRes;

{ use 5.006; }
use strict;

require Exporter;
require DynaLoader;

our @ISA = qw(Exporter DynaLoader);

our @EXPORT = qw( );
our @EXPORT_OK = qw (usleep sleep ualarm alarm gettimeofday time tv_interval
		 getitimer setitimer nanosleep clock_gettime clock_getres
		 clock clock_nanosleep
		 CLOCK_BOOTTIME CLOCK_HIGHRES
		 CLOCK_MONOTONIC CLOCK_MONOTONIC_COARSE
		 CLOCK_MONOTONIC_PRECISE CLOCK_MONOTONIC_RAW
		 CLOCK_PROCESS_CPUTIME_ID
		 CLOCK_REALTIME CLOCK_REALTIME_COARSE
		 CLOCK_REALTIME_FAST CLOCK_REALTIME_PRECISE
		 CLOCK_SECOND CLOCK_SOFTTIME CLOCK_THREAD_CPUTIME_ID
		 CLOCK_TIMEOFDAY CLOCKS_PER_SEC
		 ITIMER_REAL ITIMER_VIRTUAL ITIMER_PROF ITIMER_REALPROF
		 TIMER_ABSTIME
		 d_usleep d_ualarm d_gettimeofday d_getitimer d_setitimer
		 d_nanosleep d_clock_gettime d_clock_getres d_hires_utime
		 d_clock d_clock_nanosleep
		 stat lstat utime
		);

our $VERSION = '1.9741';
our $XS_VERSION = $VERSION;
$VERSION = eval $VERSION;

our $AUTOLOAD;
sub AUTOLOAD {
    my $constname;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    # print "AUTOLOAD: constname = $constname ($AUTOLOAD)\n";
    die "&Time::HiRes::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    # print "AUTOLOAD: error = $error, val = $val\n";
    if ($error) {
        my (undef,$file,$line) = caller;
        die "$error at $file line $line.\n";
    }
    {
	no strict 'refs';
	*$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

sub import {
    my $this = shift;
    for my $i (@_) {
	if (($i eq 'clock_getres'    && !&d_clock_getres)    ||
	    ($i eq 'clock_gettime'   && !&d_clock_gettime)   ||
	    ($i eq 'clock_nanosleep' && !&d_clock_nanosleep) ||
	    ($i eq 'clock'           && !&d_clock)           ||
	    ($i eq 'nanosleep'       && !&d_nanosleep)       ||
	    ($i eq 'usleep'          && !&d_usleep)          ||
	    ($i eq 'utime'           && !&d_hires_utime)     ||
	    ($i eq 'ualarm'          && !&d_ualarm)) {
	    require Carp;
	    Carp::croak("Time::HiRes::$i(): unimplemented in this platform");
	}
    }
    Time::HiRes->export_to_level(1, $this, @_);
}

bootstrap Time::HiRes;

# Preloaded methods go here.

sub tv_interval {
    # probably could have been done in C
    my ($a, $b) = @_;
    $b = [gettimeofday()] unless defined($b);
    (${$b}[0] - ${$a}[0]) + ((${$b}[1] - ${$a}[1]) / 1_000_000);
}

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__

#line 649

#line 1 "Time/Local.pm"
package Time::Local;

use strict;

use Carp ();
use Exporter;

our $VERSION = '1.25';

use parent 'Exporter';

our @EXPORT    = qw( timegm timelocal );
our @EXPORT_OK = qw( timegm_nocheck timelocal_nocheck );

my @MonthDays = ( 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 );

# Determine breakpoint for rolling century
my $ThisYear    = ( localtime() )[5];
my $Breakpoint  = ( $ThisYear + 50 ) % 100;
my $NextCentury = $ThisYear - $ThisYear % 100;
$NextCentury += 100 if $Breakpoint < 50;
my $Century = $NextCentury - 100;
my $SecOff  = 0;

my ( %Options, %Cheat );

use constant SECS_PER_MINUTE => 60;
use constant SECS_PER_HOUR   => 3600;
use constant SECS_PER_DAY    => 86400;

my $MaxDay;
if ( $] < 5.012000 ) {
    require Config;
    ## no critic (Variables::ProhibitPackageVars)

    my $MaxInt;
    if ( $^O eq 'MacOS' ) {

        # time_t is unsigned...
        $MaxInt = ( 1 << ( 8 * $Config::Config{ivsize} ) )
            - 1;    ## no critic qw(ProhibitPackageVars)
    }
    else {
        $MaxInt
            = ( ( 1 << ( 8 * $Config::Config{ivsize} - 2 ) ) - 1 ) * 2
            + 1;    ## no critic qw(ProhibitPackageVars)
    }

    $MaxDay = int( ( $MaxInt - ( SECS_PER_DAY / 2 ) ) / SECS_PER_DAY ) - 1;
}
else {
    # recent localtime()'s limit is the year 2**31
    $MaxDay = 365 * ( 2**31 );
}

# Determine the EPOC day for this machine
my $Epoc = 0;
if ( $^O eq 'vos' ) {

    # work around posix-977 -- VOS doesn't handle dates in the range
    # 1970-1980.
    $Epoc = _daygm( 0, 0, 0, 1, 0, 70, 4, 0 );
}
elsif ( $^O eq 'MacOS' ) {
    $MaxDay *= 2 if $^O eq 'MacOS';    # time_t unsigned ... quick hack?
          # MacOS time() is seconds since 1 Jan 1904, localtime
          # so we need to calculate an offset to apply later
    $Epoc   = 693901;
    $SecOff = timelocal( localtime(0) ) - timelocal( gmtime(0) );
    $Epoc += _daygm( gmtime(0) );
}
else {
    $Epoc = _daygm( gmtime(0) );
}

%Cheat = ();    # clear the cache as epoc has changed

sub _daygm {

    # This is written in such a byzantine way in order to avoid
    # lexical variables and sub calls, for speed
    return $_[3] + (
        $Cheat{ pack( 'ss', @_[ 4, 5 ] ) } ||= do {
            my $month = ( $_[4] + 10 ) % 12;
            my $year  = $_[5] + 1900 - int( $month / 10 );

            ( ( 365 * $year )
                + int( $year / 4 )
                    - int( $year / 100 )
                    + int( $year / 400 )
                    + int( ( ( $month * 306 ) + 5 ) / 10 ) ) - $Epoc;
            }
    );
}

sub _timegm {
    my $sec
        = $SecOff + $_[0]
        + ( SECS_PER_MINUTE * $_[1] )
        + ( SECS_PER_HOUR * $_[2] );

    return $sec + ( SECS_PER_DAY * &_daygm );
}

sub timegm {
    my ( $sec, $min, $hour, $mday, $month, $year ) = @_;

    if ( $year >= 1000 ) {
        $year -= 1900;
    }
    elsif ( $year < 100 and $year >= 0 ) {
        $year += ( $year > $Breakpoint ) ? $Century : $NextCentury;
    }

    unless ( $Options{no_range_check} ) {
        Carp::croak("Month '$month' out of range 0..11")
            if $month > 11
            or $month < 0;

        my $md = $MonthDays[$month];
        ++$md
            if $month == 1 && _is_leap_year( $year + 1900 );

        Carp::croak("Day '$mday' out of range 1..$md")
            if $mday > $md or $mday < 1;
        Carp::croak("Hour '$hour' out of range 0..23")
            if $hour > 23 or $hour < 0;
        Carp::croak("Minute '$min' out of range 0..59")
            if $min > 59 or $min < 0;
        Carp::croak("Second '$sec' out of range 0..59")
            if $sec >= 60 or $sec < 0;
    }

    my $days = _daygm( undef, undef, undef, $mday, $month, $year );

    unless ( $Options{no_range_check} or abs($days) < $MaxDay ) {
        my $msg = q{};
        $msg .= "Day too big - $days > $MaxDay\n" if $days > $MaxDay;

        $year += 1900;
        $msg
            .= "Cannot handle date ($sec, $min, $hour, $mday, $month, $year)";

        Carp::croak($msg);
    }

    return
          $sec + $SecOff
        + ( SECS_PER_MINUTE * $min )
        + ( SECS_PER_HOUR * $hour )
        + ( SECS_PER_DAY * $days );
}

sub _is_leap_year {
    return 0 if $_[0] % 4;
    return 1 if $_[0] % 100;
    return 0 if $_[0] % 400;

    return 1;
}

sub timegm_nocheck {
    local $Options{no_range_check} = 1;
    return &timegm;
}

sub timelocal {
    my $ref_t         = &timegm;
    my $loc_for_ref_t = _timegm( localtime($ref_t) );

    my $zone_off = $loc_for_ref_t - $ref_t
        or return $loc_for_ref_t;

    # Adjust for timezone
    my $loc_t = $ref_t - $zone_off;

    # Are we close to a DST change or are we done
    my $dst_off = $ref_t - _timegm( localtime($loc_t) );

    # If this evaluates to true, it means that the value in $loc_t is
    # the _second_ hour after a DST change where the local time moves
    # backward.
    if (
        !$dst_off
        && ( ( $ref_t - SECS_PER_HOUR )
            - _timegm( localtime( $loc_t - SECS_PER_HOUR ) ) < 0 )
        ) {
        return $loc_t - SECS_PER_HOUR;
    }

    # Adjust for DST change
    $loc_t += $dst_off;

    return $loc_t if $dst_off > 0;

    # If the original date was a non-extent gap in a forward DST jump,
    # we should now have the wrong answer - undo the DST adjustment
    my ( $s, $m, $h ) = localtime($loc_t);
    $loc_t -= $dst_off if $s != $_[0] || $m != $_[1] || $h != $_[2];

    return $loc_t;
}

sub timelocal_nocheck {
    local $Options{no_range_check} = 1;
    return &timelocal;
}

1;

# ABSTRACT: Efficiently compute time from local and GMT time

__END__

#line 420

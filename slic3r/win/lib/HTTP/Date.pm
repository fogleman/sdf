#line 1 "HTTP/Date.pm"
package HTTP::Date;

$VERSION = "6.02";

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(time2str str2time);
@EXPORT_OK = qw(parse_date time2iso time2isoz);

use strict;
require Time::Local;

use vars qw(@DoW @MoY %MoY);
@DoW = qw(Sun Mon Tue Wed Thu Fri Sat);
@MoY = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
@MoY{@MoY} = (1..12);

my %GMT_ZONE = (GMT => 1, UTC => 1, UT => 1, Z => 1);


sub time2str (;$)
{
    my $time = shift;
    $time = time unless defined $time;
    my ($sec, $min, $hour, $mday, $mon, $year, $wday) = gmtime($time);
    sprintf("%s, %02d %s %04d %02d:%02d:%02d GMT",
	    $DoW[$wday],
	    $mday, $MoY[$mon], $year+1900,
	    $hour, $min, $sec);
}


sub str2time ($;$)
{
    my $str = shift;
    return undef unless defined $str;

    # fast exit for strictly conforming string
    if ($str =~ /^[SMTWF][a-z][a-z], (\d\d) ([JFMAJSOND][a-z][a-z]) (\d\d\d\d) (\d\d):(\d\d):(\d\d) GMT$/) {
	return eval {
	    my $t = Time::Local::timegm($6, $5, $4, $1, $MoY{$2}-1, $3);
	    $t < 0 ? undef : $t;
	};
    }

    my @d = parse_date($str);
    return undef unless @d;
    $d[1]--;        # month

    my $tz = pop(@d);
    unless (defined $tz) {
	unless (defined($tz = shift)) {
	    return eval { my $frac = $d[-1]; $frac -= ($d[-1] = int($frac));
			  my $t = Time::Local::timelocal(reverse @d) + $frac;
			  $t < 0 ? undef : $t;
		        };
	}
    }

    my $offset = 0;
    if ($GMT_ZONE{uc $tz}) {
	# offset already zero
    }
    elsif ($tz =~ /^([-+])?(\d\d?):?(\d\d)?$/) {
	$offset = 3600 * $2;
	$offset += 60 * $3 if $3;
	$offset *= -1 if $1 && $1 eq '-';
    }
    else {
	eval { require Time::Zone } || return undef;
	$offset = Time::Zone::tz_offset($tz);
	return undef unless defined $offset;
    }

    return eval { my $frac = $d[-1]; $frac -= ($d[-1] = int($frac));
		  my $t = Time::Local::timegm(reverse @d) + $frac;
		  $t < 0 ? undef : $t - $offset;
		};
}


sub parse_date ($)
{
    local($_) = shift;
    return unless defined;

    # More lax parsing below
    s/^\s+//;  # kill leading space
    s/^(?:Sun|Mon|Tue|Wed|Thu|Fri|Sat)[a-z]*,?\s*//i; # Useless weekday

    my($day, $mon, $yr, $hr, $min, $sec, $tz, $ampm);

    # Then we are able to check for most of the formats with this regexp
    (($day,$mon,$yr,$hr,$min,$sec,$tz) =
        /^
	 (\d\d?)               # day
	    (?:\s+|[-\/])
	 (\w+)                 # month
	    (?:\s+|[-\/])
	 (\d+)                 # year
	 (?:
	       (?:\s+|:)       # separator before clock
	    (\d\d?):(\d\d)     # hour:min
	    (?::(\d\d))?       # optional seconds
	 )?                    # optional clock
	    \s*
	 ([-+]?\d{2,4}|(?![APap][Mm]\b)[A-Za-z]+)? # timezone
	    \s*
	 (?:\(\w+\)|\w{3,})?   # ASCII representation of timezone.
	    \s*$
	/x)

    ||

    # Try the ctime and asctime format
    (($mon, $day, $hr, $min, $sec, $tz, $yr) =
	/^
	 (\w{1,3})             # month
	    \s+
	 (\d\d?)               # day
	    \s+
	 (\d\d?):(\d\d)        # hour:min
	 (?::(\d\d))?          # optional seconds
	    \s+
	 (?:([A-Za-z]+)\s+)?   # optional timezone
	 (\d+)                 # year
	    \s*$               # allow trailing whitespace
	/x)

    ||

    # Then the Unix 'ls -l' date format
    (($mon, $day, $yr, $hr, $min, $sec) =
	/^
	 (\w{3})               # month
	    \s+
	 (\d\d?)               # day
	    \s+
	 (?:
	    (\d\d\d\d) |       # year
	    (\d{1,2}):(\d{2})  # hour:min
            (?::(\d\d))?       # optional seconds
	 )
	 \s*$
       /x)

    ||

    # ISO 8601 format '1996-02-29 12:00:00 -0100' and variants
    (($yr, $mon, $day, $hr, $min, $sec, $tz) =
	/^
	  (\d{4})              # year
	     [-\/]?
	  (\d\d?)              # numerical month
	     [-\/]?
	  (\d\d?)              # day
	 (?:
	       (?:\s+|[-:Tt])  # separator before clock
	    (\d\d?):?(\d\d)    # hour:min
	    (?::?(\d\d(?:\.\d*)?))?  # optional seconds (and fractional)
	 )?                    # optional clock
	    \s*
	 ([-+]?\d\d?:?(:?\d\d)?
	  |Z|z)?               # timezone  (Z is "zero meridian", i.e. GMT)
	    \s*$
	/x)

    ||

    # Windows 'dir' 11-12-96  03:52PM
    (($mon, $day, $yr, $hr, $min, $ampm) =
        /^
          (\d{2})                # numerical month
             -
          (\d{2})                # day
             -
          (\d{2})                # year
             \s+
          (\d\d?):(\d\d)([APap][Mm])  # hour:min AM or PM
             \s*$
        /x)

    ||
    return;  # unrecognized format

    # Translate month name to number
    $mon = $MoY{$mon} ||
           $MoY{"\u\L$mon"} ||
	   ($mon =~ /^\d\d?$/ && $mon >= 1 && $mon <= 12 && int($mon)) ||
           return;

    # If the year is missing, we assume first date before the current,
    # because of the formats we support such dates are mostly present
    # on "ls -l" listings.
    unless (defined $yr) {
	my $cur_mon;
	($cur_mon, $yr) = (localtime)[4, 5];
	$yr += 1900;
	$cur_mon++;
	$yr-- if $mon > $cur_mon;
    }
    elsif (length($yr) < 3) {
	# Find "obvious" year
	my $cur_yr = (localtime)[5] + 1900;
	my $m = $cur_yr % 100;
	my $tmp = $yr;
	$yr += $cur_yr - $m;
	$m -= $tmp;
	$yr += ($m > 0) ? 100 : -100
	    if abs($m) > 50;
    }

    # Make sure clock elements are defined
    $hr  = 0 unless defined($hr);
    $min = 0 unless defined($min);
    $sec = 0 unless defined($sec);

    # Compensate for AM/PM
    if ($ampm) {
	$ampm = uc $ampm;
	$hr = 0 if $hr == 12 && $ampm eq 'AM';
	$hr += 12 if $ampm eq 'PM' && $hr != 12;
    }

    return($yr, $mon, $day, $hr, $min, $sec, $tz)
	if wantarray;

    if (defined $tz) {
	$tz = "Z" if $tz =~ /^(GMT|UTC?|[-+]?0+)$/;
    }
    else {
	$tz = "";
    }
    return sprintf("%04d-%02d-%02d %02d:%02d:%02d%s",
		   $yr, $mon, $day, $hr, $min, $sec, $tz);
}


sub time2iso (;$)
{
    my $time = shift;
    $time = time unless defined $time;
    my($sec,$min,$hour,$mday,$mon,$year) = localtime($time);
    sprintf("%04d-%02d-%02d %02d:%02d:%02d",
	    $year+1900, $mon+1, $mday, $hour, $min, $sec);
}


sub time2isoz (;$)
{
    my $time = shift;
    $time = time unless defined $time;
    my($sec,$min,$hour,$mday,$mon,$year) = gmtime($time);
    sprintf("%04d-%02d-%02d %02d:%02d:%02dZ",
            $year+1900, $mon+1, $mday, $hour, $min, $sec);
}

1;


__END__

#line 389

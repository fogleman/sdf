#line 1 "URI/_punycode.pm"
package URI::_punycode;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use Exporter 'import';
our @EXPORT = qw(encode_punycode decode_punycode);

use integer;

our $DEBUG = 0;

use constant BASE => 36;
use constant TMIN => 1;
use constant TMAX => 26;
use constant SKEW => 38;
use constant DAMP => 700;
use constant INITIAL_BIAS => 72;
use constant INITIAL_N => 128;

my $Delimiter = chr 0x2D;
my $BasicRE   = qr/[\x00-\x7f]/;

sub _croak { require Carp; Carp::croak(@_); }

sub digit_value {
    my $code = shift;
    return ord($code) - ord("A") if $code =~ /[A-Z]/;
    return ord($code) - ord("a") if $code =~ /[a-z]/;
    return ord($code) - ord("0") + 26 if $code =~ /[0-9]/;
    return;
}

sub code_point {
    my $digit = shift;
    return $digit + ord('a') if 0 <= $digit && $digit <= 25;
    return $digit + ord('0') - 26 if 26 <= $digit && $digit <= 36;
    die 'NOT COME HERE';
}

sub adapt {
    my($delta, $numpoints, $firsttime) = @_;
    $delta = $firsttime ? $delta / DAMP : $delta / 2;
    $delta += $delta / $numpoints;
    my $k = 0;
    while ($delta > ((BASE - TMIN) * TMAX) / 2) {
	$delta /= BASE - TMIN;
	$k += BASE;
    }
    return $k + (((BASE - TMIN + 1) * $delta) / ($delta + SKEW));
}

sub decode_punycode {
    my $code = shift;

    my $n      = INITIAL_N;
    my $i      = 0;
    my $bias   = INITIAL_BIAS;
    my @output;

    if ($code =~ s/(.*)$Delimiter//o) {
	push @output, map ord, split //, $1;
	return _croak('non-basic code point') unless $1 =~ /^$BasicRE*$/o;
    }

    while ($code) {
	my $oldi = $i;
	my $w    = 1;
    LOOP:
	for (my $k = BASE; 1; $k += BASE) {
	    my $cp = substr($code, 0, 1, '');
	    my $digit = digit_value($cp);
	    defined $digit or return _croak("invalid punycode input");
	    $i += $digit * $w;
	    my $t = ($k <= $bias) ? TMIN
		: ($k >= $bias + TMAX) ? TMAX : $k - $bias;
	    last LOOP if $digit < $t;
	    $w *= (BASE - $t);
	}
	$bias = adapt($i - $oldi, @output + 1, $oldi == 0);
	warn "bias becomes $bias" if $DEBUG;
	$n += $i / (@output + 1);
	$i = $i % (@output + 1);
	splice(@output, $i, 0, $n);
	warn join " ", map sprintf('%04x', $_), @output if $DEBUG;
	$i++;
    }
    return join '', map chr, @output;
}

sub encode_punycode {
    my $input = shift;
    my @input = split //, $input;

    my $n     = INITIAL_N;
    my $delta = 0;
    my $bias  = INITIAL_BIAS;

    my @output;
    my @basic = grep /$BasicRE/, @input;
    my $h = my $b = @basic;
    push @output, @basic;
    push @output, $Delimiter if $b && $h < @input;
    warn "basic codepoints: (@output)" if $DEBUG;

    while ($h < @input) {
	my $m = min(grep { $_ >= $n } map ord, @input);
	warn sprintf "next code point to insert is %04x", $m if $DEBUG;
	$delta += ($m - $n) * ($h + 1);
	$n = $m;
	for my $i (@input) {
	    my $c = ord($i);
	    $delta++ if $c < $n;
	    if ($c == $n) {
		my $q = $delta;
	    LOOP:
		for (my $k = BASE; 1; $k += BASE) {
		    my $t = ($k <= $bias) ? TMIN :
			($k >= $bias + TMAX) ? TMAX : $k - $bias;
		    last LOOP if $q < $t;
		    my $cp = code_point($t + (($q - $t) % (BASE - $t)));
		    push @output, chr($cp);
		    $q = ($q - $t) / (BASE - $t);
		}
		push @output, chr(code_point($q));
		$bias = adapt($delta, $h + 1, $h == $b);
		warn "bias becomes $bias" if $DEBUG;
		$delta = 0;
		$h++;
	    }
	}
	$delta++;
	$n++;
    }
    return join '', @output;
}

sub min {
    my $min = shift;
    for (@_) { $min = $_ if $_ <= $min }
    return $min;
}

1;
__END__

#line 205

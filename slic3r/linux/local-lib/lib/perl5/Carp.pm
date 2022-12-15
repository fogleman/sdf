#line 1 "Carp.pm"
package Carp;

{ use 5.006; }
use strict;
use warnings;
BEGIN {
    # Very old versions of warnings.pm load Carp.  This can go wrong due
    # to the circular dependency.  If warnings is invoked before Carp,
    # then warnings starts by loading Carp, then Carp (above) tries to
    # invoke warnings, and gets nothing because warnings is in the process
    # of loading and hasn't defined its import method yet.  If we were
    # only turning on warnings ("use warnings" above) this wouldn't be too
    # bad, because Carp would just gets the state of the -w switch and so
    # might not get some warnings that it wanted.  The real problem is
    # that we then want to turn off Unicode warnings, but "no warnings
    # 'utf8'" won't be effective if we're in this circular-dependency
    # situation.  So, if warnings.pm is an affected version, we turn
    # off all warnings ourselves by directly setting ${^WARNING_BITS}.
    # On unaffected versions, we turn off just Unicode warnings, via
    # the proper API.
    if(!defined($warnings::VERSION) || eval($warnings::VERSION) < 1.06) {
	${^WARNING_BITS} = "";
    } else {
	"warnings"->unimport("utf8");
    }
}

sub _fetch_sub { # fetch sub without autovivifying
    my($pack, $sub) = @_;
    $pack .= '::';
    # only works with top-level packages
    return unless exists($::{$pack});
    for ($::{$pack}) {
	return unless ref \$_ eq 'GLOB' && *$_{HASH} && exists $$_{$sub};
	for ($$_{$sub}) {
	    return ref \$_ eq 'GLOB' ? *$_{CODE} : undef
	}
    }
}

# UTF8_REGEXP_PROBLEM is a compile-time constant indicating whether Carp
# must avoid applying a regular expression to an upgraded (is_utf8)
# string.  There are multiple problems, on different Perl versions,
# that require this to be avoided.  All versions prior to 5.13.8 will
# load utf8_heavy.pl for the swash system, even if the regexp doesn't
# use character classes.  Perl 5.6 and Perls [5.11.2, 5.13.11) exhibit
# specific problems when Carp is being invoked in the aftermath of a
# syntax error.
BEGIN {
    if("$]" < 5.013011) {
	*UTF8_REGEXP_PROBLEM = sub () { 1 };
    } else {
	*UTF8_REGEXP_PROBLEM = sub () { 0 };
    }
}

# is_utf8() is essentially the utf8::is_utf8() function, which indicates
# whether a string is represented in the upgraded form (using UTF-8
# internally).  As utf8::is_utf8() is only available from Perl 5.8
# onwards, extra effort is required here to make it work on Perl 5.6.
BEGIN {
    if(defined(my $sub = _fetch_sub utf8 => 'is_utf8')) {
	*is_utf8 = $sub;
    } else {
	# black magic for perl 5.6
	*is_utf8 = sub { unpack("C", "\xaa".$_[0]) != 170 };
    }
}

# The downgrade() function defined here is to be used for attempts to
# downgrade where it is acceptable to fail.  It must be called with a
# second argument that is a true value.
BEGIN {
    if(defined(my $sub = _fetch_sub utf8 => 'downgrade')) {
	*downgrade = \&{"utf8::downgrade"};
    } else {
	*downgrade = sub {
	    my $r = "";
	    my $l = length($_[0]);
	    for(my $i = 0; $i != $l; $i++) {
		my $o = ord(substr($_[0], $i, 1));
		return if $o > 255;
		$r .= chr($o);
	    }
	    $_[0] = $r;
	};
    }
}

our $VERSION = '1.40';
$VERSION =~ tr/_//d;

our $MaxEvalLen = 0;
our $Verbose    = 0;
our $CarpLevel  = 0;
our $MaxArgLen  = 64;    # How much of each argument to print. 0 = all.
our $MaxArgNums = 8;     # How many arguments to print. 0 = all.
our $RefArgFormatter = undef; # allow caller to format reference arguments

require Exporter;
our @ISA       = ('Exporter');
our @EXPORT    = qw(confess croak carp);
our @EXPORT_OK = qw(cluck verbose longmess shortmess);
our @EXPORT_FAIL = qw(verbose);    # hook to enable verbose mode

# The members of %Internal are packages that are internal to perl.
# Carp will not report errors from within these packages if it
# can.  The members of %CarpInternal are internal to Perl's warning
# system.  Carp will not report errors from within these packages
# either, and will not report calls *to* these packages for carp and
# croak.  They replace $CarpLevel, which is deprecated.    The
# $Max(EvalLen|(Arg(Len|Nums)) variables are used to specify how the eval
# text and function arguments should be formatted when printed.

our %CarpInternal;
our %Internal;

# disable these by default, so they can live w/o require Carp
$CarpInternal{Carp}++;
$CarpInternal{warnings}++;
$Internal{Exporter}++;
$Internal{'Exporter::Heavy'}++;

# if the caller specifies verbose usage ("perl -MCarp=verbose script.pl")
# then the following method will be called by the Exporter which knows
# to do this thanks to @EXPORT_FAIL, above.  $_[1] will contain the word
# 'verbose'.

sub export_fail { shift; $Verbose = shift if $_[0] eq 'verbose'; @_ }

sub _cgc {
    no strict 'refs';
    return \&{"CORE::GLOBAL::caller"} if defined &{"CORE::GLOBAL::caller"};
    return;
}

sub longmess {
    local($!, $^E);
    # Icky backwards compatibility wrapper. :-(
    #
    # The story is that the original implementation hard-coded the
    # number of call levels to go back, so calls to longmess were off
    # by one.  Other code began calling longmess and expecting this
    # behaviour, so the replacement has to emulate that behaviour.
    my $cgc = _cgc();
    my $call_pack = $cgc ? $cgc->() : caller();
    if ( $Internal{$call_pack} or $CarpInternal{$call_pack} ) {
        return longmess_heavy(@_);
    }
    else {
        local $CarpLevel = $CarpLevel + 1;
        return longmess_heavy(@_);
    }
}

our @CARP_NOT;

sub shortmess {
    local($!, $^E);
    my $cgc = _cgc();

    # Icky backwards compatibility wrapper. :-(
    local @CARP_NOT = $cgc ? $cgc->() : caller();
    shortmess_heavy(@_);
}

sub croak   { die shortmess @_ }
sub confess { die longmess @_ }
sub carp    { warn shortmess @_ }
sub cluck   { warn longmess @_ }

BEGIN {
    if("$]" >= 5.015002 || ("$]" >= 5.014002 && "$]" < 5.015) ||
	    ("$]" >= 5.012005 && "$]" < 5.013)) {
	*CALLER_OVERRIDE_CHECK_OK = sub () { 1 };
    } else {
	*CALLER_OVERRIDE_CHECK_OK = sub () { 0 };
    }
}

sub caller_info {
    my $i = shift(@_) + 1;
    my %call_info;
    my $cgc = _cgc();
    {
	# Some things override caller() but forget to implement the
	# @DB::args part of it, which we need.  We check for this by
	# pre-populating @DB::args with a sentinel which no-one else
	# has the address of, so that we can detect whether @DB::args
	# has been properly populated.  However, on earlier versions
	# of perl this check tickles a bug in CORE::caller() which
	# leaks memory.  So we only check on fixed perls.
        @DB::args = \$i if CALLER_OVERRIDE_CHECK_OK;
        package DB;
        @call_info{
            qw(pack file line sub has_args wantarray evaltext is_require) }
            = $cgc ? $cgc->($i) : caller($i);
    }

    unless ( defined $call_info{file} ) {
        return ();
    }

    my $sub_name = Carp::get_subname( \%call_info );
    if ( $call_info{has_args} ) {
        my @args;
        if (CALLER_OVERRIDE_CHECK_OK && @DB::args == 1
            && ref $DB::args[0] eq ref \$i
            && $DB::args[0] == \$i ) {
            @DB::args = ();    # Don't let anyone see the address of $i
            local $@;
            my $where = eval {
                my $func    = $cgc or return '';
                my $gv      =
                    (_fetch_sub B => 'svref_2object' or return '')
                        ->($func)->GV;
                my $package = $gv->STASH->NAME;
                my $subname = $gv->NAME;
                return unless defined $package && defined $subname;

                # returning CORE::GLOBAL::caller isn't useful for tracing the cause:
                return if $package eq 'CORE::GLOBAL' && $subname eq 'caller';
                " in &${package}::$subname";
            } || '';
            @args
                = "** Incomplete caller override detected$where; \@DB::args were not set **";
        }
        else {
            @args = @DB::args;
            my $overflow;
            if ( $MaxArgNums and @args > $MaxArgNums )
            {    # More than we want to show?
                $#args = $MaxArgNums - 1;
                $overflow = 1;
            }

            @args = map { Carp::format_arg($_) } @args;

            if ($overflow) {
                push @args, '...';
            }
        }

        # Push the args onto the subroutine
        $sub_name .= '(' . join( ', ', @args ) . ')';
    }
    $call_info{sub_name} = $sub_name;
    return wantarray() ? %call_info : \%call_info;
}

# Transform an argument to a function into a string.
our $in_recurse;
sub format_arg {
    my $arg = shift;

    if ( ref($arg) ) {
         # legitimate, let's not leak it.
        if (!$in_recurse &&
	    do {
                local $@;
	        local $in_recurse = 1;
		local $SIG{__DIE__} = sub{};
                eval {$arg->can('CARP_TRACE') }
            })
        {
            return $arg->CARP_TRACE();
        }
        elsif (!$in_recurse &&
	       defined($RefArgFormatter) &&
	       do {
                local $@;
	        local $in_recurse = 1;
		local $SIG{__DIE__} = sub{};
                eval {$arg = $RefArgFormatter->($arg); 1}
                })
        {
            return $arg;
        }
        else
        {
	    my $sub = _fetch_sub(overload => 'StrVal');
	    return $sub ? &$sub($arg) : "$arg";
        }
    }
    return "undef" if !defined($arg);
    downgrade($arg, 1);
    return $arg if !(UTF8_REGEXP_PROBLEM && is_utf8($arg)) &&
	    $arg =~ /\A-?[0-9]+(?:\.[0-9]*)?(?:[eE][-+]?[0-9]+)?\z/;
    my $suffix = "";
    if ( 2 < $MaxArgLen and $MaxArgLen < length($arg) ) {
        substr ( $arg, $MaxArgLen - 3 ) = "";
	$suffix = "...";
    }
    if(UTF8_REGEXP_PROBLEM && is_utf8($arg)) {
	for(my $i = length($arg); $i--; ) {
	    my $c = substr($arg, $i, 1);
	    my $x = substr($arg, 0, 0);   # work around bug on Perl 5.8.{1,2}
	    if($c eq "\"" || $c eq "\\" || $c eq "\$" || $c eq "\@") {
		substr $arg, $i, 0, "\\";
		next;
	    }
	    my $o = ord($c);

            # This code is repeated in Regexp::CARP_TRACE()
            if ($] ge 5.007_003) {
                substr $arg, $i, 1, sprintf("\\x{%x}", $o)
		  if utf8::native_to_unicode($o) < utf8::native_to_unicode(0x20)
                  || utf8::native_to_unicode($o) > utf8::native_to_unicode(0x7e);
            } elsif (ord("A") == 65) {
                substr $arg, $i, 1, sprintf("\\x{%x}", $o)
                    if $o < 0x20 || $o > 0x7e;
            } else { # Early EBCDIC

                # 3 EBCDIC code pages supported then;  all controls but one
                # are the code points below SPACE.  The other one is 0x5F on
                # POSIX-BC; FF on the other two.
                substr $arg, $i, 1, sprintf("\\x{%x}", $o)
                    if $o < ord(" ") || ((ord ("^") == 106)
                                          ? $o == 0x5f
                                          : $o == 0xff);
            }
	}
    } else {
	$arg =~ s/([\"\\\$\@])/\\$1/g;
        # This is all the ASCII printables spelled-out.  It is portable to all
        # Perl versions and platforms (such as EBCDIC).  There are other more
        # compact ways to do this, but may not work everywhere every version.
        $arg =~ s/([^ !"\$\%#'()*+,\-.\/0123456789:;<=>?\@ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\\\]^_`abcdefghijklmnopqrstuvwxyz\{|}~])/sprintf("\\x{%x}",ord($1))/eg;
    }
    downgrade($arg, 1);
    return "\"".$arg."\"".$suffix;
}

sub Regexp::CARP_TRACE {
    my $arg = "$_[0]";
    downgrade($arg, 1);
    if(UTF8_REGEXP_PROBLEM && is_utf8($arg)) {
	for(my $i = length($arg); $i--; ) {
	    my $o = ord(substr($arg, $i, 1));
	    my $x = substr($arg, 0, 0);   # work around bug on Perl 5.8.{1,2}

            # This code is repeated in format_arg()
            if ($] ge 5.007_003) {
                substr $arg, $i, 1, sprintf("\\x{%x}", $o)
		  if utf8::native_to_unicode($o) < utf8::native_to_unicode(0x20)
                  || utf8::native_to_unicode($o) > utf8::native_to_unicode(0x7e);
            } elsif (ord("A") == 65) {
                substr $arg, $i, 1, sprintf("\\x{%x}", $o)
                    if $o < 0x20 || $o > 0x7e;
            } else { # Early EBCDIC
                substr $arg, $i, 1, sprintf("\\x{%x}", $o)
                    if $o < ord(" ") || ((ord ("^") == 106)
                                          ? $o == 0x5f
                                          : $o == 0xff);
            }
	}
    } else {
        # See comment in format_arg() about this same regex.
        $arg =~ s/([^ !"\$\%#'()*+,\-.\/0123456789:;<=>?\@ABCDEFGHIJKLMNOPQRSTUVWXYZ\[\\\]^_`abcdefghijklmnopqrstuvwxyz\{|}~])/sprintf("\\x{%x}",ord($1))/eg;
    }
    downgrade($arg, 1);
    my $suffix = "";
    if($arg =~ /\A\(\?\^?([a-z]*)(?:-[a-z]*)?:(.*)\)\z/s) {
	($suffix, $arg) = ($1, $2);
    }
    if ( 2 < $MaxArgLen and $MaxArgLen < length($arg) ) {
        substr ( $arg, $MaxArgLen - 3 ) = "";
	$suffix = "...".$suffix;
    }
    return "qr($arg)$suffix";
}

# Takes an inheritance cache and a package and returns
# an anon hash of known inheritances and anon array of
# inheritances which consequences have not been figured
# for.
sub get_status {
    my $cache = shift;
    my $pkg   = shift;
    $cache->{$pkg} ||= [ { $pkg => $pkg }, [ trusts_directly($pkg) ] ];
    return @{ $cache->{$pkg} };
}

# Takes the info from caller() and figures out the name of
# the sub/require/eval
sub get_subname {
    my $info = shift;
    if ( defined( $info->{evaltext} ) ) {
        my $eval = $info->{evaltext};
        if ( $info->{is_require} ) {
            return "require $eval";
        }
        else {
            $eval =~ s/([\\\'])/\\$1/g;
            return "eval '" . str_len_trim( $eval, $MaxEvalLen ) . "'";
        }
    }

    # this can happen on older perls when the sub (or the stash containing it)
    # has been deleted
    if ( !defined( $info->{sub} ) ) {
        return '__ANON__::__ANON__';
    }

    return ( $info->{sub} eq '(eval)' ) ? 'eval {...}' : $info->{sub};
}

# Figures out what call (from the point of view of the caller)
# the long error backtrace should start at.
sub long_error_loc {
    my $i;
    my $lvl = $CarpLevel;
    {
        ++$i;
        my $cgc = _cgc();
        my @caller = $cgc ? $cgc->($i) : caller($i);
        my $pkg = $caller[0];
        unless ( defined($pkg) ) {

            # This *shouldn't* happen.
            if (%Internal) {
                local %Internal;
                $i = long_error_loc();
                last;
            }
            elsif (defined $caller[2]) {
                # this can happen when the stash has been deleted
                # in that case, just assume that it's a reasonable place to
                # stop (the file and line data will still be intact in any
                # case) - the only issue is that we can't detect if the
                # deleted package was internal (so don't do that then)
                # -doy
                redo unless 0 > --$lvl;
                last;
            }
            else {
                return 2;
            }
        }
        redo if $CarpInternal{$pkg};
        redo unless 0 > --$lvl;
        redo if $Internal{$pkg};
    }
    return $i - 1;
}

sub longmess_heavy {
    if ( ref( $_[0] ) ) {   # don't break references as exceptions
        return wantarray ? @_ : $_[0];
    }
    my $i = long_error_loc();
    return ret_backtrace( $i, @_ );
}

# Returns a full stack backtrace starting from where it is
# told.
sub ret_backtrace {
    my ( $i, @error ) = @_;
    my $mess;
    my $err = join '', @error;
    $i++;

    my $tid_msg = '';
    if ( defined &threads::tid ) {
        my $tid = threads->tid;
        $tid_msg = " thread $tid" if $tid;
    }

    my %i = caller_info($i);
    $mess = "$err at $i{file} line $i{line}$tid_msg";
    if( defined $. ) {
        local $@ = '';
        local $SIG{__DIE__};
        eval {
            CORE::die;
        };
        if($@ =~ /^Died at .*(, <.*?> line \d+).$/ ) {
            $mess .= $1;
        }
    }
    $mess .= "\.\n";

    while ( my %i = caller_info( ++$i ) ) {
        $mess .= "\t$i{sub_name} called at $i{file} line $i{line}$tid_msg\n";
    }

    return $mess;
}

sub ret_summary {
    my ( $i, @error ) = @_;
    my $err = join '', @error;
    $i++;

    my $tid_msg = '';
    if ( defined &threads::tid ) {
        my $tid = threads->tid;
        $tid_msg = " thread $tid" if $tid;
    }

    my %i = caller_info($i);
    return "$err at $i{file} line $i{line}$tid_msg\.\n";
}

sub short_error_loc {
    # You have to create your (hash)ref out here, rather than defaulting it
    # inside trusts *on a lexical*, as you want it to persist across calls.
    # (You can default it on $_[2], but that gets messy)
    my $cache = {};
    my $i     = 1;
    my $lvl   = $CarpLevel;
    {
        my $cgc = _cgc();
        my $called = $cgc ? $cgc->($i) : caller($i);
        $i++;
        my $caller = $cgc ? $cgc->($i) : caller($i);

        if (!defined($caller)) {
            my @caller = $cgc ? $cgc->($i) : caller($i);
            if (@caller) {
                # if there's no package but there is other caller info, then
                # the package has been deleted - treat this as a valid package
                # in this case
                redo if defined($called) && $CarpInternal{$called};
                redo unless 0 > --$lvl;
                last;
            }
            else {
                return 0;
            }
        }
        redo if $Internal{$caller};
        redo if $CarpInternal{$caller};
        redo if $CarpInternal{$called};
        redo if trusts( $called, $caller, $cache );
        redo if trusts( $caller, $called, $cache );
        redo unless 0 > --$lvl;
    }
    return $i - 1;
}

sub shortmess_heavy {
    return longmess_heavy(@_) if $Verbose;
    return @_ if ref( $_[0] );    # don't break references as exceptions
    my $i = short_error_loc();
    if ($i) {
        ret_summary( $i, @_ );
    }
    else {
        longmess_heavy(@_);
    }
}

# If a string is too long, trims it with ...
sub str_len_trim {
    my $str = shift;
    my $max = shift || 0;
    if ( 2 < $max and $max < length($str) ) {
        substr( $str, $max - 3 ) = '...';
    }
    return $str;
}

# Takes two packages and an optional cache.  Says whether the
# first inherits from the second.
#
# Recursive versions of this have to work to avoid certain
# possible endless loops, and when following long chains of
# inheritance are less efficient.
sub trusts {
    my $child  = shift;
    my $parent = shift;
    my $cache  = shift;
    my ( $known, $partial ) = get_status( $cache, $child );

    # Figure out consequences until we have an answer
    while ( @$partial and not exists $known->{$parent} ) {
        my $anc = shift @$partial;
        next if exists $known->{$anc};
        $known->{$anc}++;
        my ( $anc_knows, $anc_partial ) = get_status( $cache, $anc );
        my @found = keys %$anc_knows;
        @$known{@found} = ();
        push @$partial, @$anc_partial;
    }
    return exists $known->{$parent};
}

# Takes a package and gives a list of those trusted directly
sub trusts_directly {
    my $class = shift;
    no strict 'refs';
    my $stash = \%{"$class\::"};
    for my $var (qw/ CARP_NOT ISA /) {
        # Don't try using the variable until we know it exists,
        # to avoid polluting the caller's namespace.
        if ( $stash->{$var} && *{$stash->{$var}}{ARRAY} && @{$stash->{$var}} ) {
           return @{$stash->{$var}}
        }
    }
    return;
}

if(!defined($warnings::VERSION) ||
	do { no warnings "numeric"; $warnings::VERSION < 1.03 }) {
    # Very old versions of warnings.pm import from Carp.  This can go
    # wrong due to the circular dependency.  If Carp is invoked before
    # warnings, then Carp starts by loading warnings, then warnings
    # tries to import from Carp, and gets nothing because Carp is in
    # the process of loading and hasn't defined its import method yet.
    # So we work around that by manually exporting to warnings here.
    no strict "refs";
    *{"warnings::$_"} = \&$_ foreach @EXPORT;
}

1;

__END__

#line 934
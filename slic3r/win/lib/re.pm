#line 1 "re.pm"
package re;

# pragma for controlling the regexp engine
use strict;
use warnings;

our $VERSION     = "0.32";
our @ISA         = qw(Exporter);
our @EXPORT_OK   = ('regmust',
                    qw(is_regexp regexp_pattern
                       regname regnames regnames_count));
our %EXPORT_OK = map { $_ => 1 } @EXPORT_OK;

my %bitmask = (
    taint   => 0x00100000, # HINT_RE_TAINT
    eval    => 0x00200000, # HINT_RE_EVAL
);

my $flags_hint = 0x02000000; # HINT_RE_FLAGS
my $PMMOD_SHIFT = 0;
my %reflags = (
    m => 1 << ($PMMOD_SHIFT + 0),
    s => 1 << ($PMMOD_SHIFT + 1),
    i => 1 << ($PMMOD_SHIFT + 2),
    x => 1 << ($PMMOD_SHIFT + 3),
    n => 1 << ($PMMOD_SHIFT + 5),
    p => 1 << ($PMMOD_SHIFT + 6),
    strict => 1 << ($PMMOD_SHIFT + 10),
# special cases:
    d => 0,
    l => 1,
    u => 2,
    a => 3,
    aa => 4,
);

sub setcolor {
 eval {				# Ignore errors
  require Term::Cap;

  my $terminal = Tgetent Term::Cap ({OSPEED => 9600}); # Avoid warning.
  my $props = $ENV{PERL_RE_TC} || 'md,me,so,se,us,ue';
  my @props = split /,/, $props;
  my $colors = join "\t", map {$terminal->Tputs($_,1)} @props;

  $colors =~ s/\0//g;
  $ENV{PERL_RE_COLORS} = $colors;
 };
 if ($@) {
    $ENV{PERL_RE_COLORS} ||= qq'\t\t> <\t> <\t\t';
 }

}

my %flags = (
    COMPILE         => 0x0000FF,
    PARSE           => 0x000001,
    OPTIMISE        => 0x000002,
    TRIEC           => 0x000004,
    DUMP            => 0x000008,
    FLAGS           => 0x000010,
    TEST            => 0x000020,

    EXECUTE         => 0x00FF00,
    INTUIT          => 0x000100,
    MATCH           => 0x000200,
    TRIEE           => 0x000400,

    EXTRA           => 0xFF0000,
    TRIEM           => 0x010000,
    OFFSETS         => 0x020000,
    OFFSETSDBG      => 0x040000,
    STATE           => 0x080000,
    OPTIMISEM       => 0x100000,
    STACK           => 0x280000,
    BUFFERS         => 0x400000,
    GPOS            => 0x800000,
);
$flags{ALL} = -1 & ~($flags{OFFSETS}|$flags{OFFSETSDBG}|$flags{BUFFERS});
$flags{All} = $flags{all} = $flags{DUMP} | $flags{EXECUTE};
$flags{Extra} = $flags{EXECUTE} | $flags{COMPILE} | $flags{GPOS};
$flags{More} = $flags{MORE} = $flags{All} | $flags{TRIEC} | $flags{TRIEM} | $flags{STATE};
$flags{State} = $flags{DUMP} | $flags{EXECUTE} | $flags{STATE};
$flags{TRIE} = $flags{DUMP} | $flags{EXECUTE} | $flags{TRIEC};

if (defined &DynaLoader::boot_DynaLoader) {
    require XSLoader;
    XSLoader::load();
}
# else we're miniperl
# We need to work for miniperl, because the XS toolchain uses Text::Wrap, which
# uses re 'taint'.

sub _load_unload {
    my ($on)= @_;
    if ($on) {
	# We call install() every time, as if we didn't, we wouldn't
	# "see" any changes to the color environment var since
	# the last time it was called.

	# install() returns an integer, which if casted properly
	# in C resolves to a structure containing the regexp
	# hooks. Setting it to a random integer will guarantee
	# segfaults.
	$^H{regcomp} = install();
    } else {
        delete $^H{regcomp};
    }
}

sub bits {
    my $on = shift;
    my $bits = 0;
    my $turning_all_off = ! @_ && ! $on;
    my %seen;   # Has flag already been seen?
    if ($turning_all_off) {

        # Pretend were called with certain parameters, which are best dealt
        # with that way.
        push @_, keys %bitmask; # taint and eval
        push @_, 'strict';
    }

    # Process each subpragma parameter
   ARG:
    foreach my $idx (0..$#_){
        my $s=$_[$idx];
        if ($s eq 'Debug' or $s eq 'Debugcolor') {
            setcolor() if $s =~/color/i;
            ${^RE_DEBUG_FLAGS} = 0 unless defined ${^RE_DEBUG_FLAGS};
            for my $idx ($idx+1..$#_) {
                if ($flags{$_[$idx]}) {
                    if ($on) {
                        ${^RE_DEBUG_FLAGS} |= $flags{$_[$idx]};
                    } else {
                        ${^RE_DEBUG_FLAGS} &= ~ $flags{$_[$idx]};
                    }
                } else {
                    require Carp;
                    Carp::carp("Unknown \"re\" Debug flag '$_[$idx]', possible flags: ",
                               join(", ",sort keys %flags ) );
                }
            }
            _load_unload($on ? 1 : ${^RE_DEBUG_FLAGS});
            last;
        } elsif ($s eq 'debug' or $s eq 'debugcolor') {
	    setcolor() if $s =~/color/i;
	    _load_unload($on);
	    last;
        } elsif (exists $bitmask{$s}) {
	    $bits |= $bitmask{$s};
	} elsif ($EXPORT_OK{$s}) {
	    require Exporter;
	    re->export_to_level(2, 're', $s);
        } elsif ($s eq 'strict') {
            if ($on) {
                $^H{reflags} |= $reflags{$s};
                warnings::warnif('experimental::re_strict',
                                 "\"use re 'strict'\" is experimental");

                # Turn on warnings if not already done.
                if (! warnings::enabled('regexp')) {
                    require warnings;
                    warnings->import('regexp');
                    $^H{re_strict} = 1;
                }
            }
            else {
                $^H{reflags} &= ~$reflags{$s} if $^H{reflags};

                # Turn off warnings if we turned them on.
                warnings->unimport('regexp') if $^H{re_strict};
            }
	    if ($^H{reflags}) {
                $^H |= $flags_hint;
            }
            else {
                $^H &= ~$flags_hint;
            }
	} elsif ($s =~ s/^\///) {
	    my $reflags = $^H{reflags} || 0;
	    my $seen_charset;
	    while ($s =~ m/( . )/gx) {
                local $_ = $1;
		if (/[adul]/) {
                    # The 'a' may be repeated; hide this from the rest of the
                    # code by counting and getting rid of all of them, then
                    # changing to 'aa' if there is a repeat.
                    if ($_ eq 'a') {
                        my $sav_pos = pos $s;
                        my $a_count = $s =~ s/a//g;
                        pos $s = $sav_pos - 1;  # -1 because got rid of the 'a'
                        if ($a_count > 2) {
			    require Carp;
                            Carp::carp(
                            qq 'The "a" flag may only appear a maximum of twice'
                            );
                        }
                        elsif ($a_count == 2) {
                            $_ = 'aa';
                        }
                    }
		    if ($on) {
			if ($seen_charset) {
			    require Carp;
                            if ($seen_charset ne $_) {
                                Carp::carp(
                                qq 'The "$seen_charset" and "$_" flags '
                                .qq 'are exclusive'
                                );
                            }
                            else {
                                Carp::carp(
                                qq 'The "$seen_charset" flag may not appear '
                                .qq 'twice'
                                );
                            }
			}
			$^H{reflags_charset} = $reflags{$_};
			$seen_charset = $_;
		    }
		    else {
			delete $^H{reflags_charset}
                                     if defined $^H{reflags_charset}
                                        && $^H{reflags_charset} == $reflags{$_};
		    }
		} elsif (exists $reflags{$_}) {
                    $seen{$_}++;
                    $on
		      ? $reflags |= $reflags{$_}
		      : ($reflags &= ~$reflags{$_});
		} else {
		    require Carp;
		    Carp::carp(
		     qq'Unknown regular expression flag "$_"'
		    );
		    next ARG;
		}
	    }
	    ($^H{reflags} = $reflags or defined $^H{reflags_charset})
	                    ? $^H |= $flags_hint
	                    : ($^H &= ~$flags_hint);
	} else {
	    require Carp;
	    Carp::carp("Unknown \"re\" subpragma '$s' (known ones are: ",
                       join(', ', map {qq('$_')} 'debug', 'debugcolor', sort keys %bitmask),
                       ")");
	}
    }
    if (exists $seen{'x'} && $seen{'x'} > 1
        && (warnings::enabled("deprecated")
            || warnings::enabled("regexp")))
    {
        my $message = "Having more than one /x regexp modifier is deprecated";
        if (warnings::enabled("deprecated")) {
            warnings::warn("deprecated", $message);
        }
        else {
            warnings::warn("regexp", $message);
        }
    }

    if ($turning_all_off) {
        _load_unload(0);
        $^H{reflags} = 0;
        $^H{reflags_charset} = 0;
        $^H &= ~$flags_hint;
    }

    $bits;
}

sub import {
    shift;
    $^H |= bits(1, @_);
}

sub unimport {
    shift;
    $^H &= ~ bits(0, @_);
}

1;

__END__

#line 733

#line 1 "Encode/Locale.pm"
package Encode::Locale;

use strict;
our $VERSION = "1.05";

use base 'Exporter';
our @EXPORT_OK = qw(
    decode_argv env
    $ENCODING_LOCALE $ENCODING_LOCALE_FS
    $ENCODING_CONSOLE_IN $ENCODING_CONSOLE_OUT
);

use Encode ();
use Encode::Alias ();

our $ENCODING_LOCALE;
our $ENCODING_LOCALE_FS;
our $ENCODING_CONSOLE_IN;
our $ENCODING_CONSOLE_OUT;

sub DEBUG () { 0 }

sub _init {
    if ($^O eq "MSWin32") {
	unless ($ENCODING_LOCALE) {
	    # Try to obtain what the Windows ANSI code page is
	    eval {
		unless (defined &GetACP) {
		    require Win32;
                    eval { Win32::GetACP() };
		    *GetACP = sub { &Win32::GetACP } unless $@;
		}
		unless (defined &GetACP) {
		    require Win32::API;
		    Win32::API->Import('kernel32', 'int GetACP()');
		}
		if (defined &GetACP) {
		    my $cp = GetACP();
		    $ENCODING_LOCALE = "cp$cp" if $cp;
		}
	    };
	}

	unless ($ENCODING_CONSOLE_IN) {
            # only test one since set together
            unless (defined &GetInputCP) {
                eval {
                    require Win32;
                    eval { Win32::GetConsoleCP() };
                    # manually "import" it since Win32->import refuses
                    *GetInputCP = sub { &Win32::GetConsoleCP } unless $@;
                    *GetOutputCP = sub { &Win32::GetConsoleOutputCP } unless $@;
                };
                unless (defined &GetInputCP) {
                    eval {
                        # try Win32::Console module for codepage to use
                        require Win32::Console;
                        eval { Win32::Console::InputCP() };
                        *GetInputCP = sub { &Win32::Console::InputCP }
                            unless $@;
                        *GetOutputCP = sub { &Win32::Console::OutputCP }
                            unless $@;
                    };
                }
                unless (defined &GetInputCP) {
                    # final fallback
                    *GetInputCP = *GetOutputCP = sub {
                        # another fallback that could work is:
                        # reg query HKLM\System\CurrentControlSet\Control\Nls\CodePage /v ACP
                        ((qx(chcp) || '') =~ /^Active code page: (\d+)/)
                            ? $1 : ();
                    };
                }
	    }
            my $cp = GetInputCP();
            $ENCODING_CONSOLE_IN = "cp$cp" if $cp;
            $cp = GetOutputCP();
            $ENCODING_CONSOLE_OUT = "cp$cp" if $cp;
	}
    }

    unless ($ENCODING_LOCALE) {
	eval {
	    require I18N::Langinfo;
	    $ENCODING_LOCALE = I18N::Langinfo::langinfo(I18N::Langinfo::CODESET());

	    # Workaround of Encode < v2.25.  The "646" encoding  alias was
	    # introduced in Encode-2.25, but we don't want to require that version
	    # quite yet.  Should avoid the CPAN testers failure reported from
	    # openbsd-4.7/perl-5.10.0 combo.
	    $ENCODING_LOCALE = "ascii" if $ENCODING_LOCALE eq "646";

	    # https://rt.cpan.org/Ticket/Display.html?id=66373
	    $ENCODING_LOCALE = "hp-roman8" if $^O eq "hpux" && $ENCODING_LOCALE eq "roman8";
	};
	$ENCODING_LOCALE ||= $ENCODING_CONSOLE_IN;
    }

    if ($^O eq "darwin") {
	$ENCODING_LOCALE_FS ||= "UTF-8";
    }

    # final fallback
    $ENCODING_LOCALE ||= $^O eq "MSWin32" ? "cp1252" : "UTF-8";
    $ENCODING_LOCALE_FS ||= $ENCODING_LOCALE;
    $ENCODING_CONSOLE_IN ||= $ENCODING_LOCALE;
    $ENCODING_CONSOLE_OUT ||= $ENCODING_CONSOLE_IN;

    unless (Encode::find_encoding($ENCODING_LOCALE)) {
	my $foundit;
	if (lc($ENCODING_LOCALE) eq "gb18030") {
	    eval {
		require Encode::HanExtra;
	    };
	    if ($@) {
		die "Need Encode::HanExtra to be installed to support locale codeset ($ENCODING_LOCALE), stopped";
	    }
	    $foundit++ if Encode::find_encoding($ENCODING_LOCALE);
	}
	die "The locale codeset ($ENCODING_LOCALE) isn't one that perl can decode, stopped"
	    unless $foundit;

    }

    # use Data::Dump; ddx $ENCODING_LOCALE, $ENCODING_LOCALE_FS, $ENCODING_CONSOLE_IN, $ENCODING_CONSOLE_OUT;
}

_init();
Encode::Alias::define_alias(sub {
    no strict 'refs';
    no warnings 'once';
    return ${"ENCODING_" . uc(shift)};
}, "locale");

sub _flush_aliases {
    no strict 'refs';
    for my $a (keys %Encode::Alias::Alias) {
	if (defined ${"ENCODING_" . uc($a)}) {
	    delete $Encode::Alias::Alias{$a};
	    warn "Flushed alias cache for $a" if DEBUG;
	}
    }
}

sub reinit {
    $ENCODING_LOCALE = shift;
    $ENCODING_LOCALE_FS = shift;
    $ENCODING_CONSOLE_IN = $ENCODING_LOCALE;
    $ENCODING_CONSOLE_OUT = $ENCODING_LOCALE;
    _init();
    _flush_aliases();
}

sub decode_argv {
    die if defined wantarray;
    for (@ARGV) {
	$_ = Encode::decode(locale => $_, @_);
    }
}

sub env {
    my $k = Encode::encode(locale => shift);
    my $old = $ENV{$k};
    if (@_) {
	my $v = shift;
	if (defined $v) {
	    $ENV{$k} = Encode::encode(locale => $v);
	}
	else {
	    delete $ENV{$k};
	}
    }
    return Encode::decode(locale => $old) if defined wantarray;
}

1;

__END__

#line 374

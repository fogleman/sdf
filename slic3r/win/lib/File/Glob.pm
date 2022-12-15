#line 1 "File/Glob.pm"
package File::Glob;

use strict;
our($VERSION, @ISA, @EXPORT_OK, @EXPORT_FAIL, %EXPORT_TAGS, $DEFAULT_FLAGS);

require XSLoader;

@ISA = qw(Exporter);

# NOTE: The glob() export is only here for compatibility with 5.6.0.
# csh_glob() should not be used directly, unless you know what you're doing.

%EXPORT_TAGS = (
    'glob' => [ qw(
        GLOB_ABEND
	GLOB_ALPHASORT
        GLOB_ALTDIRFUNC
        GLOB_BRACE
        GLOB_CSH
        GLOB_ERR
        GLOB_ERROR
        GLOB_LIMIT
        GLOB_MARK
        GLOB_NOCASE
        GLOB_NOCHECK
        GLOB_NOMAGIC
        GLOB_NOSORT
        GLOB_NOSPACE
        GLOB_QUOTE
        GLOB_TILDE
        bsd_glob
        glob
    ) ],
);
$EXPORT_TAGS{bsd_glob} = [@{$EXPORT_TAGS{glob}}];
pop @{$EXPORT_TAGS{bsd_glob}}; # no "glob"

@EXPORT_OK   = (@{$EXPORT_TAGS{'glob'}}, 'csh_glob');

$VERSION = '1.26';

sub import {
    require Exporter;
    local $Exporter::ExportLevel = $Exporter::ExportLevel + 1;
    Exporter::import(grep {
        my $passthrough;
        if ($_ eq ':case') {
            $DEFAULT_FLAGS &= ~GLOB_NOCASE()
        }
        elsif ($_ eq ':nocase') {
            $DEFAULT_FLAGS |= GLOB_NOCASE();
        }
        elsif ($_ eq ':globally') {
	    no warnings 'redefine';
	    *CORE::GLOBAL::glob = \&File::Glob::csh_glob;
	}
        elsif ($_ eq ':bsd_glob') {
	    no strict; *{caller."::glob"} = \&bsd_glob_override;
            $passthrough = 1;
	}
	else {
            $passthrough = 1;
        }
        $passthrough;
    } @_);
}

XSLoader::load();

$DEFAULT_FLAGS = GLOB_CSH();
if ($^O =~ /^(?:MSWin32|VMS|os2|dos|riscos)$/) {
    $DEFAULT_FLAGS |= GLOB_NOCASE();
}

# File::Glob::glob() is deprecated because its prototype is different from
# CORE::glob() (use bsd_glob() instead)
sub glob {
    splice @_, 1; # no flags
    goto &bsd_glob;
}

1;
__END__

#line 410

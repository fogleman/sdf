#line 1 "Params/Util.pm"
package Params::Util;

#line 57

use 5.00503;
use strict;
require overload;
require Exporter;
require Scalar::Util;
require DynaLoader;

use vars qw{$VERSION @ISA @EXPORT_OK %EXPORT_TAGS};

$VERSION   = '1.07';
@ISA       = qw{
	Exporter
	DynaLoader
};
@EXPORT_OK = qw{
	_STRING     _IDENTIFIER
	_CLASS      _CLASSISA   _SUBCLASS  _DRIVER  _CLASSDOES
	_NUMBER     _POSINT     _NONNEGINT
	_SCALAR     _SCALAR0
	_ARRAY      _ARRAY0     _ARRAYLIKE
	_HASH       _HASH0      _HASHLIKE
	_CODE       _CODELIKE
	_INVOCANT   _REGEX      _INSTANCE  _INSTANCEDOES
	_SET        _SET0
	_HANDLE
};
%EXPORT_TAGS = ( ALL => \@EXPORT_OK );

eval {
	local $ENV{PERL_DL_NONLAZY} = 0 if $ENV{PERL_DL_NONLAZY};
	bootstrap Params::Util $VERSION;
	1;
} unless $ENV{PERL_PARAMS_UTIL_PP};

# Use a private pure-perl copy of looks_like_number if the version of
# Scalar::Util is old (for whatever reason).
my $SU = eval "$Scalar::Util::VERSION" || 0;
if ( $SU >= 1.18 ) { 
	Scalar::Util->import('looks_like_number');
} else {
	eval <<'END_PERL';
sub looks_like_number {
	local $_ = shift;

	# checks from perlfaq4
	return 0 if !defined($_);
	if (ref($_)) {
		return overload::Overloaded($_) ? defined(0 + $_) : 0;
	}
	return 1 if (/^[+-]?[0-9]+$/); # is a +/- integer
	return 1 if (/^([+-]?)(?=[0-9]|\.[0-9])[0-9]*(\.[0-9]*)?([Ee]([+-]?[0-9]+))?$/); # a C float
	return 1 if ($] >= 5.008 and /^(Inf(inity)?|NaN)$/i) or ($] >= 5.006001 and /^Inf$/i);

	0;
}
END_PERL
}





#####################################################################
# Param Checking Functions

#line 147

eval <<'END_PERL' unless defined &_STRING;
sub _STRING ($) {
	(defined $_[0] and ! ref $_[0] and length($_[0])) ? $_[0] : undef;
}
END_PERL

#line 166

eval <<'END_PERL' unless defined &_IDENTIFIER;
sub _IDENTIFIER ($) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^[^\W\d]\w*\z/s) ? $_[0] : undef;
}
END_PERL

#line 189

eval <<'END_PERL' unless defined &_CLASS;
sub _CLASS ($) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^[^\W\d]\w*(?:::\w+)*\z/s) ? $_[0] : undef;
}
END_PERL

#line 215

eval <<'END_PERL' unless defined &_CLASSISA;
sub _CLASSISA ($$) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^[^\W\d]\w*(?:::\w+)*\z/s and $_[0]->isa($_[1])) ? $_[0] : undef;
}
END_PERL

#line 230

eval <<'END_PERL' unless defined &_CLASSDOES;
sub _CLASSDOES ($$) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^[^\W\d]\w*(?:::\w+)*\z/s and $_[0]->DOES($_[1])) ? $_[0] : undef;
}
END_PERL

#line 256

eval <<'END_PERL' unless defined &_SUBCLASS;
sub _SUBCLASS ($$) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^[^\W\d]\w*(?:::\w+)*\z/s and $_[0] ne $_[1] and $_[0]->isa($_[1])) ? $_[0] : undef;
}
END_PERL

#line 278

eval <<'END_PERL' unless defined &_NUMBER;
sub _NUMBER ($) {
	( defined $_[0] and ! ref $_[0] and looks_like_number($_[0]) )
	? $_[0]
	: undef;
}
END_PERL

#line 302

eval <<'END_PERL' unless defined &_POSINT;
sub _POSINT ($) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^[1-9]\d*$/) ? $_[0] : undef;
}
END_PERL

#line 332

eval <<'END_PERL' unless defined &_NONNEGINT;
sub _NONNEGINT ($) {
	(defined $_[0] and ! ref $_[0] and $_[0] =~ m/^(?:0|[1-9]\d*)$/) ? $_[0] : undef;
}
END_PERL

#line 354

eval <<'END_PERL' unless defined &_SCALAR;
sub _SCALAR ($) {
	(ref $_[0] eq 'SCALAR' and defined ${$_[0]} and ${$_[0]} ne '') ? $_[0] : undef;
}
END_PERL

#line 376

eval <<'END_PERL' unless defined &_SCALAR0;
sub _SCALAR0 ($) {
	ref $_[0] eq 'SCALAR' ? $_[0] : undef;
}
END_PERL

#line 398

eval <<'END_PERL' unless defined &_ARRAY;
sub _ARRAY ($) {
	(ref $_[0] eq 'ARRAY' and @{$_[0]}) ? $_[0] : undef;
}
END_PERL

#line 421

eval <<'END_PERL' unless defined &_ARRAY0;
sub _ARRAY0 ($) {
	ref $_[0] eq 'ARRAY' ? $_[0] : undef;
}
END_PERL

#line 437

eval <<'END_PERL' unless defined &_ARRAYLIKE;
sub _ARRAYLIKE {
	(defined $_[0] and ref $_[0] and (
		(Scalar::Util::reftype($_[0]) eq 'ARRAY')
		or
		overload::Method($_[0], '@{}')
	)) ? $_[0] : undef;
}
END_PERL

#line 463

eval <<'END_PERL' unless defined &_HASH;
sub _HASH ($) {
	(ref $_[0] eq 'HASH' and scalar %{$_[0]}) ? $_[0] : undef;
}
END_PERL

#line 485

eval <<'END_PERL' unless defined &_HASH0;
sub _HASH0 ($) {
	ref $_[0] eq 'HASH' ? $_[0] : undef;
}
END_PERL

#line 501

eval <<'END_PERL' unless defined &_HASHLIKE;
sub _HASHLIKE {
	(defined $_[0] and ref $_[0] and (
		(Scalar::Util::reftype($_[0]) eq 'HASH')
		or
		overload::Method($_[0], '%{}')
	)) ? $_[0] : undef;
}
END_PERL

#line 524

eval <<'END_PERL' unless defined &_CODE;
sub _CODE ($) {
	ref $_[0] eq 'CODE' ? $_[0] : undef;
}
END_PERL

#line 572

eval <<'END_PERL' unless defined &_CODELIKE;
sub _CODELIKE($) {
	(
		(Scalar::Util::reftype($_[0])||'') eq 'CODE'
		or
		Scalar::Util::blessed($_[0]) and overload::Method($_[0],'&{}')
	)
	? $_[0] : undef;
}
END_PERL

#line 595

eval <<'END_PERL' unless defined &_INVOCANT;
sub _INVOCANT($) {
	(defined $_[0] and
		(defined Scalar::Util::blessed($_[0])
		or      
		# We used to check for stash definedness, but any class-like name is a
		# valid invocant for UNIVERSAL methods, so we stopped. -- rjbs, 2006-07-02
		Params::Util::_CLASS($_[0]))
	) ? $_[0] : undef;
}
END_PERL

#line 620

eval <<'END_PERL' unless defined &_INSTANCE;
sub _INSTANCE ($$) {
	(Scalar::Util::blessed($_[0]) and $_[0]->isa($_[1])) ? $_[0] : undef;
}
END_PERL

#line 635

eval <<'END_PERL' unless defined &_INSTANCEDOES;
sub _INSTANCEDOES ($$) {
	(Scalar::Util::blessed($_[0]) and $_[0]->DOES($_[1])) ? $_[0] : undef;
}
END_PERL

#line 653

eval <<'END_PERL' unless defined &_REGEX;
sub _REGEX ($) {
	(defined $_[0] and 'Regexp' eq ref($_[0])) ? $_[0] : undef;
}
END_PERL

#line 678

eval <<'END_PERL' unless defined &_SET;
sub _SET ($$) {
	my $set = shift;
	_ARRAY($set) or return undef;
	foreach my $item ( @$set ) {
		_INSTANCE($item,$_[0]) or return undef;
	}
	$set;
}
END_PERL

#line 708

eval <<'END_PERL' unless defined &_SET0;
sub _SET0 ($$) {
	my $set = shift;
	_ARRAY0($set) or return undef;
	foreach my $item ( @$set ) {
		_INSTANCE($item,$_[0]) or return undef;
	}
	$set;
}
END_PERL

#line 736

# We're doing this longhand for now. Once everything is perfect,
# we'll compress this into something that compiles more efficiently.
# Further, testing file handles is not something that is generally
# done millions of times, so doing it slowly is not a big speed hit.
eval <<'END_PERL' unless defined &_HANDLE;
sub _HANDLE {
	my $it = shift;

	# It has to be defined, of course
	unless ( defined $it ) {
		return undef;
	}

	# Normal globs are considered to be file handles
	if ( ref $it eq 'GLOB' ) {
		return $it;
	}

	# Check for a normal tied filehandle
	# Side Note: 5.5.4's tied() and can() doesn't like getting undef
	if ( tied($it) and tied($it)->can('TIEHANDLE') ) {
		return $it;
	}

	# There are no other non-object handles that we support
	unless ( Scalar::Util::blessed($it) ) {
		return undef;
	}

	# Check for a common base classes for conventional IO::Handle object
	if ( $it->isa('IO::Handle') ) {
		return $it;
	}


	# Check for tied file handles using Tie::Handle
	if ( $it->isa('Tie::Handle') ) {
		return $it;
	}

	# IO::Scalar is not a proper seekable, but it is valid is a
	# regular file handle
	if ( $it->isa('IO::Scalar') ) {
		return $it;
	}

	# Yet another special case for IO::String, which refuses (for now
	# anyway) to become a subclass of IO::Handle.
	if ( $it->isa('IO::String') ) {
		return $it;
	}

	# This is not any sort of object we know about
	return undef;
}
END_PERL

#line 817

eval <<'END_PERL' unless defined &_DRIVER;
sub _DRIVER ($$) {
	(defined _CLASS($_[0]) and eval "require $_[0];" and ! $@ and $_[0]->isa($_[1]) and $_[0] ne $_[1]) ? $_[0] : undef;
}
END_PERL

1;

#line 867

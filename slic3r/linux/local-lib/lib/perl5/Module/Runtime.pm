=head1 NAME

Module::Runtime - runtime module handling

=head1 SYNOPSIS

	use Module::Runtime qw(
		$module_name_rx is_module_name check_module_name
		module_notional_filename require_module
	);

	if($module_name =~ /\A$module_name_rx\z/o) { ...
	if(is_module_name($module_name)) { ...
	check_module_name($module_name);

	$notional_filename = module_notional_filename($module_name);
	require_module($module_name);

	use Module::Runtime qw(use_module use_package_optimistically);

	$bi = use_module("Math::BigInt", 1.31)->new("1_234");
	$widget = use_package_optimistically("Local::Widget")->new;

	use Module::Runtime qw(
		$top_module_spec_rx $sub_module_spec_rx
		is_module_spec check_module_spec
		compose_module_name
	);

	if($spec =~ /\A$top_module_spec_rx\z/o) { ...
	if($spec =~ /\A$sub_module_spec_rx\z/o) { ...
	if(is_module_spec("Standard::Prefix", $spec)) { ...
	check_module_spec("Standard::Prefix", $spec);

	$module_name =
		compose_module_name("Standard::Prefix", $spec);

=head1 DESCRIPTION

The functions exported by this module deal with runtime handling of
Perl modules, which are normally handled at compile time.  This module
avoids using any other modules, so that it can be used in low-level
infrastructure.

The parts of this module that work with module names apply the same syntax
that is used for barewords in Perl source.  In principle this syntax
can vary between versions of Perl, and this module applies the syntax of
the Perl on which it is running.  In practice the usable syntax hasn't
changed yet.  There's some intent for Unicode module names to be supported
in the future, but this hasn't yet amounted to any consistent facility.

The functions of this module whose purpose is to load modules include
workarounds for three old Perl core bugs regarding C<require>.  These
workarounds are applied on any Perl version where the bugs exist, except
for a case where one of the bugs cannot be adequately worked around in
pure Perl.

=head2 Module name syntax

The usable module name syntax has not changed from Perl 5.000 up to
Perl 5.19.8.  The syntax is composed entirely of ASCII characters.
From Perl 5.6 onwards there has been some attempt to allow the use of
non-ASCII Unicode characters in Perl source, but it was fundamentally
broken (like the entirety of Perl 5.6's Unicode handling) and remained
pretty much entirely unusable until it got some attention in the Perl
5.15 series.  Although Unicode is now consistently accepted by the
parser in some places, it remains broken for module names.  Furthermore,
there has not yet been any work on how to map Unicode module names into
filenames, so in that respect also Unicode module names are unusable.

The module name syntax is, precisely: the string must consist of one or
more segments separated by C<::>; each segment must consist of one or more
identifier characters (ASCII alphanumerics plus "_"); the first character
of the string must not be a digit.  Thus "C<IO::File>", "C<warnings>",
and "C<foo::123::x_0>" are all valid module names, whereas "C<IO::>"
and "C<1foo::bar>" are not.  C<'> separators are not permitted by this
module, though they remain usable in Perl source, being translated to
C<::> in the parser.

=head2 Core bugs worked around

The first bug worked around is core bug [perl #68590], which causes
lexical state in one file to leak into another that is C<require>d/C<use>d
from it.  This bug is present from Perl 5.6 up to Perl 5.10, and is
fixed in Perl 5.11.0.  From Perl 5.9.4 up to Perl 5.10.0 no satisfactory
workaround is possible in pure Perl.  The workaround means that modules
loaded via this module don't suffer this pollution of their lexical
state.  Modules loaded in other ways, or via this module on the Perl
versions where the pure Perl workaround is impossible, remain vulnerable.
The module L<Lexical::SealRequireHints> provides a complete workaround
for this bug.

The second bug worked around causes some kinds of failure in module
loading, principally compilation errors in the loaded module, to be
recorded in C<%INC> as if they were successful, so later attempts to load
the same module immediately indicate success.  This bug is present up
to Perl 5.8.9, and is fixed in Perl 5.9.0.  The workaround means that a
compilation error in a module loaded via this module won't be cached as
a success.  Modules loaded in other ways remain liable to produce bogus
C<%INC> entries, and if a bogus entry exists then it will mislead this
module if it is used to re-attempt loading.

The third bug worked around causes the wrong context to be seen at
file scope of a loaded module, if C<require> is invoked in a location
that inherits context from a higher scope.  This bug is present up to
Perl 5.11.2, and is fixed in Perl 5.11.3.  The workaround means that
a module loaded via this module will always see the correct context.
Modules loaded in other ways remain vulnerable.

=cut

package Module::Runtime;

# Don't "use 5.006" here, because Perl 5.15.6 will load feature.pm if
# the version check is done that way.
BEGIN { require 5.006; }
# Don't "use warnings" here, to avoid dependencies.  Do standardise the
# warning status by lexical override; unfortunately the only safe bitset
# to build in is the empty set, equivalent to "no warnings".
BEGIN { ${^WARNING_BITS} = ""; }
# Don't "use strict" here, to avoid dependencies.

our $VERSION = "0.014";

# Don't use Exporter here, to avoid dependencies.
our @EXPORT_OK = qw(
	$module_name_rx is_module_name is_valid_module_name check_module_name
	module_notional_filename require_module
	use_module use_package_optimistically
	$top_module_spec_rx $sub_module_spec_rx
	is_module_spec is_valid_module_spec check_module_spec
	compose_module_name
);
my %export_ok = map { ($_ => undef) } @EXPORT_OK;
sub import {
	my $me = shift;
	my $callpkg = caller(0);
	my $errs = "";
	foreach(@_) {
		if(exists $export_ok{$_}) {
			# We would need to do "no strict 'refs'" here
			# if we had enabled strict at file scope.
			if(/\A\$(.*)\z/s) {
				*{$callpkg."::".$1} = \$$1;
			} else {
				*{$callpkg."::".$_} = \&$_;
			}
		} else {
			$errs .= "\"$_\" is not exported by the $me module\n";
		}
	}
	if($errs ne "") {
		die "${errs}Can't continue after import errors ".
			"at @{[(caller(0))[1]]} line @{[(caller(0))[2]]}.\n";
	}
}

# Logic duplicated from Params::Classify.  Duplicating it here avoids
# an extensive and potentially circular dependency graph.
sub _is_string($) {
	my($arg) = @_;
	return defined($arg) && ref(\$arg) eq "SCALAR";
}

=head1 REGULAR EXPRESSIONS

These regular expressions do not include any anchors, so to check
whether an entire string matches a syntax item you must supply the
anchors yourself.

=over

=item $module_name_rx

Matches a valid Perl module name in bareword syntax.

=cut

our $module_name_rx = qr/[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*/;

=item $top_module_spec_rx

Matches a module specification for use with L</compose_module_name>,
where no prefix is being used.

=cut

my $qual_module_spec_rx =
	qr#(?:/|::)[A-Z_a-z][0-9A-Z_a-z]*(?:(?:/|::)[0-9A-Z_a-z]+)*#;

my $unqual_top_module_spec_rx =
	qr#[A-Z_a-z][0-9A-Z_a-z]*(?:(?:/|::)[0-9A-Z_a-z]+)*#;

our $top_module_spec_rx = qr/$qual_module_spec_rx|$unqual_top_module_spec_rx/o;

=item $sub_module_spec_rx

Matches a module specification for use with L</compose_module_name>,
where a prefix is being used.

=cut

my $unqual_sub_module_spec_rx = qr#[0-9A-Z_a-z]+(?:(?:/|::)[0-9A-Z_a-z]+)*#;

our $sub_module_spec_rx = qr/$qual_module_spec_rx|$unqual_sub_module_spec_rx/o;

=back

=head1 FUNCTIONS

=head2 Basic module handling

=over

=item is_module_name(ARG)

Returns a truth value indicating whether I<ARG> is a plain string
satisfying Perl module name syntax as described for L</$module_name_rx>.

=cut

sub is_module_name($) { _is_string($_[0]) && $_[0] =~ /\A$module_name_rx\z/o }

=item is_valid_module_name(ARG)

Deprecated alias for L</is_module_name>.

=cut

*is_valid_module_name = \&is_module_name;

=item check_module_name(ARG)

Check whether I<ARG> is a plain string
satisfying Perl module name syntax as described for L</$module_name_rx>.
Return normally if it is, or C<die> if it is not.

=cut

sub check_module_name($) {
	unless(&is_module_name) {
		die +(_is_string($_[0]) ? "`$_[0]'" : "argument").
			" is not a module name\n";
	}
}

=item module_notional_filename(NAME)

Generates a notional relative filename for a module, which is used in
some Perl core interfaces.
The I<NAME> is a string, which should be a valid module name (one or
more C<::>-separated segments).  If it is not a valid name, the function
C<die>s.

The notional filename for the named module is generated and returned.
This filename is always in Unix style, with C</> directory separators
and a C<.pm> suffix.  This kind of filename can be used as an argument to
C<require>, and is the key that appears in C<%INC> to identify a module,
regardless of actual local filename syntax.

=cut

sub module_notional_filename($) {
	&check_module_name;
	my($name) = @_;
	$name =~ s!::!/!g;
	return $name.".pm";
}

=item require_module(NAME)

This is essentially the bareword form of C<require>, in runtime form.
The I<NAME> is a string, which should be a valid module name (one or
more C<::>-separated segments).  If it is not a valid name, the function
C<die>s.

The module specified by I<NAME> is loaded, if it hasn't been already,
in the manner of the bareword form of C<require>.  That means that a
search through C<@INC> is performed, and a byte-compiled form of the
module will be used if available.

The return value is as for C<require>.  That is, it is the value returned
by the module itself if the module is loaded anew, or C<1> if the module
was already loaded.

=cut

# Don't "use constant" here, to avoid dependencies.
BEGIN {
	*_WORK_AROUND_HINT_LEAKAGE =
		"$]" < 5.011 && !("$]" >= 5.009004 && "$]" < 5.010001)
			? sub(){1} : sub(){0};
	*_WORK_AROUND_BROKEN_MODULE_STATE = "$]" < 5.009 ? sub(){1} : sub(){0};
}

BEGIN { if(_WORK_AROUND_BROKEN_MODULE_STATE) { eval q{
	sub Module::Runtime::__GUARD__::DESTROY {
		delete $INC{$_[0]->[0]} if @{$_[0]};
	}
	1;
}; die $@ if $@ ne ""; } }

sub require_module($) {
	# Localise %^H to work around [perl #68590], where the bug exists
	# and this is a satisfactory workaround.  The bug consists of
	# %^H state leaking into each required module, polluting the
	# module's lexical state.
	local %^H if _WORK_AROUND_HINT_LEAKAGE;
	if(_WORK_AROUND_BROKEN_MODULE_STATE) {
		my $notional_filename = &module_notional_filename;
		my $guard = bless([ $notional_filename ],
				"Module::Runtime::__GUARD__");
		my $result = CORE::require($notional_filename);
		pop @$guard;
		return $result;
	} else {
		return scalar(CORE::require(&module_notional_filename));
	}
}

=back

=head2 Structured module use

=over

=item use_module(NAME[, VERSION])

This is essentially C<use> in runtime form, but without the importing
feature (which is fundamentally a compile-time thing).  The I<NAME> is
handled just like in C<require_module> above: it must be a module name,
and the named module is loaded as if by the bareword form of C<require>.

If a I<VERSION> is specified, the C<VERSION> method of the loaded module is
called with the specified I<VERSION> as an argument.  This normally serves to
ensure that the version loaded is at least the version required.  This is
the same functionality provided by the I<VERSION> parameter of C<use>.

On success, the name of the module is returned.  This is unlike
L</require_module>, and is done so that the entire call to L</use_module>
can be used as a class name to call a constructor, as in the example in
the synopsis.

=cut

sub use_module($;$) {
	my($name, $version) = @_;
	require_module($name);
	$name->VERSION($version) if @_ >= 2;
	return $name;
}

=item use_package_optimistically(NAME[, VERSION])

This is an analogue of L</use_module> for the situation where there is
uncertainty as to whether a package/class is defined in its own module
or by some other means.  It attempts to arrange for the named package to
be available, either by loading a module or by doing nothing and hoping.

An attempt is made to load the named module (as if by the bareword form
of C<require>).  If the module cannot be found then it is assumed that
the package was actually already loaded by other means, and no error
is signalled.  That's the optimistic bit.

This is mostly the same operation that is performed by the L<base> pragma
to ensure that the specified base classes are available.  The behaviour
of L<base> was simplified in version 2.18, and later improved in version
2.20, and on both occasions this function changed to match.

If a I<VERSION> is specified, the C<VERSION> method of the loaded package is
called with the specified I<VERSION> as an argument.  This normally serves
to ensure that the version loaded is at least the version required.
On success, the name of the package is returned.  These aspects of the
function work just like L</use_module>.

=cut

sub use_package_optimistically($;$) {
	my($name, $version) = @_;
	my $fn = module_notional_filename($name);
	eval { local $SIG{__DIE__}; require_module($name); };
	die $@ if $@ ne "" &&
		($@ !~ /\ACan't locate \Q$fn\E .+ at \Q@{[__FILE__]}\E line/s ||
		 $@ =~ /^Compilation\ failed\ in\ require
			 \ at\ \Q@{[__FILE__]}\E\ line/xm);
	$name->VERSION($version) if @_ >= 2;
	return $name;
}

=back

=head2 Module name composition

=over

=item is_module_spec(PREFIX, SPEC)

Returns a truth value indicating
whether I<SPEC> is valid input for L</compose_module_name>.
See below for what that entails.  Whether a I<PREFIX> is supplied affects
the validity of I<SPEC>, but the exact value of the prefix is unimportant,
so this function treats I<PREFIX> as a truth value.

=cut

sub is_module_spec($$) {
	my($prefix, $spec) = @_;
	return _is_string($spec) &&
		$spec =~ ($prefix ? qr/\A$sub_module_spec_rx\z/o :
				    qr/\A$top_module_spec_rx\z/o);
}

=item is_valid_module_spec(PREFIX, SPEC)

Deprecated alias for L</is_module_spec>.

=cut

*is_valid_module_spec = \&is_module_spec;

=item check_module_spec(PREFIX, SPEC)

Check whether I<SPEC> is valid input for L</compose_module_name>.
Return normally if it is, or C<die> if it is not.

=cut

sub check_module_spec($$) {
	unless(&is_module_spec) {
		die +(_is_string($_[1]) ? "`$_[1]'" : "argument").
			" is not a module specification\n";
	}
}

=item compose_module_name(PREFIX, SPEC)

This function is intended to make it more convenient for a user to specify
a Perl module name at runtime.  Users have greater need for abbreviations
and context-sensitivity than programmers, and Perl module names get a
little unwieldy.  I<SPEC> is what the user specifies, and this function
translates it into a module name in standard form, which it returns.

I<SPEC> has syntax approximately that of a standard module name: it
should consist of one or more name segments, each of which consists
of one or more identifier characters.  However, C</> is permitted as a
separator, in addition to the standard C<::>.  The two separators are
entirely interchangeable.

Additionally, if I<PREFIX> is not C<undef> then it must be a module
name in standard form, and it is prefixed to the user-specified name.
The user can inhibit the prefix addition by starting I<SPEC> with a
separator (either C</> or C<::>).

=cut

sub compose_module_name($$) {
	my($prefix, $spec) = @_;
	check_module_name($prefix) if defined $prefix;
	&check_module_spec;
	if($spec =~ s#\A(?:/|::)##) {
		# OK
	} else {
		$spec = $prefix."::".$spec if defined $prefix;
	}
	$spec =~ s#/#::#g;
	return $spec;
}

=back

=head1 BUGS

On Perl versions 5.7.2 to 5.8.8, if C<require> is overridden by the
C<CORE::GLOBAL> mechanism, it is likely to break the heuristics used by
L</use_package_optimistically>, making it signal an error for a missing
module rather than assume that it was already loaded.  From Perl 5.8.9
onwards, and on 5.7.1 and earlier, this module can avoid being confused
by such an override.  On the affected versions, a C<require> override
might be installed by L<Lexical::SealRequireHints>, if something requires
its bugfix but for some reason its XS implementation isn't available.

=head1 SEE ALSO

L<Lexical::SealRequireHints>,
L<base>,
L<perlfunc/require>,
L<perlfunc/use>

=head1 AUTHOR

Andrew Main (Zefram) <zefram@fysh.org>

=head1 COPYRIGHT

Copyright (C) 2004, 2006, 2007, 2009, 2010, 2011, 2012, 2014
Andrew Main (Zefram) <zefram@fysh.org>

=head1 LICENSE

This module is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

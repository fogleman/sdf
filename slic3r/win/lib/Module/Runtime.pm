#line 1 "Module/Runtime.pm"

#line 111

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

#line 178

our $module_name_rx = qr/[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*/;

#line 187

my $qual_module_spec_rx =
	qr#(?:/|::)[A-Z_a-z][0-9A-Z_a-z]*(?:(?:/|::)[0-9A-Z_a-z]+)*#;

my $unqual_top_module_spec_rx =
	qr#[A-Z_a-z][0-9A-Z_a-z]*(?:(?:/|::)[0-9A-Z_a-z]+)*#;

our $top_module_spec_rx = qr/$qual_module_spec_rx|$unqual_top_module_spec_rx/o;

#line 202

my $unqual_sub_module_spec_rx = qr#[0-9A-Z_a-z]+(?:(?:/|::)[0-9A-Z_a-z]+)*#;

our $sub_module_spec_rx = qr/$qual_module_spec_rx|$unqual_sub_module_spec_rx/o;

#line 221

sub is_module_name($) { _is_string($_[0]) && $_[0] =~ /\A$module_name_rx\z/o }

#line 229

*is_valid_module_name = \&is_module_name;

#line 239

sub check_module_name($) {
	unless(&is_module_name) {
		die +(_is_string($_[0]) ? "`$_[0]'" : "argument").
			" is not a module name\n";
	}
}

#line 262

sub module_notional_filename($) {
	&check_module_name;
	my($name) = @_;
	$name =~ s!::!/!g;
	return $name.".pm";
}

#line 287

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

#line 345

sub use_module($;$) {
	my($name, $version) = @_;
	require_module($name);
	$name->VERSION($version) if @_ >= 2;
	return $name;
}

#line 377

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

#line 405

sub is_module_spec($$) {
	my($prefix, $spec) = @_;
	return _is_string($spec) &&
		$spec =~ ($prefix ? qr/\A$sub_module_spec_rx\z/o :
				    qr/\A$top_module_spec_rx\z/o);
}

#line 418

*is_valid_module_spec = \&is_module_spec;

#line 427

sub check_module_spec($$) {
	unless(&is_module_spec) {
		die +(_is_string($_[1]) ? "`$_[1]'" : "argument").
			" is not a module specification\n";
	}
}

#line 455

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

#line 504

1;

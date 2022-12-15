package Moo::_Utils;
use Moo::_strictures;

{
  no strict 'refs';
  sub _getglob { \*{$_[0]} }
  sub _getstash { \%{"$_[0]::"} }
}

BEGIN {
  my ($su, $sn);
  $su = $INC{'Sub/Util.pm'} && defined &Sub::Util::set_subname
    or $sn = $INC{'Sub/Name.pm'}
    or $su = eval { require Sub::Util; } && defined &Sub::Util::set_subname
    or $sn = eval { require Sub::Name; };

  *_subname = $su ? \&Sub::Util::set_subname
            : $sn ? \&Sub::Name::subname
            : sub { $_[1] };
  *_CAN_SUBNAME = ($su || $sn) ? sub(){1} : sub(){0};
}

use Module::Runtime qw(use_package_optimistically module_notional_filename);

use Devel::GlobalDestruction ();
use Exporter qw(import);
use Config;
use Carp qw(croak);

our @EXPORT = qw(
    _getglob _install_modifier _load_module _maybe_load_module
    _getstash _install_coderef _name_coderef
    _unimport_coderefs _set_loaded
);

sub _install_modifier {
  my ($into, $type, $name, $code) = @_;

  if ($INC{'Sub/Defer.pm'} and my $to_modify = $into->can($name)) { # CMM will throw for us if not
    Sub::Defer::undefer_sub($to_modify);
  }

  require Class::Method::Modifiers;
  Class::Method::Modifiers::install_modifier(@_);
}

sub _load_module {
  my $module = $_[0];
  my $file = eval { module_notional_filename($module) } or croak $@;
  use_package_optimistically($module);
  return 1
    if $INC{$file};
  my $error = $@ || "Can't locate $file";

  # can't just ->can('can') because a sub-package Foo::Bar::Baz
  # creates a 'Baz::' key in Foo::Bar's symbol table
  my $stash = _getstash($module)||{};
  return 1 if grep +(ref($_) || *$_{CODE}), values %$stash;
  return 1
    if $INC{"Moose.pm"} && Class::MOP::class_of($module)
    or Mouse::Util->can('find_meta') && Mouse::Util::find_meta($module);
  croak $error;
}

our %MAYBE_LOADED;
sub _maybe_load_module {
  my $module = $_[0];
  return $MAYBE_LOADED{$module}
    if exists $MAYBE_LOADED{$module};
  if(! eval { use_package_optimistically($module) }) {
    warn "$module exists but failed to load with error: $@";
  }
  elsif ( $INC{module_notional_filename($module)} ) {
    return $MAYBE_LOADED{$module} = 1;
  }
  return $MAYBE_LOADED{$module} = 0;
}

sub _set_loaded {
  $INC{Module::Runtime::module_notional_filename($_[0])} ||= $_[1];
}

sub _install_coderef {
  my ($glob, $code) = (_getglob($_[0]), _name_coderef(@_));
  no warnings 'redefine';
  if (*{$glob}{CODE}) {
    *{$glob} = $code;
  }
  # perl will sometimes warn about mismatched prototypes coming from the
  # inheritance cache, so disable them if we aren't redefining a sub
  else {
    no warnings 'prototype';
    *{$glob} = $code;
  }
}

sub _name_coderef {
  shift if @_ > 2; # three args is (target, name, sub)
  _CAN_SUBNAME ? _subname(@_) : $_[1];
}

sub _unimport_coderefs {
  my ($target, $info) = @_;
  return unless $info and my $exports = $info->{exports};
  my %rev = reverse %$exports;
  my $stash = _getstash($target);
  foreach my $name (keys %$exports) {
    if ($stash->{$name} and defined(&{$stash->{$name}})) {
      if ($rev{$target->can($name)}) {
        my $old = delete $stash->{$name};
        my $full_name = join('::',$target,$name);
        # Copy everything except the code slot back into place (e.g. $has)
        foreach my $type (qw(SCALAR HASH ARRAY IO)) {
          next unless defined(*{$old}{$type});
          no strict 'refs';
          *$full_name = *{$old}{$type};
        }
      }
    }
  }
}

if ($Config{useithreads}) {
  require Moo::HandleMoose::_TypeMap;
}

1;

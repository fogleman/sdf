#line 1 "Moo/Role.pm"
package Moo::Role;

use Moo::_strictures;
use Moo::_Utils qw(
  _getglob
  _getstash
  _install_coderef
  _install_modifier
  _load_module
  _name_coderef
  _set_loaded
  _unimport_coderefs
);
use Carp qw(croak);
use Role::Tiny ();
BEGIN { our @ISA = qw(Role::Tiny) }
BEGIN {
  our @CARP_NOT = qw(
    Method::Generate::Accessor
    Method::Generate::Constructor
    Moo::sification
    Moo::_Utils
  );
}

our $VERSION = '2.003001';
$VERSION = eval $VERSION;

require Moo::sification;
Moo::sification->import;

BEGIN {
    *INFO = \%Role::Tiny::INFO;
    *APPLIED_TO = \%Role::Tiny::APPLIED_TO;
    *COMPOSED = \%Role::Tiny::COMPOSED;
    *ON_ROLE_CREATE = \@Role::Tiny::ON_ROLE_CREATE;
}

our %INFO;
our %APPLIED_TO;
our %APPLY_DEFAULTS;
our %COMPOSED;
our @ON_ROLE_CREATE;

sub _install_tracked {
  my ($target, $name, $code) = @_;
  $INFO{$target}{exports}{$name} = $code;
  _install_coderef "${target}::${name}" => "Moo::Role::${name}" => $code;
}

sub import {
  my $target = caller;
  if ($Moo::MAKERS{$target} and $Moo::MAKERS{$target}{is_class}) {
    croak "Cannot import Moo::Role into a Moo class";
  }
  _set_loaded(caller);
  goto &Role::Tiny::import;
}

sub _install_subs {
  my ($me, $target) = @_;
  _install_tracked $target => has => sub {
    my $name_proto = shift;
    my @name_proto = ref $name_proto eq 'ARRAY' ? @$name_proto : $name_proto;
    if (@_ % 2 != 0) {
      croak("Invalid options for " . join(', ', map "'$_'", @name_proto)
        . " attribute(s): even number of arguments expected, got " . scalar @_)
    }
    my %spec = @_;
    foreach my $name (@name_proto) {
      my $spec_ref = @name_proto > 1 ? +{%spec} : \%spec;
      ($INFO{$target}{accessor_maker} ||= do {
        require Method::Generate::Accessor;
        Method::Generate::Accessor->new
      })->generate_method($target, $name, $spec_ref);
      push @{$INFO{$target}{attributes}||=[]}, $name, $spec_ref;
      $me->_maybe_reset_handlemoose($target);
    }
  };
  # install before/after/around subs
  foreach my $type (qw(before after around)) {
    _install_tracked $target => $type => sub {
      push @{$INFO{$target}{modifiers}||=[]}, [ $type => @_ ];
      $me->_maybe_reset_handlemoose($target);
    };
  }
  _install_tracked $target => requires => sub {
    push @{$INFO{$target}{requires}||=[]}, @_;
    $me->_maybe_reset_handlemoose($target);
  };
  _install_tracked $target => with => sub {
    $me->apply_roles_to_package($target, @_);
    $me->_maybe_reset_handlemoose($target);
  };
  *{_getglob("${target}::meta")} = $me->can('meta');
}

push @ON_ROLE_CREATE, sub {
  my $target = shift;
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::inject_fake_metaclass_for($target);
  }
};

# duplicate from Moo::Object
sub meta {
  require Moo::HandleMoose::FakeMetaClass;
  my $class = ref($_[0])||$_[0];
  bless({ name => $class }, 'Moo::HandleMoose::FakeMetaClass');
}

sub unimport {
  my $target = caller;
  _unimport_coderefs($target, $INFO{$target});
}

sub _maybe_reset_handlemoose {
  my ($class, $target) = @_;
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::maybe_reinject_fake_metaclass_for($target);
  }
}

sub methods_provided_by {
  my ($self, $role) = @_;
  _load_module($role);
  $self->_inhale_if_moose($role);
  croak "${role} is not a Moo::Role" unless $self->is_role($role);
  return $self->SUPER::methods_provided_by($role);
}

sub is_role {
  my ($self, $role) = @_;
  $self->_inhale_if_moose($role);
  $self->SUPER::is_role($role);
}

sub _inhale_if_moose {
  my ($self, $role) = @_;
  my $meta;
  if (!$self->SUPER::is_role($role)
      and (
        $INC{"Moose.pm"}
        and $meta = Class::MOP::class_of($role)
        and ref $meta ne 'Moo::HandleMoose::FakeMetaClass'
        and $meta->isa('Moose::Meta::Role')
      )
      or (
        Mouse::Util->can('find_meta')
        and $meta = Mouse::Util::find_meta($role)
        and $meta->isa('Mouse::Meta::Role')
     )
  ) {
    my $is_mouse = $meta->isa('Mouse::Meta::Role');
    $INFO{$role}{methods} = {
      map +($_ => $role->can($_)),
        grep $role->can($_),
        grep !($is_mouse && $_ eq 'meta'),
        grep !$meta->get_method($_)->isa('Class::MOP::Method::Meta'),
          $meta->get_method_list
    };
    $APPLIED_TO{$role} = {
      map +($_->name => 1), $meta->calculate_all_roles
    };
    $INFO{$role}{requires} = [ $meta->get_required_method_list ];
    $INFO{$role}{attributes} = [
      map +($_ => do {
        my $attr = $meta->get_attribute($_);
        my $spec = { %{ $is_mouse ? $attr : $attr->original_options } };

        if ($spec->{isa}) {
          require Sub::Quote;

          my $get_constraint = do {
            my $pkg = $is_mouse
                        ? 'Mouse::Util::TypeConstraints'
                        : 'Moose::Util::TypeConstraints';
            _load_module($pkg);
            $pkg->can('find_or_create_isa_type_constraint');
          };

          my $tc = $get_constraint->($spec->{isa});
          my $check = $tc->_compiled_type_constraint;
          my $tc_var = '$_check_for_'.Sub::Quote::sanitize_identifier($tc->name);

          $spec->{isa} = Sub::Quote::quote_sub(
            qq{
              &${tc_var} or Carp::croak "Type constraint failed for \$_[0]"
            },
            { $tc_var => \$check },
            {
              package => $role,
            },
          );

          if ($spec->{coerce}) {

             # Mouse has _compiled_type_coercion straight on the TC object
             $spec->{coerce} = $tc->${\(
               $tc->can('coercion')||sub { $_[0] }
             )}->_compiled_type_coercion;
          }
        }
        $spec;
      }), $meta->get_attribute_list
    ];
    my $mods = $INFO{$role}{modifiers} = [];
    foreach my $type (qw(before after around)) {
      # Mouse pokes its own internals so we have to fall back to doing
      # the same thing in the absence of the Moose API method
      my $map = $meta->${\(
        $meta->can("get_${type}_method_modifiers_map")
        or sub { shift->{"${type}_method_modifiers"} }
      )};
      foreach my $method (keys %$map) {
        foreach my $mod (@{$map->{$method}}) {
          push @$mods, [ $type => $method => $mod ];
        }
      }
    }
    $INFO{$role}{inhaled_from_moose} = 1;
    $INFO{$role}{is_role} = 1;
  }
}

sub _maybe_make_accessors {
  my ($self, $target, $role) = @_;
  my $m;
  if ($INFO{$role} && $INFO{$role}{inhaled_from_moose}
      or $INC{"Moo.pm"}
      and $m = Moo->_accessor_maker_for($target)
      and ref($m) ne 'Method::Generate::Accessor') {
    $self->_make_accessors($target, $role);
  }
}

sub _make_accessors_if_moose {
  my ($self, $target, $role) = @_;
  if ($INFO{$role} && $INFO{$role}{inhaled_from_moose}) {
    $self->_make_accessors($target, $role);
  }
}

sub _make_accessors {
  my ($self, $target, $role) = @_;
  my $acc_gen = ($Moo::MAKERS{$target}{accessor} ||= do {
    require Method::Generate::Accessor;
    Method::Generate::Accessor->new
  });
  my $con_gen = $Moo::MAKERS{$target}{constructor};
  my @attrs = @{$INFO{$role}{attributes}||[]};
  while (my ($name, $spec) = splice @attrs, 0, 2) {
    # needed to ensure we got an index for an arrayref based generator
    if ($con_gen) {
      $spec = $con_gen->all_attribute_specs->{$name};
    }
    $acc_gen->generate_method($target, $name, $spec);
  }
}

sub _undefer_subs {
  my ($self, $target, $role) = @_;
  if ($INC{'Sub/Defer.pm'}) {
    Sub::Defer::undefer_package($role);
  }
}

sub role_application_steps {
  qw(_handle_constructor _undefer_subs _maybe_make_accessors),
    $_[0]->SUPER::role_application_steps;
}

sub apply_roles_to_package {
  my ($me, $to, @roles) = @_;
  foreach my $role (@roles) {
    _load_module($role);
    $me->_inhale_if_moose($role);
    croak "${role} is not a Moo::Role" unless $me->is_role($role);
  }
  $me->SUPER::apply_roles_to_package($to, @roles);
}

sub apply_single_role_to_package {
  my ($me, $to, $role) = @_;
  _load_module($role);
  $me->_inhale_if_moose($role);
  croak "${role} is not a Moo::Role" unless $me->is_role($role);
  $me->SUPER::apply_single_role_to_package($to, $role);
}

sub create_class_with_roles {
  my ($me, $superclass, @roles) = @_;

  my ($new_name, $compose_name) = $me->_composite_name($superclass, @roles);

  return $new_name if $COMPOSED{class}{$new_name};

  foreach my $role (@roles) {
    _load_module($role);
    $me->_inhale_if_moose($role);
    croak "${role} is not a Moo::Role" unless $me->is_role($role);
  }

  my $m;
  if ($INC{"Moo.pm"}
      and $m = Moo->_accessor_maker_for($superclass)
      and ref($m) ne 'Method::Generate::Accessor') {
    # old fashioned way time.
    @{*{_getglob("${new_name}::ISA")}{ARRAY}} = ($superclass);
    $Moo::MAKERS{$new_name} = {is_class => 1};
    $me->apply_roles_to_package($new_name, @roles);
  }
  else {
    $me->SUPER::create_class_with_roles($superclass, @roles);
    $Moo::MAKERS{$new_name} = {is_class => 1};
    $me->_handle_constructor($new_name, $_) for @roles;
  }

  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::inject_fake_metaclass_for($new_name);
  }
  $COMPOSED{class}{$new_name} = 1;
  _set_loaded($new_name, (caller)[1]);
  return $new_name;
}

sub apply_roles_to_object {
  my ($me, $object, @roles) = @_;
  my $new = $me->SUPER::apply_roles_to_object($object, @roles);
  my $class = ref $new;
  _set_loaded($class, (caller)[1]);

  my $apply_defaults = exists $APPLY_DEFAULTS{$class} ? $APPLY_DEFAULTS{$class}
    : $APPLY_DEFAULTS{$class} = do {
    my %attrs = map { @{$INFO{$_}{attributes}||[]} } @roles;

    if ($INC{'Moo.pm'}
        and keys %attrs
        and my $con_gen = Moo->_constructor_maker_for($class)
        and my $m = Moo->_accessor_maker_for($class)) {

      my $specs = $con_gen->all_attribute_specs;

      my %captures;
      my $code = join('',
        ( map {
          my $name = $_;
          my $spec = $specs->{$name};
          if ($m->has_eager_default($name, $spec)) {
            my ($has, $has_cap)
              = $m->generate_simple_has('$_[0]', $name, $spec);
            my ($set, $pop_cap)
              = $m->generate_use_default('$_[0]', $name, $spec, $has);

            @captures{keys %$has_cap, keys %$pop_cap}
              = (values %$has_cap, values %$pop_cap);
            "($set),";
          }
          else {
            ();
          }
        } sort keys %attrs ),
      );
      if ($code) {
        require Sub::Quote;
        Sub::Quote::quote_sub(
          "${class}::_apply_defaults",
          "no warnings 'void';\n$code",
          \%captures,
          {
            package => $class,
            no_install => 1,
          }
        );
      }
      else {
        0;
      }
    }
    else {
      0;
    }
  };
  if ($apply_defaults) {
    local $Carp::Internal{+__PACKAGE__} = 1;
    local $Carp::Internal{$class} = 1;
    $new->$apply_defaults;
  }
  return $new;
}

sub _composable_package_for {
  my ($self, $role) = @_;
  my $composed_name = 'Role::Tiny::_COMPOSABLE::'.$role;
  return $composed_name if $COMPOSED{role}{$composed_name};
  $self->_make_accessors_if_moose($composed_name, $role);
  $self->SUPER::_composable_package_for($role);
}

sub _install_single_modifier {
  my ($me, @args) = @_;
  _install_modifier(@args);
}

sub _install_does {
    my ($me, $to) = @_;

    # If Role::Tiny actually installed the DOES, give it a name
    my $new = $me->SUPER::_install_does($to) or return;
    return _name_coderef("${to}::DOES", $new);
}

sub does_role {
  my ($proto, $role) = @_;
  return 1
    if Role::Tiny::does_role($proto, $role);
  my $meta;
  if ($INC{'Moose.pm'}
      and $meta = Class::MOP::class_of($proto)
      and ref $meta ne 'Moo::HandleMoose::FakeMetaClass'
      and $meta->can('does_role')
  ) {
    return $meta->does_role($role);
  }
  return 0;
}

sub _handle_constructor {
  my ($me, $to, $role) = @_;
  my $attr_info = $INFO{$role} && $INFO{$role}{attributes};
  return unless $attr_info && @$attr_info;
  my $info = $INFO{$to};
  my $con = $INC{"Moo.pm"} && Moo->_constructor_maker_for($to);
  my %existing
    = $info ? @{$info->{attributes} || []}
    : $con  ? %{$con->all_attribute_specs || {}}
    : ();

  my @attr_info =
    map { @{$attr_info}[$_, $_+1] }
    grep { ! $existing{$attr_info->[$_]} }
    map { 2 * $_ } 0..@$attr_info/2-1;

  if ($info) {
    push @{$info->{attributes}||=[]}, @attr_info;
  }
  elsif ($con) {
    # shallow copy of the specs since the constructor will assign an index
    $con->register_attribute_specs(map ref() ? { %$_ } : $_, @attr_info);
  }
}

1;
__END__

#line 551

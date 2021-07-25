#line 1 "Moo.pm"
package Moo;

use Moo::_strictures;
use Moo::_mro;
use Moo::_Utils qw(
  _getglob
  _getstash
  _install_coderef
  _install_modifier
  _load_module
  _set_loaded
  _unimport_coderefs
);
use Carp qw(croak);
BEGIN {
  our @CARP_NOT = qw(
    Method::Generate::Constructor
    Method::Generate::Accessor
    Moo::sification
    Moo::_Utils
    Moo::Role
  );
}

our $VERSION = '2.003001';
$VERSION = eval $VERSION;

require Moo::sification;
Moo::sification->import;

our %MAKERS;

sub _install_tracked {
  my ($target, $name, $code) = @_;
  $MAKERS{$target}{exports}{$name} = $code;
  _install_coderef "${target}::${name}" => "Moo::${name}" => $code;
}

sub import {
  my $target = caller;
  my $class = shift;
  _set_loaded(caller);

  strict->import;
  warnings->import;

  if ($INC{'Role/Tiny.pm'} and Role::Tiny->is_role($target)) {
    croak "Cannot import Moo into a role";
  }
  $MAKERS{$target} ||= {};
  _install_tracked $target => extends => sub {
    $class->_set_superclasses($target, @_);
    $class->_maybe_reset_handlemoose($target);
    return;
  };
  _install_tracked $target => with => sub {
    require Moo::Role;
    Moo::Role->apply_roles_to_package($target, @_);
    $class->_maybe_reset_handlemoose($target);
  };
  _install_tracked $target => has => sub {
    my $name_proto = shift;
    my @name_proto = ref $name_proto eq 'ARRAY' ? @$name_proto : $name_proto;
    if (@_ % 2 != 0) {
      croak "Invalid options for " . join(', ', map "'$_'", @name_proto)
        . " attribute(s): even number of arguments expected, got " . scalar @_;
    }
    my %spec = @_;
    foreach my $name (@name_proto) {
      # Note that when multiple attributes specified, each attribute
      # needs a separate \%specs hashref
      my $spec_ref = @name_proto > 1 ? +{%spec} : \%spec;
      $class->_constructor_maker_for($target)
            ->register_attribute_specs($name, $spec_ref);
      $class->_accessor_maker_for($target)
            ->generate_method($target, $name, $spec_ref);
      $class->_maybe_reset_handlemoose($target);
    }
    return;
  };
  foreach my $type (qw(before after around)) {
    _install_tracked $target => $type => sub {
      _install_modifier($target, $type, @_);
      return;
    };
  }
  return if $MAKERS{$target}{is_class}; # already exported into this package
  my $stash = _getstash($target);
  my @not_methods = map { *$_{CODE}||() } grep !ref($_), values %$stash;
  @{$MAKERS{$target}{not_methods}={}}{@not_methods} = @not_methods;
  $MAKERS{$target}{is_class} = 1;
  {
    no strict 'refs';
    @{"${target}::ISA"} = do {
      require Moo::Object; ('Moo::Object');
    } unless @{"${target}::ISA"};
  }
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::inject_fake_metaclass_for($target);
  }
}

sub unimport {
  my $target = caller;
  _unimport_coderefs($target, $MAKERS{$target});
}

sub _set_superclasses {
  my $class = shift;
  my $target = shift;
  foreach my $superclass (@_) {
    _load_module($superclass);
    if ($INC{'Role/Tiny.pm'} && Role::Tiny->is_role($superclass)) {
      croak "Can't extend role '$superclass'";
    }
  }
  # Can't do *{...} = \@_ or 5.10.0's mro.pm stops seeing @ISA
  @{*{_getglob("${target}::ISA")}{ARRAY}} = @_;
  if (my $old = delete $Moo::MAKERS{$target}{constructor}) {
    $old->assert_constructor;
    delete _getstash($target)->{new};
    Moo->_constructor_maker_for($target)
       ->register_attribute_specs(%{$old->all_attribute_specs});
  }
  elsif (!$target->isa('Moo::Object')) {
    Moo->_constructor_maker_for($target);
  }
  $Moo::HandleMoose::MOUSE{$target} = [
    grep defined, map Mouse::Util::find_meta($_), @_
  ] if Mouse::Util->can('find_meta');
}

sub _maybe_reset_handlemoose {
  my ($class, $target) = @_;
  if ($INC{'Moo/HandleMoose.pm'} && !$Moo::sification::disabled) {
    Moo::HandleMoose::maybe_reinject_fake_metaclass_for($target);
  }
}

sub _accessor_maker_for {
  my ($class, $target) = @_;
  return unless $MAKERS{$target};
  $MAKERS{$target}{accessor} ||= do {
    my $maker_class = do {
      if (my $m = do {
            require Sub::Defer;
            if (my $defer_target =
                  (Sub::Defer::defer_info($target->can('new'))||[])->[0]
              ) {
              my ($pkg) = ($defer_target =~ /^(.*)::[^:]+$/);
              $MAKERS{$pkg} && $MAKERS{$pkg}{accessor};
            } else {
              undef;
            }
          }) {
        ref($m);
      } else {
        require Method::Generate::Accessor;
        'Method::Generate::Accessor'
      }
    };
    $maker_class->new;
  }
}

sub _constructor_maker_for {
  my ($class, $target) = @_;
  return unless $MAKERS{$target};
  $MAKERS{$target}{constructor} ||= do {
    require Method::Generate::Constructor;

    my %construct_opts = (
      package => $target,
      accessor_generator => $class->_accessor_maker_for($target),
      subconstructor_handler => (
        '      if ($Moo::MAKERS{$class}) {'."\n"
        .'        if ($Moo::MAKERS{$class}{constructor}) {'."\n"
        .'          package '.$target.';'."\n"
        .'          return $invoker->SUPER::new(@_);'."\n"
        .'        }'."\n"
        .'        '.$class.'->_constructor_maker_for($class);'."\n"
        .'        return $invoker->new(@_)'.";\n"
        .'      } elsif ($INC{"Moose.pm"} and my $meta = Class::MOP::get_metaclass_by_name($class)) {'."\n"
        .'        return $meta->new_object('."\n"
        .'          $class->can("BUILDARGS") ? $class->BUILDARGS(@_)'."\n"
        .'                      : $class->Moo::Object::BUILDARGS(@_)'."\n"
        .'        );'."\n"
        .'      }'."\n"
      ),
    );

    my $con;
    my @isa = @{mro::get_linear_isa($target)};
    shift @isa;
    if (my ($parent_new) = grep { *{_getglob($_.'::new')}{CODE} } @isa) {
      if ($parent_new eq 'Moo::Object') {
        # no special constructor needed
      }
      elsif (my $makers = $MAKERS{$parent_new}) {
        $con = $makers->{constructor};
        $construct_opts{construction_string} = $con->construction_string
          if $con;
      }
      elsif ($parent_new->can('BUILDALL')) {
        $construct_opts{construction_builder} = sub {
          my $inv = $target->can('BUILDARGS') ? '' : 'Moo::Object::';
          'do {'
          .'  my $args = $class->'.$inv.'BUILDARGS(@_);'
          .'  $args->{__no_BUILD__} = 1;'
          .'  $invoker->'.$target.'::SUPER::new($args);'
          .'}'
        };
      }
      else {
        $construct_opts{construction_builder} = sub {
          '$invoker->'.$target.'::SUPER::new('
            .($target->can('FOREIGNBUILDARGS') ?
              '$class->FOREIGNBUILDARGS(@_)' : '@_')
            .')'
        };
      }
    }
    ($con ? ref($con) : 'Method::Generate::Constructor')
      ->new(%construct_opts)
      ->install_delayed
      ->register_attribute_specs(%{$con?$con->all_attribute_specs:{}})
  }
}

sub _concrete_methods_of {
  my ($me, $role) = @_;
  my $makers = $MAKERS{$role};
  # grab role symbol table
  my $stash = _getstash($role);
  # reverse so our keys become the values (captured coderefs) in case
  # they got copied or re-used since
  my $not_methods = { reverse %{$makers->{not_methods}||{}} };
  +{
    # grab all code entries that aren't in the not_methods list
    map {
      my $code = *{$stash->{$_}}{CODE};
      ( ! $code or exists $not_methods->{$code} ) ? () : ($_ => $code)
    } grep !ref($stash->{$_}), keys %$stash
  };
}

1;
__END__

#line 1079

#line 1 "Sub/Exporter.pm"
use 5.006;
use strict;
use warnings;
package Sub::Exporter;
{
  $Sub::Exporter::VERSION = '0.987';
}
# ABSTRACT: a sophisticated exporter for custom-built routines

use Carp ();
use Data::OptList 0.100 ();
use Params::Util 0.14 (); # _CODELIKE
use Sub::Install 0.92 ();


# Given a potential import name, this returns the group name -- if it's got a
# group prefix.
sub _group_name {
  my ($name) = @_;

  return if (index q{-:}, (substr $name, 0, 1)) == -1;
  return substr $name, 1;
}

# \@groups is a canonicalized opt list of exports and groups this returns
# another canonicalized opt list with groups replaced with relevant exports.
# \%seen is groups we've already expanded and can ignore.
# \%merge is merged options from the group we're descending through.
sub _expand_groups {
  my ($class, $config, $groups, $collection, $seen, $merge) = @_;
  $seen  ||= {};
  $merge ||= {};
  my @groups = @$groups;

  for my $i (reverse 0 .. $#groups) {
    if (my $group_name = _group_name($groups[$i][0])) {
      my $seen = { %$seen }; # faux-dynamic scoping

      splice @groups, $i, 1,
        _expand_group($class, $config, $groups[$i], $collection, $seen, $merge);
    } else {
      # there's nothing to munge in this export's args
      next unless my %merge = %$merge;

      # we have things to merge in; do so
      my $prefix = (delete $merge{-prefix}) || '';
      my $suffix = (delete $merge{-suffix}) || '';

      if (
        Params::Util::_CODELIKE($groups[$i][1]) ## no critic Private
        or
        Params::Util::_SCALAR0($groups[$i][1]) ## no critic Private
      ) {
        # this entry was build by a group generator
        $groups[$i][0] = $prefix . $groups[$i][0] . $suffix;
      } else {
        my $as
          = ref $groups[$i][1]{-as} ? $groups[$i][1]{-as}
          :     $groups[$i][1]{-as} ? $prefix . $groups[$i][1]{-as} . $suffix
          :                           $prefix . $groups[$i][0]      . $suffix;

        $groups[$i][1] = { %{ $groups[$i][1] }, %merge, -as => $as };
      }
    }
  }

  return \@groups;
}

# \@group is a name/value pair from an opt list.
sub _expand_group {
  my ($class, $config, $group, $collection, $seen, $merge) = @_;
  $merge ||= {};

  my ($group_name, $group_arg) = @$group;
  $group_name = _group_name($group_name);

  Carp::croak qq(group "$group_name" is not exported by the $class module)
    unless exists $config->{groups}{$group_name};

  return if $seen->{$group_name}++;

  if (ref $group_arg) {
    my $prefix = (delete $merge->{-prefix}||'') . ($group_arg->{-prefix}||'');
    my $suffix = ($group_arg->{-suffix}||'') . (delete $merge->{-suffix}||'');
    $merge = {
      %$merge,
      %$group_arg,
      ($prefix ? (-prefix => $prefix) : ()),
      ($suffix ? (-suffix => $suffix) : ()),
    };
  }

  my $exports = $config->{groups}{$group_name};

  if (
    Params::Util::_CODELIKE($exports) ## no critic Private
    or
    Params::Util::_SCALAR0($exports) ## no critic Private
  ) {
    # I'm not very happy with this code for hiding -prefix and -suffix, but
    # it's needed, and I'm not sure, offhand, how to make it better.
    # -- rjbs, 2006-12-05
    my $group_arg = $merge ? { %$merge } : {};
    delete $group_arg->{-prefix};
    delete $group_arg->{-suffix};

    my $group = Params::Util::_CODELIKE($exports) ## no critic Private
              ? $exports->($class, $group_name, $group_arg, $collection)
              : $class->$$exports($group_name, $group_arg, $collection);

    Carp::croak qq(group generator "$group_name" did not return a hashref)
      if ref $group ne 'HASH';

    my $stuff = [ map { [ $_ => $group->{$_} ] } keys %$group ];
    return @{
      _expand_groups($class, $config, $stuff, $collection, $seen, $merge)
    };
  } else {
    $exports
      = Data::OptList::mkopt($exports, "$group_name exports");

    return @{
      _expand_groups($class, $config, $exports, $collection, $seen, $merge)
    };
  }
}

sub _mk_collection_builder {
  my ($col, $etc) = @_;
  my ($config, $import_args, $class, $into) = @$etc;

  my %seen;
  sub {
    my ($collection) = @_;
    my ($name, $value) = @$collection;

    Carp::croak "collection $name provided multiple times in import"
      if $seen{ $name }++;

    if (ref(my $hook = $config->{collectors}{$name})) {
      my $arg = {
        name        => $name,
        config      => $config,
        import_args => $import_args,
        class       => $class,
        into        => $into,
      };

      my $error_msg = "collection $name failed validation";
      if (Params::Util::_SCALAR0($hook)) { ## no critic Private
        Carp::croak $error_msg unless $class->$$hook($value, $arg);
      } else {
        Carp::croak $error_msg unless $hook->($value, $arg);
      }
    }

    $col->{ $name } = $value;
  }
}

# Given a config and pre-canonicalized importer args, remove collections from
# the args and return them.
sub _collect_collections {
  my ($config, $import_args, $class, $into) = @_;

  my @collections
    = map  { splice @$import_args, $_, 1 }
      grep { exists $config->{collectors}{ $import_args->[$_][0] } }
      reverse 0 .. $#$import_args;

  unshift @collections, [ INIT => {} ] if $config->{collectors}{INIT};

  my $col = {};
  my $builder = _mk_collection_builder($col, \@_);
  for my $collection (@collections) {
    $builder->($collection)
  }

  return $col;
}


sub setup_exporter {
  my ($config)  = @_;

  Carp::croak 'into and into_level may not both be supplied to exporter'
    if exists $config->{into} and exists $config->{into_level};

  my $as   = delete $config->{as}   || 'import';
  my $into
    = exists $config->{into}       ? delete $config->{into}
    : exists $config->{into_level} ? caller(delete $config->{into_level})
    :                                caller(0);

  my $import = build_exporter($config);

  Sub::Install::reinstall_sub({
    code => $import,
    into => $into,
    as   => $as,
  });
}


sub _key_intersection {
  my ($x, $y) = @_;
  my %seen = map { $_ => 1 } keys %$x;
  my @names = grep { $seen{$_} } keys %$y;
}

# Given the config passed to setup_exporter, which contains sugary opt list
# data, rewrite the opt lists into hashes, catch a few kinds of invalid
# configurations, and set up defaults.  Since the config is a reference, it's
# rewritten in place.
my %valid_config_key;
BEGIN {
  %valid_config_key =
    map { $_ => 1 }
    qw(as collectors installer generator exports groups into into_level),
    qw(exporter), # deprecated
}

sub _assert_collector_names_ok {
  my ($collectors) = @_;

  for my $reserved_name (grep { /\A[_A-Z]+\z/ } keys %$collectors) {
    Carp::croak "unknown reserved collector name: $reserved_name"
      if $reserved_name ne 'INIT';
  }
}

sub _rewrite_build_config {
  my ($config) = @_;

  if (my @keys = grep { not exists $valid_config_key{$_} } keys %$config) {
    Carp::croak "unknown options (@keys) passed to Sub::Exporter";
  }

  Carp::croak q(into and into_level may not both be supplied to exporter)
    if exists $config->{into} and exists $config->{into_level};

  # XXX: Remove after deprecation period.
  if ($config->{exporter}) {
    Carp::cluck "'exporter' argument to build_exporter is deprecated. Use 'installer' instead; the semantics are identical.";
    $config->{installer} = delete $config->{exporter};
  }

  Carp::croak q(into and into_level may not both be supplied to exporter)
    if exists $config->{into} and exists $config->{into_level};

  for (qw(exports collectors)) {
    $config->{$_} = Data::OptList::mkopt_hash(
      $config->{$_},
      $_,
      [ 'CODE', 'SCALAR' ],
    );
  }

  _assert_collector_names_ok($config->{collectors});

  if (my @names = _key_intersection(@$config{qw(exports collectors)})) {
    Carp::croak "names (@names) used in both collections and exports";
  }

  $config->{groups} = Data::OptList::mkopt_hash(
      $config->{groups},
      'groups',
      [
        'HASH',   # standard opt list
        'ARRAY',  # standard opt list
        'CODE',   # group generator
        'SCALAR', # name of group generation method
      ]
    );

  # by default, export nothing
  $config->{groups}{default} ||= [];

  # by default, build an all-inclusive 'all' group
  $config->{groups}{all} ||= [ keys %{ $config->{exports} } ];

  $config->{generator} ||= \&default_generator;
  $config->{installer} ||= \&default_installer;
}

sub build_exporter {
  my ($config) = @_;

  _rewrite_build_config($config);

  my $import = sub {
    my ($class) = shift;

    # XXX: clean this up -- rjbs, 2006-03-16
    my $special = (ref $_[0]) ? shift(@_) : {};
    Carp::croak q(into and into_level may not both be supplied to exporter)
      if exists $special->{into} and exists $special->{into_level};

    if ($special->{exporter}) {
      Carp::cluck "'exporter' special import argument is deprecated. Use 'installer' instead; the semantics are identical.";
      $special->{installer} = delete $special->{exporter};
    }

    my $into
      = defined $special->{into}       ? delete $special->{into}
      : defined $special->{into_level} ? caller(delete $special->{into_level})
      : defined $config->{into}        ? $config->{into}
      : defined $config->{into_level}  ? caller($config->{into_level})
      :                                  caller(0);

    my $generator = delete $special->{generator} || $config->{generator};
    my $installer = delete $special->{installer} || $config->{installer};

    # this builds a AOA, where the inner arrays are [ name => value_ref ]
    my $import_args = Data::OptList::mkopt([ @_ ]);

    # is this right?  defaults first or collectors first? -- rjbs, 2006-06-24
    $import_args = [ [ -default => undef ] ] unless @$import_args;

    my $collection = _collect_collections($config, $import_args, $class, $into);

    my $to_import = _expand_groups($class, $config, $import_args, $collection);

    # now, finally $import_arg is really the "to do" list
    _do_import(
      {
        class     => $class,
        col       => $collection,
        config    => $config,
        into      => $into,
        generator => $generator,
        installer => $installer,
      },
      $to_import,
    );
  };

  return $import;
}

sub _do_import {
  my ($arg, $to_import) = @_;

  my @todo;

  for my $pair (@$to_import) {
    my ($name, $import_arg) = @$pair;

    my ($generator, $as);

    if ($import_arg and Params::Util::_CODELIKE($import_arg)) { ## no critic
      # This is the case when a group generator has inserted name/code pairs.
      $generator = sub { $import_arg };
      $as = $name;
    } else {
      $import_arg = { $import_arg ? %$import_arg : () };

      Carp::croak qq("$name" is not exported by the $arg->{class} module)
        unless exists $arg->{config}{exports}{$name};

      $generator = $arg->{config}{exports}{$name};

      $as = exists $import_arg->{-as} ? (delete $import_arg->{-as}) : $name;
    }

    my $code = $arg->{generator}->(
      { 
        class     => $arg->{class},
        name      => $name,
        arg       => $import_arg,
        col       => $arg->{col},
        generator => $generator,
      }
    );

    push @todo, $as, $code;
  }

  $arg->{installer}->(
    {
      class => $arg->{class},
      into  => $arg->{into},
      col   => $arg->{col},
    },
    \@todo,
  );
}

## Cute idea, possibly for future use: also supply an "unimport" for:
## no Module::Whatever qw(arg arg arg);
# sub _unexport {
#   my (undef, undef, undef, undef, undef, $as, $into) = @_;
# 
#   if (ref $as eq 'SCALAR') {
#     undef $$as;
#   } elsif (ref $as) {
#     Carp::croak "invalid reference type for $as: " . ref $as;
#   } else {
#     no strict 'refs';
#     delete &{$into . '::' . $as};
#   }
# }


sub default_generator {
  my ($arg) = @_;
  my ($class, $name, $generator) = @$arg{qw(class name generator)};

  if (not defined $generator) {
    my $code = $class->can($name)
      or Carp::croak "can't locate exported subroutine $name via $class";
    return $code;
  }

  # I considered making this "$class->$generator(" but it seems that
  # overloading precedence would turn an overloaded-as-code generator object
  # into a string before code. -- rjbs, 2006-06-11
  return $generator->($class, $name, $arg->{arg}, $arg->{col})
    if Params::Util::_CODELIKE($generator); ## no critic Private

  # This "must" be a scalar reference, to a generator method name.
  # -- rjbs, 2006-12-05
  return $class->$$generator($name, $arg->{arg}, $arg->{col});
}


sub default_installer {
  my ($arg, $to_export) = @_;

  for (my $i = 0; $i < @$to_export; $i += 2) {
    my ($as, $code) = @$to_export[ $i, $i+1 ];

    # Allow as isa ARRAY to push onto an array?
    # Allow into isa HASH to install name=>code into hash?

    if (ref $as eq 'SCALAR') {
      $$as = $code;
    } elsif (ref $as) {
      Carp::croak "invalid reference type for $as: " . ref $as;
    } else {
      Sub::Install::reinstall_sub({
        code => $code,
        into => $arg->{into},
        as   => $as
      });
    }
  }
}

sub default_exporter {
  Carp::cluck "default_exporter is deprecated; call default_installer instead; the semantics are identical";
  goto &default_installer;
}


setup_exporter({
  exports => [
    qw(setup_exporter build_exporter),
    _import => sub { build_exporter($_[2]) },
  ],
  groups  => {
    all   => [ qw(setup_exporter build_export) ],
  },
  collectors => { -setup => \&_setup },
});

sub _setup {
  my ($value, $arg) = @_;

  if (ref $value eq 'HASH') {
    push @{ $arg->{import_args} }, [ _import => { -as => 'import', %$value } ];
    return 1;
  } elsif (ref $value eq 'ARRAY') {
    push @{ $arg->{import_args} },
      [ _import => { -as => 'import', exports => $value } ];
    return 1;
  }
  return;
}



"jn8:32"; # <-- magic true value

__END__

#line 1109

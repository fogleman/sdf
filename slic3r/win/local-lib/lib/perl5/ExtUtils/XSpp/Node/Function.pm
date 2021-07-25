package ExtUtils::XSpp::Node::Function;
use strict;
use warnings;
use Carp ();
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Function - Node representing a function

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing a single function declaration
such as

  int foo();

More importantly, L<ExtUtils::XSpp::Node::Method> inherits from this class,
so all in here equally applies to method nodes.

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Function>.

Named parameters: C<cpp_name> indicating the C++ name of the function,
C<perl_name> indicating the Perl name of the function (defaults to the
same as C<cpp_name>), C<arguments> can be a reference to an
array of C<ExtUtils::XSpp::Node::Argument> objects and finally
C<ret_type> indicates the (C++) return type of the function.

Additionally, there are several optional decorators for a function
declaration (see L<ExtUtils::XSpp> for a list). These can be
passed to the constructor as C<code>, C<cleanup>, C<postcall>,
and C<catch>. C<catch> is special in that it must be a reference
to an array of class names.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{CPP_NAME}  = $args{cpp_name};
  $this->{PERL_NAME} = $args{perl_name} || $args{cpp_name};
  $this->{ARGUMENTS} = $args{arguments} || [];
  $this->{RET_TYPE}  = $args{ret_type};
  $this->{CODE}      = $args{code};
  $this->{CALL_CODE} = $args{call_code};
  $this->{CLEANUP}   = $args{cleanup};
  $this->{POSTCALL}  = $args{postcall};
  $this->{CLASS}     = $args{class};
  $this->{CATCH}     = $args{catch};
  $this->{CONDITION} = $args{condition};
  $this->{ALIAS}     = $args{alias};
  $this->{TAGS}      = $args{tags};
  $this->{EMIT_CONDITION} = $args{emit_condition};

  my $index = 0;
  foreach my $arg ( @{$this->{ARGUMENTS}} ) {
      $arg->{FUNCTION} = $this;
      $arg->{INDEX} = $index;
      ++$index;
  }

  if (@{$this->catch} > 1
      and grep {$_ eq 'nothing'} @{$this->{CATCH}})
  {
    Carp::croak( ref($this) . " '" . $this->{CPP_NAME}
                 . "' is supposed to catch no exceptions, yet"
                 . " there are exception handlers ("
                 . join(", ", @{$this->{CATCH}}) . ")" );
  }
  return $this;
}

=head2 resolve_typemaps

Fetches the L<ExtUtils::XSpp::Typemap> object for
the return type and the arguments from the typemap registry
and stores a reference to those objects.

=cut

sub resolve_typemaps {
  my $this = shift;
  my $index = 0;

  if( $this->ret_type ) {
    $this->{TYPEMAPS}{RET_TYPE} ||=
      ExtUtils::XSpp::Typemap::get_typemap_for_type( $this->ret_type );
  }
  foreach my $a ( @{$this->arguments} ) {
    $this->{TYPEMAPS}{ARGUMENTS}[$index++] ||=
      ExtUtils::XSpp::Typemap::get_typemap_for_type( $a->type );
  }
}


=head2 resolve_exceptions

Fetches the L<ExtUtils::XSpp::Exception> object for
the C<%catch> directives associated with this function.

=cut

sub resolve_exceptions {
  my $this = shift;

  my @catch = @{$this->catch};

  my @exceptions;

  # If this method is not hard-wired to catch nothing...
  if (not grep {$_ eq 'nothing'} @catch) {
    my %seen;
    foreach my $catch (@catch) {
      next if $seen{$catch}++;
      push @exceptions,
        ExtUtils::XSpp::Exception->get_exception_for_name($catch);
    }

    # If nothing else, catch std::exceptions nicely
    if (not @exceptions) {
      my $typenode = ExtUtils::XSpp::Node::Type->new(base => 'std::exception');
      push @exceptions,
        ExtUtils::XSpp::Exception::stdmessage->new( name => 'default',
                                                    type => $typenode );
    }
  }

  # Always catch the rest with an unspecific error message.
  # If the method is hard-wired to catch nothing, we lie to the user
  # for his own safety! (FIXME: debate this)
  push @exceptions,
    ExtUtils::XSpp::Exception::unknown->new( name => '', type => '' );

  $this->{EXCEPTIONS} = \@exceptions;
}

sub disable_exceptions {
  my $this = shift;

  $this->{EXCEPTIONS} = [];
}

=head2 add_exception_handlers

Adds a list of exception names to the list of exception handlers.
This is mainly called by a class' C<add_methods> method.
If the function is hard-wired to have no exception handlers,
any extra handlers from the class are ignored.

=cut


sub add_exception_handlers {
  my $this = shift;

  # ignore class %catch'es if overridden with "nothing" in the method
  if (@{$this->catch} == 1 and $this->{CATCH}[0] eq 'nothing') {
    return();
  }

  # ignore class %catch{nothing} if overridden in the method
  if (@_ == 1 and $_[0] eq 'nothing' and @{$this->catch}) {
    return();
  }

  $this->{CATCH} ||= [];
  push @{$this->{CATCH}}, @_;

  return();
}

# Depending on argument style, this produces either: (style=kr)
#
# return_type
# class_name::function_name( args = def, ... )
#     type arg
#     type arg
#   PREINIT:
#     aux vars
#   [ALIAS:
#     ID = INTEGER...]
#   [PP]CODE:
#     RETVAL = new Foo( THIS->method( arg1, *arg2 ) );
#   POSTCALL:
#     /* anything */
#   OUTPUT:
#     RETVAL
#   CLEANUP:
#     /* anything */
#
# Or: (style=ansi)
#
# return_type
# class_name::function_name( type arg1 = def, type arg2 = def, ... )
#   PREINIT:
# (rest as above)

sub print {
  my $this               = shift;
  my $state              = shift;

  my $out                = '';
  my $fname              = $this->perl_function_name;
  my $args               = $this->arguments;
  my $ret_type           = $this->ret_type;
  my $ret_typemap        = $this->{TYPEMAPS}{RET_TYPE};
  my $aliases            = $this->{ALIAS} || {};

  my $has_aliases = scalar(keys %$aliases);

  $out .= '#if ' . $this->emit_condition . "\n" if $this->emit_condition;

  my( $init, $arg_list, $call_arg_list, $code, $output, $cleanup,
      $postcall, $precall, $alias ) = ( ('') x 9 );

  # compute the precall code, XS argument list and C++ argument list using
  # the typemap information
  if( $args && @$args ) {
    my $has_self = $this->is_method ? 1 : 0;
    my( @arg_list, @call_arg_list );
    foreach my $i ( 0 .. $#$args ) {
      my $arg = ${$args}[$i];
      my $t   = $this->{TYPEMAPS}{ARGUMENTS}[$i];
      my $pc  = $t->precall_code( sprintf( 'ST(%d)', $i + $has_self ),
                                  $arg->name );

      push @arg_list, $t->cpp_type . ' ' . $arg->name .
                      ( $arg->has_default ? ' = ' . $arg->default : '' );

      my $call_code = $t->call_parameter_code( $arg->name );
      push @call_arg_list, defined( $call_code ) ? $call_code : $arg->name;
      $precall .= $pc . ";\n" if $pc
    }

    $arg_list = ' ' . join( ', ', @arg_list ) . ' ';
    $call_arg_list = ' ' . join( ', ', @call_arg_list ) . ' ';
  }

  # If there's %alias{foo = 123} definitions, generate ALIAS section
  if ($has_aliases) {
    # order by ordinal for consistent hash-order-independent output
    my @alias_list = map "    $_ = $aliases->{$_}\n",
                     sort {$aliases->{$a} <=> $aliases->{$b}}
                     keys %$aliases;
    $alias = "  ALIAS:\n" . join("", @alias_list);
  }

  my $retstr = $ret_typemap ? $ret_typemap->cpp_type : 'void';

  # special case: constructors with name different from 'new'
  # need to be declared 'static' in XS
  if( $this->isa( 'ExtUtils::XSpp::Node::Constructor' ) &&
      $this->perl_name ne $this->cpp_name ) {
    $retstr = "static $retstr";
  }

  my $has_ret = $ret_typemap && !$ret_typemap->type->is_void;

  my $ppcode = $has_ret && $ret_typemap->output_list( '' ) ? 1 : 0;
  my $code_type = $ppcode ? "PPCODE" : "CODE";
  my $ccode = $this->_call_code( $call_arg_list );
  if ($this->{CALL_CODE}) {
    $ccode = join( "\n", @{$this->{CALL_CODE}} );
  } elsif ($this->isa('ExtUtils::XSpp::Node::Destructor')) {
    $ccode = 'delete THIS';
    $has_ret = 0;
  } elsif( $has_ret && defined $ret_typemap->call_function_code( '', '' ) ) {
    $ccode = $ret_typemap->call_function_code( $ccode, 'RETVAL' );
  } elsif( $has_ret ) {
    if ($has_aliases) {
      $ccode = $this->_generate_alias_conditionals($call_arg_list, 1); # 1 == use RETVAL
    } else {
      $ccode = "RETVAL = $ccode";
    }
  } elsif( $has_aliases ) { # aliases but no RETVAL
    $ccode = $this->_generate_alias_conditionals($call_arg_list, 0); # 0 == no RETVAL
  }

  my @catchers = @{$this->{EXCEPTIONS}};
  $code .= "  $code_type:\n";
  $code .= "    try {\n" if @catchers;
  if ($precall) {
    $code .= '      ' . $precall;
  }
  $code .= (@catchers ? '  ' : '') . '    ' . $ccode . ";\n";
  if( $has_ret && defined $ret_typemap->output_code( '', '' ) ) {
    my $retcode = $ret_typemap->output_code( 'ST(0)', 'RETVAL' );
    $code .= '      ' . $retcode . ";\n";
  }
  if( $has_ret && defined $ret_typemap->output_list( '' ) ) {
    my $retcode = $ret_typemap->output_list( 'RETVAL' );
    $code .= '      ' . $retcode . ";\n";
  }
  $code .= "    }\n" if @catchers;
  foreach my $exception_handler (@catchers) {
    my $handler_code = $exception_handler->handler_code;
    $code .= $handler_code;
  }

  $output = "  OUTPUT: RETVAL\n" if $has_ret;

  if( $has_ret && defined $ret_typemap->cleanup_code( '', '' ) ) {
    $cleanup .= "  CLEANUP:\n";
    my $cleanupcode = $ret_typemap->cleanup_code( 'ST(0)', 'RETVAL' );
    $cleanup .= '    ' . $cleanupcode . ";\n";
  }

  if( $this->code ) {
    $code = "  $code_type:\n    " . join( "\n", @{$this->code} ) . "\n";
    $output = "  OUTPUT: RETVAL\n" if $code =~ m/\bRETVAL\b/;
  }
  if( $this->postcall ) {
    $postcall = "  POSTCALL:\n    " . join( "\n", @{$this->postcall} ) . "\n";
    $output ||= "  OUTPUT: RETVAL\n" if $has_ret;
  }
  if( $this->cleanup ) {
    $cleanup ||= "  CLEANUP:\n";
    my $clcode = join( "\n", @{$this->cleanup} );
    $cleanup .= "    $clcode\n";
  }
  if( $ppcode ) {
    $output = '';
  }

  if( !$this->is_method && $fname =~ /^(.*)::(\w+)$/ ) {
    my $pcname = $1;
    $fname = $2;
    my $cur_module = $state->{current_module}->to_string;
    $out .= <<EOT;
$cur_module PACKAGE=$pcname

EOT
  }

  my $head = "$retstr\n"
             . "$fname($arg_list)\n";
  my $body = $alias . $init . $code . $postcall . $output . $cleanup;

  # cleanup potential multiple newlines because they break XSUBs
  $body =~ s/^\s*\n//mg;
  $body .= "\n";

  $this->_munge_code(\$body) if $this->has_argument_with_length;

  $out .= $head . $body;
  $out .= '#endif // ' . $this->emit_condition . "\n" if $this->emit_condition;

  return $out;
}

# This replaces the use of "length(varname)" with
# the proper name of the XS variable that is auto-generated in
# case of the XS length() feature. The Argument's take care of
# this and do nothing if they're not of the "length" type.
# Any additional checking "$this->_munge_code(\$code) if $using_length"
# is just an optimization!
sub _munge_code {
  my $this = shift;
  my $code = shift;
  
  foreach my $arg (@{$this->{ARGUMENTS}}) {
    $$code = $arg->fix_name_in_code($$code);
  }
}

=head2 print_declaration

Returns a string with a C++ method declaration for the node.

=cut

sub print_declaration {
    my( $this ) = @_;

    return $this->ret_type->print . ' ' . $this->cpp_name . '( ' .
           join( ', ', map $_->print, @{$this->arguments} ) . ')' .
           ( $this->const ? ' const' : '' );
}

=head2 perl_function_name

Returns the name of the Perl function to generate.

=cut

sub perl_function_name { $_[0]->perl_name }

=head2 is_method

Returns whether the object at hand is a method. Hard-wired
to be false for C<ExtUtils::XSpp::Node::Function> object,
but overridden in the L<ExtUtils::XSpp::Node::Method> sub-class.

=cut

sub is_method { 0 }

=head2 has_argument_with_length

Returns true if the function has any argument that uses the XS length
feature.

=cut

sub has_argument_with_length {
  my $this = shift;
  foreach my $arg (@{$this->{ARGUMENTS}}) {
    return 1 if $arg->uses_length;
  }
  return();
}


=begin documentation

ExtUtils::XSpp::Function::_call_code( argument_string )

Return something like "foo( $argument_string )".

=end documentation

=cut

sub _call_code { return $_[0]->cpp_name . '(' . $_[1] . ')'; }

=begin documentation

ExtUtils::XSpp::Function::_call_code_aliased( function_alias_name, argument_string )

Return something like "$function_alias_name( $argument_string )".

=end documentation

=cut

sub _call_code_aliased { return $_[1] . '(' . $_[2] . ')'; }

=begin documentation

ExtUtils::XSpp::Function::_generate_alias_conditionals( argument_string, use_retval_bool )

Generates if()else if()else block for XS function name aliasing (cf. the XS manual and the ix
variable). If use_retval_bool is true, each included function call will contain an
assignment to RETVAL.

Returns the generated code.

=end documentation

=cut
sub _generate_alias_conditionals {
  my ($this, $call_arg_list, $use_retval) = @_;
  my $aliases = $this->{ALIAS};

  my $retval_code = $use_retval ? "RETVAL = " : "";
  my $buf = "if (ix == 0) {\n  $retval_code"
            . $this->_call_code($call_arg_list)
            . ";\n}\n";
  # order by ordinal for consistent hash-order-independent output
  foreach my $alias (sort {$aliases->{$a} <=> $aliases->{$b}} keys %$aliases)
  {
    $buf .= "else if (ix == $aliases->{$alias}) {\n  "
            . $retval_code . $this->_call_code_aliased($alias, $call_arg_list)
            . ";\n}\n";
  }
  $buf .= "else\n  croak(\"Panic: Invalid invocation of function alias number %i!\", (int)ix))";

  # indent
  $buf =~ s/^/      /gm;
  $buf =~ s/^\s+//; # first line will get special treatment...

  return $buf;
}


=head1 ACCESSORS

=head2 cpp_name

Returns the C++ name of the function.

=head2 perl_name

Returns the Perl name of the function (defaults to same as C++).

=head2 set_perl_name

Sets the Perl name of the function.

=head2 arguments

Returns the internal array reference of L<ExtUtils::XSpp::Node::Argument>
objects that represent the function arguments.

=head2 ret_type

Returns the C++ return type.

=head2 code

Returns the C<%code> decorator if any.

=head2 set_code

Sets the implementation for the method call (equivalent to using
C<%code>); takes the code as an array reference containing the lines.

=head2 cleanup

Returns the C<%cleanup> decorator if any.

=head2 postcall

Returns the C<%postcall> decorator if any.

=head2 catch

Returns the set of exception types that were associated
with the function via C<%catch>. (array reference)

=head2 aliases

Returns a hashref of C<name =E<gt> position>
function name aliases (see %alias and L<perlxs> ALIAS keyword).
Does not include the main function name.

=cut

sub cpp_name { $_[0]->{CPP_NAME} }
sub set_cpp_name { $_[0]->{CPP_NAME} = $_[1] }
sub perl_name { $_[0]->{PERL_NAME} }
sub set_perl_name { $_[0]->{PERL_NAME} = $_[1] }
sub arguments { $_[0]->{ARGUMENTS} }
sub ret_type { $_[0]->{RET_TYPE} }
sub code { $_[0]->{CODE} }
sub set_code { $_[0]->{CODE} = $_[1] }
sub cleanup { $_[0]->{CLEANUP} }
sub postcall { $_[0]->{POSTCALL} }
sub catch { $_[0]->{CATCH} ? $_[0]->{CATCH} : [] }
sub aliases { $_[0]->{ALIAS} ? $_[0]->{ALIAS} : {} }
sub tags { $_[0]->{TAGS} }

=head2 set_static

Sets the C<static>-ness attribute of the function.
Can be either undef (i.e. not static), C<"package_static">,
or C<"class_static">.

=head2 package_static

Returns whether the function is package static.  A package static
function can be invoked as:

    My::Package::Function( ... );

=head2 class_static

Returns whether the function is class static. A class static function
can be invoked as:

    My::Package->Function( ... );

=cut

sub set_static { $_[0]->{STATIC} = $_[1] }
sub package_static { ( $_[0]->{STATIC} || '' ) eq 'package_static' }
sub class_static { ( $_[0]->{STATIC} || '' ) eq 'class_static' }

=head2 ret_typemap

Returns the typemap for the return value of the function.

=head2 set_ret_typemap( typemap )

Sets the typemap for the return value of the function.

=head2 arg_typemap( index )

Returns the typemap for one function arguments.

=head2 set_arg_typemap( index, typemap )

Sets the typemap for one function argument.

=cut

sub ret_typemap {
  my ($this) = @_;

  die "Typemap not available yet" unless $this->{TYPEMAPS}{RET_TYPE};
  return $this->{TYPEMAPS}{RET_TYPE};
}

sub set_ret_typemap {
  my ($this, $typemap) = @_;

  $this->{TYPEMAPS}{RET_TYPE} = $typemap;
}

sub arg_typemap {
  my ($this, $index) = @_;

  die "Invalid index" unless $index < @{$this->{ARGUMENTS}};
  die "Typemap not available yet" unless $this->{TYPEMAPS}{ARGUMENTS};
  return $this->{TYPEMAPS}{ARGUMENTS}[$index];
}

sub set_arg_typemap {
  my ($this, $index, $typemap) = @_;

  die "Invalid index" unless $index < @{$this->{ARGUMENTS}};
  $this->{TYPEMAPS}{ARGUMENTS}[$index] = $typemap;
}

1;

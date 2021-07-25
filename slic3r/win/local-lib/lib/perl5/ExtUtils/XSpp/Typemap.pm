package ExtUtils::XSpp::Typemap;
use strict;
use warnings;

use ExtUtils::Typemaps;

require ExtUtils::XSpp::Node::Type;
require ExtUtils::XSpp::Typemap::parsed;
require ExtUtils::XSpp::Typemap::simple;
require ExtUtils::XSpp::Typemap::reference;

my %TypemapsByName;

=head1 NAME

ExtUtils::XSpp::Typemap - map types

=cut

sub new {
  my $class = shift;
  my $this = bless {}, $class;

  $this->init( @_ );

  return $this;
}

sub create {
  my( $name, @args ) = @_;

  if( my $template = $TypemapsByName{$name} ) {
    my $package = ref $template;

    return $package->new( base => $template, @args );
  } else {
    my $package = "ExtUtils::XSpp::Typemap::" . $name;

    return $package->new( @args );
  }
}

=head1 METHODS

=head2 ExtUtils::XSpp::Typemap::type

Returns the ExtUtils::XSpp::Node::Type that is used for this typemap.

=cut

sub type { $_[0]->{TYPE} }

=head2 ExtUtils::XSpp::Typemap::xs_type()

(Optional) XS typemap identifier (e.g. T_IV) for this C++ type.

=head2 ExtUtils::XSpp::Typemap::xs_input_code()

(Optional) XS input code for the associated XS typemap.

=head2 ExtUtils::XSpp::Typemap::xs_output_code()

(Optional) XS output code for the associated XS typemap.

=head2 ExtUtils::XSpp::Typemap::cpp_type()

Returns the C++ type to be used for the local variable declaration.

=head2 ExtUtils::XSpp::Typemap::input_code( perl_argument_name, cpp_var_name1, ... )

Code to put the contents of the perl_argument (typically ST(x)) into
the C++ variable(s).

=head2 ExtUtils::XSpp::Typemap::output_code( perl_variable, c_variable )

=head2 ExtUtils::XSpp::Typemap::cleanup_code( perl_variable, c_variable )

=head2 ExtUtils::XSpp::Typemap::call_parameter_code( parameter_name )

=head2 ExtUtils::XSpp::Typemap::call_function_code( function_call_code, return_variable )

Allows modifying the code used in the function/method call.  The first
parameter has the form C<THIS->method( <args> )>, the second
parameter is a variable to hold the return value.

=cut

sub init { }

sub xs_type { $_[0]->{XS_TYPE} }
sub xs_input_code { $_[0]->{XS_INPUT_CODE} }
sub xs_output_code { $_[0]->{XS_OUTPUT_CODE} }
sub name { $_[0]->{NAME} }
sub cpp_type { die; }
sub input_code { die; }
sub precall_code { undef }
sub output_code { undef }
sub cleanup_code { undef }
sub call_parameter_code { undef }
sub call_function_code { undef }
sub output_list { undef }

my @Typemaps;
my $Default_output_code = 'sv_setref_pv( $arg, xsp_constructor_class("${my $ntt = $type; $ntt =~ s{^const\s+|[ \t*]+$}{}g; \\$ntt}"), (void*)$var );';
my $Default_input_code = <<'INPUTCODE';
	if( sv_isobject($arg) && (SvTYPE(SvRV($arg)) == SVt_PVMG) )
		$var = ($type)SvIV((SV*)SvRV( $arg ));
	else{
		warn( \"${Package}::$func_name() -- $var is not a blessed SV reference\" );
		XSRETURN_UNDEF;
	}
INPUTCODE


# add typemaps for basic C types
add_default_typemaps();

sub add_typemap_for_type {
  my( $type, $typemap ) = @_;

  unshift @Typemaps, [ $type, $typemap ];
  $TypemapsByName{$typemap->name} = $typemap if $typemap->name;
}

sub reset_typemaps {
  @Typemaps = ();
  add_default_typemaps();
}

# a weak typemap does not override an already existing typemap for the
# same type
sub add_weak_typemap_for_type {
  my( $type, $typemap ) = @_;
  push @Typemaps, [ $type, $typemap ];
  $TypemapsByName{$typemap->name} ||= $typemap if $typemap->name;
}

sub get_typemap_for_type {
  my $type = shift;

  foreach my $t ( @Typemaps ) {
    return ${$t}[1] if $t->[0]->equals( $type );
  }

  # construct verbose error message:
  my $errmsg = "No typemap for type " . $type->print
               . "\nThere are typemaps for the following types:\n";
  my @types;
  foreach my $t (@Typemaps) {
    push @types, "  - " . $t->[0]->print . "\n";
  }

  if (@types) {
    $errmsg .= join('', @types);
  }
  else {
    $errmsg .= "  (none)\n";
  }
  $errmsg .= "Did you forget to declare your type in an XS++ typemap?";

  Carp::confess( $errmsg );
}

sub get_xs_typemap_code_for_all_typemaps {
  my $typemaps = ExtUtils::Typemaps->new;

  # process typemaps in reverse order, so newer ones take precedence
  my @xs_typemaps = grep $_->[1]->xs_type, reverse @Typemaps;
  return unless @xs_typemaps;

  my %xs_types;
  foreach my $typemap (grep $_->[1]->cpp_type && $_->[1]->cpp_type ne '_', @xs_typemaps) {
    my $xstype = $typemap->[1]->xs_type;

    $xs_types{$typemap->[1]->cpp_type} = $xstype;
    $typemaps->add_typemap(
      ctype => $typemap->[1]->cpp_type,
      xstype => $xstype,
      replace => 1,
    );
  }

  # avoid adding INPUT/OUTPUT sections for unused mappings
  %xs_types = reverse %xs_types;
  foreach my $typemap (grep $xs_types{$_->[1]->xs_type || ''}, @xs_typemaps) {
    my $xstype = $typemap->[1]->xs_type;

    $typemaps->add_inputmap(
      xstype => $xstype,
      code => $typemap->[1]->xs_input_code,
      replace => 1,
    ) if $typemap->[1]->xs_input_code;

    $typemaps->add_outputmap(
      xstype => $xstype,
      code => $typemap->[1]->xs_output_code,
      replace => 1,
    ) if $typemap->[1]->xs_output_code;
  }

  return '' if $typemaps->is_empty;
  my $code = $typemaps->as_string;
  my $end_marker = 'END';
  while ($code =~ /^\Q$end_marker\E\s*$/m) {
    $end_marker .= '_';
  }
  return "TYPEMAP: <<$end_marker\n$code\n$end_marker\n";
}

# adds default typemaps for C* and C&
sub add_class_default_typemaps {
  my( $name ) = @_;

  my $ptr = ExtUtils::XSpp::Node::Type->new
                ( base    => $name,
                  pointer => 1,
                  );
  my $ref = ExtUtils::XSpp::Node::Type->new
                ( base      => $name,
                  reference => 1,
                  );

  my $xs_type = $TypemapsByName{object}->xs_type;

  add_weak_typemap_for_type
      ( $ptr, ExtUtils::XSpp::Typemap::simple->new( type => $ptr, xs_type => $xs_type ) );
  add_weak_typemap_for_type
      ( $ref, ExtUtils::XSpp::Typemap::reference->new( type => $ref, xs_type => $xs_type ) );
}

sub add_default_typemaps {
  # void, integral and floating point types
  foreach my $t ( 'char', 'short', 'int', 'long', 'bool',
                  'unsigned char', 'unsigned short', 'unsigned int',
                  'unsigned long', 'void',
                  'float', 'double', 'long double' ) {
    my $type = ExtUtils::XSpp::Node::Type->new( base => $t );

    ExtUtils::XSpp::Typemap::add_typemap_for_type
        ( $type, ExtUtils::XSpp::Typemap::simple->new( type => $type ) );
  }

  # char*, const char*
  my $char_p = ExtUtils::XSpp::Node::Type->new
                   ( base    => 'char',
                     pointer => 1,
                     );

  ExtUtils::XSpp::Typemap::add_typemap_for_type
      ( $char_p, ExtUtils::XSpp::Typemap::simple->new( type => $char_p ) );

  my $const_char_p = ExtUtils::XSpp::Node::Type->new
                         ( base    => 'char',
                           pointer => 1,
                           const   => 1,
                           );

  ExtUtils::XSpp::Typemap::add_typemap_for_type
      ( $const_char_p, ExtUtils::XSpp::Typemap::simple->new( type => $const_char_p ) );

  # objects
  my $dummy_type = ExtUtils::XSpp::Node::Type->new( base => '' );
  my $obj_typemap = ExtUtils::XSpp::Typemap::parsed->new(
    name             => 'object',
    type             => $dummy_type,
    xs_input_code    => $Default_input_code,
    xs_output_code   => $Default_output_code,
  );

  ExtUtils::XSpp::Typemap::add_typemap_for_type( $dummy_type, $obj_typemap )
}

sub _enable_default_xs_typemaps {
  foreach my $t ( reverse @Typemaps ) {
    if( ($t->[1]->name || '') eq 'object' ) {
      $t->[1]{XS_TYPE} ||= 'O_OBJECT';
      last;
    }
  }
}

1;

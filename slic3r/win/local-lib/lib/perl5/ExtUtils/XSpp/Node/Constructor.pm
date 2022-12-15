package ExtUtils::XSpp::Node::Constructor;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node::Method';

=head1 NAME

ExtUtils::XSpp::Node::Constructor - Node representing a constructor method

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node::Method> subclass representing a 
constructor such as:

  class FooBar {
    FooBar(); // <-- this one
  };

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Constructor>.

Most of the functionality of this class is inherited. This
means that all named parameters of L<ExtUtils::XSpp::Node::Method>
and its base class are also valid for this class' constructor.

Additionally, this class requires that no return type has
been specified as constructors do not have return types.

=cut

sub init {
  my $this = shift;
  $this->SUPER::init( @_ );

  die "Can't specify return value in constructor" if $this->{RET_TYPE};
}

sub print {
    my $this  = shift;
    my $state = shift;
    my $out = $this->SUPER::print( $state );

    return sprintf <<EOT, $out;
#undef  xsp_constructor_class
#define xsp_constructor_class(c) (CLASS)

%s#undef  xsp_constructor_class
#define xsp_constructor_class(c) (c)

EOT
}

=head2 ret_type

Unlike the C<ret_type> method of the L<ExtUtils::XSpp::Node::Method> class,
C<ret_type> will return the type "pointer to object of this class"
as return type of the constructor.

=cut

sub ret_type {
  my $this = shift;

  ExtUtils::XSpp::Node::Type->new( base    => $this->class->cpp_name,
                                   pointer => 1 );
}

sub perl_function_name {
  my $this = shift;
  my( $pname, $cname, $pclass, $cclass ) = ( $this->perl_name,
                                             $this->cpp_name,
                                             $this->class->perl_name,
                                             $this->class->cpp_name );

  if( $pname ne $cname ) {
    return $cclass . '::' . $pname;
  } else {
    return $cclass . '::' . 'new';
  }
}

sub _call_code { return "new " . $_[0]->class->cpp_name .
                   '(' . $_[1] . ')'; }

1;

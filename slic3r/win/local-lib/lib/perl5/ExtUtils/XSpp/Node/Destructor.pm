package ExtUtils::XSpp::Node::Destructor;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node::Method';

=head1 NAME

ExtUtils::XSpp::Node::Destructor - Node representing a destructor method

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node::Method> subclass representing a 
destructor such as:

  class FooBar {
    ~FooBar(); // <-- this one
  };

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Destructor>.

Most of the functionality of this class is inherited. This
means that all named parameters of L<ExtUtils::XSpp::Node::Method>
and its base class are also valid for this class' destructor.

Additionally, this class requires that no return type has
been specified as destructors do not have return types.

=cut

sub init {
  my $this = shift;
  $this->SUPER::init( @_ );

  die "Can't specify return value in destructor" if $this->{RET_TYPE};
}

=head2 perl_function_name

Returns the name of the class with C<::DESTROY> appended.

=cut

sub perl_function_name {
  my $this = shift;

  if( $this->perl_name ne $this->cpp_name ) {
    return $this->class->cpp_name . '::' . $this->perl_name;
  } else {
    return $this->class->cpp_name . '::' . 'DESTROY';
  }
}

sub ret_type { undef }

1;

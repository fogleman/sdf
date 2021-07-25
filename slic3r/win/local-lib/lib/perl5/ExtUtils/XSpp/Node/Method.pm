package ExtUtils::XSpp::Node::Method;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node::Function';

=head1 NAME

ExtUtils::XSpp::Node::Method - Node representing a method

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node::Function> sub-class representing a single method
declaration in a class such as

  class FooBar {
    int foo(double someArgument); // <-- this one
  }


=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Method>.

Most of the functionality of this class is inherited. This
means that all named parameters of L<ExtUtils::XSpp::Node::Function>
are also valid for this class.

Additional named parameters accepted by the constructor:
C<class>, which can be an L<ExtUtils::XSpp::Node::Class>
object, C<const> and C<virtual> that are true if the method has
been declared C<const> or C<virtual>.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->SUPER::init( %args );
  $this->{CLASS} = $args{class};
  $this->{CONST} = $args{const};
  $this->{VIRTUAL} = $args{virtual};
}

=head2 perl_function_name

Returns the name of the Perl function (method) that this
method represents. It is constructed from the method's
class's name and the C<perl_name> attribute.

=cut

sub perl_function_name {
    my( $self ) = @_;

    if( $self->package_static ) {
        return $self->perl_name;
    } else {
        return $self->class->cpp_name . '::' . $self->perl_name;
    }
}

sub _call_code {
    my( $self, $arg_string ) = @_;

    return $self->_call_code_aliased($self->cpp_name, $arg_string);
}

sub _call_code_aliased {
    my( $self, $alias_name, $arg_string ) = @_;

    if( $self->package_static ) {
        return $self->class->cpp_name . '::' .
               $alias_name . '(' . $arg_string . ')';
    } else {
        return "THIS->" .
               $alias_name . '(' . $arg_string . ')';
    }
}

=head2 is_method

Returns true, since all objects of this class are methods.

=cut

sub is_method { 1 }

=head2 ACCESSORS

=head2 class

Returns the class (L<ExtUtils::XSpp::Node::Class>) that the
method belongs to.

=head2 virtual

Returns whether the method was declared virtual.

=head2 set_virtual

Set whether the method is to be considered virtual.

=head2 const

Returns whether the method was declared const.

=head2 access

Returns C<'public'>, C<'protected'> or C<'private'> depending on
method access declaration.  By default, only public methods are
generated.

=cut

sub class { $_[0]->{CLASS} }
sub virtual { $_[0]->{VIRTUAL} }
sub set_virtual { $_[0]->{VIRTUAL} = $_[1] }
sub const { $_[0]->{CONST} }
sub access { $_[0]->{ACCESS} }
sub set_access { $_[0]->{ACCESS} = $_[1] }

1;

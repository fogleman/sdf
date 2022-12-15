package ExtUtils::XSpp::Node::Argument;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Argument - Node representing a method/function argument

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing a single function
or method argument such as

  int foo = 0.

which would translate to an C<ExtUtils::XSpp::Node::Argument> which has
its C<type> set to C<int>, its C<name> set to C<foo> and its C<default>
set to C<0.>.

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Argument>.

Named parameters: C<type> indicating the C++ argument type,
C<name> indicating the variable name, and optionally
C<default> indicating the default value of the argument.

=head2 uses_length

Returns true if the argument uses the XS length feature, false
otherwise.

=head2 implementation_name

Returns the same as the C<name> method unless
the argument is of the C<%length(something)> variant.
In that case, C<implementation_name> returns a
munged version of the name that addresses the name mangling
done by F<xsubpp>: C<XSauto_length_of_somthing>.

=head2 fix_name_in_code

Given a code string, replaces any occurrances of
the name of this C<Argument> with its implementation
name. If the implementation name is the same as the name,
which is the most likely case, the code remains
completely untouched.

Returns the potentially modified code.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{TYPE} = $args{type};
  $this->{NAME} = $args{name};
  $this->{DEFAULT} = $args{default};
  $this->{TAGS} = $args{tags};
}

sub print {
  my $this = shift;
  my $state = shift;

  return join( ' ',
               $this->type->print( $state ),
               $this->name,
               ( $this->default ?
                 ( '=', $this->default ) : () ) );
}

sub uses_length {
  return($_[0]->name =~ /^length\([^\)]+\)/);
}

sub implementation_name {
  my $this = shift;
  my $name = $this->name;
  if ($this->uses_length) {
    $name =~ /^length\(([^\)]+)\)/;
    return "XSauto_length_of_$1";
  }
  return $name;
}

sub fix_name_in_code {
  my $this = shift;
  my $code = shift;
  return $code if not $this->uses_length;
  my $name = $this->name;
  my $impl = $this->implementation_name;
  $code =~ s/\b\Q$name\E/$impl/g;
  return $code;
}

=head1 ACCESSORS

=head2 type

Returns the type of the argument.

=head2 name

Returns the variable name of the argument variable.

=head2 default

Returns the default for the function parameter if any.

=head2 has_default

Returns whether there is a default for the function parameter.

=head2 function

Returns a reference to the containing function/method.

=head2 index

Returns the 0-based index of the argument in the argument list.

=cut

sub type { $_[0]->{TYPE} }
sub name { $_[0]->{NAME} }
sub tags { $_[0]->{TAGS} }

sub default { $_[0]->{DEFAULT} }
sub has_default { defined $_[0]->{DEFAULT} }

sub function { $_[0]->{FUNCTION} }
sub index { $_[0]->{INDEX} }

1;

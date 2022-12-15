package ExtUtils::XSpp::Node::Member;
use strict;
use warnings;
use Carp ();
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Member - Node representing a class member variable

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> sub-class representing a single member
variable in a class such as

  class FooBar {
    int foo; // <-- this one
  }

Member declarations do not produce any XS code unless they are
decorated by either C<%get> or C<%set>.

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Member>.

Named parameters: C<cpp_name> indicating the C++ name of the member,
C<perl_name> indicating the Perl name of the member (defaults to the
same as C<cpp_name>), C<type> indicates the (C++) type of the member
and finally C<class>, which is an L<ExtUtils::XSpp::Node::Class>.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{CPP_NAME}  = $args{cpp_name};
  $this->{PERL_NAME} = $args{perl_name} || $args{cpp_name};
  $this->{TYPE}      = $args{type};
  $this->{CLASS}     = $args{class};
  $this->{CONDITION} = $args{condition};
  $this->{TAGS}      = $args{tags};
  $this->{EMIT_CONDITION} = $args{emit_condition};
}

sub print {
  my( $this, $state ) = @_;
  my $str = '';

  $str .= $this->_getter->print( $state ) if $this->_getter;
  $str .= $this->_setter->print( $state ) if $this->_setter;

  return $str;
}

sub _getter {
  my( $this ) = @_;

  die 'Tried to create getter before adding member to a class'
    unless $this->class;
  return $this->{_getter} if $this->{_getter};

  # TODO use plugin infrastructure
  my $getter;
  for my $tag ( @{$this->tags} ) {
    if( $tag->{any} eq 'get' ) {
      $getter = $tag->{positional}[0] || '';
      last;
    }
  }
  return unless defined $getter;

  my $f = $this->{_getter} =
    ExtUtils::XSpp::Node::Method->new
      ( class          => $this->class,
        cpp_name       => $this->_getter_name( $getter ),
        ret_type       => $this->type,
        call_code      => $this->_getter_code,
        condition      => $this->condition,
        emit_condition => $this->emit_condition,
        const          => 1,
        );
  $f->set_ret_typemap( $this->typemap );
  $f->resolve_typemaps;
  $f->disable_exceptions;

  return $this->{_getter};
}

sub _setter {
  my( $this ) = @_;

  die 'Tried to create getter before adding member to a class'
    unless $this->class;
  return $this->{_setter} if $this->{_setter};

  # TODO use plugin infrastructure
  my $setter;
  for my $tag ( @{$this->tags} ) {
    if( $tag->{any} eq 'set' ) {
      $setter = $tag->{positional}[0] || '';
      last;
    }
  }
  return unless defined $setter;

  my $f = $this->{_setter} =
    ExtUtils::XSpp::Node::Method->new
      ( class          => $this->class,
        cpp_name       => $this->_setter_name( $setter ),
        arguments      => [ ExtUtils::XSpp::Node::Argument->new
                              ( type => $this->type,
                                name => 'value'
                                )
                            ],
        ret_type       => ExtUtils::XSpp::Node::Type->new( base => 'void' ),
        call_code      => $this->_setter_code,
        condition      => $this->condition,
        emit_condition => $this->emit_condition,
        );
  $f->set_arg_typemap( 0, $this->typemap );
  $f->resolve_typemaps;
  $f->disable_exceptions;

  return $this->{_setter};
}

sub _getter_code {
  my( $this ) = @_;

  return [ sprintf 'RETVAL = THIS->%s', $this->cpp_name ];
}

sub _getter_name {
  my( $this, $name ) = @_;

  return $name if $name;
  return $this->class->_getter_name( $this->perl_name );
}

sub _setter_code {
  my( $this ) = @_;

  return [ sprintf 'THIS->%s = value', $this->cpp_name ];
}

sub _setter_name {
  my( $this, $name ) = @_;

  return $name if $name;
  return $this->class->_setter_name( $this->perl_name );
}

=head2 resolve_typemaps

Fetches the L<ExtUtils::XSpp::Typemap> object for the type
from the typemap registry and stores a reference to the object.

=cut

sub resolve_typemaps {
  my $this = shift;

  $this->{TYPEMAPS}{TYPE} ||=
      ExtUtils::XSpp::Typemap::get_typemap_for_type( $this->type );
}

=head1 ACCESSORS

=head2 cpp_name

Returns the C++ name of the member.

=head2 perl_name

Returns the Perl name of the member (defaults to same as C++).

=head2 set_perl_name

Sets the Perl name of the member.

=head2 type

Returns the C++ type for the member.

=head2 class

Returns the class (L<ExtUtils::XSpp::Node::Class>) that the
member belongs to.

=head2 access

Returns C<'public'>, C<'protected'> or C<'private'> depending on
member access declaration.

=cut

sub cpp_name { $_[0]->{CPP_NAME} }
sub set_cpp_name { $_[0]->{CPP_NAME} = $_[1] }
sub perl_name { $_[0]->{PERL_NAME} }
sub set_perl_name { $_[0]->{PERL_NAME} = $_[1] }
sub type { $_[0]->{TYPE} }
sub tags { $_[0]->{TAGS} }
sub class { $_[0]->{CLASS} }
sub access { $_[0]->{ACCESS} }
sub set_access { $_[0]->{ACCESS} = $_[1] }

=head2 typemap

Returns the typemap for member type.

=head2 set_typemap( typemap )

Sets the typemap for member type.

=cut

sub typemap {
  my ($this) = @_;

  die "Typemap not available yet" unless $this->{TYPEMAPS}{TYPE};
  return $this->{TYPEMAPS}{TYPE};
}

sub set_typemap {
  my ($this, $typemap) = @_;

  $this->{TYPEMAPS}{TYPE} = $typemap;
}

1;

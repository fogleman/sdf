package ExtUtils::XSpp::Node::Enum;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Enum - Node representing an enum declaration

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing an C<enum> declaration.
As an example

    enum Bool
    {
        FALSE = 0,
        TRUE
    };

will create an C<ExtUtils::XSpp::Node::Enum> object with C<name>
C<Bool> and two L<ExtUtils::XSpp::Node::EnumValue> values in the
C<arguments> array.

Enumerations do not affect the generated code.

=head1 METHODS

=head2 new

    my $e = ExtUtils::XSpp::Node::Enum->new( name     => 'Bool',
                                             elements => [ ... ],
                                             );

Creates a new C<ExtUtils::XSpp::Node::Enum>.

C<name> gives the name of the enumeration, C<undef> for anonymous
enumerations.  C<elements> should only contain
L<ExtUtils::XSpp::Node::EnumValue> or L<ExtUtils::XSpp::Node::Raw>
objects.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{NAME}      = $args{name};
  $this->{ELEMENTS}  = $args{elements};
  $this->{CONDITION} = $args{condition};
}

sub print {
  my( $this, $state ) = @_;

  # no standard way of emitting an enum
  ''
}

=head1 ACCESSORS

=head2 name

Returns the name of the enumeration, or C<undef> for anonymous
enumerations.

=head2 elements

An array reference containing mostly
L<ExtUtils::XSpp::Node::EnumValue> (it can contain other kinds of
nodes).

=cut

sub name { $_[0]->{NAME} }
sub elements { $_[0]->{ELEMENTS} }

1;

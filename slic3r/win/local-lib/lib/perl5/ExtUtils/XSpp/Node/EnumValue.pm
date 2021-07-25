package ExtUtils::XSpp::Node::EnumValue;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::EnumValue - Node representing an enum element

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing an C<enum> declaration.
As an example

    enum Bool
    {
        FALSE = 0,
        TRUE
    };

Will create two C<ExtUtils::XSpp::Node::EnumValue> objects, the first
with C<name> C<FALSE> and C<value> C<0>, the second with C<name>
C<TRUE> and no value.

Enumerations do not affect the generated code.

=head1 METHODS

=head2 new

    my $e = ExtUtils::XSpp::Node::EnumValue->new( name  => 'FALSE',
                                                  value => '0x1 | 0x4',
                                                  );

Creates a new C<ExtUtils::XSpp::Node::EnumValue>.

C<value> is optional.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{NAME}      = $args{name};
  $this->{VALUE}     = $args{value};
  $this->{CONDITION} = $args{condition};
}

sub print {
  my( $this, $state ) = @_;

  # no standard way of emitting an enum value
  ''
}

=head1 ACCESSORS

=head2 name

Returns the name of the enumeration element.

=head2 value

Returns the initializer of the enumeration element, or C<undef>.

=cut

sub name { $_[0]->{NAME} }
sub value { $_[0]->{VALUE} }

1;

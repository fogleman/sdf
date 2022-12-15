package ExtUtils::XSpp::Node::Access;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Access - Node representing an access specifier

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing an access (or method scope)
specifier such as C<public>, C<protected>, C<private>.

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Access> object.

Named parameters: C<access> must be the name of the access
specifier (see above).

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{ACCESS} = $args{access};
}

=head1 ACCESSORS

=head2 access

Returns the name of the access specifier.

=cut

sub access { $_[0]->{ACCESS} }

1;

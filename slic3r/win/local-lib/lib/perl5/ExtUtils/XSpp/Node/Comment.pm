package ExtUtils::XSpp::Node::Comment;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node::Raw';

=head1 NAME

ExtUtils::XSpp::Node::Comment - Node representing a comment in the source file

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node::Raw> subclass representing a piece of raw data
that should be included in the output verbatim, but with comment markers prefixed.

  // This is a comment!

would become something like

  ## This is a comment!

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Comment>.

Named parameters: C<rows> should be a reference to
an array of source code comment lines.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{ROWS} = $args{rows};
}

sub print {
  my $this = shift;
  my $state = shift;

  return "\n";
}

1;

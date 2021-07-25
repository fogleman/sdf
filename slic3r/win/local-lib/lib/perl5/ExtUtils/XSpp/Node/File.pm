package ExtUtils::XSpp::Node::File;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::File - Directive that sets the name of the output file

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing a directive to change the
name of the output file:

  %file{file/to/write/to.xs}
  
A special case is

  %file{-}
  
which indicates that output should be written to STDOUT.

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::File>.

Named parameters: C<file>, the path to the file
that should be written to (or '-').

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{FILE} = $args{file};
}

=head1 ACCESSORS

=head2 file

Returns the path of the file to write to (or C<-> for STDOUT).

=cut

sub file { $_[0]->{FILE} }
sub print { return '' }

1;

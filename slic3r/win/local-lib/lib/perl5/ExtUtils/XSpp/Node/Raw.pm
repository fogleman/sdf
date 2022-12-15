package ExtUtils::XSpp::Node::Raw;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Raw - Node for data that should be included in XS verbatim

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing code that should be included
in the output XS code verbatim.

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Raw>.

Named parameters: C<rows> should be a reference to
an array of source code lines. A trailing newline
is automatically appended.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{ROWS} = $args{rows};
  $this->{EMIT_CONDITION} = $args{emit_condition};
  push @{$this->{ROWS}}, "\n";
}

=head1 ACCESSORS

=head2 rows

Returns an array reference holding the rows to be output in the final file.

=cut

sub rows { $_[0]->{ROWS} }

sub print {
  my $this  = shift;
  my $state = shift;
  my $out = '';

  $out .= '#if ' . $this->emit_condition . "\n" if $this->emit_condition;
  $out .= join( "\n", @{$this->rows} ) . "\n";
  $out .= '#endif // ' . $this->emit_condition . "\n" if $this->emit_condition;

  return $out;
}

1;

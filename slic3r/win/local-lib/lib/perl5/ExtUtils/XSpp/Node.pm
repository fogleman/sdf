package ExtUtils::XSpp::Node;
use strict;
use warnings;
use Carp ();

=head1 NAME

ExtUtils::XSpp::Node - Base class for elements of the parser output

=head1 DESCRIPTION

ExtUtils::XSpp::Node is a base class for all elements of the
parser's output.

=head1 METHODS

=head2 new

Calls the C<$self->init(@_)> method after construction.
Override C<init()> in subclasses.

=cut

sub new {
  my $class = shift;
  my $this = bless {}, $class;

  $this->init( @_ );

  return $this;
}

=head2 init

Called by the constructor. Every sub-class needs to override this.

=cut

sub init {
  Carp::croak(
    "Programmer was too lazy to implement init() in her Node sub-class"
  );
}

=head2 ExtUtils::XSpp::Node::print

Return a string to be output in the final XS file.
Every sub-class must override this method.

=cut

sub print {
  Carp::croak(
    "Programmer was too lazy to implement print() in her Node sub-class"
  );
}

sub condition { $_[0]->{CONDITION} }

sub condition_expression {
    my $this = shift;

    return $this->emit_condition if $this->emit_condition;
    return 'defined( ' . $this->condition . ' )' if $this->condition;
    return '1';
}

sub emit_condition { $_[0]->{EMIT_CONDITION} }

1;

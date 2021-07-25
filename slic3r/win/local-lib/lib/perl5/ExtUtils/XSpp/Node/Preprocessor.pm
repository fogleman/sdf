package ExtUtils::XSpp::Node::Preprocessor;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node::Raw';

sub init {
  my $this = shift;
  my %args = @_;

  $this->SUPER::init( %args );
  $this->{SYMBOL} = $args{symbol};
}

sub print {
  $_[0]->rows->[0] . "\n" .
    ( $_[0]->symbol ? '#define ' . $_[0]->symbol . "\n\n" : "\n" )
}

sub symbol { $_[0]->{SYMBOL} }

1;

package ExtUtils::XSpp::Node::Package;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Package - Node representing a Perl package

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing a Perl package and
thus acting as a container for methods (cf. sub-class
L<ExtUtils::XSpp::Node::Class>) or functions.

A literal C<ExtUtils::XSpp::Node::Package> would, for example,
be created from:

  %package{Some::Perl::Namespace}

This would be compiled to a new XS line a la

MODULE=$WhateverCurrentModule PACKAGE=Some::Perl::Namespace

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Package>.

Named parameters: C<cpp_name> indicating the C++ class name
(if any), and C<perl_name> indicating the name of the Perl
package. If C<perl_name> is not specified but C<cpp_name> is,
C<perl_name> defaults to C<cpp_name>.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{CPP_NAME} = $args{cpp_name};
  $this->{PERL_NAME} = $args{perl_name} || $args{cpp_name};
}

=head1 ACCESSORS

=head2 cpp_name

Returns the C++ name for the package (will be used for namespaces).

=head2 perl_name

Returns the Perl name for the package.

=head2 set_perl_name

Setter for the Perl package name.

=cut

sub cpp_name { $_[0]->{CPP_NAME} }
sub perl_name { $_[0]->{PERL_NAME} }
sub set_perl_name { $_[0]->{PERL_NAME} = $_[1] }

sub print {
  my $this = shift;
  my $state = shift;
  my $out = '';
  my $pcname = $this->perl_name;

  if( !defined $state->{current_module} ) {
    die "No current module: remember to add a %module{} directive";
  }
  my $cur_module = $state->{current_module}->to_string;

  $out .= <<EOT;

$cur_module PACKAGE=$pcname

EOT

  return $out;
}

1;

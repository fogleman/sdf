package ExtUtils::XSpp::Node::Module;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

=head1 NAME

ExtUtils::XSpp::Node::Module - Node representing an XS++/XS MODULE declaration

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node> subclass representing a module declaration.
For example, this XS++

  %module{Some::Perl::Namespace}

would turn into this XS:

MODULE=Some::Perl::Namespace

See also: L<ExtUtils::XSpp::Node::Package>.

In a nutshell, the module that your XS++/XS code belongs to is
the main Perl package of your wrapper. A single module can (and usually does)
have several packages (respectively C++ classes).

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Module>.

Named parameters: C<module> indicating the name
of the module.

=cut

sub init {
  my $this = shift;
  my %args = @_;

  $this->{MODULE} = $args{module};
}

sub to_string { 'MODULE=' . $_[0]->module }

sub print { return $_[0]->to_string . "\n" }

=head1 ACCESSORS

=head2 module

Returns the name of the module.

=cut

sub module { $_[0]->{MODULE} }

1;

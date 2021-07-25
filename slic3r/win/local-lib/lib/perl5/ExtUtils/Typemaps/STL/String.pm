package ExtUtils::Typemaps::STL::String;

use strict;
use warnings;
use ExtUtils::Typemaps;

our $VERSION = '1.05';

our @ISA = qw(ExtUtils::Typemaps);

=head1 NAME

ExtUtils::Typemaps::STL::String - A set of typemaps for STL std::strings

=head1 SYNOPSIS

  use ExtUtils::Typemaps::STL::String;
  # First, read my own type maps:
  my $private_map = ExtUtils::Typemaps->new(file => 'my.map');
  
  # Then, get the object map set and merge it into my maps
  $private_map->merge(typemap => ExtUtils::Typemaps::STL::String->new);
  
  # Now, write the combined map to an output file
  $private_map->write(file => 'typemap');

=head1 DESCRIPTION

C<ExtUtils::Typemaps::STL::String> is an C<ExtUtils::Typemaps>
subclass that provides a set of mappings for C++ STL strings.
These are:

  TYPEMAP
  std::string   T_STD_STRING
  std::string*  T_STD_STRING_PTR

  INPUT
  T_STD_STRING
      $var = std::string( SvPV_nolen( $arg ), SvCUR( $arg ) );

  T_STD_STRING_PTR
      $var = new std::string( SvPV_nolen( $arg ), SvCUR( $arg ) );

  OUTPUT
  T_STD_STRING
      $arg = newSVpvn( $var.c_str(), $var.length() );

  T_STD_STRING_PTR
      $arg = newSVpvn( $var->c_str(), $var->length() );

=head1 METHODS

These are the overridden methods:

=head2 new

Creates a new C<ExtUtils::Typemaps::STL::String> object.
It acts as any other C<ExtUtils::Typemaps> object, except that
it has the string type maps initialized.

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);
  $self->add_string(string => <<'END_TYPEMAP');
TYPEMAP
std::string   T_STD_STRING
std::string*  T_STD_STRING_PTR

INPUT
T_STD_STRING
    $var = std::string( SvPV_nolen( $arg ), SvCUR( $arg ) );

T_STD_STRING_PTR
    $var = new std::string( SvPV_nolen( $arg ), SvCUR( $arg ) );

OUTPUT
T_STD_STRING
    $arg = newSVpvn( $var.c_str(), $var.length() );

T_STD_STRING_PTR
    $arg = newSVpvn( $var->c_str(), $var->length() );
END_TYPEMAP

  return $self;
}

1;

__END__

=head1 SEE ALSO

L<ExtUtils::Typemaps>, L<ExtUtils::Typemaps::Default>, L<ExtUtils::Typemaps::ObjectMap>

=head1 AUTHOR

Steffen Mueller <smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2010, 2011, 2012, 2013 by Steffen Mueller

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

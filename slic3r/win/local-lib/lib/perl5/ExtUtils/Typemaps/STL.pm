package ExtUtils::Typemaps::STL;

use strict;
use warnings;
use ExtUtils::Typemaps;
use ExtUtils::Typemaps::STL::Vector;
use ExtUtils::Typemaps::STL::String;
use ExtUtils::Typemaps::STL::List;

our $VERSION = '1.05';

our @ISA = qw(ExtUtils::Typemaps);

=head1 NAME

ExtUtils::Typemaps::STL - A set of useful typemaps for STL

=head1 SYNOPSIS

  use ExtUtils::Typemaps::STL;
  # First, read my own type maps:
  my $private_map = ExtUtils::Typemaps->new(file => 'my.map');
  
  # Then, get the STL set and merge it into my maps
  my $map = ExtUtils::Typemaps::STL->new;
  $private_map->merge(typemap => $map);
  
  # Now, write the combined map to an output file
  $private_map->write(file => 'typemap');

=head1 DESCRIPTION

C<ExtUtils::Typemaps::STL> is an C<ExtUtils::Typemaps>
subclass that provides a few of default mappings for Standard Template Library
types. These default mappings are currently defined
as the combination of the mappings provided by the
following typemap classes which are provided in this distribution:

L<ExtUtils::Typemaps::STL::Vector>, L<ExtUtils::Typemaps::STL::String>,
L<ExtUtils::Typemaps::STL::List>

More are to come, patches are welcome.

=head1 METHODS

These are the overridden methods:

=head2 new

Creates a new C<ExtUtils::Typemaps::STL> object.

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);
  $self->merge(typemap => ExtUtils::Typemaps::STL::String->new);
  $self->merge(typemap => ExtUtils::Typemaps::STL::Vector->new);
  $self->merge(typemap => ExtUtils::Typemaps::STL::List->new);

  return $self;
}

1;

__END__

=head1 SEE ALSO

L<ExtUtils::Typemaps>, L<ExtUtils::Typemaps::Default>

L<ExtUtils::Typemaps::STL::String>,
L<ExtUtils::Typemaps::STL::Vector>
L<ExtUtils::Typemaps::STL::List>

=head1 AUTHOR

Steffen Mueller <smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2010, 2011, 2012, 2013 by Steffen Mueller

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

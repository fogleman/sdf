package ExtUtils::Typemaps::Default;

use strict;
use warnings;
use ExtUtils::Typemaps;

our $VERSION = '1.05';

our @ISA = qw(ExtUtils::Typemaps);

require ExtUtils::Typemaps::ObjectMap;
require ExtUtils::Typemaps::Basic;
require ExtUtils::Typemaps::STL;


=head1 NAME

ExtUtils::Typemaps::Default - A set of useful typemaps

=head1 SYNOPSIS

  use ExtUtils::Typemaps::Default;
  # First, read my own type maps:
  my $private_map = ExtUtils::Typemaps->new(file => 'my.map');
  
  # Then, get the default set and merge it into my maps
  my $map = ExtUtils::Typemaps::Default->new;
  $private_map->merge(typemap => $map);
  
  # Now, write the combined map to an output file
  $private_map->write(file => 'typemap');

=head1 DESCRIPTION

C<ExtUtils::Typemaps::Default> is an C<ExtUtils::Typemaps>
subclass that provides a set of default mappings (in addition to what
perl itself provides). These default mappings are currently defined
as the combination of the mappings provided by the
following typemap classes which are provided in this distribution:

L<ExtUtils::Typemaps::ObjectMap>, L<ExtUtils::Typemaps::STL>,
L<ExtUtils::Typemaps::Basic>

=head1 METHODS

These are the overridden methods:

=head2 new

Creates a new C<ExtUtils::Typemaps::Default> object.

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);
  $self->merge(typemap => ExtUtils::Typemaps::Basic->new);
  $self->merge(typemap => ExtUtils::Typemaps::ObjectMap->new);
  $self->merge(typemap => ExtUtils::Typemaps::STL->new);

  return $self;
}

1;

__END__

=head1 SEE ALSO

L<ExtUtils::Typemaps>,
L<ExtUtils::Typemaps::ObjectMap>,
L<ExtUtils::Typemaps::STL>,
L<ExtUtils::Typemaps::Basic>

=head1 AUTHOR

Steffen Mueller <smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2010, 2011, 2012, 2013 by Steffen Mueller

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

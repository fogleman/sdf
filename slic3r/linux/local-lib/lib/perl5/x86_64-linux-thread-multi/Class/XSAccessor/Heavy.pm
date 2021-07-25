package # hide from PAUSE
    Class::XSAccessor::Heavy;

use 5.008;
use strict;
use warnings;
use Carp;

our $VERSION  = '1.19';
our @CARP_NOT = qw(
        Class::XSAccessor
        Class::XSAccessor::Array
);

# TODO Move more duplicated code from XSA and XSA::Array here


sub check_sub_existence {
  my $subname = shift;

  my $sub_package = $subname;
  $sub_package =~ s/([^:]+)$// or die;
  my $bare_subname = $1;
    
  my $sym;
  {
    no strict 'refs';
    $sym = \%{"$sub_package"};
  }
  no warnings;
  local *s = $sym->{$bare_subname};
  my $coderef = *s{CODE};
  if ($coderef) {
    $sub_package =~ s/::$//;
    Carp::croak("Cannot replace existing subroutine '$bare_subname' in package '$sub_package' with an XS implementation. If you wish to force a replacement, add the 'replace => 1' parameter to the arguments of 'use ".(caller())[0]."'.");
  }
}

1;

__END__

=head1 NAME

Class::XSAccessor::Heavy - Guts you don't care about

=head1 SYNOPSIS
  
  use Class::XSAccessor!

=head1 DESCRIPTION

Common guts for Class::XSAccessor and Class::XSAccessor::Array.
No user-serviceable parts inside!

=head1 SEE ALSO

L<Class::XSAccessor>
L<Class::XSAccessor::Array>

=head1 AUTHOR

Steffen Mueller, E<lt>smueller@cpan.orgE<gt>

chocolateboy, E<lt>chocolate@cpan.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2008, 2009, 2010, 2011, 2012, 2013 by Steffen Mueller

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8 or,
at your option, any later version of Perl 5 you may have available.

=cut


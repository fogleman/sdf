#############################################################################
## Name:        build/Wx/Overload/Handle.pm
## Purpose:     builds overload constants
## Author:      Mattia Barbon
## Modified by:
## Created:     17/08/2001
## RCS-ID:      $Id: Handle.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2001-2003, 2005-2006 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Overload::Handle;

use strict;

use Wx::build::Utils qw(read_file write_file);

sub TIEHANDLE {
  my( $class, $file ) = @_;

  return bless { FILE => $file,
                 DATA => '' }, $class;
}

sub PRINT {
  my( $this ) = shift;
  $this->{DATA} .= join '', @_;
}

sub do_write {
  my( $this ) = @_;

  print "Writing '", $this->{FILE}, "'.\n";
  write_file( $this->{FILE}, $this->{DATA} );
}

sub CLOSE {
  my( $this ) = @_;

  eval {
    my $text = read_file( $this->{FILE} );
    if( $text eq $this->{DATA} ) {
      print "'", $this->{FILE}, "' not modified, skipping\n";
    } else {
      $this->do_write
    }
  };
  if( $@ ) {
    $this->do_write;
  };
}

1;

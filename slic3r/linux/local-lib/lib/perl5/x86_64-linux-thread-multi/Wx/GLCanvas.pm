#############################################################################
## Name:        lib/Wx/GLCanvas.pm
## Purpose:     loader for Wx::GLCanvas.pm
## Author:      Mattia Barbon
## Modified by:
## Created:     26/07/2003
## RCS-ID:      $Id: GLCanvas.pm 2489 2008-10-27 19:50:51Z mbarbon $
## Copyright:   (c) 2003, 2005, 2007-2009 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::GLCanvas;

use strict;
use Wx;
use base 'Wx::ScrolledWindow';

require Exporter; *import = \&Exporter::import;
our @EXPORT_OK =
  ( qw(WX_GL_RGBA WX_GL_BUFFER_SIZE WX_GL_LEVEL WX_GL_DOUBLEBUFFER
       WX_GL_STEREO WX_GL_AUX_BUFFERS WX_GL_MIN_RED WX_GL_MIN_GREEN
       WX_GL_MIN_BLUE WX_GL_MIN_ALPHA WX_GL_DEPTH_SIZE WX_GL_STENCIL_SIZE
       WX_GL_MIN_ACCUM_RED WX_GL_MIN_ACCUM_GREEN WX_GL_MIN_ACCUM_BLUE
       WX_GL_MIN_ACCUM_ALPHA) );
our %EXPORT_TAGS =
  ( all        => \@EXPORT_OK,
    everything => \@EXPORT_OK,
    );

$Wx::GLCanvas::VERSION = '0.09';

Wx::load_dll( 'gl' );
Wx::wx_boot( 'Wx::GLCanvas', $Wx::GLCanvas::VERSION );

our $AUTOLOAD;
sub AUTOLOAD {
  ( my $constname = $AUTOLOAD ) =~ s<^.*::>{};
  return if $constname eq 'DESTROY';
  my $val = constant( $constname, 0 );

  if( $! != 0 ) {
# re-add this if need support for autosplitted subroutines
#    $AutoLoader::AUTOLOAD = $AUTOLOAD;
#    goto &AutoLoader::AUTOLOAD;
    Wx::_croak( "Error while autoloading '$AUTOLOAD'" );
  }

  eval "sub $AUTOLOAD() { $val }";
  goto &$AUTOLOAD;
}

1;

__END__

=head1 NAME

Wx::GLCanvas - interface to wxWidgets' OpenGL canvas

=head1 SYNOPSIS

    use OpenGL; # or any other module providing OpenGL API
    use Wx::GLCanvas;

=head1 DESCRIPTION

The documentation for this module is included in the main
wxPerl distribution (wxGLCanvas).

=head1 AUTHOR

Mattia Barbon <mbarbon@cpan.org>

=head1 LICENSE

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# local variables:
# mode: cperl
# end:

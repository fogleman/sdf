#############################################################################
## Name:        ext/pperl/splashfast/SplashFast.pm
## Purpose:     Wx::Perl::SplashFast -> Show a splash before loading Wx.
## Author:      Graciliano M. P.
## Modified by:
## Created:     30/06/2002
## RCS-ID:      $Id: SplashFast.pm 2723 2009-12-25 17:35:15Z mbarbon $
## Copyright:   (c) 2002-2006, 2009 Graciliano M. P.
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

use strict;

package Wx::Perl::SplashFast ;
use vars qw($VERSION) ;

$VERSION = '0.02'; # for wxPerl 0.15+

sub import {
  Wx::Perl::SplashFast::new(@_) if @_ > 1;
}

sub new {
  my $class = shift;

  Wx::Perl::SplashFast::App->new() ;
  Wx::InitAllImageHandlers() ;

  my $dummy;
  my $any = Wx::constant( 'wxBITMAP_TYPE_ANY', 0, $dummy );
  my $spl_c = Wx::constant( 'wxSPLASH_CENTRE_ON_SCREEN', 0, $dummy );
  my $spl_ti = Wx::constant( 'wxSPLASH_TIMEOUT', 0, $dummy );
  my $bitmap = Wx::Bitmap->new( $_[0], $any );

  my $splash = Wx::SplashScreen->new( $bitmap , $spl_c|$spl_ti ,
                                      $_[1] || 1000 , undef , -1 );

  return $splash ;
}

###################
# SPLASHFAST::APP #
###################

# Ghost package for your APP.
use Wx::App;
package Wx::Perl::SplashFast::App ;
use vars qw(@ISA) ;
@ISA = qw(Wx::App) ;

sub OnInit { return 1 }

###############################################################################
## WX BASICS: #################################################################
###############################################################################

use Wx::Mini;

Wx::_start();

#######
# END #
#######

1;

__END__

=head1 NAME

Wx::Perl::SplashFast - Fast splash screen for the Wx module.

=head1 SYNOPSIS

  use Wx::Perl::SplashFast ('/path/to/logo.jpg',3000);
  # timeout in milliseconds

  package myApp ;
  # subclass Wx::App ...

  package myFrame;
  # subclass Wx::Frame ...

  package main;

  my $myApp = myApp->new();
  my $frame = myFrame->new();

  $myApp->MainLoop();


=head1 DESCRIPTION

Using Wx::SplashScreen from Wx::App::OnInit may cause a high delay
before the splash screen is shown on low end machines.

This module works around this limitation; you just need to follow the
example.

=head1 USAGE

Just put the code inside the 'BEGIN {}' of your main app, like:

  sub BEGIN {
    use Wx::Perl::SplashFast ;
    Wx::Perl::SplashFast->new("./logo.jpg",5000);
  }

or load the module before any other:

  use Wx::Perl::SplashFast ("./logo.jpg",5000) ;
  use Wx ;
  ...

=head2 import ( IMG_FILE, SPLASH_TIMEOUT )

=over 10

=item IMG_FILE

Path of the image file to show.

=item SPLASH_TIMEOUT

Timeout of the splash screen in milliseconds.

=back

If you C<use Wx::Perl::SplashFast './logo.jpg', 1000;> this has the same
affetc as.

  BEGIN {
    require Wx::Perl::SplashFast;
    Wx::Perl::SplashFast->new( './logo.jpg', 1000 );
  }

=head2 new ( IMG_FILE , SPLASH_TIMEOUT )

Show the splash screen.

=over 10

=item IMG_FILE

Path of the image file to show.

=item SPLASH_TIMEOUT

Timeout of the splash screen in milliseconds.

=back

=head1 EXAMPLE

  use Wx::Perl::SplashFast ("./logo.jpg",5000) ;
  # Don't forget to put your own image in the same path. Duh

  package myApp ;
  use base 'Wx::App';
  sub OnInit { return(@_[0]) ;}

  package myFrame ;
  use base 'Wx::Frame';
  use Wx qw( wxDEFAULT_FRAME_STYLE );

  sub new {
    my $app = shift ;
    my( $frame ) = $app->SUPER::new( @_[0] , -1, 'wxPerl Test' ,
                                     [0,0] , [400,300] ) ;
    return( $frame ) ;
  }

  package main ;
  use Wx ;

  my $myApp = myApp->new() ;

  print "window\n" ;
  my $win = myFrame->new() ;
  $win->Show(1) ;

  $myApp->SetTopWindow( $win ) ;
  $myApp->MainLoop();

=head1 SEE ALSO

L<Wx>, L<Wx:SplashScreen>

=head1 AUTHOR

Graciliano M. P. <gm@virtuasites.com.br>
Thanks to wxWidgets people and Mattia Barbon for wxPerl! :P

=head1 COPYRIGHT

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

# Local variables: #
# mode: cperl #
# End: #

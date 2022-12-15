#############################################################################
## Name:        lib/Wx/DemoModules/wxGLCanvas.pm
## Purpose:     wxPerl demo helper for Wx::GLCanvas
## Author:      Mattia Barbon
## Modified by:
## Created:     26/07/2003
## RCS-ID:      $Id: wxGLCanvas.pm 2489 2008-10-27 19:50:51Z mbarbon $
## Copyright:   (c) 2000, 2006, 2008 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::DemoModules::wxGLCanvas;

use strict;

use Wx::Event qw(EVT_PAINT EVT_SIZE EVT_ERASE_BACKGROUND EVT_IDLE EVT_TIMER);
# must load OpenGL *before* Wx::GLCanvas
use OpenGL qw(:glconstants :glfunctions);
use base qw(Wx::GLCanvas Class::Accessor::Fast);
use Wx::GLCanvas qw(:all);

__PACKAGE__->mk_accessors( qw(timer x_rot y_rot dirty init) );

sub new {
    my( $class, $parent ) = @_;
    my $self = $class->SUPER::new( $parent );
#     my $self = $class->SUPER::new( $parent, -1, [-1, -1], [-1, -1], 0,
#                                    "GLCanvas",
#                                    [WX_GL_RGBA, WX_GL_DOUBLEBUFFER, 0] );

    my $timer = $self->timer( Wx::Timer->new( $self ) );
    $timer->Start( 50 );

    $self->x_rot( 0 );
    $self->y_rot( 0 );

    EVT_PAINT( $self,
               sub {
                   my $dc = Wx::PaintDC->new( $self );
                   $self->Render( $dc );
               } );
    EVT_SIZE( $self, sub { $self->dirty( 1 ) } );
    EVT_IDLE( $self, sub {
                  return unless $self->dirty;
                  $self->Resize( $self->GetSizeWH );
                  $self->Refresh;
              } );
    EVT_TIMER( $self, -1, sub {
                   my( $self, $e ) = @_;

                   $self->x_rot( $self->x_rot - 1 );
                   $self->y_rot( $self->y_rot + 2 );

                   $self->dirty( 1 );
                   Wx::WakeUpIdle;
               } );

    return $self;
}

sub GetContext {
    my( $self ) = @_;

    if( Wx::wxVERSION >= 2.009 ) {
        return $self->{context} ||= Wx::GLContext->new( $self );
    } else {
        return $self->SUPER::GetContext;
    }
}

sub SetCurrent {
    my( $self, $context ) = @_;

    if( Wx::wxVERSION >= 2.009 ) {
        return $self->SUPER::SetCurrent( $context );
    } else {
        return $self->SUPER::SetCurrent;
    }
}

sub Resize {
    my( $self, $x, $y ) = @_;

    return unless $self->GetContext;
    $self->dirty( 0 );

    $self->SetCurrent( $self->GetContext );
    glViewport( 0, 0, $x, $y );

    glMatrixMode(GL_PROJECTION);
    glLoadIdentity();
    my_gluPerspective( 45, $x/$y, .5, 100 );

    glMatrixMode(GL_MODELVIEW);
}

use Math::Trig;

sub my_gluPerspective {
    my( $fov, $ratio, $near, $far ) = @_;

    my $top = tan(deg2rad($fov)*0.5) * $near;
    my $bottom = -$top;
    my $left = $ratio * $bottom;
    my $right = $ratio * $top;

    glFrustum( $left, $right, $bottom, $top, $near, $far );
}

sub DESTROY {
    my( $self ) = @_;

    $self->timer->Stop;
    $self->timer( undef );
}

sub tags { [ 'windows/glcanvas' => 'wxGLCanvas' ] }

package Wx::DemoModules::wxGLCanvas::Cube;

use strict;

# must load OpenGL *before* Wx::GLCanvas
use OpenGL qw(:glconstants :glfunctions);
use base qw(Wx::DemoModules::wxGLCanvas);

sub cube {
    my( @v ) = ( [ 1, 1, 1 ], [ -1, 1, 1 ],
                 [ -1, -1, 1 ], [ 1, -1, 1 ],
                 [ 1, 1, -1 ], [ -1, 1, -1 ],
                 [ -1, -1, -1 ], [ 1, -1, -1 ] );
    my( @c ) = ( [ 1, 1, 0 ], [ 1, 0, 1 ],
                 [ 0, 1, 1 ], [ 1, 1, 1 ],
                 [ 0, 0, 1 ], [ 0, 1, 0 ],
                 [ 1, 0, 1 ], [ 1, 1, 0 ] );
    my( @s ) = ( [ 0, 1, 2, 3 ], [ 4, 5, 6, 7 ],
                 [ 0, 1, 5, 4 ], [ 2, 3, 7, 6 ],
                 [ 1, 2, 6, 5 ], [ 0, 3, 7, 4 ] );

    for my $i ( 0 .. 5 ) {
        my $s = $s[$i];
        glBegin(GL_QUADS);
        foreach my $j ( @$s ) {
            glColor3f( @{$c[$j]} );
            glVertex3f( @{$v[$j]} );
        }
        glEnd();
    }
}

sub InitGL {
    my $self = shift;

    return if $self->init;
    return unless $self->GetContext;
    $self->init( 1 );

    glDisable( GL_LIGHTING );
    glDepthFunc( GL_LESS );
    glEnable( GL_DEPTH_TEST );
}

sub Render {
    my( $self, $dc ) = @_;

    return unless $self->GetContext;
    $self->SetCurrent( $self->GetContext );
    $self->InitGL;

    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);

    glPushMatrix();
    glTranslatef( 0, 0, -5 );
    glRotatef( $self->x_rot, 1, 0, 0 );
    glRotatef( $self->y_rot, 0, 0, 1 );

    cube();

    glPopMatrix();
    glFlush();

    $self->SwapBuffers();
}

sub add_to_tags { qw(windows/glcanvas) }
sub title { 'Cube' }
sub file { __FILE__ }

package Wx::DemoModules::wxGLCanvas::Light;

use strict;

# must load OpenGL *before* Wx::GLCanvas
use OpenGL qw(:glconstants :glfunctions);
use base qw(Wx::DemoModules::wxGLCanvas);

sub plane_mat {
    glMaterialfv_p( GL_FRONT, GL_AMBIENT_AND_DIFFUSE, 0.2, 0.1, 0.8, 0.5 );
    glMaterialfv_p( GL_FRONT, GL_SPECULAR, 1, 1, 1, 1 );
    glMaterialfv_p( GL_FRONT, GL_SHININESS, 4 );
}

sub plane {
    my( $x, $y, $step ) = ( -2, -2, .5 );

    for my $i ( 0 .. 7 ) {
        $x += $step;
        $y = -2;
        for my $j ( 0 .. 7 ) {
            $y += $step;
            glBegin(GL_QUADS);
                glNormal3f(  0,         1,  0 );
                glVertex3f( $x,         -1, $y );
                glVertex3f( $x,         -1, $y + $step );
                glVertex3f( $x + $step, -1, $y + $step );
                glVertex3f( $x + $step, -1, $y );
            glEnd();
        }
    }
}

sub icosaedron_mat {
    glMaterialfv_p( GL_FRONT, GL_AMBIENT_AND_DIFFUSE, 0.1, 0.4, 0.7, 1 );
    glMaterialfv_p( GL_FRONT, GL_SPECULAR, 1, 0, 0, 1 );
    glMaterialfv_p( GL_FRONT, GL_SHININESS, 5 );
    glMaterialfv_p( GL_FRONT, GL_EMISSION, 0.1, 0.2, 0.7, 0 );
}

sub icosahedron{
    # from the 'light' demo in OpenGL-0.54
    # from OpenGL Programming Guide page 56
    my $x = 0.525731112119133606;
    my $z = 0.850650808352039932;

    my $v=[
	[-$x,   0,  $z],
	[ $x,   0,  $z],
	[-$x,   0, -$z],
	[ $x,   0, -$z],
	[  0,  $z,  $x],
	[  0,  $z, -$x],
	[  0, -$z,  $x],
	[  0, -$z, -$x],
	[ $z,  $x,   0],
	[-$z,  $x,   0],
	[ $z, -$x,   0],
	[-$z, -$x,   0],
       ];
    my $t=[
	[0,4,1],  	[0, 9, 4],
    	[9, 5, 4],    	[4, 5, 8],
    	[4, 8, 1],    	[8, 10, 1],
    	[8, 3, 10],    	[5, 3, 8],
    	[5, 2, 3],    	[2, 7, 3],
    	[7, 10, 3],    	[7, 6, 10],
    	[7, 11, 6],    	[11, 0, 6],
    	[0, 1, 6],    	[6, 1, 10],
    	[9, 0, 11],    	[9, 11, 2],
    	[9, 2, 5],    	[7, 2, 11],
       ];
    for(my $i=0;$i<20;$i++) {
	glBegin(GL_POLYGON);
	    for(my $j=0;$j<3;$j++) {
		glNormal3f( $v->[$t->[$i][$j]][0],
				$v->[$t->[$i][$j]][1],
				$v->[$t->[$i][$j]][2]);
		glVertex3f( $v->[$t->[$i][$j]][0],
				$v->[$t->[$i][$j]][1],
				$v->[$t->[$i][$j]][2]);
	    }
	glEnd();
    }
}

sub InitGL {
    my $self = shift;

    return if $self->init;
    return unless $self->GetContext;
    $self->init( 1 );

    glLightfv_p( GL_LIGHT0, GL_AMBIENT, .5,.5,.5,1 );
    glLightfv_p( GL_LIGHT0, GL_DIFFUSE, .2,.2,.2,1 );
    glLightfv_p( GL_LIGHT0, GL_SPECULAR, 1,.5,.5,1 );
    glLightfv_p( GL_LIGHT0, GL_POSITION, -3, 3, -4, 1);

    glLightfv_p( GL_LIGHT1, GL_SPECULAR, 0, 1, 1, 1 );
    glLightfv_p( GL_LIGHT1, GL_POSITION, 0, 0, -6, 1 );

    glLightfv_p( GL_LIGHT2, GL_SPECULAR, 1, 1, 1, 1 );
    glLightfv_p( GL_LIGHT2, GL_POSITION, 2, -0.5, -4, 1 );

    glEnable( GL_LIGHTING );
    glEnable( GL_LIGHT0 );
    glEnable( GL_LIGHT1 );
    glEnable( GL_LIGHT2 );
    glDepthFunc( GL_LESS );
    glEnable( GL_DEPTH_TEST );
}

sub Render {
    my( $self, $dc ) = @_;

    return unless $self->GetContext;
    $self->SetCurrent( $self->GetContext );

    $self->InitGL;

    glClear( GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT );
    glPushMatrix();
    glTranslatef( 0, 0, -5 );

    plane_mat();
    plane();

    glRotatef( $self->x_rot, 1, 0, 0 );
    glRotatef( $self->y_rot, 0, 0, 1 );

    icosaedron_mat();
    icosahedron();

    glPopMatrix();
    glFlush();

    $self->SwapBuffers();
}

sub add_to_tags { qw(windows/glcanvas) }
sub title { 'Light' }
sub file { __FILE__ }

1;

###################################################################################
# Distribution    Wx::Perl::Packager
# File            packtest.pl
# Description:    simple test for packaging
# File Revision:  $Id: packtest.pl 41 2010-03-13 22:37:13Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################
#!/usr/bin/perl

# PACKAGE AND TEST ME

BEGIN {
    my $checkargs = join('', @ARGV);
    $ENV{WXPERLPACKAGER_DEBUGPRINT_ON} = 1 if $checkargs =~ /debug/i;
    $ENV{WXPERLPACKAGER_DEBUGPRINT_ON} = 1;
}

use threads;
use Wx::Perl::Packager 0.20;
use strict;
use warnings;

print qq(CONSOLE OUTPUT\n);

#############################################################
# App
#############################################################

package Packtest::App;
use Wx qw( :everything );
use base qw( Wx::App );

sub OnInit {
    my $self = shift;
    Wx::InitAllImageHandlers;
    my $mainwindow = Packtest::MainWindow->new();
    $mainwindow->Show(1);
    $self->SetTopWindow($mainwindow);
    return 1;
}

#############################################################
# Main Window
#############################################################

package Packtest::MainWindow;
use Wx qw( :everything );
use Wx::Event qw( EVT_MENU );
use base qw( Wx::Frame );

sub new {
    my $class = shift;
    my $framesize = [500,300];
    my $self = $class->SUPER::new(undef, wxID_ANY, 'Wx Perl Packager Test Script', wxDefaultPosition, $framesize);
    
    #---------------------------------------------------------------
    # Commands
    #---------------------------------------------------------------
    
    my $menubar = Wx::MenuBar->new;
    my $menu = Wx::Menu->new();
    my $menuitem = Wx::MenuItem->new($menu,wxID_ANY, 'E&xit', 'Exit Application');
    $menu->Append($menuitem);
    EVT_MENU($self, $menuitem, sub { shift->OnMenuExit( @_ ); } );
    
    $menubar->Append($menu, '&File');
    
    $self->SetMenuBar($menubar);
    
    #---------------------------------------------------------------
    # Controls
    #---------------------------------------------------------------
    my $mainpanel = Wx::Panel->new($self, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxBORDER_NONE|wxTAB_TRAVERSAL);
    my $notebook = Packtest::Notebook->new($mainpanel, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxBORDER_NONE); 
    
    #---------------------------------------------------------------
    # Layout
    #---------------------------------------------------------------
    my $mainsizer = Wx::BoxSizer->new(wxVERTICAL);
    my $panelsizer = Wx::BoxSizer->new(wxVERTICAL);
    
    $panelsizer->Add($notebook, 1, wxEXPAND|wxALL, 0);
    $mainpanel->SetSizer($panelsizer);
    
    $mainsizer->Add($mainpanel, 1, wxEXPAND|wxALL, 0);
    $self->SetSizer($mainsizer);
    
    #---------------------------------------------------------------
    # Init
    #---------------------------------------------------------------
    my $xpmfile = $self->get_resource('packager.xpm');
    $self->SetIcon( Wx::Icon->new( $xpmfile, wxBITMAP_TYPE_XPM ) ) if -f $xpmfile; 
    $self->Centre;
    return $self;
}

sub OnMenuExit {
    my ($self, $event) = @_;
    $self->Close;
}

sub get_resource {
    my ($self, $resource) = @_;
    return $self->get_resource_path . '/' . $resource;
}

sub get_resource_path {
    # find path to resources
    my $self = shift;
    return $self->{_resourcepath} if exists $self->{_resourcepath};
    foreach ( @INC ) {
        my $path = "$_/Wx/Perl/Packager/packager.xpm";
        if( -f  $path) {
          $path =~ s/packager\.xpm$/\/resource/;
          $self->{_resourcepath} = $path;
          last;
        }
    }
    $self->{_resourcepath} ||= '';
    return $self->{_resourcepath};
}

#############################################################
# Main Notebook
#############################################################

package Packtest::Notebook;
use Wx qw( :everything );
use base qw( Wx::Notebook );

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
    
    #-------------------------------------------------------
    # Panels
    #-------------------------------------------------------
    
    my $stcpanel = Packtest::Panel::STC->new($self);
    $self->AddPage($stcpanel, 'Styled Text');
    
    my $htmlpanel = Packtest::Panel::Html->new($self);
    $self->AddPage($htmlpanel, 'Html Window');
    
    my $listpanel = Packtest::Panel::ListCtrl->new($self);
    $self->AddPage($listpanel, 'List Control');

    return $self;
}

#############################################################
# Panel HTML
#############################################################

package Packtest::Panel::Html;
use Wx qw( :everything );
use base qw( Wx::Panel );
use Wx::Html;

sub new {
    my ($class, $parent) = @_;
    my $self = $class->SUPER::new($parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxBORDER_NONE|wxTAB_TRAVERSAL);
    
    my $htmlwindow = Wx::HtmlWindow->new($self, wxID_ANY);
    
    my $html = q(<!-- If you see this and HTML tags, the HTML load has failed -->
                 <head><body><center>
                 <h1>Wx::HtmlWindow Header 1 Text</h1><br/>
                 <h2>Wx::HtmlWindow Header 2 Text</h2><br/>
                 <h3>Wx::HtmlWindow Header 3 Text</h3><br/>
                 <h4>Wx::HtmlWindow Header 4 Text</h4><br/>
                 </center>
                 
                 </body></head>);
    $htmlwindow->SetPage($html);
    
    my $sizer = Wx::BoxSizer->new(wxVERTICAL);
    $sizer->Add($htmlwindow, 1, wxEXPAND|wxALL, 0);
    $self->SetSizer($sizer);
    return $self;
}

#############################################################
# Panel STC
#############################################################

package Packtest::Panel::STC;
use Wx qw( :everything );
use Wx::STC;
use base qw( Wx::Panel );

sub new {
    my ($class, $parent) = @_;
    my $self = $class->SUPER::new($parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxBORDER_NONE|wxTAB_TRAVERSAL);
    
    my $stcwindow;
    
    $stcwindow = Wx::StyledTextCtrl->new($self, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxBORDER_NONE);
    
    my $font = Wx::Font->new( 10, wxTELETYPE, wxNORMAL, wxNORMAL );
    my $sizer = Wx::BoxSizer->new(wxVERTICAL);
    
    #---------------------------------------
    # STC Code taken directly from Wx::Demo
    #---------------------------------------

    if( $stcwindow ) {

        $stcwindow->SetFont( $font );
        $stcwindow->StyleSetFont( wxSTC_STYLE_DEFAULT, $font );
        $stcwindow->StyleClearAll();
    
        $stcwindow->StyleSetForeground( wxSTC_PL_DEFAULT,      Wx::Colour->new(0x00, 0x00, 0x7f));
        $stcwindow->StyleSetForeground( wxSTC_PL_ERROR,        Wx::Colour->new(0xff, 0x00, 0x00));
        $stcwindow->StyleSetForeground( wxSTC_PL_COMMENTLINE,  Wx::Colour->new(0x00, 0x7f, 0x00)); # line green
        $stcwindow->StyleSetForeground( wxSTC_PL_POD,          Wx::Colour->new(0x7f, 0x7f, 0x7f));
        $stcwindow->StyleSetForeground( wxSTC_PL_NUMBER,       Wx::Colour->new(0x00, 0x7f, 0x7f));
        $stcwindow->StyleSetForeground( wxSTC_PL_WORD,         Wx::Colour->new(0x00, 0x00, 0x7f));
        $stcwindow->StyleSetForeground( wxSTC_PL_STRING,       Wx::Colour->new(0xff, 0x7f, 0x00)); # orange
        $stcwindow->StyleSetForeground( wxSTC_PL_CHARACTER,    Wx::Colour->new(0x7f, 0x00, 0x7f));
        $stcwindow->StyleSetForeground( wxSTC_PL_PUNCTUATION,  Wx::Colour->new(0x00, 0x00, 0x00));
        $stcwindow->StyleSetForeground( wxSTC_PL_PREPROCESSOR, Wx::Colour->new(0x7f, 0x7f, 0x7f));
        $stcwindow->StyleSetForeground( wxSTC_PL_OPERATOR,     Wx::Colour->new(0x00, 0x00, 0x7f)); # dark blue
        $stcwindow->StyleSetForeground( wxSTC_PL_IDENTIFIER,   Wx::Colour->new(0x00, 0x00, 0xff)); # bright blue
        $stcwindow->StyleSetForeground( wxSTC_PL_SCALAR,       Wx::Colour->new(0x7f, 0x00, 0x7f)); # purple
        $stcwindow->StyleSetForeground( wxSTC_PL_ARRAY,        Wx::Colour->new(0x40, 0x80, 0xff)); # light blue
        $stcwindow->StyleSetForeground( wxSTC_PL_HASH,         Wx::Colour->new(0x00, 0x80, 0xff));
        # wxSTC_PL_SYMBOLTABLE (15)
        # missing SCE_PL_VARIABLE_INDEXER (16)  
        $stcwindow->StyleSetForeground( wxSTC_PL_REGEX,        Wx::Colour->new(0xff, 0x00, 0x7f)); # red
        $stcwindow->StyleSetForeground( wxSTC_PL_REGSUBST,     Wx::Colour->new(0x7f, 0x7f, 0x00)); # light olive
        # wxSTC_PL_LONGQUOTE (19)
        # wxSTC_PL_BACKTICKS (20)
        # wxSTC_PL_DATASECTION (21)
        # wxSTC_PL_HERE_DELIM (22)
        $stcwindow->StyleSetForeground( wxSTC_PL_HERE_Q,       Wx::Colour->new(0x7f, 0x00, 0x7f));
        # wxSTC_PL_HERE_QQ (24)
        # wxSTC_PL_HERE_QX (25)
        $stcwindow->StyleSetForeground( wxSTC_PL_STRING_Q,     Wx::Colour->new(0x7f, 0x00, 0x7f));
        $stcwindow->StyleSetForeground( wxSTC_PL_STRING_QQ,    Wx::Colour->new(0xff, 0x7f, 0x00)); # orange
        # wxSTC_PL_STRING_QX  (28)
        # wxSTC_PL_STRING_QR  (29)
        $stcwindow->StyleSetForeground( wxSTC_PL_STRING_QW,         Wx::Colour->new(0x7f, 0x00, 0x7f));
    
        #Set a style 12 bold
        $stcwindow->StyleSetBold(12,  1);
    
        # Apply tag style for selected lexer (blue)
        $stcwindow->StyleSetSpec( wxSTC_H_TAG, "fore:#0000ff" );
    
        $stcwindow->SetLexer( wxSTC_LEX_PERL );
    
        #---------------------------------------
        # Set some Perl
        #---------------------------------------
        my $code = q(TYPE SOMETHING IN HERE TO TEST
rmtree ON EXIT IN PDK FOR MSWIN
IF YOU DON'T INTERACT WITH THE
KEYBOARD, rmtree works anyway

PACKTEST version 0.30

use strict;
use warnings;
# If you are seeing this, styled text worked OK;

our $var = "one";
print qq(Var is $var\n);
        );
    
    

        $stcwindow->SetText($code);
    
    
        $sizer->Add($stcwindow, 1, wxEXPAND|wxALL, 0);
    }# end of if stcwindow
    
    $self->SetSizer($sizer);
    return $self;
}

#############################################################
# Panel ListCtrl
#############################################################

package Packtest::Panel::ListCtrl;
use Wx qw( :everything );
use base qw( Wx::Panel );

sub new {
    my ($class, $parent) = @_;
    my $self = $class->SUPER::new($parent, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxBORDER_NONE|wxTAB_TRAVERSAL);
    
    my $list = Wx::ListCtrl->new($self, wxID_ANY, wxDefaultPosition, wxDefaultSize, wxBORDER_NONE|wxLC_VIRTUAL);
    $list->InsertColumn(0, 'Column One', wxLIST_FORMAT_LEFT, 200);
    $list->InsertColumn(1, 'Column Two', wxLIST_FORMAT_LEFT, 200);
    my $sizer = Wx::BoxSizer->new(wxVERTICAL);
    $sizer->Add($list, 1, wxEXPAND|wxALL, 0);
    $self->SetSizer($sizer);
    return $self;
}


#############################################################
# Load
#############################################################

package main;

my $app = Packtest::App->new;
$app->MainLoop;

1;

__END__




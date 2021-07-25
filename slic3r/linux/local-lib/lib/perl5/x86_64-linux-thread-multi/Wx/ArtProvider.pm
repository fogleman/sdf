#############################################################################
## Name:        lib/Wx/ArtProvider.pm
## Purpose:     Wx::ArtProvider
## Author:      Matthew "Cheetah" Gabeler-Lee
## Modified by:
## Created:     11/01/2005
## RCS-ID:      $Id: ArtProvider.pm 2443 2008-08-13 21:08:46Z mbarbon $
## Copyright:   (c) 2005, 2008 Matthew Gabeler-Lee
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::ArtProvider;

use strict;
use base 'Exporter';

our %EXPORT_TAGS = (
  'artid' => [qw/wxART_ADD_BOOKMARK wxART_DEL_BOOKMARK wxART_HELP_SIDE_PANEL
    wxART_HELP_SETTINGS wxART_HELP_BOOK wxART_HELP_FOLDER wxART_HELP_PAGE
    wxART_GO_BACK wxART_GO_FORWARD wxART_GO_UP wxART_GO_DOWN
    wxART_GO_TO_PARENT wxART_GO_HOME wxART_FILE_OPEN wxART_PRINT wxART_HELP
    wxART_TIP wxART_REPORT_VIEW wxART_LIST_VIEW wxART_NEW_DIR wxART_FOLDER
    wxART_GO_DIR_UP wxART_EXECUTABLE_FILE wxART_NORMAL_FILE wxART_TICK_MARK
    wxART_CROSS_MARK wxART_ERROR wxART_QUESTION wxART_WARNING
    wxART_INFORMATION wxART_MISSING_IMAGE wxART_CDROM wxART_COPY
    wxART_CUT wxART_DELETE wxART_FILE_SAVE wxART_FILE_SAVE_AS
    wxART_FIND wxART_FIND_AND_REPLACE wxART_FLOPPY wxART_FOLDER_OPEN
    wxART_HARDDISK wxART_NEW wxART_PASTE wxART_QUIT wxART_REDO
    wxART_REMOVABLE wxART_UNDO/],
  'clientid' => [qw/wxART_TOOLBAR wxART_MENU wxART_FRAME_ICON
    wxART_CMN_DIALOG wxART_HELP_BROWSER wxART_MESSAGE_BOX wxART_BUTTON
    wxART_LIST wxART_OTHER/],
);
our @EXPORT_OK = (qw(MAKE_CLIENT_ID MAKE_ART_ID), @{$EXPORT_TAGS{artid}},
  @{$EXPORT_TAGS{clientid}});

sub MAKE_CLIENT_ID($) {
  return $_[0] . "_C";
}

sub MAKE_ART_ID($) {
  return $_[0];
}

# generate artid and clientid subs based on export tags
for my $artid (@{$EXPORT_TAGS{artid}}) {
  eval "sub $artid { return MAKE_ART_ID(\"$artid\") }";
  die "ERROR compiling artid $artid: $@" if $@;
}
for my $clientid (@{$EXPORT_TAGS{clientid}}) {
  eval "sub $clientid { return MAKE_CLIENT_ID(\"$clientid\") }";
  die "ERROR compiling clientid $clientid: $@" if $@;
}

no strict;

package Wx::PlArtProvider; @ISA = qw(Wx::ArtProvider);

1;

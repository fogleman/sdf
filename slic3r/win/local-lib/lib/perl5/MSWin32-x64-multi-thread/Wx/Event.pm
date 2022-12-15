#############################################################################
## Name:        lib/Wx/Event.pm
## Purpose:     Wx::*Event classes and EVT_* macros
## Author:      Mattia Barbon
## Modified by:
## Created:     29/10/2000
## RCS-ID:      $Id: Event.pm 2785 2010-02-06 21:31:04Z mdootson $
## Copyright:   (c) 2000-2010 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Event;

use strict;
use vars qw(@ISA @EXPORT_OK);

use Exporter;

@ISA = qw(Exporter);
@EXPORT_OK = qw();

# !parser: sub { $_[0] =~ m/sub (EVT_\w+)/ }
# !package: Wx::Event

#
# ActivateEvent
#

sub EVT_ACTIVATE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_ACTIVATE, $_[1] ) }
sub EVT_ACTIVATE_APP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_ACTIVATE_APP, $_[1] ) }

#
# CommandEvent
#

sub EVT_COMMAND_RANGE($$$$$) { $_[0]->Connect( $_[1], $_[2], $_[3], $_[4] ) }
sub EVT_BUTTON($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_BUTTON_CLICKED, $_[2] ) }
sub EVT_CHECKBOX($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_CHECKBOX_CLICKED, $_[2] ) }
sub EVT_CHOICE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_CHOICE_SELECTED, $_[2] ) }
sub EVT_LISTBOX($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LISTBOX_SELECTED, $_[2] ) }
sub EVT_LISTBOX_DCLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LISTBOX_DOUBLECLICKED, $_[2] ) }
sub EVT_TEXT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TEXT_UPDATED, $_[2] ) }
sub EVT_TEXT_ENTER($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TEXT_ENTER, $_[2] ) }
sub EVT_TEXT_MAXLEN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TEXT_MAXLEN, $_[2] ) }
sub EVT_TEXT_URL($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TEXT_URL, $_[2] ) }
sub EVT_MENU($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_MENU_SELECTED, $_[2] ) }
sub EVT_MENU_RANGE($$$$) { $_[0]->Connect( $_[1], $_[2], &Wx::wxEVT_COMMAND_MENU_SELECTED, $_[3] ) }
sub EVT_SLIDER($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SLIDER_UPDATED, $_[2] ) }
sub EVT_RADIOBOX($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_RADIOBOX_SELECTED, $_[2] ) }
sub EVT_RADIOBUTTON($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_RADIOBUTTON_SELECTED, $_[2] ) }
sub EVT_SCROLLBAR($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SCROLLBAR_UPDATED, $_[2] ) }
sub EVT_COMBOBOX($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_COMBOBOX_SELECTED, $_[2] ) }
sub EVT_TOOL($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TOOL_CLICKED, $_[2] ) }
sub EVT_TOOL_RANGE($$$$) { $_[0]->Connect( $_[1], $_[2], &Wx::wxEVT_COMMAND_TOOL_CLICKED, $_[3] ) }
sub EVT_TOOL_RCLICKED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TOOL_RCLICKED, $_[2] ) }
sub EVT_TOOL_RCLICKED_RANGE($$$$) { $_[0]->Connect( $_[1], $_[2], &Wx::wxEVT_COMMAND_TOOL_RCLICKED, $_[3] ) }
sub EVT_TOOL_ENTER($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TOOL_ENTER, $_[2] ) }
sub EVT_COMMAND_LEFT_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LEFT_CLICK, $_[2] ) }
sub EVT_COMMAND_LEFT_DCLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LEFT_DCLICK, $_[2] ) }
sub EVT_COMMAND_RIGHT_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_RIGHT_CLICK, $_[2] ) }
sub EVT_COMMAND_SET_FOCUS($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SET_FOCUS, $_[2] ) }
sub EVT_COMMAND_KILL_FOCUS($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_KILL_FOCUS, $_[2] ) }
sub EVT_COMMAND_ENTER($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_ENTER, $_[2] ) }
sub EVT_TOGGLEBUTTON($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TOGGLEBUTTON_CLICKED, $_[2] ) }
sub EVT_CHECKLISTBOX($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_CHECKLISTBOX_TOGGLED, $_[2] ) }
sub EVT_TEXT_CUT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TEXT_CUT, $_[2] ) }
sub EVT_TEXT_COPY($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TEXT_COPY, $_[2] ) }
sub EVT_TEXT_PASTE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TEXT_PASTE, $_[2] ) }

#
# CloseEvent
#

sub EVT_CLOSE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_CLOSE_WINDOW, $_[1] ) }
sub EVT_END_SESSION($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_END_SESSION, $_[1] ) }
sub EVT_QUERY_END_SESSION($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_QUERY_END_SESSION, $_[1] ) }

#
# DropFilesEvent
#

sub EVT_DROP_FILES($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_DROP_FILES, $_[1] ) }

#
# EraseEvent
#

sub EVT_ERASE_BACKGROUND($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_ERASE_BACKGROUND, $_[1] ) }

#
# FindDialogEvent
#

sub EVT_FIND($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_FIND, $_[2] ) }
sub EVT_FIND_NEXT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_FIND_NEXT, $_[2] ) }
sub EVT_FIND_REPLACE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_FIND_REPLACE, $_[2] ) }
sub EVT_FIND_REPLACE_ALL($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_FIND_REPLACE_ALL, $_[2] ) }
sub EVT_FIND_CLOSE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_FIND_CLOSE, $_[2] ) }

#
# FocusEvent
#

sub EVT_SET_FOCUS($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SET_FOCUS, $_[1] ) }
sub EVT_KILL_FOCUS($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_KILL_FOCUS, $_[1] ) }

#
# KeyEvent
#

sub EVT_CHAR($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_CHAR, $_[1] ) }
sub EVT_CHAR_HOOK($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_CHAR_HOOK, $_[1] ) }
sub EVT_KEY_DOWN($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_KEY_DOWN, $_[1] ) }
sub EVT_KEY_UP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_KEY_UP, $_[1] ) }

#
# HelpEvent
#

sub EVT_HELP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_HELP, $_[2] ) }
sub EVT_HELP_RANGE($$$$) { $_[0]->Connect( $_[1], $_[2], &Wx::wxEVT_HELP, $_[3] ) }
sub EVT_DETAILED_HELP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_DETAILED_HELP, $_[2] ) }
sub EVT_DETAILED_HELP_RANGE($$$$) { $_[0]->Connect( $_[1], $_[2], &Wx::wxEVT_DETAILED_HELP, $_[3] ) }

#
# IdleEvent
#

sub EVT_IDLE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_IDLE, $_[1] ) }

#
# InitDialogEvent
#

sub EVT_INIT_DIALOG($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_INIT_DIALOG, $_[1] ) }

#
# JoystickEvent
#

sub EVT_JOY_BUTTON_DOWN($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_JOY_BUTTON_DOWN, $_[1] ) }
sub EVT_JOY_BUTTON_UP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_JOY_BUTTON_UP, $_[1] ) }
sub EVT_JOY_MOVE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_JOY_MOVE, $_[1] ) }
sub EVT_JOY_ZMOVE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_JOY_ZMOVE, $_[1] ) }

#
# ListbookEvent
#

sub EVT_LISTBOOK_PAGE_CHANGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LISTBOOK_PAGE_CHANGING, $_[2] ) }
sub EVT_LISTBOOK_PAGE_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LISTBOOK_PAGE_CHANGED, $_[2] ) }

#
# ChoicebookEvent
#

sub EVT_CHOICEBOOK_PAGE_CHANGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_CHOICEBOOK_PAGE_CHANGING, $_[2] ) }
sub EVT_CHOICEBOOK_PAGE_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_CHOICEBOOK_PAGE_CHANGED, $_[2] ) }

#
# ToolbookEvent
#

sub EVT_TOOLBOOK_PAGE_CHANGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TOOLBOOK_PAGE_CHANGING, $_[2] ) }
sub EVT_TOOLBOOK_PAGE_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TOOLBOOK_PAGE_CHANGED, $_[2] ) }

#
# TreebookEvent
#

sub EVT_TREEBOOK_PAGE_CHANGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREEBOOK_PAGE_CHANGING, $_[2] ) }
sub EVT_TREEBOOK_PAGE_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREEBOOK_PAGE_CHANGED, $_[2] ) }
sub EVT_TREEBOOK_NODE_COLLAPSED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREEBOOK_NODE_COLLAPSED, $_[2] ) }
sub EVT_TREEBOOK_NODE_EXPANDED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREEBOOK_NODE_EXPANDED, $_[2] ) }

#
# ListEvent
#

sub EVT_LIST_BEGIN_DRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_BEGIN_DRAG, $_[2] ) }
sub EVT_LIST_BEGIN_RDRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_BEGIN_RDRAG, $_[2] ) }
sub EVT_LIST_BEGIN_LABEL_EDIT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_BEGIN_LABEL_EDIT, $_[2] ) }
sub EVT_LIST_CACHE_HINT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_CACHE_HINT, $_[2] ) }
sub EVT_LIST_END_LABEL_EDIT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_END_LABEL_EDIT, $_[2] ) }
sub EVT_LIST_DELETE_ITEM($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_DELETE_ITEM, $_[2] ) }
sub EVT_LIST_DELETE_ALL_ITEMS($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_DELETE_ALL_ITEMS, $_[2] ) }
sub EVT_LIST_GET_INFO($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_GET_INFO, $_[2] ) }
sub EVT_LIST_SET_INFO($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_SET_INFO, $_[2] ) }
sub EVT_LIST_ITEM_SELECTED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_ITEM_SELECTED, $_[2] ) }
sub EVT_LIST_ITEM_DESELECTED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_ITEM_DESELECTED, $_[2] ) }
sub EVT_LIST_KEY_DOWN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_KEY_DOWN, $_[2] ) }
sub EVT_LIST_INSERT_ITEM($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_INSERT_ITEM, $_[2] ) }
sub EVT_LIST_COL_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_COL_CLICK, $_[2] ) }
sub EVT_LIST_RIGHT_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_RIGHT_CLICK, $_[2] ) }
sub EVT_LIST_MIDDLE_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_MIDDLE_CLICK, $_[2] ) }
sub EVT_LIST_ITEM_ACTIVATED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_ITEM_ACTIVATED, $_[2] ) }
sub EVT_LIST_COL_RIGHT_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_COL_RIGHT_CLICK, $_[2] ) }
sub EVT_LIST_COL_BEGIN_DRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_COL_BEGIN_DRAG, $_[2] ) }
sub EVT_LIST_COL_DRAGGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_COL_DRAGGING, $_[2] ) }
sub EVT_LIST_COL_END_DRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_COL_END_DRAG, $_[2] ) }
sub EVT_LIST_ITEM_FOCUSED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_ITEM_FOCUSED, $_[2] ) }
sub EVT_LIST_ITEM_RIGHT_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_LIST_ITEM_RIGHT_CLICK, $_[2] ) }

#
# MenuEvent
#

sub EVT_MENU_CHAR($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MENU_CHAR, $_[1] ) }
sub EVT_MENU_INIT($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MENU_INIT, $_[1] ) }
sub EVT_MENU_HIGHLIGHT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_MENU_HIGHLIGHT, $_[2] ) }
sub EVT_POPUP_MENU($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_POPUP_MENU, $_[1] ) }
sub EVT_CONTEXT_MENU($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_CONTEXT_MENU, $_[1] ) }
sub EVT_MENU_OPEN($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MENU_OPEN, $_[1] ) }
sub EVT_MENU_CLOSE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MENU_CLOSE, $_[1] ) }

#
# MouseEvent
#

sub EVT_MOTION($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MOTION, $_[1] ) }
sub EVT_ENTER_WINDOW($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_ENTER_WINDOW, $_[1] ) }
sub EVT_LEAVE_WINDOW($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_LEAVE_WINDOW, $_[1] ) }
sub EVT_MOUSEWHEEL($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MOUSEWHEEL, $_[1] ) }
sub EVT_MOUSE_EVENTS($$) {
  my( $x, $y ) = @_;
  EVT_LEFT_DOWN( $x, $y );
  EVT_LEFT_UP( $x, $y );
  EVT_LEFT_DCLICK( $x, $y );
  EVT_MIDDLE_DOWN( $x, $y );
  EVT_MIDDLE_UP( $x, $y );
  EVT_MIDDLE_DCLICK( $x, $y );
  EVT_RIGHT_DOWN( $x, $y );
  EVT_RIGHT_UP( $x, $y );
  EVT_RIGHT_DCLICK( $x, $y );
  EVT_AUX1_DOWN( $x, $y );
  EVT_AUX1_UP( $x, $y );
  EVT_AUX1_DCLICK( $x, $y );
  EVT_AUX2_DOWN( $x, $y );
  EVT_AUX2_UP( $x, $y );
  EVT_AUX2_DCLICK( $x, $y );
  EVT_MOTION( $x, $y );
  EVT_ENTER_WINDOW( $x, $y );
  EVT_LEAVE_WINDOW( $x, $y );
  EVT_MOUSEWHEEL( $x, $y );
}

#
# MoveEvent
#

sub EVT_MOVE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MOVE, $_[1] ) }
sub EVT_MOVING($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_MOVING, $_[1] ) }

#
# NotebookEvent
#

sub EVT_NOTEBOOK_PAGE_CHANGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_NOTEBOOK_PAGE_CHANGING, $_[2] ) }
sub EVT_NOTEBOOK_PAGE_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_NOTEBOOK_PAGE_CHANGED, $_[2] ) }

#
# PaintEvent
#

sub EVT_PAINT($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_PAINT, $_[1] ) }

#
# ProcessEvent
#

sub EVT_END_PROCESS($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_END_PROCESS, $_[2] ) }

#
# SashEvent
#

sub EVT_SASH_DRAGGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SASH_DRAGGED, $_[2] ) }
sub EVT_SASH_DRAGGED_RANGE($$$$) { $_[0]->Connect( $_[1], $_[2], &Wx::wxEVT_SASH_DRAGGED, $_[3] ) }

#
# SizeEvent
#

sub EVT_SIZE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SIZE, $_[1] ) }
sub EVT_SIZING($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SIZING, $_[1] ) }

#
# ScrollEvent
#

sub EVT_SCROLL_TOP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_TOP, $_[1] ) }
sub EVT_SCROLL_BOTTOM($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_BOTTOM, $_[1] ) }
sub EVT_SCROLL_LINEUP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_LINEUP, $_[1] ) }
sub EVT_SCROLL_LINEDOWN($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_LINEDOWN, $_[1] ) }
sub EVT_SCROLL_PAGEUP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_PAGEUP, $_[1] ) }
sub EVT_SCROLL_PAGEDOWN($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_PAGEDOWN, $_[1] ) }
sub EVT_SCROLL_THUMBTRACK($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_THUMBTRACK, $_[1] ) }
sub EVT_SCROLL_THUMBRELEASE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLL_THUMBRELEASE, $_[1] ) }

sub EVT_SCROLL($$) {
  my( $x, $y ) = @_;
  EVT_SCROLL_TOP( $x, $y );
  EVT_SCROLL_BOTTOM( $x, $y );
  EVT_SCROLL_LINEUP( $x, $y );
  EVT_SCROLL_LINEDOWN( $x, $y );
  EVT_SCROLL_PAGEUP( $x, $y );
  EVT_SCROLL_PAGEDOWN( $x, $y );
  EVT_SCROLL_THUMBTRACK( $x, $y );
  EVT_SCROLL_THUMBRELEASE( $x, $y );
}

sub EVT_COMMAND_SCROLL_TOP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_TOP, $_[2] ) }
sub EVT_COMMAND_SCROLL_BOTTOM($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_BOTTOM, $_[2] ) }
sub EVT_COMMAND_SCROLL_LINEUP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_LINEUP, $_[2] ) }
sub EVT_COMMAND_SCROLL_LINEDOWN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_LINEDOWN, $_[2] ) }
sub EVT_COMMAND_SCROLL_PAGEUP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_PAGEUP, $_[2] ) }
sub EVT_COMMAND_SCROLL_PAGEDOWN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_PAGEDOWN, $_[2] ) }
sub EVT_COMMAND_SCROLL_THUMBTRACK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_THUMBTRACK, $_[2] ) }
sub EVT_COMMAND_SCROLL_THUMBRELEASE($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_THUMBRELEASE, $_[2] ) }

sub EVT_COMMAND_SCROLL($$$) {
  my( $x, $y, $z ) = @_;
  EVT_COMMAND_SCROLL_TOP( $x, $y, $z );
  EVT_COMMAND_SCROLL_BOTTOM( $x, $y, $z );
  EVT_COMMAND_SCROLL_LINEUP( $x, $y, $z );
  EVT_COMMAND_SCROLL_LINEDOWN( $x, $y, $z );
  EVT_COMMAND_SCROLL_PAGEUP( $x, $y, $z );
  EVT_COMMAND_SCROLL_PAGEDOWN( $x, $y, $z );
  EVT_COMMAND_SCROLL_THUMBTRACK( $x, $y, $z );
  EVT_COMMAND_SCROLL_THUMBRELEASE( $x, $y, $z );
}

#
# ScrollWinEvent
#

sub EVT_SCROLLWIN_TOP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_TOP, $_[1] ) }
sub EVT_SCROLLWIN_BOTTOM($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_BOTTOM, $_[1] ) }
sub EVT_SCROLLWIN_LINEUP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_LINEUP, $_[1] ) }
sub EVT_SCROLLWIN_LINEDOWN($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_LINEDOWN, $_[1] ) }
sub EVT_SCROLLWIN_PAGEUP($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_PAGEUP, $_[1] ) }
sub EVT_SCROLLWIN_PAGEDOWN($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_PAGEDOWN, $_[1] ) }
sub EVT_SCROLLWIN_THUMBTRACK($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_THUMBTRACK, $_[1] ) }
sub EVT_SCROLLWIN_THUMBRELEASE($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SCROLLWIN_THUMBRELEASE, $_[1] ) }

sub EVT_SCROLLWIN {
  my( $x, $y ) = @_;
  EVT_SCROLLWIN_TOP( $x, $y );
  EVT_SCROLLWIN_BOTTOM( $x, $y );
  EVT_SCROLLWIN_LINEUP( $x, $y );
  EVT_SCROLLWIN_LINEDOWN( $x, $y );
  EVT_SCROLLWIN_PAGEUP( $x, $y );
  EVT_SCROLLWIN_PAGEDOWN( $x, $y );
  EVT_SCROLLWIN_THUMBTRACK( $x, $y );
  EVT_SCROLLWIN_THUMBRELEASE( $x, $y );
}

#
# SpinEvent
#

sub EVT_SPIN_UP($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_LINEUP, $_[2] ) }
sub EVT_SPIN_DOWN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_LINEDOWN, $_[2] ) }
sub EVT_SPIN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_SCROLL_THUMBTRACK, $_[2] ) }
sub EVT_SPINCTRL($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SPINCTRL_UPDATED, $_[2] ) }

#
# SplitterEvent
#

sub EVT_SPLITTER_SASH_POS_CHANGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SPLITTER_SASH_POS_CHANGING, $_[2] ) }
sub EVT_SPLITTER_SASH_POS_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SPLITTER_SASH_POS_CHANGED, $_[2] ) }
sub EVT_SPLITTER_UNSPLIT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SPLITTER_UNSPLIT, $_[2] ) }
sub EVT_SPLITTER_DOUBLECLICKED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SPLITTER_DOUBLECLICKED, $_[2] ) }
sub EVT_SPLITTER_DCLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_SPLITTER_DOUBLECLICKED, $_[2] ) }

#
# SysColourChangedEvent
#

sub EVT_SYS_COLOUR_CHANGED($$) { $_[0]->Connect( -1, -1, &Wx::wxEVT_SYS_COLOUR_CHANGED, $_[1] ) }

#
# TreeEvent
#

sub EVT_TREE_BEGIN_DRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_BEGIN_DRAG, $_[2] ) }
sub EVT_TREE_BEGIN_RDRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_BEGIN_RDRAG, $_[2] ) }
sub EVT_TREE_END_DRAG($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_END_DRAG, $_[2] ) }
sub EVT_TREE_BEGIN_LABEL_EDIT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_BEGIN_LABEL_EDIT, $_[2] ) }
sub EVT_TREE_END_LABEL_EDIT($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_END_LABEL_EDIT, $_[2] ) }
sub EVT_TREE_GET_INFO($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_GET_INFO, $_[2] ) }
sub EVT_TREE_SET_INFO($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_SET_INFO, $_[2] ) }
sub EVT_TREE_ITEM_EXPANDED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_EXPANDED, $_[2] ) }
sub EVT_TREE_ITEM_EXPANDING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_EXPANDING, $_[2] ) }
sub EVT_TREE_ITEM_COLLAPSED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_COLLAPSED, $_[2] ) }
sub EVT_TREE_ITEM_COLLAPSING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_COLLAPSING, $_[2] ) }
sub EVT_TREE_SEL_CHANGED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_SEL_CHANGED, $_[2] ) }
sub EVT_TREE_SEL_CHANGING($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_SEL_CHANGING, $_[2] ) }
sub EVT_TREE_KEY_DOWN($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_KEY_DOWN, $_[2] ) }
sub EVT_TREE_DELETE_ITEM($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_DELETE_ITEM, $_[2] ) }
sub EVT_TREE_ITEM_ACTIVATED($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_ACTIVATED, $_[2] ) }
sub EVT_TREE_ITEM_RIGHT_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_RIGHT_CLICK, $_[2] ) }
sub EVT_TREE_ITEM_MIDDLE_CLICK($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_MIDDLE_CLICK, $_[2] ) }
sub EVT_TREE_ITEM_MENU($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_COMMAND_TREE_ITEM_MENU, $_[2] ) }

#
# UpdateUIEvent
#

sub EVT_UPDATE_UI($$$) { $_[0]->Connect( $_[1], -1, &Wx::wxEVT_UPDATE_UI, $_[2] ) }
sub EVT_UPDATE_UI_RANGE($$$$) { $_[0]->Connect( $_[1], $_[2], &Wx::wxEVT_UPDATE_UI, $_[3] ) }

#
# Socket
#

sub EVT_SOCKET($$$) { goto &Wx::Socket::Event::EVT_SOCKET }
sub EVT_SOCKET_ALL($$$) { goto &Wx::Socket::Event::EVT_SOCKET_ALL }
sub EVT_SOCKET_INPUT($$$) { goto &Wx::Socket::Event::EVT_SOCKET_INPUT }
sub EVT_SOCKET_OUTPUT($$$) { goto &Wx::Socket::Event::EVT_SOCKET_OUTPUT }
sub EVT_SOCKET_CONNECTION($$$) { goto &Wx::Socket::Event::EVT_SOCKET_CONNECTION }
sub EVT_SOCKET_LOST($$$) { goto &Wx::Socket::Event::EVT_SOCKET_LOST }

#
# Prototypes
#
sub EVT_CALENDAR($$$);
sub EVT_CALENDAR_SEL_CHANGED($$$);
sub EVT_CALENDAR_DAY($$$);
sub EVT_CALENDAR_MONTH($$$);
sub EVT_CALENDAR_YEAR($$$);
sub EVT_CALENDAR_WEEKDAY_CLICKED($$$);

sub EVT_STC_CHANGE($$$);
sub EVT_STC_STYLENEEDED($$$);
sub EVT_STC_CHARADDED($$$);
sub EVT_STC_SAVEPOINTREACHED($$$);
sub EVT_STC_SAVEPOINTLEFT($$$);
sub EVT_STC_ROMODIFYATTEMPT($$$);
sub EVT_STC_KEY($$$);
sub EVT_STC_DOUBLECLICK($$$);
sub EVT_STC_UPDATEUI($$$);
sub EVT_STC_MODIFIED($$$);
sub EVT_STC_MACRORECORD($$$);
sub EVT_STC_MARGINCLICK($$$);
sub EVT_STC_NEEDSHOWN($$$);
sub EVT_STC_POSCHANGED($$$);
sub EVT_STC_PAINTED($$$);
sub EVT_STC_USERLISTSELECTION($$$);
sub EVT_STC_URIDROPPED($$$);
sub EVT_STC_DWELLSTART($$$);
sub EVT_STC_DWELLEND($$$);
sub EVT_STC_START_DRAG($$$);
sub EVT_STC_DRAG_OVER($$$);
sub EVT_STC_DO_DROP($$$);
sub EVT_STC_ZOOM($$$);
sub EVT_STC_HOTSPOT_CLICK($$$);
sub EVT_STC_HOTSPOT_DCLICK($$$);
sub EVT_STC_CALLTIP_CLICK($$$);

1;

__END__

# local variables:
# mode: cperl
# end:

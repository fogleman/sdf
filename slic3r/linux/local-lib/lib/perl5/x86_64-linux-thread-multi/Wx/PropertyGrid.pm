#############################################################################
## Name:        ext/propgrid/lib/Wx/PropertyGrid.pm
## Purpose:     Wx::PropertyGrid and related classes
## Author:      Mark Dootson
## Created:     01/03/2012
## SVN-ID:      $Id: PropertyGrid.pm 3242 2012-03-23 22:29:59Z mdootson $
## Copyright:   (c) 2012 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################
BEGIN {
    package Wx::PropertyGrid;
    our $__wx_pgrid_present = Wx::_wx_optmod_propgrid();
}

package Wx::PropertyGrid;
use strict;

our $VERSION = '0.01';

our $__wx_pgrid_present;

if( $__wx_pgrid_present ) {
    Wx::load_dll( 'adv' );
    Wx::load_dll( 'propgrid' );
    Wx::wx_boot( 'Wx::PropertyGrid', $VERSION );
}

# Setup constants
# (cached strings - not constant at all)

package Wx;
sub wxPG_ATTR_UNITS { return ( $Wx::PropertyGrid::__wx_pgrid_present ) ? Wx::PropertyGrid::_get_wxPG_ATTR_UNITS() : undef ; }
sub wxPG_ATTR_HINT { return ( $Wx::PropertyGrid::__wx_pgrid_present ) ? Wx::PropertyGrid::_get_wxPG_ATTR_HINT() : undef ; }
sub wxPG_ATTR_INLINE_HELP { return ( $Wx::PropertyGrid::__wx_pgrid_present ) ? Wx::PropertyGrid::_get_wxPG_ATTR_INLINE_HELP() : undef ; }
sub wxPG_ATTR_DEFAULT_VALUE { return ( $Wx::PropertyGrid::__wx_pgrid_present ) ? Wx::PropertyGrid::_get_wxPG_ATTR_DEFAULT_VALUE() : undef ; }
sub wxPG_ATTR_MIN { return ( $Wx::PropertyGrid::__wx_pgrid_present ) ? Wx::PropertyGrid::_get_wxPG_ATTR_MIN() : undef ; }
sub wxPG_ATTR_MAX { return ( $Wx::PropertyGrid::__wx_pgrid_present ) ? Wx::PropertyGrid::_get_wxPG_ATTR_MAX() : undef ; }
package Wx::PropertyGrid;

# these are all string 'constants', those above
# and those added in Constant.xs
our @_wxpg_extra_exported_constants = qw(
    wxPG_ATTR_UNITS 
    wxPG_ATTR_HINT 
    wxPG_ATTR_INLINE_HELP 
    wxPG_ATTR_DEFAULT_VALUE 
    wxPG_ATTR_MIN 
    wxPG_ATTR_MAX 
    wxPG_ATTR_AUTOCOMPLETE 
    wxPG_BOOL_USE_CHECKBOX 
    wxPG_BOOL_USE_DOUBLE_CLICK_CYCLING 
    wxPG_FLOAT_PRECISION 
    wxPG_STRING_PASSWORD 
    wxPG_UINT_BASE 
    wxPG_UINT_PREFIX 
    wxPG_FILE_WILDCARD 
    wxPG_FILE_SHOW_FULL_PATH 
    wxPG_FILE_SHOW_RELATIVE_PATH 
    wxPG_FILE_INITIAL_PATH 
    wxPG_FILE_DIALOG_TITLE 
    wxPG_DIR_DIALOG_MESSAGE 
    wxPG_ARRAY_DELIMITER 
    wxPG_DATE_FORMAT 
    wxPG_DATE_PICKER_STYLE 
    wxPG_ATTR_SPINCTRL_STEP 
    wxPG_ATTR_SPINCTRL_WRAP 
    wxPG_ATTR_MULTICHOICE_USERSTRINGMODE 
    wxPG_COLOUR_ALLOW_CUSTOM 
    wxPG_COLOUR_HAS_ALPHA 
);

if( $__wx_pgrid_present ) {
    push @{ $Wx::EXPORT_TAGS{'propgrid'} }, @_wxpg_extra_exported_constants;
}

#
# properly setup inheritance tree
#

no strict;

package Wx::PropertyGridIteratorBase;
package Wx::PropertyGridIterator;       @ISA = qw( Wx::PropertyGridIteratorBase );
package Wx::PropertyGridManager;        @ISA = qw( Wx::Panel );
package Wx::PropertyGridPage;           @ISA = qw( Wx::EvtHandler );
package Wx::PropertyGrid;               @ISA = qw( Wx::Control);

package Wx::PGProperty;                 @ISA = qw( Wx::Object );
package Wx::PropertyCategory;           @ISA = qw( Wx::PGProperty );
package Wx::PGCell;                     @ISA = qw( Wx::Object );

package Wx::ObjectRefData;

package Wx::PGCellRenderer;             @ISA = qw( Wx::ObjectRefData );
package Wx::PGDefaultRenderer;          @ISA = qw( Wx::PGCellRenderer );
package Wx::PGChoicesData;              @ISA = qw( Wx::ObjectRefData );
package Wx::PGMultiButton;              @ISA = qw( Wx::Window );

package Wx::PGEditor;                   @ISA = qw( Wx::Object );

package Wx::PGTextCtrlEditor;           @ISA = qw( Wx::PGEditor );
package Wx::PGChoiceEditor;             @ISA = qw( Wx::PGEditor );
package Wx::PGComboBoxEditor;           @ISA = qw( Wx::PGChoiceEditor );
package Wx::PGChoiceAndButtonEditor;    @ISA = qw( Wx::PGChoiceEditor );
package Wx::PGTextCtrlAndButtonEditor;  @ISA = qw( Wx::PGTextCtrlEditor );
package Wx::PGCheckBoxEditor;           @ISA = qw( Wx::PGEditor );
package Wx::PGDatePickerCtrlEditor;     @ISA = qw( Wx::PGEditor );
package Wx::PGSpinCtrlEditor;           @ISA = qw( Wx::PGTextCtrlEditor );

package Wx::PGInDialogValidator;

package Wx::StringProperty;             @ISA = qw( Wx::PGProperty );
package Wx::IntProperty;                @ISA = qw( Wx::PGProperty );
package Wx::UIntProperty;               @ISA = qw( Wx::PGProperty );
package Wx::FloatProperty;              @ISA = qw( Wx::PGProperty );
package Wx::BoolProperty;               @ISA = qw( Wx::PGProperty );
package Wx::EnumProperty;               @ISA = qw( Wx::PGProperty );
package Wx::EditEnumProperty;           @ISA = qw( Wx::EnumProperty );
package Wx::FlagsProperty;              @ISA = qw( Wx::PGProperty );
package Wx::FileProperty;               @ISA = qw( Wx::PGProperty );
package Wx::LongStringProperty;         @ISA = qw( Wx::PGProperty );
package Wx::DirProperty ;               @ISA = qw( Wx::LongStringProperty );
package Wx::ArrayStringProperty;        @ISA = qw( Wx::PGProperty );
package Wx::MultiChoiceProperty;        @ISA = qw( Wx::PGProperty );
package Wx::FontProperty;               @ISA = qw( Wx::PGProperty );
package Wx::SystemColourProperty;       @ISA = qw( Wx::EnumProperty );
package Wx::ColourProperty;             @ISA = qw( Wx::SystemColourProperty );
package Wx::CursorProperty;             @ISA = qw( Wx::EnumProperty );
package Wx::ImageFileProperty;          @ISA = qw( Wx::FileProperty );
package Wx::DateProperty;               @ISA = qw( Wx::PGProperty );

package Wx::PGFileDialogAdapter;        @ISA = qw( Wx::PGEditorDialogAdapter );  
package Wx::PGLongStringDialogAdapter;  @ISA = qw( Wx::PGEditorDialogAdapter ); 
package Wx::PGArrayEditorDialog;        @ISA = qw( Wx::Dialog );    
package Wx::PGArrayStringEditorDialog;  @ISA = qw( Wx::PGArrayEditorDialog );

package Wx::ColourPropertyValue;        @ISA = qw( Wx::Object );

package Wx::ArrayStringProperty;
#FIXME - until we fix XS method
sub GetPlValue {
    my @return = ();
    my $variant = $_[0]->GetValue;
    @return = $variant->GetArrayString if !$variant->IsNull;
    return @return;
}

package Wx::MultiChoiceProperty;
#FIXME - until we fix XS method
sub GetPlValue {
    my @return = ();
    my $variant = $_[0]->GetValue;
    @return = $variant->GetArrayString if !$variant->IsNull;
    return @return;
}

1;

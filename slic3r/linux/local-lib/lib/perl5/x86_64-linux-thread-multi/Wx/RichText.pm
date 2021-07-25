#############################################################################
## Name:        ext/richtext/lib/Wx/RichText.pm
## Purpose:     Wx::RichTextCtrl and related classes
## Author:      Mattia Barbon
## Modified by:
## Created:     05/11/2006
## RCS-ID:      $Id: RichText.pm 3325 2012-08-16 03:41:14Z mdootson $
## Copyright:   (c) 2006-2007, 2010-2011 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::RichText;

use strict;
use Wx::Print;

our $VERSION = '0.01';

Wx::load_dll( 'adv' );
Wx::load_dll( 'html' );
Wx::load_dll( 'xml' );
Wx::load_dll( 'richtext' );
Wx::wx_boot( 'Wx::RichText', $VERSION );

SetEvents();

#
# properly setup inheritance tree
#

no strict;

package Wx::Printout;
package Wx::RichTextCtrl;    @ISA = ( Wx::wxVERSION() <= 2.009001 ? qw(Wx::TextCtrl) : qw(Wx::Control) );
package Wx::TextAttrEx;      @ISA = qw(Wx::TextAttr);
package Wx::RichTextEvent;   @ISA = qw(Wx::NotifyEvent);
package Wx::RichTextStyleDefinition;
package Wx::RichTextCharacterStyleDefinition; @ISA = qw(Wx::RichTextStyleDefinition);
package Wx::RichTextParagraphStyleDefinition; @ISA = qw(Wx::RichTextStyleDefinition);
package Wx::RichTextListStyleDefinition; @ISA = qw(Wx::RichTextParagraphStyleDefinition);
package Wx::RichTextStyleListCtrl; @ISA = qw(Wx::Control);
package Wx::HtmlListBox;     @ISA = qw(Wx::VListBox);
package Wx::RichTextStyleListBox; @ISA = qw(Wx::HtmlListBox);
package Wx::RichTextStyleComboCtrl; @ISA = qw(Wx::ComboCtrl);
package Wx::RichTextFormattingDialog; @ISA = qw(Wx::PropertySheetDialog);
package Wx::RichTextXMLHandler; @ISA = qw(Wx::RichTextFileHandler);
package Wx::RichTextHTMLHandler; @ISA = qw(Wx::RichTextFileHandler);
package Wx::RichTextObject;
package Wx::RichTextCompositeObject; @ISA = qw(Wx::RichTextObject);
package Wx::RichTextBox;     @ISA = ( Wx::wxVERSION() <= 2.009001 ? qw(Wx::RichTextCompositeObject) : qw(Wx::RichTextParagraphLayoutBox) );
package Wx::RichTextParagraphLayoutBox; @ISA = ( Wx::wxVERSION() <= 2.009001 ? qw(Wx::RichTextBox) : qw(Wx::RichTextCompositeObject) );
package Wx::RichTextBuffer;  @ISA = qw(Wx::RichTextParagraphLayoutBox);
package Wx::RichTextPrinting;  @ISA = qw(Wx::Object);
package Wx::RichTextHeaderFooterData;  @ISA = qw(Wx::Object);
package Wx::SymbolPickerDialog; @ISA = qw(Wx::Dialog);
package Wx::RichTextStyleOrganiserDialog; @ISA = qw(Wx::Dialog);

#
# constants
#

package Wx;

# !parser: sub { $_[0] =~ m/^\s*sub\s+(wx\w+)/ }
# !package: Wx
# !tag: richtextctrl

sub wxRichTextLineBreakChar() { chr(29) }

1;

# Local variables: #
# mode: cperl #
# End: #


package Slic3r::GUI::OptionsGroup::Field;
use Moo;

# This is a base class for option fields.

has 'parent'                => (is => 'ro', required => 1);
has 'option'                => (is => 'ro', required => 1);     # Slic3r::GUI::OptionsGroup::Option
has 'on_change'             => (is => 'rw', default => sub { sub {} });
has 'on_kill_focus'         => (is => 'rw', default => sub { sub {} });
has 'disable_change_event'  => (is => 'rw', default => sub { 0 });

# This method should not fire the on_change event
sub set_value {
    my ($self, $value) = @_;
    die "Method not implemented";
}

sub get_value {
    my ($self) = @_;
    die "Method not implemented";
}

sub set_tooltip {
    my ($self, $tooltip) = @_;
    die "Method not implemented";
}

sub toggle {
    my ($self, $enable) = @_;
    $enable ? $self->enable : $self->disable;
}

sub _on_change {
    my ($self, $opt_id) = @_;
    
    $self->on_change->($opt_id, $self->get_value)
        unless $self->disable_change_event;
}

sub _on_kill_focus {
    my ($self, $opt_id, $s, $event) = @_;
    
    # Without this, there will be nasty focus bugs on Windows.
    # Also, docs for wxEvent::Skip() say "In general, it is recommended to skip all 
    # non-command events to allow the default handling to take place."
    $event->Skip(1);
    
    $self->on_kill_focus->($opt_id);
}


package Slic3r::GUI::OptionsGroup::Field::wxWindow;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field';

has 'wxWindow'  => (is => 'rw', trigger => 1);    # wxWindow object

sub _default_size {
    my ($self) = @_;
    
    # default width on Windows is too large
    return Wx::Size->new($self->option->width || 60, $self->option->height || -1);
}

sub _trigger_wxWindow {
    my ($self) = @_;
    
    $self->set_tooltip($self->option->tooltip);
}

sub set_tooltip {
    my ($self, $tooltip) = @_;
    
    $self->wxWindow->SetToolTipString($tooltip)
        if $self->wxWindow->can('SetToolTipString');
}

sub set_value {
    my ($self, $value) = @_;
    
    $self->disable_change_event(1);
    $self->wxWindow->SetValue($value);
    $self->disable_change_event(0);
}

sub get_value {
    my ($self) = @_;
    return $self->wxWindow->GetValue;
}

sub enable {
    my ($self) = @_;
    
    $self->wxWindow->Enable;
    $self->wxWindow->Refresh;
}

sub disable {
    my ($self) = @_;
    
    $self->wxWindow->Disable;
    $self->wxWindow->Refresh;
}


package Slic3r::GUI::OptionsGroup::Field::Checkbox;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxWindow';

use Wx qw(:misc);
use Wx::Event qw(EVT_CHECKBOX);

sub BUILD {
    my ($self) = @_;
    
    my $field = Wx::CheckBox->new($self->parent, -1, "");
    $self->wxWindow($field);
    $field->SetValue($self->option->default);
    $field->Disable if $self->option->readonly;
    
    EVT_CHECKBOX($self->parent, $field, sub {
        $self->_on_change($self->option->opt_id);
    });
}


package Slic3r::GUI::OptionsGroup::Field::SpinCtrl;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxWindow';

use Wx qw(:misc);
use Wx::Event qw(EVT_SPINCTRL EVT_TEXT EVT_KILL_FOCUS);

has 'tmp_value' => (is => 'rw');

sub BUILD {
    my ($self) = @_;
    
    my $field = Wx::SpinCtrl->new($self->parent, -1, $self->option->default, wxDefaultPosition, $self->_default_size,
        0, $self->option->min || 0, $self->option->max || 2147483647, $self->option->default);
    $self->wxWindow($field);
    
    EVT_SPINCTRL($self->parent, $field, sub {
        $self->tmp_value(undef);
        $self->_on_change($self->option->opt_id);
    });
    EVT_TEXT($self->parent, $field, sub {
        my ($s, $event) = @_;
        
        # On OSX/Cocoa, wxSpinCtrl::GetValue() doesn't return the new value
        # when it was changed from the text control, so the on_change callback
        # gets the old one, and on_kill_focus resets the control to the old value.
        # As a workaround, we get the new value from $event->GetString and store
        # here temporarily so that we can return it from $self->get_value
        $self->tmp_value($event->GetString) if $event->GetString =~ /^\d+$/;
        $self->_on_change($self->option->opt_id);
        # We don't reset tmp_value here because _on_change might put callbacks
        # in the CallAfter queue, and we want the tmp value to be available from
        # them as well.
    });
    EVT_KILL_FOCUS($field, sub {
        $self->tmp_value(undef);
        $self->_on_kill_focus($self->option->opt_id, @_);
    });
}

sub get_value {
    my ($self) = @_;
    return $self->tmp_value // $self->wxWindow->GetValue;
}


package Slic3r::GUI::OptionsGroup::Field::TextCtrl;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxWindow';

use Wx qw(:misc :textctrl);
use Wx::Event qw(EVT_TEXT EVT_KILL_FOCUS);

sub BUILD {
    my ($self) = @_;
    
    my $style = 0;
    $style = wxTE_MULTILINE if $self->option->multiline;
    my $field = Wx::TextCtrl->new($self->parent, -1, $self->option->default, wxDefaultPosition,
        $self->_default_size, $style);
    $self->wxWindow($field);
    
    # TODO: test loading a config that has empty string for multi-value options like 'wipe'
    
    EVT_TEXT($self->parent, $field, sub {
        $self->_on_change($self->option->opt_id);
    });
    EVT_KILL_FOCUS($field, sub {
        $self->_on_kill_focus($self->option->opt_id, @_);
    });
}

sub enable {
    my ($self) = @_;
    
    $self->wxWindow->Enable;
    $self->wxWindow->SetEditable(1);
}

sub disable {
    my ($self) = @_;
    
    $self->wxWindow->Disable;
    $self->wxWindow->SetEditable(0);
}


package Slic3r::GUI::OptionsGroup::Field::Choice;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxWindow';

use List::Util qw(first);
use Wx qw(:misc :combobox);
use Wx::Event qw(EVT_COMBOBOX EVT_TEXT);

sub BUILD {
    my ($self) = @_;
    
    my $style = 0;
    $style |= wxCB_READONLY if defined $self->option->gui_type && $self->option->gui_type ne 'select_open';
    my $field = Wx::ComboBox->new($self->parent, -1, "", wxDefaultPosition, $self->_default_size,
        $self->option->labels || $self->option->values || [], $style);
    $self->wxWindow($field);
    
    $self->set_value($self->option->default);
    
    EVT_COMBOBOX($self->parent, $field, sub {
        $self->_on_change($self->option->opt_id);
    });
    EVT_TEXT($self->parent, $field, sub {
        $self->_on_change($self->option->opt_id);
    });
}

sub set_value {
    my ($self, $value) = @_;
    
    $self->disable_change_event(1);
    
    my $idx;
    if ($self->option->values) {
        $idx = first { $self->option->values->[$_] eq $value } 0..$#{$self->option->values};
        # if value is not among indexes values we use SetValue()
    }
    
    if (defined $idx) {
        $self->wxWindow->SetSelection($idx);
    } else {
        $self->wxWindow->SetValue($value);
    }
    
    $self->disable_change_event(0);
}

sub set_values {
    my ($self, $values) = @_;
    
    $self->disable_change_event(1);
    
    # it looks that Clear() also clears the text field in recent wxWidgets versions,
    # but we want to preserve it
    my $ww = $self->wxWindow;
    my $value = $ww->GetValue;
    $ww->Clear;
    $ww->Append($_) for @$values;
    $ww->SetValue($value);
    
    $self->disable_change_event(0);
}

sub get_value {
    my ($self) = @_;
    
    if ($self->option->values) {
        my $idx = $self->wxWindow->GetSelection;
        if ($idx != &Wx::wxNOT_FOUND) {
            return $self->option->values->[$idx];
        }
    }
    return $self->wxWindow->GetValue;
}

package Slic3r::GUI::OptionsGroup::Field::NumericChoice;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxWindow';

use List::Util qw(first);
use Wx qw(wxTheApp :misc :combobox);
use Wx::Event qw(EVT_COMBOBOX EVT_TEXT);

# if option has no 'values', indices are values
# if option has no 'labels', values are labels

sub BUILD {
    my ($self) = @_;
    
    my $field = Wx::ComboBox->new($self->parent, -1, $self->option->default, wxDefaultPosition, $self->_default_size,
        $self->option->labels || $self->option->values);
    $self->wxWindow($field);
    
    $self->set_value($self->option->default);
    
    EVT_COMBOBOX($self->parent, $field, sub {
        my $disable_change_event = $self->disable_change_event;
        $self->disable_change_event(1);
        
        my $idx = $field->GetSelection;  # get index of selected value
        my $label;
        
        if ($self->option->labels && $idx <= $#{$self->option->labels}) {
            $label = $self->option->labels->[$idx];
        } elsif ($self->option->values && $idx <= $#{$self->option->values}) {
            $label = $self->option->values->[$idx];
        } else {
            $label = $idx;
        }
        
        # The MSW implementation of wxComboBox will leave the field blank if we call
        # SetValue() in the EVT_COMBOBOX event handler, so we postpone the call.
        wxTheApp->CallAfter(sub {
            my $dce = $self->disable_change_event;
            $self->disable_change_event(1);
            
            # ChangeValue() is not exported in wxPerl
            $field->SetValue($label);
            
            $self->disable_change_event($dce);
        });
        
        $self->disable_change_event($disable_change_event);
        $self->_on_change($self->option->opt_id);
    });
    EVT_TEXT($self->parent, $field, sub {
        $self->_on_change($self->option->opt_id);
    });
}

sub set_value {
    my ($self, $value) = @_;
    
    $self->disable_change_event(1);
    
    my $field = $self->wxWindow;
    if ($self->option->gui_flags =~ /\bshow_value\b/) {
        $field->SetValue($value);
    } else {
        if ($self->option->values) {
            # check whether we have a value index
            my $value_idx = first { $self->option->values->[$_] eq $value } 0..$#{$self->option->values};
            if (defined $value_idx) {
                $field->SetSelection($value_idx);
                $self->disable_change_event(0);
                return;
            }
        } elsif ($self->option->labels && $value <= $#{$self->option->labels}) {
            # if we have no values, we expect value to be an index
            $field->SetValue($self->option->labels->[$value]);
            $self->disable_change_event(0);
            return;
        }
        $field->SetValue($value);
    }
    
    $self->disable_change_event(0);
}

sub get_value {
    my ($self) = @_;
    
    my $label = $self->wxWindow->GetValue;
    if ($self->option->labels) {
        my $value_idx = first { $self->option->labels->[$_] eq $label } 0..$#{$self->option->labels};
        if (defined $value_idx) {
            if ($self->option->values) {
                return $self->option->values->[$value_idx];
            }
            return $value_idx;
        }
    }
    return $label;
}


package Slic3r::GUI::OptionsGroup::Field::ColourPicker;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxWindow';

use Wx qw(:misc :colour);
use Wx::Event qw(EVT_COLOURPICKER_CHANGED);

sub BUILD {
    my ($self) = @_;
    
    my $field = Wx::ColourPickerCtrl->new($self->parent, -1, 
        $self->_string_to_colour($self->option->default), wxDefaultPosition, 
        $self->_default_size);
    $self->wxWindow($field);
    
    EVT_COLOURPICKER_CHANGED($self->parent, $field, sub {
        $self->_on_change($self->option->opt_id);
    });
}

sub set_value {
    my ($self, $value) = @_;
    
    $self->disable_change_event(1);
    $self->wxWindow->SetColour($self->_string_to_colour($value));
    $self->disable_change_event(0);
}

sub get_value {
    my ($self) = @_;
    return $self->wxWindow->GetColour->GetAsString(wxC2S_HTML_SYNTAX);
}

sub _string_to_colour {
    my ($self, $string) = @_;
    
    $string =~ s/^#//;
    return Wx::Colour->new(unpack 'C*', pack 'H*', $string);
}


package Slic3r::GUI::OptionsGroup::Field::wxSizer;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field';

has 'wxSizer'  => (is => 'rw');    # wxSizer object


package Slic3r::GUI::OptionsGroup::Field::Point;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxSizer';

has 'x_textctrl' => (is => 'rw');
has 'y_textctrl' => (is => 'rw');

use Slic3r::Geometry qw(X Y);
use Wx qw(:misc :sizer);
use Wx::Event qw(EVT_TEXT);

sub BUILD {
    my ($self) = @_;
    
    my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->wxSizer($sizer);
    
    my $field_size = Wx::Size->new(40, -1);
    
    $self->x_textctrl(Wx::TextCtrl->new($self->parent, -1, $self->option->default->[X], wxDefaultPosition, $field_size));
    $self->y_textctrl(Wx::TextCtrl->new($self->parent, -1, $self->option->default->[Y], wxDefaultPosition, $field_size));
    
    my @items = (
        Wx::StaticText->new($self->parent, -1, "x:"),
        $self->x_textctrl,
        Wx::StaticText->new($self->parent, -1, "  y:"),
        $self->y_textctrl,
    );
    $sizer->Add($_, 0, wxALIGN_CENTER_VERTICAL, 0) for @items;
    
    if ($self->option->tooltip) {
        foreach my $item (@items) {
            $item->SetToolTipString($self->option->tooltip)
                if $item->can('SetToolTipString');
        }
    }
    
    EVT_TEXT($self->parent, $_, sub {
        $self->_on_change($self->option->opt_id);
    }) for $self->x_textctrl, $self->y_textctrl;
}

sub set_value {
    my ($self, $value) = @_;
    
    $self->disable_change_event(1);
    $self->x_textctrl->SetValue($value->[X]);
    $self->y_textctrl->SetValue($value->[Y]);
    $self->disable_change_event(0);
}

sub get_value {
    my ($self) = @_;
    
    return [
        $self->x_textctrl->GetValue,
        $self->y_textctrl->GetValue,
    ];
}

sub enable {
    my ($self) = @_;
    
    $self->x_textctrl->Enable;
    $self->y_textctrl->Enable;
}

sub disable {
    my ($self) = @_;
    
    $self->x_textctrl->Disable;
    $self->y_textctrl->Disable;
}

package Slic3r::GUI::OptionsGroup::Field::Point3;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxSizer';

has 'x_textctrl' => (is => 'rw');
has 'y_textctrl' => (is => 'rw');
has 'z_textctrl' => (is => 'rw');

use Slic3r::Geometry qw(X Y Z);
use Wx qw(:misc :sizer);
use Wx::Event qw(EVT_TEXT);

sub BUILD {
    my ($self) = @_;
    
    my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->wxSizer($sizer);
    
    my $field_size = Wx::Size->new(40, -1);
    
    $self->x_textctrl(Wx::TextCtrl->new($self->parent, -1, $self->option->default->[X], wxDefaultPosition, $field_size));
    $self->y_textctrl(Wx::TextCtrl->new($self->parent, -1, $self->option->default->[Y], wxDefaultPosition, $field_size));
    $self->z_textctrl(Wx::TextCtrl->new($self->parent, -1, $self->option->default->[Z], wxDefaultPosition, $field_size));
    
    my @items = (
        Wx::StaticText->new($self->parent, -1, "x:"),
        $self->x_textctrl,
        Wx::StaticText->new($self->parent, -1, "  y:"),
        $self->y_textctrl,
        Wx::StaticText->new($self->parent, -1, "  z:"),
        $self->z_textctrl,
    );
    $sizer->Add($_, 0, wxALIGN_CENTER_VERTICAL, 0) for @items;
    
    if ($self->option->tooltip) {
        foreach my $item (@items) {
            $item->SetToolTipString($self->option->tooltip)
                if $item->can('SetToolTipString');
        }
    }
    
    EVT_TEXT($self->parent, $_, sub {
        $self->_on_change($self->option->opt_id);
    }) for $self->x_textctrl, $self->y_textctrl, $self->z_textctrl;
}

sub set_value {
    my ($self, $value) = @_;
    
    $self->disable_change_event(1);
    $self->x_textctrl->SetValue($value->[X]);
    $self->y_textctrl->SetValue($value->[Y]);
    $self->z_textctrl->SetValue($value->[Z]);
    $self->disable_change_event(0);
}

sub get_value {
    my ($self) = @_;
    
    return [
        $self->x_textctrl->GetValue,
        $self->y_textctrl->GetValue,
        $self->z_textctrl->GetValue,
    ];
}

sub enable {
    my ($self) = @_;
    
    $self->x_textctrl->Enable;
    $self->y_textctrl->Enable;
    $self->z_textctrl->Enable;
}

sub disable {
    my ($self) = @_;
    
    $self->x_textctrl->Disable;
    $self->y_textctrl->Disable;
    $self->z_textctrl->Disable;
}

package Slic3r::GUI::OptionsGroup::Field::Slider;
use Moo;
extends 'Slic3r::GUI::OptionsGroup::Field::wxSizer';

has 'scale'         => (is => 'rw', default => sub { 10 });
has 'slider'        => (is => 'rw');
has 'textctrl'      => (is => 'rw');

use Slic3r::Geometry qw(X Y);
use Wx qw(:misc :sizer);
use Wx::Event qw(EVT_SLIDER EVT_TEXT EVT_KILL_FOCUS);

sub BUILD {
    my ($self) = @_;
    
    my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $self->wxSizer($sizer);
    
    my $slider = Wx::Slider->new(
        $self->parent, -1,
        ($self->option->default // $self->option->min) * $self->scale,
        ($self->option->min // 0) * $self->scale,
        ($self->option->max // 100) * $self->scale,
        wxDefaultPosition,
        [ $self->option->width // -1, $self->option->height // -1 ],
    );
    $self->slider($slider);
    
    my $textctrl = Wx::TextCtrl->new($self->parent, -1, $slider->GetValue/$self->scale,
        wxDefaultPosition, [50,-1]);
    $self->textctrl($textctrl);
    
    $sizer->Add($slider, 1, wxALIGN_CENTER_VERTICAL, 0);
    $sizer->Add($textctrl, 0, wxALIGN_CENTER_VERTICAL, 0);
    
    EVT_SLIDER($self->parent, $slider, sub {
        $self->_update_textctrl;
        $self->_on_change($self->option->opt_id);
    });
    EVT_TEXT($self->parent, $textctrl, sub {
        my $value = $textctrl->GetValue;
        if ($value =~ /^-?\d+(\.\d*)?$/) {
            # Update the slider without re-updating the text field being modified.
            $self->disable_change_event(1);
            $self->slider->SetValue($value*$self->scale);
            $self->disable_change_event(0);
            
            $self->_on_change($self->option->opt_id);
        }
    });
    EVT_KILL_FOCUS($textctrl, sub {
        $self->_update_textctrl;
        $self->_on_kill_focus($self->option->opt_id, @_);
    });
}

sub set_value {
    my ($self, $value) = @_;
    
    $self->disable_change_event(1);
    $self->slider->SetValue($value*$self->scale);
    $self->_update_textctrl;
    $self->disable_change_event(0);
}

sub get_value {
    my ($self) = @_;
    return $self->slider->GetValue/$self->scale;
}

# Update internal scaling
sub set_scale {
    my ($self, $scale) = @_;
    $self->disable_change_event(1);
    my $current_value = $self->get_value;
    $self->slider->SetRange($self->slider->GetMin / $self->scale * $scale, $self->slider->GetMax / $self->scale * $scale);
    $self->scale($scale);
    $self->set_value($current_value);
    $self->disable_change_event(0);
}

sub _update_textctrl {
    my ($self) = @_;
    
    $self->textctrl->ChangeValue($self->get_value);
    $self->textctrl->SetInsertionPointEnd;
}

sub enable {
    my ($self) = @_;
    
    $self->slider->Enable;
    $self->textctrl->Enable;
    $self->textctrl->SetEditable(1);
}

sub disable {
    my ($self) = @_;
    
    $self->slider->Disable;
    $self->textctrl->Disable;
    $self->textctrl->SetEditable(0);
}

sub set_range {
    my ($self, $min, $max) = @_;
    
    $self->slider->SetRange($min * $self->scale, $max * $self->scale);
}

1;

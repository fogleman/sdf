# Generate an anonymous or "lambda" 3D object. This gets used with the Create Modifier option in Settings.
# 

package Slic3r::GUI::Plater::LambdaObjectDialog;
use strict;
use warnings;
use utf8;

use Slic3r::Geometry qw(PI X);
use Wx qw(wxTheApp :dialog :id :misc :sizer wxTAB_TRAVERSAL wxCB_READONLY wxTE_PROCESS_TAB);
use Wx::Event qw(EVT_CLOSE EVT_BUTTON EVT_COMBOBOX EVT_TEXT);
use Scalar::Util qw(looks_like_number);
use base 'Wx::Dialog';

sub new {
    my $class = shift;
    my ($parent, %params) = @_;
    my $self = $class->SUPER::new($parent, -1, "Create Modifier", wxDefaultPosition, [500,500],
        wxDEFAULT_DIALOG_STYLE | wxRESIZE_BORDER);
    
    # Note whether the window was already closed, so a pending update is not executed.
    $self->{already_closed} = 0;
    $self->{object_parameters} = { 
        type    => 'slab', 
        dim     => [1, 1, 1],
        cyl_r   => 1,
        cyl_h   => 1,
        sph_rho => 1.0,
        slab_h  => 1.0,
    };

    $self->{sizer}  = Wx::BoxSizer->new(wxVERTICAL);
    my $buttons     = $self->CreateStdDialogButtonSizer(wxOK | wxCANCEL);
    EVT_BUTTON($self, wxID_OK, sub {
        $self->EndModal(wxID_OK);
        $self->Destroy;
    });
    EVT_BUTTON($self, wxID_CANCEL, sub {
        $self->EndModal(wxID_CANCEL);
        $self->Destroy;
    });
    
    $self->{type} = Wx::ComboBox->new($self, 1, $self->{object_parameters}{type},
        wxDefaultPosition, wxDefaultSize,
        [qw(slab box cylinder sphere)], wxCB_READONLY);
    
    my $optgroup_box;
    $optgroup_box = $self->{optgroup_box} = Slic3r::GUI::OptionsGroup->new(
        parent      => $self,
        title       => 'Add Cube...',
        on_change   => sub {
            # Do validation
            my ($opt_id) = @_;
            if ($opt_id == 0 || $opt_id == 1 || $opt_id == 2) {
                if (!looks_like_number($optgroup_box->get_value($opt_id))) {
                    return 0;
                }
            }
            $self->{object_parameters}->{dim}[$opt_id] = $optgroup_box->get_value($opt_id);
        },
        label_width => 100,
    );

    $optgroup_box->append_single_option_line(Slic3r::GUI::OptionsGroup::Option->new(
        opt_id  =>  0,
        label   =>  'L (x)',
        type    =>  'f',
        default =>  $self->{object_parameters}{dim}[0],
        sidetext => 'mm',
    ));
    $optgroup_box->append_single_option_line(Slic3r::GUI::OptionsGroup::Option->new(
        opt_id  =>  1,
        label   =>  'W (y)',
        type    =>  'f',
        default =>  $self->{object_parameters}{dim}[1],
        sidetext => 'mm',
    ));
    $optgroup_box->append_single_option_line(Slic3r::GUI::OptionsGroup::Option->new(
        opt_id  =>  2,
        label   =>  'H (z)',
        type    =>  'f',
        default =>  $self->{object_parameters}{dim}[2],
        sidetext => 'mm',
    ));

    my $optgroup_cylinder;
    $optgroup_cylinder = $self->{optgroup_cylinder} = Slic3r::GUI::OptionsGroup->new(
        parent      => $self,
        title       => 'Add Cylinder...',
        on_change   => sub {
            # Do validation
            my ($opt_id) = @_;
            if ($opt_id eq 'cyl_r' || $opt_id eq 'cyl_h') {
                if (!looks_like_number($optgroup_cylinder->get_value($opt_id))) {
                    return 0;
                }
            }
            $self->{object_parameters}->{$opt_id} = $optgroup_cylinder->get_value($opt_id);
        },
        label_width => 100,
    );

    $optgroup_cylinder->append_single_option_line(Slic3r::GUI::OptionsGroup::Option->new(
        opt_id  =>  "cyl_r",
        label   =>  'Radius',
        type    =>  'f',
        default =>  $self->{object_parameters}{cyl_r},
        sidetext => 'mm',
    ));
    $optgroup_cylinder->append_single_option_line(Slic3r::GUI::OptionsGroup::Option->new(
        opt_id  =>  "cyl_h",
        label   =>  'Height',
        type    =>  'f',
        default =>  $self->{object_parameters}{cyl_h},
        sidetext => 'mm',
    ));

    my $optgroup_sphere;
    $optgroup_sphere = $self->{optgroup_sphere} = Slic3r::GUI::OptionsGroup->new(
        parent      => $self,
        title       => 'Add Sphere...',
        on_change   => sub {
            # Do validation
            my ($opt_id) = @_;
            if ($opt_id eq 'sph_rho') {
                if (!looks_like_number($optgroup_sphere->get_value($opt_id))) {
                    return 0;
                }
            }
            $self->{object_parameters}->{$opt_id} = $optgroup_sphere->get_value($opt_id);
        },
        label_width => 100,
    );

    $optgroup_sphere->append_single_option_line(Slic3r::GUI::OptionsGroup::Option->new(
        opt_id  =>  "sph_rho",
        label   =>  'Radius',
        type    =>  'f',
        default =>  $self->{object_parameters}{sph_rho},
        sidetext => 'mm',
    ));

    my $optgroup_slab;
    $optgroup_slab = $self->{optgroup_slab} = Slic3r::GUI::OptionsGroup->new(
        parent      => $self,
        title       => 'Add Slab...',
        on_change   => sub {
            # Do validation
            my ($opt_id) = @_;
            if ($opt_id eq 'slab_h') {
                if (!looks_like_number($optgroup_slab->get_value($opt_id))) {
                    return 0;
                }
            }
            $self->{object_parameters}->{$opt_id} = $optgroup_slab->get_value($opt_id);
        },
        label_width => 100,
    );
    $optgroup_slab->append_single_option_line(Slic3r::GUI::OptionsGroup::Option->new(
        opt_id  =>  "slab_h",
        label   =>  'Thickness',
        type    =>  'f',
        default =>  $self->{object_parameters}{slab_h},
        sidetext => 'mm',
    ));


    EVT_COMBOBOX($self, 1, sub{ 
        $self->{object_parameters}->{type} = $self->{type}->GetValue();
        $self->_update_ui;
    });


    $self->{sizer}->Add($self->{type}, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    $self->{sizer}->Add($optgroup_box->sizer, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    $self->{sizer}->Add($optgroup_cylinder->sizer, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    $self->{sizer}->Add($optgroup_sphere->sizer, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    $self->{sizer}->Add($optgroup_slab->sizer, 0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    $self->{sizer}->Add($buttons,0, wxEXPAND | wxBOTTOM | wxLEFT | wxRIGHT, 10);
    $self->_update_ui;

    $self->SetSizer($self->{sizer});
    $self->{sizer}->Fit($self);
    $self->{sizer}->SetSizeHints($self);

    
    return $self;
}

sub ObjectParameter {
    my ($self) = @_;
    return $self->{object_parameters};
}

sub _update_ui {
    my ($self) = @_;
    $self->{sizer}->Hide($self->{optgroup_cylinder}->sizer);
    $self->{sizer}->Hide($self->{optgroup_slab}->sizer);
    $self->{sizer}->Hide($self->{optgroup_box}->sizer);
    $self->{sizer}->Hide($self->{optgroup_sphere}->sizer);
    if ($self->{type}->GetValue eq "box") {
        $self->{sizer}->Show($self->{optgroup_box}->sizer);
    } elsif ($self->{type}->GetValue eq "cylinder") {
        $self->{sizer}->Show($self->{optgroup_cylinder}->sizer);
    } elsif ($self->{type}->GetValue eq "slab") {
        $self->{sizer}->Show($self->{optgroup_slab}->sizer);
    } elsif ($self->{type}->GetValue eq "sphere") {
        $self->{sizer}->Show($self->{optgroup_sphere}->sizer);
    }
    $self->{sizer}->Fit($self);
    $self->{sizer}->SetSizeHints($self);
    
}
1;

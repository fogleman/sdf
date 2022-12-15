package Slic3r::GUI::Plater::3DPreview;
use strict;
use warnings;
use utf8;

use Slic3r::Print::State ':steps';
use Wx qw(:misc :sizer :slider :statictext);
use Wx::Event qw(EVT_SLIDER EVT_KEY_DOWN);
use base qw(Wx::Panel Class::Accessor);

__PACKAGE__->mk_accessors(qw(print enabled _loaded canvas slider));

sub new {
    my $class = shift;
    my ($parent, $print) = @_;
    
    my $self = $class->SUPER::new($parent, -1, wxDefaultPosition);
    
    # init GUI elements
    my $canvas = Slic3r::GUI::3DScene->new($self);
    $self->canvas($canvas);
    my $slider = Wx::Slider->new(
        $self, -1,
        0,                              # default
        0,                              # min
        # we set max to a bogus non-zero value because the MSW implementation of wxSlider
        # will skip drawing the slider if max <= min:
        1,                              # max
        wxDefaultPosition,
        wxDefaultSize,
        wxVERTICAL | wxSL_INVERSE,
    );
    $self->slider($slider);
    
    my $z_label = $self->{z_label} = Wx::StaticText->new($self, -1, "", wxDefaultPosition,
        [40,-1], wxALIGN_CENTRE_HORIZONTAL);
    $z_label->SetFont($Slic3r::GUI::small_font);
    
    my $vsizer = Wx::BoxSizer->new(wxVERTICAL);
    $vsizer->Add($slider, 1, wxALL | wxEXPAND | wxALIGN_CENTER, 3);
    $vsizer->Add($z_label, 0, wxALL | wxEXPAND | wxALIGN_CENTER, 3);
    
    my $sizer = Wx::BoxSizer->new(wxHORIZONTAL);
    $sizer->Add($canvas, 1, wxALL | wxEXPAND, 0);
    $sizer->Add($vsizer, 0, wxTOP | wxBOTTOM | wxEXPAND, 5);
    
    EVT_SLIDER($self, $slider, sub {
        $self->set_z($self->{layers_z}[$slider->GetValue])
            if $self->enabled;
    });
    EVT_KEY_DOWN($canvas, sub {
        my ($s, $event) = @_;
        
        my $key = $event->GetKeyCode;
        if ($key == 85 || $key == 315) {
            $slider->SetValue($slider->GetValue + 1);
            $self->set_z($self->{layers_z}[$slider->GetValue]);
        } elsif ($key == 68 || $key == 317) {
            $slider->SetValue($slider->GetValue - 1);
            $self->set_z($self->{layers_z}[$slider->GetValue]);
        } else {
            $event->Skip;
        }
    });
    
    $self->SetSizer($sizer);
    $self->SetMinSize($self->GetSize);
    $sizer->SetSizeHints($self);
    
    # init canvas
    $self->print($print);
    $self->reload_print;
    
    return $self;
}

sub reload_print {
    my ($self, $obj_idx) = @_;
    
    $self->canvas->reset_objects;
    $self->_loaded(0);
    $self->load_print($obj_idx);
}

sub load_print {
    my ($self, $obj_idx) = @_;
    
    return if $self->_loaded;
    
    # we require that there's at least one object and the posSlice step
    # is performed on all of them (this ensures that _shifted_copies was
    # populated and we know the number of layers)
    if (!$self->print->object_step_done(STEP_SLICE)) {
        $self->enabled(0);
        $self->slider->Hide;
        $self->canvas->Refresh;  # clears canvas
        return;
    }
    
    my $z_idx;
    {
        my %z = ();  # z => 1
        if(defined $obj_idx) { # Load only given object
            foreach my $layer (@{$self->{print}->get_object($obj_idx)->layers}) {
                $z{$layer->print_z} = 1;
            }
        }else{ # Load all objects on the plater + support material
            foreach my $object (@{$self->{print}->objects}) {
                foreach my $layer (@{$object->layers}, @{$object->support_layers}) {
                    $z{$layer->print_z} = 1;
                }
            }
        }
        $self->enabled(1);
        $self->{layers_z} = [ sort { $a <=> $b } keys %z ];
        $self->slider->SetRange(0, scalar(@{$self->{layers_z}})-1);
        if (($z_idx = $self->slider->GetValue) <= $#{$self->{layers_z}} && $self->slider->GetValue != 0) {
            # use $z_idx
        } else {
            $self->slider->SetValue(scalar(@{$self->{layers_z}})-1);
            $z_idx = @{$self->{layers_z}} ? -1 : undef;
        }
        $self->slider->Show;
        $self->Layout;
    }
    
    if ($self->IsShown) {
        # set colors
        $self->canvas->color_toolpaths_by($Slic3r::GUI::Settings->{_}{color_toolpaths_by});
        if ($self->canvas->color_toolpaths_by eq 'extruder') {
            my @filament_colors = map { s/^#//; [ map $_/255, (unpack 'C*', pack 'H*', $_), 255 ] }
                @{$self->print->config->filament_colour};
            $self->canvas->colors->[$_] = $filament_colors[$_] for 0..$#filament_colors;
        } else {
            $self->canvas->colors([ $self->canvas->default_colors ]);
        }
        
        if(defined $obj_idx) { # Load only one object
            $self->canvas->load_print_object_toolpaths($self->{print}->get_object($obj_idx));
        }else{ # load all objects
	        # load skirt and brim
            $self->canvas->load_print_toolpaths($self->print);
            
            foreach my $object (@{$self->print->objects}) {
                $self->canvas->load_print_object_toolpaths($object);

                #my @volume_ids = $self->canvas->load_object($object->model_object);
                #$self->canvas->volumes->[$_]->color->[3] = 0.2 for @volume_ids;
            }
        }
        $self->_loaded(1);
    }
    
    $self->set_z($self->{layers_z}[$z_idx]);
}

sub set_z {
    my ($self, $z) = @_;
    
    return if !$self->enabled;
    $self->{z_label}->SetLabel(sprintf '%.2f', $z);
    $self->canvas->set_toolpaths_range(0, $z);
    $self->canvas->Refresh if $self->IsShown;
}

sub set_bed_shape {
    my ($self, $bed_shape) = @_;
    $self->canvas->set_bed_shape($bed_shape);
}

1;

#############################################################################
## Name:        ext/pperl/textval/TextValidator.pm
## Purpose:     Wx::Perl::TextValidator, a perl-ish wxTextValidator
## Author:      Johan Vromans, Mattia Barbon
## Modified by:
## Created:     15/08/2005
## RCS-ID:      $Id: TextValidator.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2005 Johan Vromans, Mattia Barbon
## Licence:     This program is free software; you can redistribute itand/or
##              modify it under the same terms as Perl itself
#############################################################################

package Wx::Perl::TextValidator;

=head1 NAME

Wx::Perl::TextValidator - Perl replacement for wxTextValidator

=head1 SYNOPSIS

    my $storage = '';
    my $validator1 = Wx::Perl::TextValidator->new( '\d', \$storage );
    my $validator2 = Wx::Perl::TextValidator->new( '[abcdef]' );
    my $validator3 = Wx::Perl::TextValidator->new( qr/[a-zA-Z]/ );

    my $textctrl = Wx::TextCtrl->new( $parent, -1, "", $pos, $size, $style,
                                      $validator1 );

=head1 DESCRIPTION

A C<Wx::Validator> subclass that allows filtering user input to
a C<Wx::TextCtrl>.

=head1 METHODS

    my $validator1 = Wx::Perl::TextValidator->new( $regexp, \$storage );
    my $validator2 = Wx::Perl::TextValidator->new( $regexp );

Constructs a new C<Wx::Perl::Validator>. The first argument must be
a regular expression matching a single-character string and is used
to validate the field contents and user input. The second argument,
if present, is used in TransferDataToWindow/TransferDataToWindow as
the source/destination for the fields contents.

  The first argument can be a string as well as a reqular expression
object created using C<qr//>.

=cut

use strict;
use Wx qw(:keycode wxOK wxICON_EXCLAMATION);
use Wx::Event qw(EVT_CHAR);
use Wx::Locale qw(:default);

use base qw(Wx::PlValidator);

our $VERSION = '0.01';

sub new {
    my( $class, $validate, $data ) = @_;
    my $self = $class->SUPER::new;

    $self->{validate} = ref $validate ? $validate : qr/^$validate$/;
    $self->{data} = $data;

    EVT_CHAR($self, \&OnKbdInput);

    return $self;
}

sub OnKbdInput {
    my ($self, $event) = @_;
    my $c = $event->GetKeyCode;

    if( $c  < WXK_SPACE   ||   # skip control characters
        $c == WXK_DELETE  ||
        $c  > WXK_START   ||
        $event->HasModifiers   # allow Ctrl-C and such
       ) {
        $event->Skip;
    } elsif( pack( "C", $c ) =~ $self->{validate} ) {
        $event->Skip;
    } else {
        Wx::Bell;
    }
}

sub Clone {
    my( $self ) = @_;

    return ref( $self )->new( $self->{validate}, $self->{data} );
}

sub Validate {
    my( $self, $window ) = @_;
    my $value = $self->GetWindow->GetValue;

    my $ko = grep { !/$self->{validate}/ }
                  split //, $value;

    if( $ko ) {
        Wx::MessageBox( sprintf( gettext( "'%s' is invalid" ), $value ),
                        gettext( "Validation conflict" ),
                        wxOK | wxICON_EXCLAMATION, $window );
    }

    return !$ko;
}

sub TransferToWindow {
    my( $self ) = @_;

    if( $self->{data} ) {
        $self->GetWindow->SetValue( ${$self->{data}} );
    }

    return 1;
}

sub TransferFromWindow {
    my( $self ) = @_;

    if( $self->{data} ) {
        ${$self->{data}} = $self->GetWindow->GetValue;
    }

    return 1;
}

1;

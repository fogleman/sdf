package Parse::Binary::FixedFormat::Variants;

use strict;
our $VERSION = "0.03";

sub new {
    my ($class,$recfmt) = @_;
    my $self;
    $self = { Layouts=>[], Chooser=>$recfmt->{Chooser}, Formats => $recfmt->{Formats} };
    bless $self, $class;
    foreach my $fmt (@{$recfmt->{Formats}}) {
	push @{$self->{Layouts}},new Parse::Binary::FixedFormat $fmt;
    }
    return $self;
}

sub unformat {
    my ($self,$frec) = @_;
    my $rec = $self->{Layouts}[0]->unformat($frec);
    if ($self->{Chooser}) {
	my $w = &{$self->{Chooser}}($rec, $self, 'unformat');
	$rec = $self->{Layouts}[$w]->unformat($frec) if $w;
    }
    return $rec;
}

sub format {
    my ($self,$rec) = @_;
    my $w = 0;
    if ($self->{Chooser}) {
	$w = &{$self->{Chooser}}($rec, $self, 'format');
    }
    my $frec = $self->{Layouts}[$w]->format($rec);
    return $frec;
}

sub blank {
    my ($self,$w) = @_;
    $w = 0 unless $w;
    my $rec = $self->{Layouts}[$w]->blank();
    return $rec;
}

1;

=head1 NAME

Parse::Binary::FixedFormat::Variants - Convert between variant records and hashes

=head1 DESCRIPTION

B<Parse::Binary::FixedFormat> supports variant record formats.  To describe a
variant structure, pass a hash reference containing the following
elements to B<new>.  The object returned to handle variant records
will be a B<Parse::Binary::FixedFormat::Variants>.

=over 4

=item Chooser

When converting a buffer to a hash, this subroutine is invoked after
applying the first format to the buffer.  The generated hash reference
is passed to this routine.  Any field names specified in the first
format are available to be used in making a decision on which format
to use to decipher the buffer.  This routine should return the index
of the proper format specification.

When converting a hash to a buffer, this subroutine is invoked first
to choose a packing format.  Since the same function is used for both
conversions, this function should restrict itself to field names that
exist in format 0 and those fields should exist in the same place in
all formats.

=item Formats

This is a reference to a list of formats.  Each format contains a list
of field specifications.

=back

For example:

    my $cvt = new Parse::Binary::FixedFormat {
        Chooser => sub { my $rec=shift;
		         $rec->{RecordType} eq '0' ? 1 : 2
		       },
	Formats => [ [ 'RecordType:A1' ],
		     [ 'RecordType:A1', 'FieldA:A6', 'FieldB:A4:4' ],
		     [ 'RecordType:A1', 'FieldC:A4', 'FieldD:A18' ] ]
        };
    my $rec0 = $cvt->unformat("0FieldAB[0]B[1]B[2]B[3]");
    my $rec1 = $cvt->unformat("1FldC<-----FieldD----->");

In the above example, the C<Chooser> function looks at the contents of
the C<RecordType> field.  If it contains a '0', format 1 is used.
Otherwise, format 2 is used.

B<Parse::Binary::FixedFormat::Variants> can be used is if it were a
B<Parse::Binary::FixedFormat>.  The C<format> and C<unformat> methods will
determine which variant to use automatically.  The C<blank> method
requires an argument that specifies the variant number.

=head1 ATTRIBUTES

Each Parse::Binary::FixedFormat::Variants instance contains the following
attributes.

=over 4

=item Layouts

Contains an array of Parse::Binary::FixedFormat objects.  Each of these objects
is responsible for converting a single record format variant.

=item Chooser

This attribute contains the function that chooses which variant to
apply to the record.

=back

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

Based on Data::FixedFormat::Variants, written by Thomas Pfau <pfau@nbpfaus.net>
http://nbpfaus.net/~pfau/.

=head1 COPYRIGHT

Copyright 2004-2009 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

Copyright (C) 2000,2002 Thomas Pfau.  All rights reserved.

This module is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the
Free Software Foundation; either version 2 of the License, or (at your
option) any later version.

This library is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
Library General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software Foundation,
Inc., 59 Temple Place - Suite 330, Boston, MA 02111-1307, USA.

=cut

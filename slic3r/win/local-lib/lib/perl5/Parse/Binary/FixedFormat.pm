package Parse::Binary::FixedFormat;

use bytes;
use strict;
use integer;
our $VERSION = '0.05';

sub new {
    my ($class, $layout) = @_;
    my $self;
    if (UNIVERSAL::isa($layout, 'HASH')) {
	require Parse::Binary::FixedFormat::Variants;
	$self = Parse::Binary::FixedFormat::Variants->new($layout);
    } else {
	$self = { Names=>[], Count=>[], Format=>"" };
	bless $self, $class;
	$self->parse_fields($layout) if $layout;
    }
    return $self;
}

sub parse_fields {
    my ($self,$fmt) = @_;
    foreach my $fld (@$fmt) {
	my ($name, $format, $count, $group) = split /\s*:\s*/,$fld;
	push @{$self->{Names}}, $name;
	push @{$self->{Count}}, $count;
	push @{$self->{Group}}, $group;
	if (defined $count) {
	    push @{$self->{Format}||=[]}, "($format)$count";
	}
	else {
	    push @{$self->{Format}||=[]}, $format;
	}
    }
}

my %_format_cache;
sub _format {
    my ($self, $lazy) = @_;
    $self->{_format} ||= do {
	my $format = join('', @{$self->{Format}});
	$_format_cache{$format} ||= do {
	    $format =~ s/\((.*?)\)\*$/a*/ if $lazy; # tail iteration
	    $format =~ s/\((.*?)\)(?:(\d+)|(\*))/$1 x ($3 ? 1 : $2)/eg if ($] < 5.008);
	    $format;
	};
    };
}

my %_parent_format;
sub unformat {
    my $self = shift;
    my @flds = shift;
    my $lazy = shift;
    my $parent = shift;

    my $format = $self->_format($lazy);
    @flds = unpack($format, $flds[0]) unless $format eq 'a*';

    my $rec = {};
    foreach my $i (0 .. $#{$self->{Names}}) {
	my $name = $self->{Names}[$i];
	if (defined(my $count = $self->{Count}[$i])) {
	    next unless $count;

	    my $group = $self->{Group}[$i];
	    if ($count eq '*') {
		$count = @flds;
		$group ||= 1;
	    }

	    if ($group) {
		my $pad = 0;
		$pad = length($1) if $self->{Format}[$i] =~ /(X+)/;

		if ($lazy and $i == $#{$self->{Names}}) {
		    my $format = $self->{Format}[$i] or die "No format found";
		    $format =~ s/^\((.*?)\)\*$/$1/ or die "Not a count=* field";

                    my $record = ($rec->{$name} ||= []);
		    push @$record, $self->lazy_unformat(
			$parent, $record, $pad, $format, \($flds[0])
		    ) if @flds and length($flds[0]);

		    next;
		}

		my $count_idx = 0;
		while (my @content = splice(@flds, 0, $group)) {
		    substr($content[-1], -$pad, $pad, '') if $pad;
		    push @{$rec->{$name}}, \@content;
		    $count_idx += $group;
		    last if $count_idx >= $count;
		}
	    }
	    else {
		@{$rec->{$name}} = splice @flds, 0, $count;
	    }
	} else {
	    $rec->{$name} = shift @flds;
	}
    }
    return $rec;
}

sub lazy_unformat {
    my ($self, $parent, $record, $pad, $format, $data) = @_;

    # for each request of a member data, we:
    my $valid_sub = ($parent->can('valid_unformat') ? 1 : 0);
    return sub { {
	# grab one chunk of data 
	my @content = unpack($format, $$data);
	my $length = length(pack($format, @content));

	# eliminate it from the source string
	my $chunk = substr($$data, 0, $length, '');
	my $done = (length($$data) <= $pad);

	if ($valid_sub and !$done and !$_[0]->valid_unformat(\@content, \$chunk, $done)) {
	    # weed out invalid data immediately
	    redo;
	}

	# remove extra padding
	substr($content[-1], -$pad, $pad, '') if $pad;

	# and prepend (or replace if there are no more data) with it
	splice(@{$_[1]}, -1, $done, \@content);
	return \@content;
    } };
}

sub format {
    my ($self,$rec) = @_;
    my @flds;
    my $i = 0;
    foreach my $name (@{$self->{Names}}) {
	if ($self->{Count}[$i]) {
	    push @flds,map {ref($_) ? @$_ : $_} @{$rec->{$name}};
	} else {
	    if (ref($rec->{$name}) eq "ARRAY") {
                if (@{$rec->{$name}}) {
                    push @flds,$rec->{$name};
                }
            } else {
                push @flds,$rec->{$name};
            }
	}
    	$i++;
    } 
    no warnings 'uninitialized';
    return pack($self->_format, @flds);
}

sub blank {
    my $self = shift;
    my $rec = $self->unformat(pack($self->_format,
				   unpack($self->_format,
					  '')));
    return $rec;
}

1;

=head1 NAME

Parse::Binary::FixedFormat - Convert between fixed-length fields and hashes

=head1 SYNOPSIS

   use Parse::Binary::FixedFormat;

   my $tarhdr =
      new Parse::Binary::FixedFormat [ qw(name:a100 mode:a8 uid:a8 gid:a8 size:a12
			         mtime:a12 chksum:a8 typeflag:a1 linkname:a100
				 magic:a6 version:a2 uname:a32 gname:a32
			         devmajor:a8 devminor:a8 prefix:a155) ];
   my $buf;
   read TARFILE, $buf, 512;

   # create a hash from the buffer read from the file
   my $hdr = $tarhdr->unformat($buf);   # $hdr gets a hash ref

   # create a flat record from a hash reference
   my $buf = $tarhdr->format($hdr);     # $hdr is a hash ref

   # create a hash for a new record
   my $newrec = $tarhdr->blank();

=head1 DESCRIPTION

B<Parse::Binary::FixedFormat> can be used to convert between a buffer with
fixed-length field definitions and a hash with named entries for each
field.  The perl C<pack> and C<unpack> functions are used to perform
the conversions.  B<Parse::Binary::FixedFormat> builds the format string by
concatenating the field descriptions and converts between the lists
used by C<pack> and C<unpack> and a hash that can be reference by
field name.

=head1 METHODS

B<Parse::Binary::FixedFormat> provides the following methods.

=head2 new

To create a converter, invoke the B<new> method with a reference to a
list of field specifications.

    my $cvt =
        new Parse::Binary::FixedFormat [ 'field-name:descriptor:count', ... ];

Field specifications contain the following information.

=over 4

=item field-name

This is the name of the field and will be used as the hash index.

=item descriptor

This describes the content and size of the field.  All of the
descriptors get strung together and passed to B<pack> and B<unpack> as
part of the template argument.  See B<perldoc -f pack> for information
on what can be specified here.

Don't use repeat counts in the descriptor except for string types
("a", "A", "h, "H", and "Z").  If you want to get an array out of the
buffer, use the C<count> argument.

=item count

This specifies a repeat count for the field.  If specified as a
non-zero value, this field's entry in the resultant hash will be an
array reference instead of a scalar.

=back

=head2 unformat

To convert a buffer of data into a hash, pass the buffer to the
B<unformat> method.

    $hashref = $cvt->unformat($buf);

Parse::Binary::FixedFormat applies the constructed format to the buffer with
C<unpack> and maps the returned list of elements to hash entries.
Fields can now be accessed by name though the hash:

    print $hashref->{field-name};
    print $hashref->{array-field}[3];

=head2 format

To convert the hash back into a fixed-format buffer, pass the hash
reference to the B<format> method.

    $buf = $cvt->format($hashref);

=head2 blank


To get a hash that can be used to create a new record, call the
B<blank> method.

    $newrec = $cvt->blank();

=head1 ATTRIBUTES

Each Parse::Binary::FixedFormat instance contains the following attributes.

=over 4

=item Names

Names contains a list of the field names for this variant.

=item Count

Count contains a list of occurrence counts.  This is used to indicate
which fields contain arrays.

=item Format

Format contains the template string for the Perl B<pack> and B<unpack>
functions.

=back

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

Based on Data::FixedFormat, written by Thomas Pfau <pfau@nbpfaus.net>
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

# $Id$

package XML::SAX::PurePerl::Reader::String;

use strict;
use vars qw(@ISA);

use XML::SAX::PurePerl::Reader qw(
    LINE
    COLUMN
    BUFFER
    ENCODING
    EOF
);

@ISA = ('XML::SAX::PurePerl::Reader');

use constant DISCARDED  => 8;
use constant STRING     => 9;
use constant USED       => 10;
use constant CHUNK_SIZE => 2048;

sub new {
    my $class = shift;
    my $string = shift;
    my @parts;
    @parts[BUFFER, EOF, LINE, COLUMN, DISCARDED, STRING, USED] =
        ('',   0,   1,    0,       0, $string, 0);
    return bless \@parts, $class;
}

sub read_more () {
    my $self = shift;
    if ($self->[USED] >= length($self->[STRING])) {
        $self->[EOF]++;
        return 0;
    }
    my $bytes = CHUNK_SIZE;
    if ($bytes > (length($self->[STRING]) - $self->[USED])) {
       $bytes = (length($self->[STRING]) - $self->[USED]);
    }
    $self->[BUFFER] .= substr($self->[STRING], $self->[USED], $bytes);
    $self->[USED] += $bytes;
    return 1;
 }


sub move_along {
    my($self, $bytes) = @_;
    my $discarded = substr($self->[BUFFER], 0, $bytes, '');
    $self->[DISCARDED] += length($discarded);
    
    # Wish I could skip this lot - tells us where we are in the file
    my $lines = $discarded =~ tr/\n//;
    $self->[LINE] += $lines;
    if ($lines) {
        $discarded =~ /\n([^\n]*)$/;
        $self->[COLUMN] = length($1);
    }
    else {
        $self->[COLUMN] += $_[0];
    }
}

sub set_encoding {
    my $self = shift;
    my ($encoding) = @_;

    XML::SAX::PurePerl::Reader::switch_encoding_string($self->[BUFFER], $encoding, "utf-8");
    $self->[ENCODING] = $encoding;
}

sub bytepos {
    my $self = shift;
    $self->[DISCARDED];
}

1;

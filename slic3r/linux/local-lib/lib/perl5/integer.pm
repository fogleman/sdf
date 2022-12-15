#line 1 "integer.pm"
package integer;

our $VERSION = '1.01';

#line 82

$integer::hint_bits = 0x1;

sub import {
    $^H |= $integer::hint_bits;
}

sub unimport {
    $^H &= ~$integer::hint_bits;
}

1;

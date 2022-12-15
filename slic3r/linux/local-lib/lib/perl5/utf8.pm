#line 1 "utf8.pm"
package utf8;

$utf8::hint_bits = 0x00800000;

our $VERSION = '1.19';

sub import {
    $^H |= $utf8::hint_bits;
}

sub unimport {
    $^H &= ~$utf8::hint_bits;
}

sub AUTOLOAD {
    require "utf8_heavy.pl";
    goto &$AUTOLOAD if defined &$AUTOLOAD;
    require Carp;
    Carp::croak("Undefined subroutine $AUTOLOAD called");
}

1;
__END__

#line 246

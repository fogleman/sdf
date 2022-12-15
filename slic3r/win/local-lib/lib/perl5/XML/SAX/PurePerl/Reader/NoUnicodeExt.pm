# $Id$

package XML::SAX::PurePerl::Reader;
use strict;

sub set_raw_stream {
    # no-op
}

sub switch_encoding_stream {
    my ($fh, $encoding) = @_;
    throw XML::SAX::Exception::Parse (
        Message => "Only ASCII encoding allowed without perl 5.7.2 or higher. You tried: $encoding",
    ) if $encoding !~ /(ASCII|UTF\-?8)/i;
}

sub switch_encoding_string {
    my (undef, $encoding) = @_;
    throw XML::SAX::Exception::Parse (
        Message => "Only ASCII encoding allowed without perl 5.7.2 or higher. You tried: $encoding",
    ) if $encoding !~ /(ASCII|UTF\-?8)/i;
}

1;


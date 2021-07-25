#line 1 "MIME/Base64.pm"
package MIME::Base64;

use strict;
use vars qw(@ISA @EXPORT @EXPORT_OK $VERSION);

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(encode_base64 decode_base64);
@EXPORT_OK = qw(encode_base64url decode_base64url encoded_base64_length decoded_base64_length);

$VERSION = '3.15';

require XSLoader;
XSLoader::load('MIME::Base64', $VERSION);

*encode = \&encode_base64;
*decode = \&decode_base64;

sub encode_base64url {
    my $e = encode_base64(shift, "");
    $e =~ s/=+\z//;
    $e =~ tr[+/][-_];
    return $e;
}

sub decode_base64url {
    my $s = shift;
    $s =~ tr[-_][+/];
    $s .= '=' while length($s) % 4;
    return decode_base64($s);
}

1;

__END__

#line 189

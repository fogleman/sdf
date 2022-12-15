#line 1 "HTTP/Status.pm"
package HTTP::Status;

use strict;
use warnings;

require 5.002;   # because we use prototypes

use base 'Exporter';
our @EXPORT = qw(is_info is_success is_redirect is_error status_message);
our @EXPORT_OK = qw(is_client_error is_server_error);

our $VERSION = "6.11";

# Note also addition of mnemonics to @EXPORT below

# Unmarked codes are from RFC 2616
# See also: http://en.wikipedia.org/wiki/List_of_HTTP_status_codes

my %StatusCode = (
    100 => 'Continue',
    101 => 'Switching Protocols',
    102 => 'Processing',                      # RFC 2518 (WebDAV)
    200 => 'OK',
    201 => 'Created',
    202 => 'Accepted',
    203 => 'Non-Authoritative Information',
    204 => 'No Content',
    205 => 'Reset Content',
    206 => 'Partial Content',
    207 => 'Multi-Status',                    # RFC 2518 (WebDAV)
    208 => 'Already Reported',		      # RFC 5842
    300 => 'Multiple Choices',
    301 => 'Moved Permanently',
    302 => 'Found',
    303 => 'See Other',
    304 => 'Not Modified',
    305 => 'Use Proxy',
    307 => 'Temporary Redirect',
    308 => 'Permanent Redirect',              # RFC 7238
    400 => 'Bad Request',
    401 => 'Unauthorized',
    402 => 'Payment Required',
    403 => 'Forbidden',
    404 => 'Not Found',
    405 => 'Method Not Allowed',
    406 => 'Not Acceptable',
    407 => 'Proxy Authentication Required',
    408 => 'Request Timeout',
    409 => 'Conflict',
    410 => 'Gone',
    411 => 'Length Required',
    412 => 'Precondition Failed',
    413 => 'Request Entity Too Large',
    414 => 'Request-URI Too Large',
    415 => 'Unsupported Media Type',
    416 => 'Request Range Not Satisfiable',
    417 => 'Expectation Failed',
    418 => 'I\'m a teapot',		      # RFC 2324
    422 => 'Unprocessable Entity',            # RFC 2518 (WebDAV)
    423 => 'Locked',                          # RFC 2518 (WebDAV)
    424 => 'Failed Dependency',               # RFC 2518 (WebDAV)
    425 => 'No code',                         # WebDAV Advanced Collections
    426 => 'Upgrade Required',                # RFC 2817
    428 => 'Precondition Required',
    429 => 'Too Many Requests',
    431 => 'Request Header Fields Too Large',
    449 => 'Retry with',                      # unofficial Microsoft
    500 => 'Internal Server Error',
    501 => 'Not Implemented',
    502 => 'Bad Gateway',
    503 => 'Service Unavailable',
    504 => 'Gateway Timeout',
    505 => 'HTTP Version Not Supported',
    506 => 'Variant Also Negotiates',         # RFC 2295
    507 => 'Insufficient Storage',            # RFC 2518 (WebDAV)
    509 => 'Bandwidth Limit Exceeded',        # unofficial
    510 => 'Not Extended',                    # RFC 2774
    511 => 'Network Authentication Required',
);

my $mnemonicCode = '';
my ($code, $message);
while (($code, $message) = each %StatusCode) {
    # create mnemonic subroutines
    $message =~ s/I'm/I am/;
    $message =~ tr/a-z \-/A-Z__/;
    $mnemonicCode .= "sub HTTP_$message () { $code }\n";
    $mnemonicCode .= "*RC_$message = \\&HTTP_$message;\n";  # legacy
    $mnemonicCode .= "push(\@EXPORT_OK, 'HTTP_$message');\n";
    $mnemonicCode .= "push(\@EXPORT, 'RC_$message');\n";
}
eval $mnemonicCode; # only one eval for speed
die if $@;

# backwards compatibility
*RC_MOVED_TEMPORARILY = \&RC_FOUND;  # 302 was renamed in the standard
push(@EXPORT, "RC_MOVED_TEMPORARILY");

our %EXPORT_TAGS = (
   constants => [grep /^HTTP_/, @EXPORT_OK],
   is => [grep /^is_/, @EXPORT, @EXPORT_OK],
);


sub status_message  ($) { $StatusCode{$_[0]}; }

sub is_info         ($) { $_[0] >= 100 && $_[0] < 200; }
sub is_success      ($) { $_[0] >= 200 && $_[0] < 300; }
sub is_redirect     ($) { $_[0] >= 300 && $_[0] < 400; }
sub is_error        ($) { $_[0] >= 400 && $_[0] < 600; }
sub is_client_error ($) { $_[0] >= 400 && $_[0] < 500; }
sub is_server_error ($) { $_[0] >= 500 && $_[0] < 600; }

1;


__END__

#line 270
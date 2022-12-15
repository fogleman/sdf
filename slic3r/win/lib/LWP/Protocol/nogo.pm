#line 1 "LWP/Protocol/nogo.pm"
package LWP::Protocol::nogo;
# If you want to disable access to a particular scheme, use this
# class and then call
#   LWP::Protocol::implementor(that_scheme, 'LWP::Protocol::nogo');
# For then on, attempts to access URLs with that scheme will generate
# a 500 error.
$LWP::Protocol::nogo::VERSION = '6.24';
use strict;

require HTTP::Response;
require HTTP::Status;
use base qw(LWP::Protocol);

sub request {
    my($self, $request) = @_;
    my $scheme = $request->uri->scheme;

    return HTTP::Response->new(
      HTTP::Status::RC_INTERNAL_SERVER_ERROR,
      "Access to \'$scheme\' URIs has been disabled"
    );
}
1;

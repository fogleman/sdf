package Mozilla::CA;

use strict;
our $VERSION = '20160104';

use Cwd ();
use File::Spec ();
use File::Basename qw(dirname);

sub SSL_ca_file {
    my $file = File::Spec->catfile(dirname(__FILE__), "CA", "cacert.pem");
    if (!File::Spec->file_name_is_absolute($file)) {
	$file = File::Spec->catfile(Cwd::cwd(), $file);
    }
    return $file;
}

1;

__END__

=head1 NAME

Mozilla::CA - Mozilla's CA cert bundle in PEM format

=head1 SYNOPSIS

    use IO::Socket::SSL;
    use Mozilla::CA;

    my $host = "www.paypal.com";
    my $client = IO::Socket::SSL->new(
	PeerHost => "$host:443",
	SSL_verify_mode => 0x02,
	SSL_ca_file => Mozilla::CA::SSL_ca_file(),
    )
	|| die "Can't connect: $@";

    $client->verify_hostname($host, "http")
	|| die "hostname verification failure";

=head1 DESCRIPTION

Mozilla::CA provides a copy of Mozilla's bundle of Certificate Authority
certificates in a form that can be consumed by modules and libraries
based on OpenSSL.

The module provide a single function:

=over

=item SSL_ca_file()

Returns the absolute path to the Mozilla's CA cert bundle PEM file.

=back

=head1 SEE ALSO

L<http://curl.haxx.se/docs/caextract.html>

=head1 LICENSE

For the bundled Mozilla CA PEM file the following applies:

=over

This Source Code Form is subject to the terms of the Mozilla Public
License, v. 2.0. If a copy of the MPL was not distributed with this
file, You can obtain one at http://mozilla.org/MPL/2.0/.

=back

The Mozilla::CA distribution itself is available under the same license.

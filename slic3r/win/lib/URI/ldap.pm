#line 1 "URI/ldap.pm"
# Copyright (c) 1998 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package URI::ldap;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent qw(URI::_ldap URI::_server);

sub default_port { 389 }

sub _nonldap_canonical {
    my $self = shift;
    $self->URI::_server::canonical(@_);
}

1;

__END__

#line 122

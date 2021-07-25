package URI::urn::oid;  # RFC 2061

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::urn';

sub oid {
    my $self = shift;
    my $old = $self->nss;
    if (@_) {
	$self->nss(join(".", @_));
    }
    return split(/\./, $old) if wantarray;
    return $old;
}

1;

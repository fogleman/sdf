#line 1 "URI/http.pm"
package URI::http;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use parent 'URI::_server';

sub default_port { 80 }

sub canonical
{
    my $self = shift;
    my $other = $self->SUPER::canonical;

    my $slash_path = defined($other->authority) &&
        !length($other->path) && !defined($other->query);

    if ($slash_path) {
	$other = $other->clone if $other == $self;
	$other->path("/");
    }
    $other;
}

1;

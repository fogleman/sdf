#line 1 "URI/Split.pm"
package URI::Split;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use Exporter 5.57 'import';
our @EXPORT_OK = qw(uri_split uri_join);

use URI::Escape ();

sub uri_split {
     return $_[0] =~ m,(?:([^:/?#]+):)?(?://([^/?#]*))?([^?#]*)(?:\?([^#]*))?(?:#(.*))?,;
}

sub uri_join {
    my($scheme, $auth, $path, $query, $frag) = @_;
    my $uri = defined($scheme) ? "$scheme:" : "";
    $path = "" unless defined $path;
    if (defined $auth) {
	$auth =~ s,([/?\#]), URI::Escape::escape_char($1),eg;
	$uri .= "//$auth";
	$path = "/$path" if length($path) && $path !~ m,^/,;
    }
    elsif ($path =~ m,^//,) {
	$uri .= "//";  # XXX force empty auth
    }
    unless (length $uri) {
	$path =~ s,(:), URI::Escape::escape_char($1),e while $path =~ m,^[^:/?\#]+:,;
    }
    $path =~ s,([?\#]), URI::Escape::escape_char($1),eg;
    $uri .= $path;
    if (defined $query) {
	$query =~ s,(\#), URI::Escape::escape_char($1),eg;
	$uri .= "?$query";
    }
    $uri .= "#$frag" if defined $frag;
    $uri;
}

1;

__END__

#line 99

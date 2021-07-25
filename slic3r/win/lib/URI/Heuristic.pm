#line 1 "URI/Heuristic.pm"
package URI::Heuristic;

#line 88

use strict;
use warnings;

use Exporter 5.57 'import';
our @EXPORT_OK = qw(uf_uri uf_uristr uf_url uf_urlstr);
our $VERSION = "4.20";

our ($MY_COUNTRY, $DEBUG);

sub MY_COUNTRY() {
    for ($MY_COUNTRY) {
	return $_ if defined;

	# First try the environment.
	$_ = $ENV{COUNTRY};
	return $_ if defined;

	# Try the country part of LC_ALL and LANG from environment
	my @srcs = ($ENV{LC_ALL}, $ENV{LANG});
	# ...and HTTP_ACCEPT_LANGUAGE before those if present
	if (my $httplang = $ENV{HTTP_ACCEPT_LANGUAGE}) {
	    # TODO: q-value processing/ordering
	    for $httplang (split(/\s*,\s*/, $httplang)) {
		if ($httplang =~ /^\s*([a-zA-Z]+)[_-]([a-zA-Z]{2})\s*$/) {
		    unshift(@srcs, "${1}_${2}");
		    last;
		}
	    }
	}
	for (@srcs) {
	    next unless defined;
	    return lc($1) if /^[a-zA-Z]+_([a-zA-Z]{2})(?:[.@]|$)/;
	}

	# Last bit of domain name.  This may access the network.
	require Net::Domain;
	my $fqdn = Net::Domain::hostfqdn();
	$_ = lc($1) if $fqdn =~ /\.([a-zA-Z]{2})$/;
	return $_ if defined;

	# Give up.  Defined but false.
	return ($_ = 0);
    }
}

our %LOCAL_GUESSING =
(
 'us' => [qw(www.ACME.gov www.ACME.mil)],
 'gb' => [qw(www.ACME.co.uk www.ACME.org.uk www.ACME.ac.uk)],
 'au' => [qw(www.ACME.com.au www.ACME.org.au www.ACME.edu.au)],
 'il' => [qw(www.ACME.co.il www.ACME.org.il www.ACME.net.il)],
 # send corrections and new entries to <gisle@aas.no>
);
# Backwards compatibility; uk != United Kingdom in ISO 3166
$LOCAL_GUESSING{uk} = $LOCAL_GUESSING{gb};


sub uf_uristr ($)
{
    local($_) = @_;
    print STDERR "uf_uristr: resolving $_\n" if $DEBUG;
    return unless defined;

    s/^\s+//;
    s/\s+$//;

    if (/^(www|web|home)[a-z0-9-]*(?:\.|$)/i) {
	$_ = "http://$_";

    } elsif (/^(ftp|gopher|news|wais|https|http)[a-z0-9-]*(?:\.|$)/i) {
	$_ = lc($1) . "://$_";

    } elsif ($^O ne "MacOS" && 
	    (m,^/,      ||          # absolute file name
	     m,^\.\.?/, ||          # relative file name
	     m,^[a-zA-Z]:[/\\],)    # dosish file name
	    )
    {
	$_ = "file:$_";

    } elsif ($^O eq "MacOS" && m/:/) {
        # potential MacOS file name
	unless (m/^(ftp|gopher|news|wais|http|https|mailto):/) {
	    require URI::file;
	    my $a = URI::file->new($_)->as_string;
	    $_ = ($a =~ m/^file:/) ? $a : "file:$a";
	}
    } elsif (/^\w+([\.\-]\w+)*\@(\w+\.)+\w{2,3}$/) {
	$_ = "mailto:$_";

    } elsif (!/^[a-zA-Z][a-zA-Z0-9.+\-]*:/) {      # no scheme specified
	if (s/^([-\w]+(?:\.[-\w]+)*)([\/:\?\#]|$)/$2/) {
	    my $host = $1;

	    my $scheme = "http";
	    if (/^:(\d+)\b/) {
		# Some more or less well known ports
		if ($1 =~ /^[56789]?443$/) {
		    $scheme = "https";
		} elsif ($1 eq "21") {
		    $scheme = "ftp";
		}
	    }

	    if ($host !~ /\./ && $host ne "localhost") {
		my @guess;
		if (exists $ENV{URL_GUESS_PATTERN}) {
		    @guess = map { s/\bACME\b/$host/; $_ }
		             split(' ', $ENV{URL_GUESS_PATTERN});
		} else {
		    if (MY_COUNTRY()) {
			my $special = $LOCAL_GUESSING{MY_COUNTRY()};
			if ($special) {
			    my @special = @$special;
			    push(@guess, map { s/\bACME\b/$host/; $_ }
                                               @special);
			} else {
			    push(@guess, "www.$host." . MY_COUNTRY());
			}
		    }
		    push(@guess, map "www.$host.$_",
			             "com", "org", "net", "edu", "int");
		}


		my $guess;
		for $guess (@guess) {
		    print STDERR "uf_uristr: gethostbyname('$guess.')..."
		      if $DEBUG;
		    if (gethostbyname("$guess.")) {
			print STDERR "yes\n" if $DEBUG;
			$host = $guess;
			last;
		    }
		    print STDERR "no\n" if $DEBUG;
		}
	    }
	    $_ = "$scheme://$host$_";

	} else {
	    # pure junk, just return it unchanged...

	}
    }
    print STDERR "uf_uristr: ==> $_\n" if $DEBUG;

    $_;
}

sub uf_uri ($)
{
    require URI;
    URI->new(uf_uristr($_[0]));
}

# legacy
*uf_urlstr = \*uf_uristr;

sub uf_url ($)
{
    require URI::URL;
    URI::URL->new(uf_uristr($_[0]));
}

1;

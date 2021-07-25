#line 1 "HTTP/Negotiate.pm"
package HTTP::Negotiate;

$VERSION = "6.01";
sub Version { $VERSION; }

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(choose);

require HTTP::Headers;

$DEBUG = 0;

sub choose ($;$)
{
    my($variants, $request) = @_;
    my(%accept);

    unless (defined $request) {
	# Create a request object from the CGI environment variables
	$request = HTTP::Headers->new;
	$request->header('Accept', $ENV{HTTP_ACCEPT})
	  if $ENV{HTTP_ACCEPT};
	$request->header('Accept-Charset', $ENV{HTTP_ACCEPT_CHARSET})
	  if $ENV{HTTP_ACCEPT_CHARSET};
	$request->header('Accept-Encoding', $ENV{HTTP_ACCEPT_ENCODING})
	  if $ENV{HTTP_ACCEPT_ENCODING};
	$request->header('Accept-Language', $ENV{HTTP_ACCEPT_LANGUAGE})
	  if $ENV{HTTP_ACCEPT_LANGUAGE};
    }

    # Get all Accept values from the request.  Build a hash initialized
    # like this:
    #
    #   %accept = ( type =>     { 'audio/*'     => { q => 0.2, mbx => 20000 },
    #                             'audio/basic' => { q => 1 },
    #                           },
    #               language => { 'no'          => { q => 1 },
    #                           }
    #             );

    $request->scan(sub {
	my($key, $val) = @_;

	my $type;
	if ($key =~ s/^Accept-//) {
	    $type = lc($key);
	}
	elsif ($key eq "Accept") {
	    $type = "type";
	}
	else {
	    return;
	}

	$val =~ s/\s+//g;
	my $default_q = 1;
	for my $name (split(/,/, $val)) {
	    my(%param, $param);
	    if ($name =~ s/;(.*)//) {
		for $param (split(/;/, $1)) {
		    my ($pk, $pv) = split(/=/, $param, 2);
		    $param{lc $pk} = $pv;
		}
	    }
	    $name = lc $name;
	    if (defined $param{'q'}) {
		$param{'q'} = 1 if $param{'q'} > 1;
		$param{'q'} = 0 if $param{'q'} < 0;
	    }
	    else {
		$param{'q'} = $default_q;

		# This makes sure that the first ones are slightly better off
		# and therefore more likely to be chosen.
		$default_q -= 0.0001;
	    }
	    $accept{$type}{$name} = \%param;
	}
    });

    # Check if any of the variants specify a language.  We do this
    # because it influences how we treat those without (they default to
    # 0.5 instead of 1).
    my $any_lang = 0;
    for $var (@$variants) {
	if ($var->[5]) {
	    $any_lang = 1;
	    last;
	}
    }

    if ($DEBUG) {
	print "Negotiation parameters in the request\n";
	for $type (keys %accept) {
	    print " $type:\n";
	    for $name (keys %{$accept{$type}}) {
		print "    $name\n";
		for $pv (keys %{$accept{$type}{$name}}) {
		    print "      $pv = $accept{$type}{$name}{$pv}\n";
		}
	    }
	}
    }

    my @Q = ();  # This is where we collect the results of the
		 # quality calculations

    # Calculate quality for all the variants that are available.
    for (@$variants) {
	my($id, $qs, $ct, $enc, $cs, $lang, $bs) = @$_;
	$qs = 1 unless defined $qs;
        $ct = '' unless defined $ct;
	$bs = 0 unless defined $bs;
	$lang = lc($lang) if $lang; # lg tags are always case-insensitive
	if ($DEBUG) {
	    print "\nEvaluating $id (ct='$ct')\n";
	    printf "  qs   = %.3f\n", $qs;
	    print  "  enc  = $enc\n"  if $enc && !ref($enc);
	    print  "  enc  = @$enc\n" if $enc && ref($enc);
	    print  "  cs   = $cs\n"   if $cs;
	    print  "  lang = $lang\n" if $lang;
	    print  "  bs   = $bs\n"   if $bs;
	}

	# Calculate encoding quality
	my $qe = 1;
	# If the variant has no assigned Content-Encoding, or if no
	# Accept-Encoding field is present, then the value assigned
	# is "qe=1".  If *all* of the variant's content encodings
	# are listed in the Accept-Encoding field, then the value
	# assigned is "qw=1".  If *any* of the variant's content
	# encodings are not listed in the provided Accept-Encoding
	# field, then the value assigned is "qe=0"
	if (exists $accept{'encoding'} && $enc) {
	    my @enc = ref($enc) ? @$enc : ($enc);
	    for (@enc) {
		print "Is encoding $_ accepted? " if $DEBUG;
		unless(exists $accept{'encoding'}{$_}) {
		    print "no\n" if $DEBUG;
		    $qe = 0;
		    last;
		}
		else {
		    print "yes\n" if $DEBUG;
		}
	    }
	}

	# Calculate charset quality
	my $qc  = 1;
	# If the variant's media-type has no charset parameter,
	# or the variant's charset is US-ASCII, or if no Accept-Charset
	# field is present, then the value assigned is "qc=1".  If the
	# variant's charset is listed in the Accept-Charset field,
	# then the value assigned is "qc=1.  Otherwise, if the variant's
	# charset is not listed in the provided Accept-Encoding field,
	# then the value assigned is "qc=0".
	if (exists $accept{'charset'} && $cs && $cs ne 'us-ascii' ) {
	    $qc = 0 unless $accept{'charset'}{$cs};
	}

	# Calculate language quality
	my $ql  = 1;
	if ($lang && exists $accept{'language'}) {
	    my @lang = ref($lang) ? @$lang : ($lang);
	    # If any of the variant's content languages are listed
	    # in the Accept-Language field, the the value assigned is
	    # the largest of the "q" parameter values for those language
	    # tags.
	    my $q = undef;
	    for (@lang) {
		next unless exists $accept{'language'}{$_};
		my $this_q = $accept{'language'}{$_}{'q'};
		$q = $this_q unless defined $q;
		$q = $this_q if $this_q > $q;
	    }
	    if(defined $q) {
	        $DEBUG and print " -- Exact language match at q=$q\n";
	    }
	    else {
		# If there was no exact match and at least one of
		# the Accept-Language field values is a complete
		# subtag prefix of the content language tag(s), then
		# the "q" parameter value of the largest matching
		# prefix is used.
		$DEBUG and print " -- No exact language match\n";
		my $selected = undef;
		for $al (keys %{ $accept{'language'} }) {
		    if (index($al, "$lang-") == 0) {
		        # $lang starting with $al isn't enough, or else
		        #  Accept-Language: hu (Hungarian) would seem
		        #  to accept a document in hup (Hupa)
		        $DEBUG and print " -- $al ISA $lang\n";
			$selected = $al unless defined $selected;
			$selected = $al if length($al) > length($selected);
		    }
		    else {
		        $DEBUG and print " -- $lang  isn't a $al\n";
		    }
		}
		$q = $accept{'language'}{$selected}{'q'} if $selected;

		# If none of the variant's content language tags or
		# tag prefixes are listed in the provided
		# Accept-Language field, then the value assigned
		# is "ql=0.001"
		$q = 0.001 unless defined $q;
	    }
	    $ql = $q;
	}
	else {
	    $ql = 0.5 if $any_lang && exists $accept{'language'};
	}

	my $q   = 1;
	my $mbx = undef;
	# If no Accept field is given, then the value assigned is "q=1".
	# If at least one listed media range matches the variant's media
	# type, then the "q" parameter value assigned to the most specific
	# of those matched is used (e.g. "text/html;version=3.0" is more
	# specific than "text/html", which is more specific than "text/*",
	# which in turn is more specific than "*/*"). If not media range
	# in the provided Accept field matches the variant's media type,
	# then the value assigned is "q=0".
	if (exists $accept{'type'} && $ct) {
	    # First we clean up our content-type
	    $ct =~ s/\s+//g;
	    my $params = "";
	    $params = $1 if $ct =~ s/;(.*)//;
	    my($type, $subtype) = split("/", $ct, 2);
	    my %param = ();
	    for $param (split(/;/, $params)) {
		my($pk,$pv) = split(/=/, $param, 2);
		$param{$pk} = $pv;
	    }

	    my $sel_q = undef;
	    my $sel_mbx = undef;
	    my $sel_specificness = 0;

	    ACCEPT_TYPE:
	    for $at (keys %{ $accept{'type'} }) {
		print "Consider $at...\n" if $DEBUG;
		my($at_type, $at_subtype) = split("/", $at, 2);
		# Is it a match on the type
		next if $at_type    ne '*' && $at_type    ne $type;
		next if $at_subtype ne '*' && $at_subtype ne $subtype;
		my $specificness = 0;
		$specificness++ if $at_type ne '*';
		$specificness++ if $at_subtype ne '*';
		# Let's see if content-type parameters also match
		while (($pk, $pv) = each %param) {
		    print "Check if $pk = $pv is true\n" if $DEBUG;
		    next unless exists $accept{'type'}{$at}{$pk};
		    next ACCEPT_TYPE
		      unless $accept{'type'}{$at}{$pk} eq $pv;
		    print "yes it is!!\n" if $DEBUG;
		    $specificness++;
		}
		print "Hurray, type match with specificness = $specificness\n"
		  if $DEBUG;

		if (!defined($sel_q) || $sel_specificness < $specificness) {
		    $sel_q   = $accept{'type'}{$at}{'q'};
		    $sel_mbx = $accept{'type'}{$at}{'mbx'};
		    $sel_specificness = $specificness;
		}
	    }
	    $q   = $sel_q || 0;
	    $mbx = $sel_mbx;
	}

	my $Q;
	if (!defined($mbx) || $mbx >= $bs) {
	    $Q = $qs * $qe * $qc * $ql * $q;
	}
	else {
	    $Q = 0;
	    print "Variant's size is too large ==> Q=0\n" if $DEBUG;
	}

	if ($DEBUG) {
	    $mbx = "undef" unless defined $mbx;
	    printf "Q=%.4f", $Q;
	    print "  (q=$q, mbx=$mbx, qe=$qe, qc=$qc, ql=$ql, qs=$qs)\n";
	}

	push(@Q, [$id, $Q, $bs]);
    }


    @Q = sort { $b->[1] <=> $a->[1] || $a->[2] <=> $b->[2] } @Q;

    return @Q if wantarray;
    return undef unless @Q;
    return undef if $Q[0][1] == 0;
    $Q[0][0];
}

1;

__END__


#line 529

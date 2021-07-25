#line 1 "HTTP/Response.pm"
package HTTP::Response;

use strict;
use warnings;

use base 'HTTP::Message';

our $VERSION = "6.11";

use HTTP::Status ();


sub new
{
    my($class, $rc, $msg, $header, $content) = @_;
    my $self = $class->SUPER::new($header, $content);
    $self->code($rc);
    $self->message($msg);
    $self;
}


sub parse
{
    my($class, $str) = @_;
    my $status_line;
    if ($str =~ s/^(.*)\n//) {
	$status_line = $1;
    }
    else {
	$status_line = $str;
	$str = "";
    }

    my $self = $class->SUPER::parse($str);
    my($protocol, $code, $message);
    if ($status_line =~ /^\d{3} /) {
       # Looks like a response created by HTTP::Response->new
       ($code, $message) = split(' ', $status_line, 2);
    } else {
       ($protocol, $code, $message) = split(' ', $status_line, 3);
    }
    $self->protocol($protocol) if $protocol;
    $self->code($code) if defined($code);
    $self->message($message) if defined($message);
    $self;
}


sub clone
{
    my $self = shift;
    my $clone = bless $self->SUPER::clone, ref($self);
    $clone->code($self->code);
    $clone->message($self->message);
    $clone->request($self->request->clone) if $self->request;
    # we don't clone previous
    $clone;
}


sub code      { shift->_elem('_rc',      @_); }
sub message   { shift->_elem('_msg',     @_); }
sub previous  { shift->_elem('_previous',@_); }
sub request   { shift->_elem('_request', @_); }


sub status_line
{
    my $self = shift;
    my $code = $self->{'_rc'}  || "000";
    my $mess = $self->{'_msg'} || HTTP::Status::status_message($code) || "Unknown code";
    return "$code $mess";
}


sub base
{
    my $self = shift;
    my $base = (
	$self->header('Content-Base'),        # used to be HTTP/1.1
	$self->header('Content-Location'),    # HTTP/1.1
	$self->header('Base'),                # HTTP/1.0
    )[0];
    if ($base && $base =~ /^$URI::scheme_re:/o) {
	# already absolute
	return $HTTP::URI_CLASS->new($base);
    }

    my $req = $self->request;
    if ($req) {
        # if $base is undef here, the return value is effectively
        # just a copy of $self->request->uri.
        return $HTTP::URI_CLASS->new_abs($base, $req->uri);
    }

    # can't find an absolute base
    return undef;
}


sub redirects {
    my $self = shift;
    my @r;
    my $r = $self;
    while (my $p = $r->previous) {
        push(@r, $p);
        $r = $p;
    }
    return @r unless wantarray;
    return reverse @r;
}


sub filename
{
    my $self = shift;
    my $file;

    my $cd = $self->header('Content-Disposition');
    if ($cd) {
	require HTTP::Headers::Util;
	if (my @cd = HTTP::Headers::Util::split_header_words($cd)) {
	    my ($disposition, undef, %cd_param) = @{$cd[-1]};
	    $file = $cd_param{filename};

	    # RFC 2047 encoded?
	    if ($file && $file =~ /^=\?(.+?)\?(.+?)\?(.+)\?=$/) {
		my $charset = $1;
		my $encoding = uc($2);
		my $encfile = $3;

		if ($encoding eq 'Q' || $encoding eq 'B') {
		    local($SIG{__DIE__});
		    eval {
			if ($encoding eq 'Q') {
			    $encfile =~ s/_/ /g;
			    require MIME::QuotedPrint;
			    $encfile = MIME::QuotedPrint::decode($encfile);
			}
			else { # $encoding eq 'B'
			    require MIME::Base64;
			    $encfile = MIME::Base64::decode($encfile);
			}

			require Encode;
			require Encode::Locale;
			Encode::from_to($encfile, $charset, "locale_fs");
		    };

		    $file = $encfile unless $@;
		}
	    }
	}
    }

    unless (defined($file) && length($file)) {
	my $uri;
	if (my $cl = $self->header('Content-Location')) {
	    $uri = URI->new($cl);
	}
	elsif (my $request = $self->request) {
	    $uri = $request->uri;
	}

	if ($uri) {
	    $file = ($uri->path_segments)[-1];
	}
    }

    if ($file) {
	$file =~ s,.*[\\/],,;  # basename
    }

    if ($file && !length($file)) {
	$file = undef;
    }

    $file;
}


sub as_string
{
    my $self = shift;
    my($eol) = @_;
    $eol = "\n" unless defined $eol;

    my $status_line = $self->status_line;
    my $proto = $self->protocol;
    $status_line = "$proto $status_line" if $proto;

    return join($eol, $status_line, $self->SUPER::as_string(@_));
}


sub dump
{
    my $self = shift;

    my $status_line = $self->status_line;
    my $proto = $self->protocol;
    $status_line = "$proto $status_line" if $proto;

    return $self->SUPER::dump(
	preheader => $status_line,
        @_,
    );
}


sub is_info     { HTTP::Status::is_info     (shift->{'_rc'}); }
sub is_success  { HTTP::Status::is_success  (shift->{'_rc'}); }
sub is_redirect { HTTP::Status::is_redirect (shift->{'_rc'}); }
sub is_error    { HTTP::Status::is_error    (shift->{'_rc'}); }
sub is_client_error { HTTP::Status::is_client_error (shift->{'_rc'}); }
sub is_server_error { HTTP::Status::is_server_error (shift->{'_rc'}); }


sub error_as_HTML
{
    my $self = shift;
    my $title = 'An Error Occurred';
    my $body  = $self->status_line;
    $body =~ s/&/&amp;/g;
    $body =~ s/</&lt;/g;
    return <<EOM;
<html>
<head><title>$title</title></head>
<body>
<h1>$title</h1>
<p>$body</p>
</body>
</html>
EOM
}


sub current_age
{
    my $self = shift;
    my $time = shift;

    # Implementation of RFC 2616 section 13.2.3
    # (age calculations)
    my $response_time = $self->client_date;
    my $date = $self->date;

    my $age = 0;
    if ($response_time && $date) {
	$age = $response_time - $date;  # apparent_age
	$age = 0 if $age < 0;
    }

    my $age_v = $self->header('Age');
    if ($age_v && $age_v > $age) {
	$age = $age_v;   # corrected_received_age
    }

    if ($response_time) {
	my $request = $self->request;
	if ($request) {
	    my $request_time = $request->date;
	    if ($request_time && $request_time < $response_time) {
		# Add response_delay to age to get 'corrected_initial_age'
		$age += $response_time - $request_time;
	    }
	}
	$age += ($time || time) - $response_time;
    }
    return $age;
}


sub freshness_lifetime
{
    my($self, %opt) = @_;

    # First look for the Cache-Control: max-age=n header
    for my $cc ($self->header('Cache-Control')) {
	for my $cc_dir (split(/\s*,\s*/, $cc)) {
	    return $1 if $cc_dir =~ /^max-age\s*=\s*(\d+)/i;
	}
    }

    # Next possibility is to look at the "Expires" header
    my $date = $self->date || $self->client_date || $opt{time} || time;
    if (my $expires = $self->expires) {
	return $expires - $date;
    }

    # Must apply heuristic expiration
    return undef if exists $opt{heuristic_expiry} && !$opt{heuristic_expiry};

    # Default heuristic expiration parameters
    $opt{h_min} ||= 60;
    $opt{h_max} ||= 24 * 3600;
    $opt{h_lastmod_fraction} ||= 0.10; # 10% since last-mod suggested by RFC2616
    $opt{h_default} ||= 3600;

    # Should give a warning if more than 24 hours according to
    # RFC 2616 section 13.2.4.  Here we just make this the default
    # maximum value.

    if (my $last_modified = $self->last_modified) {
	my $h_exp = ($date - $last_modified) * $opt{h_lastmod_fraction};
	return $opt{h_min} if $h_exp < $opt{h_min};
	return $opt{h_max} if $h_exp > $opt{h_max};
	return $h_exp;
    }

    # default when all else fails
    return $opt{h_min} if $opt{h_min} > $opt{h_default};
    return $opt{h_default};
}


sub is_fresh
{
    my($self, %opt) = @_;
    $opt{time} ||= time;
    my $f = $self->freshness_lifetime(%opt);
    return undef unless defined($f);
    return $f > $self->current_age($opt{time});
}


sub fresh_until
{
    my($self, %opt) = @_;
    $opt{time} ||= time;
    my $f = $self->freshness_lifetime(%opt);
    return undef unless defined($f);
    return $f - $self->current_age($opt{time}) + $opt{time};
}

1;


__END__

#line 645

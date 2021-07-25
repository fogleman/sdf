#line 1 "LWP/UserAgent.pm"
package LWP::UserAgent;

use strict;

use base qw(LWP::MemberMixin);

use Carp ();
use HTTP::Request ();
use HTTP::Response ();
use HTTP::Date ();

use LWP ();
use LWP::Protocol ();

use Scalar::Util qw(blessed);
use Try::Tiny qw(try catch);

our $VERSION = '6.24';

sub new
{
    # Check for common user mistake
    Carp::croak("Options to LWP::UserAgent should be key/value pairs, not hash reference")
        if ref($_[1]) eq 'HASH';

    my($class, %cnf) = @_;

    my $agent = delete $cnf{agent};
    my $from  = delete $cnf{from};
    my $def_headers = delete $cnf{default_headers};
    my $timeout = delete $cnf{timeout};
    $timeout = 3*60 unless defined $timeout;
    my $local_address = delete $cnf{local_address};
    my $ssl_opts = delete $cnf{ssl_opts} || {};
    unless (exists $ssl_opts->{verify_hostname}) {
	# The processing of HTTPS_CA_* below is for compatibility with Crypt::SSLeay
	if (exists $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}) {
	    $ssl_opts->{verify_hostname} = $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME};
	}
	elsif ($ENV{HTTPS_CA_FILE} || $ENV{HTTPS_CA_DIR}) {
	    # Crypt-SSLeay compatibility (verify peer certificate; but not the hostname)
	    $ssl_opts->{verify_hostname} = 0;
	    $ssl_opts->{SSL_verify_mode} = 1;
	}
	else {
	    $ssl_opts->{verify_hostname} = 1;
	}
    }
    unless (exists $ssl_opts->{SSL_ca_file}) {
	if (my $ca_file = $ENV{PERL_LWP_SSL_CA_FILE} || $ENV{HTTPS_CA_FILE}) {
	    $ssl_opts->{SSL_ca_file} = $ca_file;
	}
    }
    unless (exists $ssl_opts->{SSL_ca_path}) {
	if (my $ca_path = $ENV{PERL_LWP_SSL_CA_PATH} || $ENV{HTTPS_CA_DIR}) {
	    $ssl_opts->{SSL_ca_path} = $ca_path;
	}
    }
    my $use_eval = delete $cnf{use_eval};
    $use_eval = 1 unless defined $use_eval;
    my $parse_head = delete $cnf{parse_head};
    $parse_head = 1 unless defined $parse_head;
    my $show_progress = delete $cnf{show_progress};
    my $max_size = delete $cnf{max_size};
    my $max_redirect = delete $cnf{max_redirect};
    $max_redirect = 7 unless defined $max_redirect;
    my $env_proxy = exists $cnf{env_proxy} ? delete $cnf{env_proxy} : $ENV{PERL_LWP_ENV_PROXY};
    my $no_proxy = exists $cnf{no_proxy} ? delete $cnf{no_proxy} : [];
    Carp::croak(qq{no_proxy must be an arrayref, not $no_proxy!}) if ref $no_proxy ne 'ARRAY';

    my $cookie_jar = delete $cnf{cookie_jar};
    my $conn_cache = delete $cnf{conn_cache};
    my $keep_alive = delete $cnf{keep_alive};

    Carp::croak("Can't mix conn_cache and keep_alive")
	  if $conn_cache && $keep_alive;

    my $protocols_allowed   = delete $cnf{protocols_allowed};
    my $protocols_forbidden = delete $cnf{protocols_forbidden};

    my $requests_redirectable = delete $cnf{requests_redirectable};
    $requests_redirectable = ['GET', 'HEAD']
      unless defined $requests_redirectable;

    # Actually ""s are just as good as 0's, but for concision we'll just say:
    Carp::croak("protocols_allowed has to be an arrayref or 0, not \"$protocols_allowed\"!")
      if $protocols_allowed and ref($protocols_allowed) ne 'ARRAY';
    Carp::croak("protocols_forbidden has to be an arrayref or 0, not \"$protocols_forbidden\"!")
      if $protocols_forbidden and ref($protocols_forbidden) ne 'ARRAY';
    Carp::croak("requests_redirectable has to be an arrayref or 0, not \"$requests_redirectable\"!")
      if $requests_redirectable and ref($requests_redirectable) ne 'ARRAY';

    if (%cnf && $^W) {
	Carp::carp("Unrecognized LWP::UserAgent options: @{[sort keys %cnf]}");
    }

    my $self = bless {
        def_headers           => $def_headers,
        timeout               => $timeout,
        local_address         => $local_address,
        ssl_opts              => $ssl_opts,
        use_eval              => $use_eval,
        show_progress         => $show_progress,
        max_size              => $max_size,
        max_redirect          => $max_redirect,
        # We set proxy later as we do validation on the values
        proxy                 => {},
        no_proxy              => [ @{ $no_proxy } ],
        protocols_allowed     => $protocols_allowed,
        protocols_forbidden   => $protocols_forbidden,
        requests_redirectable => $requests_redirectable,
    }, $class;

    $self->agent(defined($agent) ? $agent : $class->_agent)
        if defined($agent) || !$def_headers || !$def_headers->header("User-Agent");
    $self->from($from) if $from;
    $self->cookie_jar($cookie_jar) if $cookie_jar;
    $self->parse_head($parse_head);
    $self->env_proxy if $env_proxy;

    if (exists $cnf{proxy}) {
        Carp::croak(qq{proxy must be an arrayref, not $cnf{proxy}!})
            if ref $cnf{proxy} ne 'ARRAY';
        $self->proxy($cnf{proxy});
    }

    $self->protocols_allowed(  $protocols_allowed  ) if $protocols_allowed;
    $self->protocols_forbidden($protocols_forbidden) if $protocols_forbidden;

    if ($keep_alive) {
	$conn_cache ||= { total_capacity => $keep_alive };
    }
    $self->conn_cache($conn_cache) if $conn_cache;

    return $self;
}


sub send_request
{
    my($self, $request, $arg, $size) = @_;
    my($method, $url) = ($request->method, $request->uri);
    my $scheme = $url->scheme;

    local($SIG{__DIE__});  # protect against user defined die handlers

    $self->progress("begin", $request);

    my $response = $self->run_handlers("request_send", $request);

    unless ($response) {
        my $protocol;

        {
            # Honor object-specific restrictions by forcing protocol objects
            #  into class LWP::Protocol::nogo.
            my $x;
            if($x = $self->protocols_allowed) {
                if (grep lc($_) eq $scheme, @$x) {
                }
                else {
                    require LWP::Protocol::nogo;
                    $protocol = LWP::Protocol::nogo->new;
                }
            }
            elsif ($x = $self->protocols_forbidden) {
                if(grep lc($_) eq $scheme, @$x) {
                    require LWP::Protocol::nogo;
                    $protocol = LWP::Protocol::nogo->new;
                }
            }
            # else fall thru and create the protocol object normally
        }

        # Locate protocol to use
        my $proxy = $request->{proxy};
        if ($proxy) {
            $scheme = $proxy->scheme;
        }

        unless ($protocol) {
            try {
                $protocol = LWP::Protocol::create($scheme, $self);
            }
            catch {
                my $error = $_;
                $error =~ s/ at .* line \d+.*//s;  # remove file/line number
                $response =  _new_response($request, HTTP::Status::RC_NOT_IMPLEMENTED, $error);
                if ($scheme eq "https") {
                    $response->message($response->message . " (LWP::Protocol::https not installed)");
                    $response->content_type("text/plain");
                    $response->content(<<EOT);
LWP will support https URLs if the LWP::Protocol::https module
is installed.
EOT
                }
            };
        }

        if (!$response && $self->{use_eval}) {
            # we eval, and turn dies into responses below
            try {
                $response = $protocol->request($request, $proxy, $arg, $size, $self->{timeout}) || die "No response returned by $protocol";
            }
            catch {
                my $error = $_;
                if (blessed($error) && $error->isa("HTTP::Response")) {
                    $response = $error;
                    $response->request($request);
                }
                else {
                    my $full = $error;
                    (my $status = $error) =~ s/\n.*//s;
                    $status =~ s/ at .* line \d+.*//s;  # remove file/line number
                    my $code = ($status =~ s/^(\d\d\d)\s+//) ? $1 : HTTP::Status::RC_INTERNAL_SERVER_ERROR;
                    $response = _new_response($request, $code, $status, $full);
                }
            };
        }
        elsif (!$response) {
            $response = $protocol->request($request, $proxy,
                                           $arg, $size, $self->{timeout});
            # XXX: Should we die unless $response->is_success ???
        }
    }

    $response->request($request);  # record request for reference
    $response->header("Client-Date" => HTTP::Date::time2str(time));

    $self->run_handlers("response_done", $response);

    $self->progress("end", $response);
    return $response;
}


sub prepare_request
{
    my($self, $request) = @_;
    die "Method missing" unless $request->method;
    my $url = $request->uri;
    die "URL missing" unless $url;
    die "URL must be absolute" unless $url->scheme;

    $self->run_handlers("request_preprepare", $request);

    if (my $def_headers = $self->{def_headers}) {
	for my $h ($def_headers->header_field_names) {
	    $request->init_header($h => [$def_headers->header($h)]);
	}
    }

    $self->run_handlers("request_prepare", $request);

    return $request;
}


sub simple_request
{
    my($self, $request, $arg, $size) = @_;

    # sanity check the request passed in
    if (defined $request) {
	if (ref $request) {
	    Carp::croak("You need a request object, not a " . ref($request) . " object")
	      if ref($request) eq 'ARRAY' or ref($request) eq 'HASH' or
		 !$request->can('method') or !$request->can('uri');
	}
	else {
	    Carp::croak("You need a request object, not '$request'");
	}
    }
    else {
        Carp::croak("No request object passed in");
    }

    my $error;
    try {
        $request = $self->prepare_request($request);
    }
    catch {
        $error = $_;
        $error =~ s/ at .* line \d+.*//s;  # remove file/line number
    };

    if ($error) {
        return _new_response($request, HTTP::Status::RC_BAD_REQUEST, $error);
    }
    return $self->send_request($request, $arg, $size);
}


sub request {
    my ($self, $request, $arg, $size, $previous) = @_;

    my $response = $self->simple_request($request, $arg, $size);
    $response->previous($previous) if $previous;

    if ($response->redirects >= $self->{max_redirect}) {
        $response->header("Client-Warning" =>
                "Redirect loop detected (max_redirect = $self->{max_redirect})"
        );
        return $response;
    }

    if (my $req = $self->run_handlers("response_redirect", $response)) {
        return $self->request($req, $arg, $size, $response);
    }

    my $code = $response->code;

    if (   $code == HTTP::Status::RC_MOVED_PERMANENTLY
        or $code == HTTP::Status::RC_FOUND
        or $code == HTTP::Status::RC_SEE_OTHER
        or $code == HTTP::Status::RC_TEMPORARY_REDIRECT)
    {
        my $referral = $request->clone;

        # These headers should never be forwarded
        $referral->remove_header('Host', 'Cookie');

        if (   $referral->header('Referer')
            && $request->uri->scheme eq 'https'
            && $referral->uri->scheme eq 'http')
        {
            # RFC 2616, section 15.1.3.
            # https -> http redirect, suppressing Referer
            $referral->remove_header('Referer');
        }

        if (   $code == HTTP::Status::RC_SEE_OTHER
            || $code == HTTP::Status::RC_FOUND)
        {
            my $method = uc($referral->method);
            unless ($method eq "GET" || $method eq "HEAD") {
                $referral->method("GET");
                $referral->content("");
                $referral->remove_content_headers;
            }
        }

        # And then we update the URL based on the Location:-header.
        my $referral_uri = $response->header('Location');
        {
            # Some servers erroneously return a relative URL for redirects,
            # so make it absolute if it not already is.
            local $URI::ABS_ALLOW_RELATIVE_SCHEME = 1;
            my $base = $response->base;
            $referral_uri = "" unless defined $referral_uri;
            $referral_uri
                = $HTTP::URI_CLASS->new($referral_uri, $base)->abs($base);
        }
        $referral->uri($referral_uri);

        return $response unless $self->redirect_ok($referral, $response);
        return $self->request($referral, $arg, $size, $response);

    }
    elsif ($code == HTTP::Status::RC_UNAUTHORIZED
        || $code == HTTP::Status::RC_PROXY_AUTHENTICATION_REQUIRED)
    {
        my $proxy = ($code == HTTP::Status::RC_PROXY_AUTHENTICATION_REQUIRED);
        my $ch_header
            = $proxy || $request->method eq 'CONNECT'
            ? "Proxy-Authenticate"
            : "WWW-Authenticate";
        my @challenges = $response->header($ch_header);
        unless (@challenges) {
            $response->header(
                "Client-Warning" => "Missing Authenticate header");
            return $response;
        }

        require HTTP::Headers::Util;
        CHALLENGE: for my $challenge (@challenges) {
            $challenge =~ tr/,/;/;    # "," is used to separate auth-params!!
            ($challenge) = HTTP::Headers::Util::split_header_words($challenge);
            my $scheme = shift(@$challenge);
            shift(@$challenge);       # no value
            $challenge = {@$challenge};    # make rest into a hash

            unless ($scheme =~ /^([a-z]+(?:-[a-z]+)*)$/) {
                $response->header(
                    "Client-Warning" => "Bad authentication scheme '$scheme'");
                return $response;
            }
            $scheme = $1;                  # untainted now
            my $class = "LWP::Authen::\u$scheme";
            $class =~ s/-/_/g;

            no strict 'refs';
            unless (%{"$class\::"}) {
                # try to load it
                my $error;
                try {
                    (my $req = $class) =~ s{::}{/}g;
                    $req .= '.pm' unless $req =~ /\.pm$/;
                    require $req;
                }
                catch {
                    $error = $_;
                };
                if ($error) {
                    if ($error =~ /^Can\'t locate/) {
                        $response->header("Client-Warning" =>
                                "Unsupported authentication scheme '$scheme'");
                    }
                    else {
                        $response->header("Client-Warning" => $error);
                    }
                    next CHALLENGE;
                }
            }
            unless ($class->can("authenticate")) {
                $response->header("Client-Warning" =>
                        "Unsupported authentication scheme '$scheme'");
                next CHALLENGE;
            }
            return $class->authenticate($self, $proxy, $challenge, $response,
                $request, $arg, $size);
        }
        return $response;
    }
    return $response;
}

#
# Now the shortcuts...
#
sub get {
    require HTTP::Request::Common;
    my($self, @parameters) = @_;
    my @suff = $self->_process_colonic_headers(\@parameters,1);
    return $self->request( HTTP::Request::Common::GET( @parameters ), @suff );
}

sub _has_raw_content {
    my $self = shift;
    shift; # drop url

    # taken from HTTP::Request::Common::request_type_with_data
    my $content;
    $content = shift if @_ and ref $_[0];
    my($k, $v);
    while (($k,$v) = splice(@_, 0, 2)) {
        if (lc($k) eq 'content') {
            $content = $v;
        }
    }

    # We were given Content => 'string' ...
    if (defined $content && ! ref ($content)) {
        return 1;
    }

    return;
}

sub _maybe_copy_default_content_type {
    my ($self, $req, @parameters) = @_;

    # If we have a default Content-Type and someone passes in a POST/PUT
    # with Content => 'some-string-value', use that Content-Type instead
    # of x-www-form-urlencoded
    my $ct = $self->default_header('Content-Type');
    return unless defined $ct && $self->_has_raw_content(@parameters);

    $req->header('Content-Type' => $ct);
}

sub post {
    require HTTP::Request::Common;
    my($self, @parameters) = @_;
    my @suff = $self->_process_colonic_headers(\@parameters, (ref($parameters[1]) ? 2 : 1));
    my $req = HTTP::Request::Common::POST(@parameters);
    $self->_maybe_copy_default_content_type($req, @parameters);
    return $self->request($req, @suff);
}


sub head {
    require HTTP::Request::Common;
    my($self, @parameters) = @_;
    my @suff = $self->_process_colonic_headers(\@parameters,1);
    return $self->request( HTTP::Request::Common::HEAD( @parameters ), @suff );
}


sub put {
    require HTTP::Request::Common;
    my($self, @parameters) = @_;
    my @suff = $self->_process_colonic_headers(\@parameters, (ref($parameters[1]) ? 2 : 1));
    my $req = HTTP::Request::Common::PUT(@parameters);
    $self->_maybe_copy_default_content_type($req, @parameters);
    return $self->request($req, @suff);
}


sub delete {
    require HTTP::Request::Common;
    my($self, @parameters) = @_;
    my @suff = $self->_process_colonic_headers(\@parameters,1);
    return $self->request( HTTP::Request::Common::DELETE( @parameters ), @suff );
}


sub _process_colonic_headers {
    # Process :content_cb / :content_file / :read_size_hint headers.
    my($self, $args, $start_index) = @_;

    my($arg, $size);
    for(my $i = $start_index; $i < @$args; $i += 2) {
	next unless defined $args->[$i];

	#printf "Considering %s => %s\n", $args->[$i], $args->[$i + 1];

	if($args->[$i] eq ':content_cb') {
	    # Some sanity-checking...
	    $arg = $args->[$i + 1];
	    Carp::croak("A :content_cb value can't be undef") unless defined $arg;
	    Carp::croak("A :content_cb value must be a coderef")
		unless ref $arg and UNIVERSAL::isa($arg, 'CODE');

	}
	elsif ($args->[$i] eq ':content_file') {
	    $arg = $args->[$i + 1];

	    # Some sanity-checking...
	    Carp::croak("A :content_file value can't be undef")
		unless defined $arg;
	    Carp::croak("A :content_file value can't be a reference")
		if ref $arg;
	    Carp::croak("A :content_file value can't be \"\"")
		unless length $arg;

	}
	elsif ($args->[$i] eq ':read_size_hint') {
	    $size = $args->[$i + 1];
	    # Bother checking it?

	}
	else {
	    next;
	}
	splice @$args, $i, 2;
	$i -= 2;
    }

    # And return a suitable suffix-list for request(REQ,...)

    return             unless defined $arg;
    return $arg, $size if     defined $size;
    return $arg;
}


sub is_online {
    my $self = shift;
    return 1 if $self->get("http://www.msftncsi.com/ncsi.txt")->content eq "Microsoft NCSI";
    return 1 if $self->get("http://www.apple.com")->content =~ m,<title>Apple</title>,;
    return 0;
}


my @ANI = qw(- \ | /);

sub progress {
    my($self, $status, $m) = @_;
    return unless $self->{show_progress};

    local($,, $\);
    if ($status eq "begin") {
        print STDERR "** ", $m->method, " ", $m->uri, " ==> ";
        $self->{progress_start} = time;
        $self->{progress_lastp} = "";
        $self->{progress_ani} = 0;
    }
    elsif ($status eq "end") {
        delete $self->{progress_lastp};
        delete $self->{progress_ani};
        print STDERR $m->status_line;
        my $t = time - delete $self->{progress_start};
        print STDERR " (${t}s)" if $t;
        print STDERR "\n";
    }
    elsif ($status eq "tick") {
        print STDERR "$ANI[$self->{progress_ani}++]\b";
        $self->{progress_ani} %= @ANI;
    }
    else {
        my $p = sprintf "%3.0f%%", $status * 100;
        return if $p eq $self->{progress_lastp};
        print STDERR "$p\b\b\b\b";
        $self->{progress_lastp} = $p;
    }
    STDERR->flush;
}


#
# This whole allow/forbid thing is based on man 1 at's way of doing things.
#
sub is_protocol_supported
{
    my($self, $scheme) = @_;
    if (ref $scheme) {
	# assume we got a reference to an URI object
	$scheme = $scheme->scheme;
    }
    else {
	Carp::croak("Illegal scheme '$scheme' passed to is_protocol_supported")
	    if $scheme =~ /\W/;
	$scheme = lc $scheme;
    }

    my $x;
    if(ref($self) and $x       = $self->protocols_allowed) {
      return 0 unless grep lc($_) eq $scheme, @$x;
    }
    elsif (ref($self) and $x = $self->protocols_forbidden) {
      return 0 if grep lc($_) eq $scheme, @$x;
    }

    local($SIG{__DIE__});  # protect against user defined die handlers
    $x = LWP::Protocol::implementor($scheme);
    return 1 if $x and $x ne 'LWP::Protocol::nogo';
    return 0;
}


sub protocols_allowed      { shift->_elem('protocols_allowed'    , @_) }
sub protocols_forbidden    { shift->_elem('protocols_forbidden'  , @_) }
sub requests_redirectable  { shift->_elem('requests_redirectable', @_) }


sub redirect_ok
{
    # RFC 2616, section 10.3.2 and 10.3.3 say:
    #  If the 30[12] status code is received in response to a request other
    #  than GET or HEAD, the user agent MUST NOT automatically redirect the
    #  request unless it can be confirmed by the user, since this might
    #  change the conditions under which the request was issued.

    # Note that this routine used to be just:
    #  return 0 if $_[1]->method eq "POST";  return 1;

    my($self, $new_request, $response) = @_;
    my $method = $response->request->method;
    return 0 unless grep $_ eq $method,
      @{ $self->requests_redirectable || [] };

    if ($new_request->uri->scheme eq 'file') {
      $response->header("Client-Warning" =>
			"Can't redirect to a file:// URL!");
      return 0;
    }

    # Otherwise it's apparently okay...
    return 1;
}


sub credentials
{
    my $self = shift;
    my $netloc = lc(shift);
    my $realm = shift || "";
    my $old = $self->{basic_authentication}{$netloc}{$realm};
    if (@_) {
        $self->{basic_authentication}{$netloc}{$realm} = [@_];
    }
    return unless $old;
    return @$old if wantarray;
    return join(":", @$old);
}


sub get_basic_credentials
{
    my($self, $realm, $uri, $proxy) = @_;
    return if $proxy;
    return $self->credentials($uri->host_port, $realm);
}


sub timeout      { shift->_elem('timeout',      @_); }
sub local_address{ shift->_elem('local_address',@_); }
sub max_size     { shift->_elem('max_size',     @_); }
sub max_redirect { shift->_elem('max_redirect', @_); }
sub show_progress{ shift->_elem('show_progress', @_); }

sub ssl_opts {
    my $self = shift;
    if (@_ == 1) {
	my $k = shift;
	return $self->{ssl_opts}{$k};
    }
    if (@_) {
	my $old;
	while (@_) {
	    my($k, $v) = splice(@_, 0, 2);
	    $old = $self->{ssl_opts}{$k} unless @_;
	    if (defined $v) {
		$self->{ssl_opts}{$k} = $v;
	    }
	    else {
		delete $self->{ssl_opts}{$k};
	    }
	}
	%{$self->{ssl_opts}} = (%{$self->{ssl_opts}}, @_);
	return $old;
    }

    return keys %{$self->{ssl_opts}};
}

sub parse_head {
    my $self = shift;
    if (@_) {
        my $flag = shift;
        my $parser;
        my $old = $self->set_my_handler("response_header", $flag ? sub {
               my($response, $ua) = @_;
               require HTML::HeadParser;
               $parser = HTML::HeadParser->new;
               $parser->xml_mode(1) if $response->content_is_xhtml;
               $parser->utf8_mode(1) if $] >= 5.008 && $HTML::Parser::VERSION >= 3.40;

               push(@{$response->{handlers}{response_data}}, {
		   callback => sub {
		       return unless $parser;
		       unless ($parser->parse($_[3])) {
			   my $h = $parser->header;
			   my $r = $_[0];
			   for my $f ($h->header_field_names) {
			       $r->init_header($f, [$h->header($f)]);
			   }
			   undef($parser);
		       }
		   },
	       });

            } : undef,
            m_media_type => "html",
        );
        return !!$old;
    }
    else {
        return !!$self->get_my_handler("response_header");
    }
}

sub cookie_jar {
    my $self = shift;
    my $old = $self->{cookie_jar};
    if (@_) {
	my $jar = shift;
	if (ref($jar) eq "HASH") {
	    require HTTP::Cookies;
	    $jar = HTTP::Cookies->new(%$jar);
	}
	$self->{cookie_jar} = $jar;
        $self->set_my_handler("request_prepare",
            $jar ? sub { $jar->add_cookie_header($_[0]); } : undef,
        );
        $self->set_my_handler("response_done",
            $jar ? sub { $jar->extract_cookies($_[0]); } : undef,
        );
    }
    $old;
}

sub default_headers {
    my $self = shift;
    my $old = $self->{def_headers} ||= HTTP::Headers->new;
    if (@_) {
	Carp::croak("default_headers not set to HTTP::Headers compatible object")
	    unless @_ == 1 && $_[0]->can("header_field_names");
	$self->{def_headers} = shift;
    }
    return $old;
}

sub default_header {
    my $self = shift;
    return $self->default_headers->header(@_);
}

sub _agent { "libwww-perl/$VERSION" }

sub agent {
    my $self = shift;
    if (@_) {
	my $agent = shift;
        if ($agent) {
            $agent .= $self->_agent if $agent =~ /\s+$/;
        }
        else {
            undef($agent)
        }
        return $self->default_header("User-Agent", $agent);
    }
    return $self->default_header("User-Agent");
}

sub from {  # legacy
    my $self = shift;
    return $self->default_header("From", @_);
}


sub conn_cache {
    my $self = shift;
    my $old = $self->{conn_cache};
    if (@_) {
	my $cache = shift;
	if (ref($cache) eq "HASH") {
	    require LWP::ConnCache;
	    $cache = LWP::ConnCache->new(%$cache);
	}
	$self->{conn_cache} = $cache;
    }
    $old;
}


sub add_handler {
    my($self, $phase, $cb, %spec) = @_;
    $spec{line} ||= join(":", (caller)[1,2]);
    my $conf = $self->{handlers}{$phase} ||= do {
        require HTTP::Config;
        HTTP::Config->new;
    };
    $conf->add(%spec, callback => $cb);
}

sub set_my_handler {
    my($self, $phase, $cb, %spec) = @_;
    $spec{owner} = (caller(1))[3] unless exists $spec{owner};
    $self->remove_handler($phase, %spec);
    $spec{line} ||= join(":", (caller)[1,2]);
    $self->add_handler($phase, $cb, %spec) if $cb;
}

sub get_my_handler {
    my $self = shift;
    my $phase = shift;
    my $init = pop if @_ % 2;
    my %spec = @_;
    my $conf = $self->{handlers}{$phase};
    unless ($conf) {
        return unless $init;
        require HTTP::Config;
        $conf = $self->{handlers}{$phase} = HTTP::Config->new;
    }
    $spec{owner} = (caller(1))[3] unless exists $spec{owner};
    my @h = $conf->find(%spec);
    if (!@h && $init) {
        if (ref($init) eq "CODE") {
            $init->(\%spec);
        }
        elsif (ref($init) eq "HASH") {
            while (my($k, $v) = each %$init) {
                $spec{$k} = $v;
            }
        }
        $spec{callback} ||= sub {};
        $spec{line} ||= join(":", (caller)[1,2]);
        $conf->add(\%spec);
        return \%spec;
    }
    return wantarray ? @h : $h[0];
}

sub remove_handler {
    my($self, $phase, %spec) = @_;
    if ($phase) {
        my $conf = $self->{handlers}{$phase} || return;
        my @h = $conf->remove(%spec);
        delete $self->{handlers}{$phase} if $conf->empty;
        return @h;
    }

    return unless $self->{handlers};
    return map $self->remove_handler($_), sort keys %{$self->{handlers}};
}

sub handlers {
    my($self, $phase, $o) = @_;
    my @h;
    if ($o->{handlers} && $o->{handlers}{$phase}) {
        push(@h, @{$o->{handlers}{$phase}});
    }
    if (my $conf = $self->{handlers}{$phase}) {
        push(@h, $conf->matching($o));
    }
    return @h;
}

sub run_handlers {
    my($self, $phase, $o) = @_;
    if (defined(wantarray)) {
        for my $h ($self->handlers($phase, $o)) {
            my $ret = $h->{callback}->($o, $self, $h);
            return $ret if $ret;
        }
        return undef;
    }

    for my $h ($self->handlers($phase, $o)) {
        $h->{callback}->($o, $self, $h);
    }
}


# deprecated
sub use_eval   { shift->_elem('use_eval',  @_); }
sub use_alarm
{
    Carp::carp("LWP::UserAgent->use_alarm(BOOL) is a no-op")
	if @_ > 1 && $^W;
    "";
}


sub clone
{
    my $self = shift;
    my $copy = bless { %$self }, ref $self;  # copy most fields

    delete $copy->{handlers};
    delete $copy->{conn_cache};

    # copy any plain arrays and hashes; known not to need recursive copy
    for my $k (qw(proxy no_proxy requests_redirectable ssl_opts)) {
        next unless $copy->{$k};
        if (ref($copy->{$k}) eq "ARRAY") {
            $copy->{$k} = [ @{$copy->{$k}} ];
        }
        elsif (ref($copy->{$k}) eq "HASH") {
            $copy->{$k} = { %{$copy->{$k}} };
        }
    }

    if ($self->{def_headers}) {
        $copy->{def_headers} = $self->{def_headers}->clone;
    }

    # re-enable standard handlers
    $copy->parse_head($self->parse_head);

    # no easy way to clone the cookie jar; so let's just remove it for now
    $copy->cookie_jar(undef);

    $copy;
}


sub mirror
{
    my($self, $url, $file) = @_;

    my $request = HTTP::Request->new('GET', $url);

    # If the file exists, add a cache-related header
    if ( -e $file ) {
        my ($mtime) = ( stat($file) )[9];
        if ($mtime) {
            $request->header( 'If-Modified-Since' => HTTP::Date::time2str($mtime) );
        }
    }
    my $tmpfile = "$file-$$";

    my $response = $self->request($request, $tmpfile);
    if ( $response->header('X-Died') ) {
	die $response->header('X-Died');
    }

    # Only fetching a fresh copy of the would be considered success.
    # If the file was not modified, "304" would returned, which
    # is considered by HTTP::Status to be a "redirect", /not/ "success"
    if ( $response->is_success ) {
        my @stat        = stat($tmpfile) or die "Could not stat tmpfile '$tmpfile': $!";
        my $file_length = $stat[7];
        my ($content_length) = $response->header('Content-length');

        if ( defined $content_length and $file_length < $content_length ) {
            unlink($tmpfile);
            die "Transfer truncated: " . "only $file_length out of $content_length bytes received\n";
        }
        elsif ( defined $content_length and $file_length > $content_length ) {
            unlink($tmpfile);
            die "Content-length mismatch: " . "expected $content_length bytes, got $file_length\n";
        }
        # The file was the expected length.
        else {
            # Replace the stale file with a fresh copy
            if ( -e $file ) {
                # Some DOSish systems fail to rename if the target exists
                chmod 0777, $file;
                unlink $file;
            }
            rename( $tmpfile, $file )
                or die "Cannot rename '$tmpfile' to '$file': $!\n";

            # make sure the file has the same last modification time
            if ( my $lm = $response->last_modified ) {
                utime $lm, $lm, $file;
            }
        }
    }
    # The local copy is fresh enough, so just delete the temp file
    else {
	unlink($tmpfile);
    }
    return $response;
}


sub _need_proxy {
    my($req, $ua) = @_;
    return if exists $req->{proxy};
    my $proxy = $ua->{proxy}{$req->uri->scheme} || return;
    if ($ua->{no_proxy}) {
        if (my $host = eval { $req->uri->host }) {
            for my $domain (@{$ua->{no_proxy}}) {
                if ($host =~ /\Q$domain\E$/) {
                    return;
                }
            }
        }
    }
    $req->{proxy} = $HTTP::URI_CLASS->new($proxy);
}


sub proxy {
    my $self = shift;
    my $key  = shift;
    if (!@_ && ref $key eq 'ARRAY') {
        die 'odd number of items in proxy arrayref!' unless @{$key} % 2 == 0;

        # This map reads the elements of $key 2 at a time
        return
            map { $self->proxy($key->[2 * $_], $key->[2 * $_ + 1]) }
            (0 .. @{$key} / 2 - 1);
    }
    return map { $self->proxy($_, @_) } @$key if ref $key;

    Carp::croak("'$key' is not a valid URI scheme") unless $key =~ /^$URI::scheme_re\z/;
    my $old = $self->{'proxy'}{$key};
    if (@_) {
        my $url = shift;
        if (defined($url) && length($url)) {
            Carp::croak("Proxy must be specified as absolute URI; '$url' is not") unless $url =~ /^$URI::scheme_re:/;
            Carp::croak("Bad http proxy specification '$url'") if $url =~ /^https?:/ && $url !~ m,^https?://\w,;
        }
        $self->{proxy}{$key} = $url;
        $self->set_my_handler("request_preprepare", \&_need_proxy)
    }
    return $old;
}


sub env_proxy {
    my ($self) = @_;
    require Encode;
    require Encode::Locale;
    my($k,$v);
    while(($k, $v) = each %ENV) {
	if ($ENV{REQUEST_METHOD}) {
	    # Need to be careful when called in the CGI environment, as
	    # the HTTP_PROXY variable is under control of that other guy.
	    next if $k =~ /^HTTP_/;
	    $k = "HTTP_PROXY" if $k eq "CGI_HTTP_PROXY";
	}
	$k = lc($k);
	next unless $k =~ /^(.*)_proxy$/;
	$k = $1;
	if ($k eq 'no') {
	    $self->no_proxy(split(/\s*,\s*/, $v));
	}
	else {
            # Ignore random _proxy variables, allow only valid schemes
            next unless $k =~ /^$URI::scheme_re\z/;
            # Ignore xxx_proxy variables if xxx isn't a supported protocol
            next unless LWP::Protocol::implementor($k);
	    $self->proxy($k, Encode::decode(locale => $v));
	}
    }
}


sub no_proxy {
    my($self, @no) = @_;
    if (@no) {
	push(@{ $self->{'no_proxy'} }, @no);
    }
    else {
	$self->{'no_proxy'} = [];
    }
}


sub _new_response {
    my($request, $code, $message, $content) = @_;
    $message ||= HTTP::Status::status_message($code);
    my $response = HTTP::Response->new($code, $message);
    $response->request($request);
    $response->header("Client-Date" => HTTP::Date::time2str(time));
    $response->header("Client-Warning" => "Internal response");
    $response->header("Content-Type" => "text/plain");
    $response->content($content || "$code $message\n");
    return $response;
}


1;

__END__

#line 1993

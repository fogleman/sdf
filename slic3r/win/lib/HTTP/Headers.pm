#line 1 "HTTP/Headers.pm"
package HTTP::Headers;

use strict;
use warnings;

use Carp ();

our $VERSION = "6.11";

# The $TRANSLATE_UNDERSCORE variable controls whether '_' can be used
# as a replacement for '-' in header field names.
our $TRANSLATE_UNDERSCORE = 1 unless defined $TRANSLATE_UNDERSCORE;

# "Good Practice" order of HTTP message headers:
#    - General-Headers
#    - Request-Headers
#    - Response-Headers
#    - Entity-Headers

my @general_headers = qw(
    Cache-Control Connection Date Pragma Trailer Transfer-Encoding Upgrade
    Via Warning
);

my @request_headers = qw(
    Accept Accept-Charset Accept-Encoding Accept-Language
    Authorization Expect From Host
    If-Match If-Modified-Since If-None-Match If-Range If-Unmodified-Since
    Max-Forwards Proxy-Authorization Range Referer TE User-Agent
);

my @response_headers = qw(
    Accept-Ranges Age ETag Location Proxy-Authenticate Retry-After Server
    Vary WWW-Authenticate
);

my @entity_headers = qw(
    Allow Content-Encoding Content-Language Content-Length Content-Location
    Content-MD5 Content-Range Content-Type Expires Last-Modified
);

my %entity_header = map { lc($_) => 1 } @entity_headers;

my @header_order = (
    @general_headers,
    @request_headers,
    @response_headers,
    @entity_headers,
);

# Make alternative representations of @header_order.  This is used
# for sorting and case matching.
my %header_order;
my %standard_case;

{
    my $i = 0;
    for (@header_order) {
	my $lc = lc $_;
	$header_order{$lc} = ++$i;
	$standard_case{$lc} = $_;
    }
}



sub new
{
    my($class) = shift;
    my $self = bless {}, $class;
    $self->header(@_) if @_; # set up initial headers
    $self;
}


sub header
{
    my $self = shift;
    Carp::croak('Usage: $h->header($field, ...)') unless @_;
    my(@old);
    my %seen;
    while (@_) {
	my $field = shift;
        my $op = @_ ? ($seen{lc($field)}++ ? 'PUSH' : 'SET') : 'GET';
	@old = $self->_header($field, shift, $op);
    }
    return @old if wantarray;
    return $old[0] if @old <= 1;
    join(", ", @old);
}

sub clear
{
    my $self = shift;
    %$self = ();
}


sub push_header
{
    my $self = shift;
    return $self->_header(@_, 'PUSH_H') if @_ == 2;
    while (@_) {
	$self->_header(splice(@_, 0, 2), 'PUSH_H');
    }
}


sub init_header
{
    Carp::croak('Usage: $h->init_header($field, $val)') if @_ != 3;
    shift->_header(@_, 'INIT');
}


sub remove_header
{
    my($self, @fields) = @_;
    my $field;
    my @values;
    foreach $field (@fields) {
	$field =~ tr/_/-/ if $field !~ /^:/ && $TRANSLATE_UNDERSCORE;
	my $v = delete $self->{lc $field};
	push(@values, ref($v) eq 'ARRAY' ? @$v : $v) if defined $v;
    }
    return @values;
}

sub remove_content_headers
{
    my $self = shift;
    unless (defined(wantarray)) {
	# fast branch that does not create return object
	delete @$self{grep $entity_header{$_} || /^content-/, keys %$self};
	return;
    }

    my $c = ref($self)->new;
    for my $f (grep $entity_header{$_} || /^content-/, keys %$self) {
	$c->{$f} = delete $self->{$f};
    }
    if (exists $self->{'::std_case'}) {
	$c->{'::std_case'} = $self->{'::std_case'};
    }
    $c;
}


sub _header
{
    my($self, $field, $val, $op) = @_;

    Carp::croak("Illegal field name '$field'")
        if rindex($field, ':') > 1 || !length($field);

    unless ($field =~ /^:/) {
	$field =~ tr/_/-/ if $TRANSLATE_UNDERSCORE;
	my $old = $field;
	$field = lc $field;
	unless($standard_case{$field} || $self->{'::std_case'}{$field}) {
	    # generate a %std_case entry for this field
	    $old =~ s/\b(\w)/\u$1/g;
	    $self->{'::std_case'}{$field} = $old;
	}
    }

    $op ||= defined($val) ? 'SET' : 'GET';
    if ($op eq 'PUSH_H') {
	# Like PUSH but where we don't care about the return value
	if (exists $self->{$field}) {
	    my $h = $self->{$field};
	    if (ref($h) eq 'ARRAY') {
		push(@$h, ref($val) eq "ARRAY" ? @$val : $val);
	    }
	    else {
		$self->{$field} = [$h, ref($val) eq "ARRAY" ? @$val : $val]
	    }
	    return;
	}
	$self->{$field} = $val;
	return;
    }

    my $h = $self->{$field};
    my @old = ref($h) eq 'ARRAY' ? @$h : (defined($h) ? ($h) : ());

    unless ($op eq 'GET' || ($op eq 'INIT' && @old)) {
	if (defined($val)) {
	    my @new = ($op eq 'PUSH') ? @old : ();
	    if (ref($val) ne 'ARRAY') {
		push(@new, $val);
	    }
	    else {
		push(@new, @$val);
	    }
	    $self->{$field} = @new > 1 ? \@new : $new[0];
	}
	elsif ($op ne 'PUSH') {
	    delete $self->{$field};
	}
    }
    @old;
}


sub _sorted_field_names
{
    my $self = shift;
    return [ sort {
        ($header_order{$a} || 999) <=> ($header_order{$b} || 999) ||
         $a cmp $b
    } grep !/^::/, keys %$self ];
}


sub header_field_names {
    my $self = shift;
    return map $standard_case{$_} || $self->{'::std_case'}{$_} || $_, @{ $self->_sorted_field_names },
	if wantarray;
    return grep !/^::/, keys %$self;
}


sub scan
{
    my($self, $sub) = @_;
    my $key;
    for $key (@{ $self->_sorted_field_names }) {
	my $vals = $self->{$key};
	if (ref($vals) eq 'ARRAY') {
	    my $val;
	    for $val (@$vals) {
		$sub->($standard_case{$key} || $self->{'::std_case'}{$key} || $key, $val);
	    }
	}
	else {
	    $sub->($standard_case{$key} || $self->{'::std_case'}{$key} || $key, $vals);
	}
    }
}

sub flatten {
	my($self)=@_;

	(
		map {
			my $k = $_;
			map {
				( $k => $_ )
			} $self->header($_);
		} $self->header_field_names
	);
}

sub as_string
{
    my($self, $endl) = @_;
    $endl = "\n" unless defined $endl;

    my @result = ();
    for my $key (@{ $self->_sorted_field_names }) {
	next if index($key, '_') == 0;
	my $vals = $self->{$key};
	if ( ref($vals) eq 'ARRAY' ) {
	    for my $val (@$vals) {
		$val = '' if not defined $val;
		my $field = $standard_case{$key} || $self->{'::std_case'}{$key} || $key;
		$field =~ s/^://;
		if ( index($val, "\n") >= 0 ) {
		    $val = _process_newline($val, $endl);
		}
		push @result, $field . ': ' . $val;
	    }
	}
	else {
	    $vals = '' if not defined $vals;
	    my $field = $standard_case{$key} || $self->{'::std_case'}{$key} || $key;
	    $field =~ s/^://;
	    if ( index($vals, "\n") >= 0 ) {
		$vals = _process_newline($vals, $endl);
	    }
	    push @result, $field . ': ' . $vals;
	}
    }

    join($endl, @result, '');
}

sub _process_newline {
    local $_ = shift;
    my $endl = shift;
    # must handle header values with embedded newlines with care
    s/\s+$//;        # trailing newlines and space must go
    s/\n(\x0d?\n)+/\n/g;     # no empty lines
    s/\n([^\040\t])/\n $1/g; # initial space for continuation
    s/\n/$endl/g;    # substitute with requested line ending
    $_;
}



if (eval { require Storable; 1 }) {
    *clone = \&Storable::dclone;
} else {
    *clone = sub {
	my $self = shift;
	my $clone = HTTP::Headers->new;
	$self->scan(sub { $clone->push_header(@_);} );
	$clone;
    };
}


sub _date_header
{
    require HTTP::Date;
    my($self, $header, $time) = @_;
    my($old) = $self->_header($header);
    if (defined $time) {
	$self->_header($header, HTTP::Date::time2str($time));
    }
    $old =~ s/;.*// if defined($old);
    HTTP::Date::str2time($old);
}


sub date                { shift->_date_header('Date',                @_); }
sub expires             { shift->_date_header('Expires',             @_); }
sub if_modified_since   { shift->_date_header('If-Modified-Since',   @_); }
sub if_unmodified_since { shift->_date_header('If-Unmodified-Since', @_); }
sub last_modified       { shift->_date_header('Last-Modified',       @_); }

# This is used as a private LWP extension.  The Client-Date header is
# added as a timestamp to a response when it has been received.
sub client_date         { shift->_date_header('Client-Date',         @_); }

# The retry_after field is dual format (can also be a expressed as
# number of seconds from now), so we don't provide an easy way to
# access it until we have know how both these interfaces can be
# addressed.  One possibility is to return a negative value for
# relative seconds and a positive value for epoch based time values.
#sub retry_after       { shift->_date_header('Retry-After',       @_); }

sub content_type      {
    my $self = shift;
    my $ct = $self->{'content-type'};
    $self->{'content-type'} = shift if @_;
    $ct = $ct->[0] if ref($ct) eq 'ARRAY';
    return '' unless defined($ct) && length($ct);
    my @ct = split(/;\s*/, $ct, 2);
    for ($ct[0]) {
	s/\s+//g;
	$_ = lc($_);
    }
    wantarray ? @ct : $ct[0];
}

sub content_type_charset {
    my $self = shift;
    require HTTP::Headers::Util;
    my $h = $self->{'content-type'};
    $h = $h->[0] if ref($h);
    $h = "" unless defined $h;
    my @v = HTTP::Headers::Util::split_header_words($h);
    if (@v) {
	my($ct, undef, %ct_param) = @{$v[0]};
	my $charset = $ct_param{charset};
	if ($ct) {
	    $ct = lc($ct);
	    $ct =~ s/\s+//;
	}
	if ($charset) {
	    $charset = uc($charset);
	    $charset =~ s/^\s+//;  $charset =~ s/\s+\z//;
	    undef($charset) if $charset eq "";
	}
	return $ct, $charset if wantarray;
	return $charset;
    }
    return undef, undef if wantarray;
    return undef;
}

sub content_is_text {
    my $self = shift;
    return $self->content_type =~ m,^text/,;
}

sub content_is_html {
    my $self = shift;
    return $self->content_type eq 'text/html' || $self->content_is_xhtml;
}

sub content_is_xhtml {
    my $ct = shift->content_type;
    return $ct eq "application/xhtml+xml" ||
           $ct eq "application/vnd.wap.xhtml+xml";
}

sub content_is_xml {
    my $ct = shift->content_type;
    return 1 if $ct eq "text/xml";
    return 1 if $ct eq "application/xml";
    return 1 if $ct =~ /\+xml$/;
    return 0;
}

sub referer           {
    my $self = shift;
    if (@_ && $_[0] =~ /#/) {
	# Strip fragment per RFC 2616, section 14.36.
	my $uri = shift;
	if (ref($uri)) {
	    $uri = $uri->clone;
	    $uri->fragment(undef);
	}
	else {
	    $uri =~ s/\#.*//;
	}
	unshift @_, $uri;
    }
    ($self->_header('Referer', @_))[0];
}
*referrer = \&referer;  # on tchrist's request

sub title             { (shift->_header('Title',            @_))[0] }
sub content_encoding  { (shift->_header('Content-Encoding', @_))[0] }
sub content_language  { (shift->_header('Content-Language', @_))[0] }
sub content_length    { (shift->_header('Content-Length',   @_))[0] }

sub user_agent        { (shift->_header('User-Agent',       @_))[0] }
sub server            { (shift->_header('Server',           @_))[0] }

sub from              { (shift->_header('From',             @_))[0] }
sub warning           { (shift->_header('Warning',          @_))[0] }

sub www_authenticate  { (shift->_header('WWW-Authenticate', @_))[0] }
sub authorization     { (shift->_header('Authorization',    @_))[0] }

sub proxy_authenticate  { (shift->_header('Proxy-Authenticate',  @_))[0] }
sub proxy_authorization { (shift->_header('Proxy-Authorization', @_))[0] }

sub authorization_basic       { shift->_basic_auth("Authorization",       @_) }
sub proxy_authorization_basic { shift->_basic_auth("Proxy-Authorization", @_) }

sub _basic_auth {
    require MIME::Base64;
    my($self, $h, $user, $passwd) = @_;
    my($old) = $self->_header($h);
    if (defined $user) {
	Carp::croak("Basic authorization user name can't contain ':'")
	  if $user =~ /:/;
	$passwd = '' unless defined $passwd;
	$self->_header($h => 'Basic ' .
                             MIME::Base64::encode("$user:$passwd", ''));
    }
    if (defined $old && $old =~ s/^\s*Basic\s+//) {
	my $val = MIME::Base64::decode($old);
	return $val unless wantarray;
	return split(/:/, $val, 2);
    }
    return;
}


1;

__END__

#line 874

#line 1 "HTTP/Message.pm"
package HTTP::Message;

use strict;
use warnings;

our $VERSION = "6.11";

require HTTP::Headers;
require Carp;

my $CRLF = "\015\012";   # "\r\n" is not portable
unless ($HTTP::URI_CLASS) {
    if ($ENV{PERL_HTTP_URI_CLASS}
    &&  $ENV{PERL_HTTP_URI_CLASS} =~ /^([\w:]+)$/) {
        $HTTP::URI_CLASS = $1;
    } else {
        $HTTP::URI_CLASS = "URI";
    }
}
eval "require $HTTP::URI_CLASS"; die $@ if $@;

*_utf8_downgrade = defined(&utf8::downgrade) ?
    sub {
        utf8::downgrade($_[0], 1) or
            Carp::croak("HTTP::Message content must be bytes")
    }
    :
    sub {
    };

sub new
{
    my($class, $header, $content) = @_;
    if (defined $header) {
	Carp::croak("Bad header argument") unless ref $header;
        if (ref($header) eq "ARRAY") {
	    $header = HTTP::Headers->new(@$header);
	}
	else {
	    $header = $header->clone;
	}
    }
    else {
	$header = HTTP::Headers->new;
    }
    if (defined $content) {
        _utf8_downgrade($content);
    }
    else {
        $content = '';
    }

    bless {
	'_headers' => $header,
	'_content' => $content,
    }, $class;
}


sub parse
{
    my($class, $str) = @_;

    my @hdr;
    while (1) {
	if ($str =~ s/^([^\s:]+)[ \t]*: ?(.*)\n?//) {
	    push(@hdr, $1, $2);
	    $hdr[-1] =~ s/\r\z//;
	}
	elsif (@hdr && $str =~ s/^([ \t].*)\n?//) {
	    $hdr[-1] .= "\n$1";
	    $hdr[-1] =~ s/\r\z//;
	}
	else {
	    $str =~ s/^\r?\n//;
	    last;
	}
    }
    local $HTTP::Headers::TRANSLATE_UNDERSCORE;
    new($class, \@hdr, $str);
}


sub clone
{
    my $self  = shift;
    my $clone = HTTP::Message->new($self->headers,
				   $self->content);
    $clone->protocol($self->protocol);
    $clone;
}


sub clear {
    my $self = shift;
    $self->{_headers}->clear;
    $self->content("");
    delete $self->{_parts};
    return;
}


sub protocol {
    shift->_elem('_protocol',  @_);
}

sub headers {
    my $self = shift;

    # recalculation of _content might change headers, so we
    # need to force it now
    $self->_content unless exists $self->{_content};

    $self->{_headers};
}

sub headers_as_string {
    shift->headers->as_string(@_);
}


sub content  {

    my $self = $_[0];
    if (defined(wantarray)) {
	$self->_content unless exists $self->{_content};
	my $old = $self->{_content};
	$old = $$old if ref($old) eq "SCALAR";
	&_set_content if @_ > 1;
	return $old;
    }

    if (@_ > 1) {
	&_set_content;
    }
    else {
	Carp::carp("Useless content call in void context") if $^W;
    }
}


sub _set_content {
    my $self = $_[0];
    _utf8_downgrade($_[1]);
    if (!ref($_[1]) && ref($self->{_content}) eq "SCALAR") {
	${$self->{_content}} = $_[1];
    }
    else {
	die "Can't set content to be a scalar reference" if ref($_[1]) eq "SCALAR";
	$self->{_content} = $_[1];
	delete $self->{_content_ref};
    }
    delete $self->{_parts} unless $_[2];
}


sub add_content
{
    my $self = shift;
    $self->_content unless exists $self->{_content};
    my $chunkref = \$_[0];
    $chunkref = $$chunkref if ref($$chunkref);  # legacy

    _utf8_downgrade($$chunkref);

    my $ref = ref($self->{_content});
    if (!$ref) {
	$self->{_content} .= $$chunkref;
    }
    elsif ($ref eq "SCALAR") {
	${$self->{_content}} .= $$chunkref;
    }
    else {
	Carp::croak("Can't append to $ref content");
    }
    delete $self->{_parts};
}

sub add_content_utf8 {
    my($self, $buf)  = @_;
    utf8::upgrade($buf);
    utf8::encode($buf);
    $self->add_content($buf);
}

sub content_ref
{
    my $self = shift;
    $self->_content unless exists $self->{_content};
    delete $self->{_parts};
    my $old = \$self->{_content};
    my $old_cref = $self->{_content_ref};
    if (@_) {
	my $new = shift;
	Carp::croak("Setting content_ref to a non-ref") unless ref($new);
	delete $self->{_content};  # avoid modifying $$old
	$self->{_content} = $new;
	$self->{_content_ref}++;
    }
    $old = $$old if $old_cref;
    return $old;
}


sub content_charset
{
    my $self = shift;
    if (my $charset = $self->content_type_charset) {
	return $charset;
    }

    # time to start guessing
    my $cref = $self->decoded_content(ref => 1, charset => "none");

    # Unicode BOM
    for ($$cref) {
	return "UTF-8"     if /^\xEF\xBB\xBF/;
	return "UTF-32LE" if /^\xFF\xFE\x00\x00/;
	return "UTF-32BE" if /^\x00\x00\xFE\xFF/;
	return "UTF-16LE" if /^\xFF\xFE/;
	return "UTF-16BE" if /^\xFE\xFF/;
    }

    if ($self->content_is_xml) {
	# http://www.w3.org/TR/2006/REC-xml-20060816/#sec-guessing
	# XML entity not accompanied by external encoding information and not
	# in UTF-8 or UTF-16 encoding must begin with an XML encoding declaration,
	# in which the first characters must be '<?xml'
	for ($$cref) {
	    return "UTF-32BE" if /^\x00\x00\x00</;
	    return "UTF-32LE" if /^<\x00\x00\x00/;
	    return "UTF-16BE" if /^(?:\x00\s)*\x00</;
	    return "UTF-16LE" if /^(?:\s\x00)*<\x00/;
	    if (/^\s*(<\?xml[^\x00]*?\?>)/) {
		if ($1 =~ /\sencoding\s*=\s*(["'])(.*?)\1/) {
		    my $enc = $2;
		    $enc =~ s/^\s+//; $enc =~ s/\s+\z//;
		    return $enc if $enc;
		}
	    }
	}
	return "UTF-8";
    }
    elsif ($self->content_is_html) {
	# look for <META charset="..."> or <META content="...">
	# http://dev.w3.org/html5/spec/Overview.html#determining-the-character-encoding
	require IO::HTML;
	# Use relaxed search to match previous versions of HTTP::Message:
	my $encoding = IO::HTML::find_charset_in($$cref, { encoding    => 1,
	                                                   need_pragma => 0 });
	return $encoding->mime_name if $encoding;
    }
    elsif ($self->content_type eq "application/json") {
	for ($$cref) {
	    # RFC 4627, ch 3
	    return "UTF-32BE" if /^\x00\x00\x00./s;
	    return "UTF-32LE" if /^.\x00\x00\x00/s;
	    return "UTF-16BE" if /^\x00.\x00./s;
	    return "UTF-16LE" if /^.\x00.\x00/s;
	    return "UTF-8";
	}
    }
    if ($self->content_type =~ /^text\//) {
	for ($$cref) {
	    if (length) {
		return "US-ASCII" unless /[\x80-\xFF]/;
		require Encode;
		eval {
		    Encode::decode_utf8($_, Encode::FB_CROAK() | Encode::LEAVE_SRC());
		};
		return "UTF-8" unless $@;
		return "ISO-8859-1";
	    }
	}
    }

    return undef;
}


sub decoded_content
{
    my($self, %opt) = @_;
    my $content_ref;
    my $content_ref_iscopy;

    eval {
	$content_ref = $self->content_ref;
	die "Can't decode ref content" if ref($content_ref) ne "SCALAR";

	if (my $h = $self->header("Content-Encoding")) {
	    $h =~ s/^\s+//;
	    $h =~ s/\s+$//;
	    for my $ce (reverse split(/\s*,\s*/, lc($h))) {
		next unless $ce;
		next if $ce eq "identity" || $ce eq "none";
		if ($ce eq "gzip" || $ce eq "x-gzip") {
		    require IO::Uncompress::Gunzip;
		    my $output;
		    IO::Uncompress::Gunzip::gunzip($content_ref, \$output, Transparent => 0)
			or die "Can't gunzip content: $IO::Uncompress::Gunzip::GunzipError";
		    $content_ref = \$output;
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "x-bzip2" or $ce eq "bzip2") {
		    require IO::Uncompress::Bunzip2;
		    my $output;
		    IO::Uncompress::Bunzip2::bunzip2($content_ref, \$output, Transparent => 0)
			or die "Can't bunzip content: $IO::Uncompress::Bunzip2::Bunzip2Error";
		    $content_ref = \$output;
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "deflate") {
		    require IO::Uncompress::Inflate;
		    my $output;
		    my $status = IO::Uncompress::Inflate::inflate($content_ref, \$output, Transparent => 0);
		    my $error = $IO::Uncompress::Inflate::InflateError;
		    unless ($status) {
			# "Content-Encoding: deflate" is supposed to mean the
			# "zlib" format of RFC 1950, but Microsoft got that
			# wrong, so some servers sends the raw compressed
			# "deflate" data.  This tries to inflate this format.
			$output = undef;
			require IO::Uncompress::RawInflate;
			unless (IO::Uncompress::RawInflate::rawinflate($content_ref, \$output)) {
			    $self->push_header("Client-Warning" =>
				"Could not raw inflate content: $IO::Uncompress::RawInflate::RawInflateError");
			    $output = undef;
			}
		    }
		    die "Can't inflate content: $error" unless defined $output;
		    $content_ref = \$output;
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "compress" || $ce eq "x-compress") {
		    die "Can't uncompress content";
		}
		elsif ($ce eq "base64") {  # not really C-T-E, but should be harmless
		    require MIME::Base64;
		    $content_ref = \MIME::Base64::decode($$content_ref);
		    $content_ref_iscopy++;
		}
		elsif ($ce eq "quoted-printable") { # not really C-T-E, but should be harmless
		    require MIME::QuotedPrint;
		    $content_ref = \MIME::QuotedPrint::decode($$content_ref);
		    $content_ref_iscopy++;
		}
		else {
		    die "Don't know how to decode Content-Encoding '$ce'";
		}
	    }
	}

	if ($self->content_is_text || (my $is_xml = $self->content_is_xml)) {
	    my $charset = lc(
	        $opt{charset} ||
		$self->content_type_charset ||
		$opt{default_charset} ||
		$self->content_charset ||
		"ISO-8859-1"
	    );
	    if ($charset eq "none") {
		# leave it as is
	    }
	    elsif ($charset eq "us-ascii" || $charset eq "iso-8859-1") {
		if ($$content_ref =~ /[^\x00-\x7F]/ && defined &utf8::upgrade) {
		    unless ($content_ref_iscopy) {
			my $copy = $$content_ref;
			$content_ref = \$copy;
			$content_ref_iscopy++;
		    }
		    utf8::upgrade($$content_ref);
		}
	    }
	    else {
		require Encode;
		eval {
		    $content_ref = \Encode::decode($charset, $$content_ref,
			 ($opt{charset_strict} ? Encode::FB_CROAK() : 0) | Encode::LEAVE_SRC());
		};
		if ($@) {
		    my $retried;
		    if ($@ =~ /^Unknown encoding/) {
			my $alt_charset = lc($opt{alt_charset} || "");
			if ($alt_charset && $charset ne $alt_charset) {
			    # Retry decoding with the alternative charset
			    $content_ref = \Encode::decode($alt_charset, $$content_ref,
				 ($opt{charset_strict} ? Encode::FB_CROAK() : 0) | Encode::LEAVE_SRC())
			        unless $alt_charset eq "none";
			    $retried++;
			}
		    }
		    die unless $retried;
		}
		die "Encode::decode() returned undef improperly" unless defined $$content_ref;
		if ($is_xml) {
		    # Get rid of the XML encoding declaration if present
		    $$content_ref =~ s/^\x{FEFF}//;
		    if ($$content_ref =~ /^(\s*<\?xml[^\x00]*?\?>)/) {
			substr($$content_ref, 0, length($1)) =~ s/\sencoding\s*=\s*(["']).*?\1//;
		    }
		}
	    }
	}
    };
    if ($@) {
	Carp::croak($@) if $opt{raise_error};
	return undef;
    }

    return $opt{ref} ? $content_ref : $$content_ref;
}


sub decodable
{
    # should match the Content-Encoding values that decoded_content can deal with
    my $self = shift;
    my @enc;
    # XXX preferably we should determine if the modules are available without loading
    # them here
    eval {
        require IO::Uncompress::Gunzip;
        push(@enc, "gzip", "x-gzip");
    };
    eval {
        require IO::Uncompress::Inflate;
        require IO::Uncompress::RawInflate;
        push(@enc, "deflate");
    };
    eval {
        require IO::Uncompress::Bunzip2;
        push(@enc, "x-bzip2");
    };
    # we don't care about announcing the 'identity', 'base64' and
    # 'quoted-printable' stuff
    return wantarray ? @enc : join(", ", @enc);
}


sub decode
{
    my $self = shift;
    return 1 unless $self->header("Content-Encoding");
    if (defined(my $content = $self->decoded_content(charset => "none"))) {
	$self->remove_header("Content-Encoding", "Content-Length", "Content-MD5");
	$self->content($content);
	return 1;
    }
    return 0;
}


sub encode
{
    my($self, @enc) = @_;

    Carp::croak("Can't encode multipart/* messages") if $self->content_type =~ m,^multipart/,;
    Carp::croak("Can't encode message/* messages") if $self->content_type =~ m,^message/,;

    return 1 unless @enc;  # nothing to do

    my $content = $self->content;
    for my $encoding (@enc) {
	if ($encoding eq "identity") {
	    # nothing to do
	}
	elsif ($encoding eq "base64") {
	    require MIME::Base64;
	    $content = MIME::Base64::encode($content);
	}
	elsif ($encoding eq "gzip" || $encoding eq "x-gzip") {
	    require IO::Compress::Gzip;
	    my $output;
	    IO::Compress::Gzip::gzip(\$content, \$output, Minimal => 1)
		or die "Can't gzip content: $IO::Compress::Gzip::GzipError";
	    $content = $output;
	}
	elsif ($encoding eq "deflate") {
	    require IO::Compress::Deflate;
	    my $output;
	    IO::Compress::Deflate::deflate(\$content, \$output)
		or die "Can't deflate content: $IO::Compress::Deflate::DeflateError";
	    $content = $output;
	}
	elsif ($encoding eq "x-bzip2") {
	    require IO::Compress::Bzip2;
	    my $output;
	    IO::Compress::Bzip2::bzip2(\$content, \$output)
		or die "Can't bzip2 content: $IO::Compress::Bzip2::Bzip2Error";
	    $content = $output;
	}
	elsif ($encoding eq "rot13") {  # for the fun of it
	    $content =~ tr/A-Za-z/N-ZA-Mn-za-m/;
	}
	else {
	    return 0;
	}
    }
    my $h = $self->header("Content-Encoding");
    unshift(@enc, $h) if $h;
    $self->header("Content-Encoding", join(", ", @enc));
    $self->remove_header("Content-Length", "Content-MD5");
    $self->content($content);
    return 1;
}


sub as_string
{
    my($self, $eol) = @_;
    $eol = "\n" unless defined $eol;

    # The calculation of content might update the headers
    # so we need to do that first.
    my $content = $self->content;

    return join("", $self->{'_headers'}->as_string($eol),
		    $eol,
		    $content,
		    (@_ == 1 && length($content) &&
		     $content !~ /\n\z/) ? "\n" : "",
		);
}


sub dump
{
    my($self, %opt) = @_;
    my $content = $self->content;
    my $chopped = 0;
    if (!ref($content)) {
	my $maxlen = $opt{maxlength};
	$maxlen = 512 unless defined($maxlen);
	if ($maxlen && length($content) > $maxlen * 1.1 + 3) {
	    $chopped = length($content) - $maxlen;
	    $content = substr($content, 0, $maxlen) . "...";
	}

	$content =~ s/\\/\\\\/g;
	$content =~ s/\t/\\t/g;
	$content =~ s/\r/\\r/g;

	# no need for 3 digits in escape for these
	$content =~ s/([\0-\11\13-\037])(?!\d)/sprintf('\\%o',ord($1))/eg;

	$content =~ s/([\0-\11\13-\037\177-\377])/sprintf('\\x%02X',ord($1))/eg;
	$content =~ s/([^\12\040-\176])/sprintf('\\x{%X}',ord($1))/eg;

	# remaining whitespace
	$content =~ s/( +)\n/("\\40" x length($1)) . "\n"/eg;
	$content =~ s/(\n+)\n/("\\n" x length($1)) . "\n"/eg;
	$content =~ s/\n\z/\\n/;

	my $no_content = $opt{no_content};
	$no_content = "(no content)" unless defined $no_content;
	if ($content eq $no_content) {
	    # escape our $no_content marker
	    $content =~ s/^(.)/sprintf('\\x%02X',ord($1))/eg;
	}
	elsif ($content eq "") {
	    $content = $no_content;
	}
    }

    my @dump;
    push(@dump, $opt{preheader}) if $opt{preheader};
    push(@dump, $self->{_headers}->as_string, $content);
    push(@dump, "(+ $chopped more bytes not shown)") if $chopped;

    my $dump = join("\n", @dump, "");
    $dump =~ s/^/$opt{prefix}/gm if $opt{prefix};

    print $dump unless defined wantarray;
    return $dump;
}

# allow subclasses to override what will handle individual parts
sub _part_class {
    return __PACKAGE__;
}

sub parts {
    my $self = shift;
    if (defined(wantarray) && (!exists $self->{_parts} || ref($self->{_content}) eq "SCALAR")) {
	$self->_parts;
    }
    my $old = $self->{_parts};
    if (@_) {
	my @parts = map { ref($_) eq 'ARRAY' ? @$_ : $_ } @_;
	my $ct = $self->content_type || "";
	if ($ct =~ m,^message/,) {
	    Carp::croak("Only one part allowed for $ct content")
		if @parts > 1;
	}
	elsif ($ct !~ m,^multipart/,) {
	    $self->remove_content_headers;
	    $self->content_type("multipart/mixed");
	}
	$self->{_parts} = \@parts;
	_stale_content($self);
    }
    return @$old if wantarray;
    return $old->[0];
}

sub add_part {
    my $self = shift;
    if (($self->content_type || "") !~ m,^multipart/,) {
	my $p = $self->_part_class->new(
	    $self->remove_content_headers,
	    $self->content(""),
	);
	$self->content_type("multipart/mixed");
	$self->{_parts} = [];
        if ($p->headers->header_field_names || $p->content ne "") {
            push(@{$self->{_parts}}, $p);
        }
    }
    elsif (!exists $self->{_parts} || ref($self->{_content}) eq "SCALAR") {
	$self->_parts;
    }

    push(@{$self->{_parts}}, @_);
    _stale_content($self);
    return;
}

sub _stale_content {
    my $self = shift;
    if (ref($self->{_content}) eq "SCALAR") {
	# must recalculate now
	$self->_content;
    }
    else {
	# just invalidate cache
	delete $self->{_content};
	delete $self->{_content_ref};
    }
}


# delegate all other method calls to the headers object.
our $AUTOLOAD;
sub AUTOLOAD
{
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);

    # We create the function here so that it will not need to be
    # autoloaded the next time.
    no strict 'refs';
    *$method = sub { local $Carp::Internal{+__PACKAGE__} = 1; shift->headers->$method(@_) };
    goto &$method;
}


sub DESTROY {}  # avoid AUTOLOADing it


# Private method to access members in %$self
sub _elem
{
    my $self = shift;
    my $elem = shift;
    my $old = $self->{$elem};
    $self->{$elem} = $_[0] if @_;
    return $old;
}


# Create private _parts attribute from current _content
sub _parts {
    my $self = shift;
    my $ct = $self->content_type;
    if ($ct =~ m,^multipart/,) {
	require HTTP::Headers::Util;
	my @h = HTTP::Headers::Util::split_header_words($self->header("Content-Type"));
	die "Assert" unless @h;
	my %h = @{$h[0]};
	if (defined(my $b = $h{boundary})) {
	    my $str = $self->content;
	    $str =~ s/\r?\n--\Q$b\E--.*//s;
	    if ($str =~ s/(^|.*?\r?\n)--\Q$b\E\r?\n//s) {
		$self->{_parts} = [map $self->_part_class->parse($_),
				   split(/\r?\n--\Q$b\E\r?\n/, $str)]
	    }
	}
    }
    elsif ($ct eq "message/http") {
	require HTTP::Request;
	require HTTP::Response;
	my $content = $self->content;
	my $class = ($content =~ m,^(HTTP/.*)\n,) ?
	    "HTTP::Response" : "HTTP::Request";
	$self->{_parts} = [$class->parse($content)];
    }
    elsif ($ct =~ m,^message/,) {
	$self->{_parts} = [ $self->_part_class->parse($self->content) ];
    }

    $self->{_parts} ||= [];
}


# Create private _content attribute from current _parts
sub _content {
    my $self = shift;
    my $ct = $self->{_headers}->header("Content-Type") || "multipart/mixed";
    if ($ct =~ m,^\s*message/,i) {
	_set_content($self, $self->{_parts}[0]->as_string($CRLF), 1);
	return;
    }

    require HTTP::Headers::Util;
    my @v = HTTP::Headers::Util::split_header_words($ct);
    Carp::carp("Multiple Content-Type headers") if @v > 1;
    @v = @{$v[0]};

    my $boundary;
    my $boundary_index;
    for (my @tmp = @v; @tmp;) {
	my($k, $v) = splice(@tmp, 0, 2);
	if ($k eq "boundary") {
	    $boundary = $v;
	    $boundary_index = @v - @tmp - 1;
	    last;
	}
    }

    my @parts = map $_->as_string($CRLF), @{$self->{_parts}};

    my $bno = 0;
    $boundary = _boundary() unless defined $boundary;
 CHECK_BOUNDARY:
    {
	for (@parts) {
	    if (index($_, $boundary) >= 0) {
		# must have a better boundary
		$boundary = _boundary(++$bno);
		redo CHECK_BOUNDARY;
	    }
	}
    }

    if ($boundary_index) {
	$v[$boundary_index] = $boundary;
    }
    else {
	push(@v, boundary => $boundary);
    }

    $ct = HTTP::Headers::Util::join_header_words(@v);
    $self->{_headers}->header("Content-Type", $ct);

    _set_content($self, "--$boundary$CRLF" .
	                join("$CRLF--$boundary$CRLF", @parts) .
			"$CRLF--$boundary--$CRLF",
                        1);
}


sub _boundary
{
    my $size = shift || return "xYzZY";
    require MIME::Base64;
    my $b = MIME::Base64::encode(join("", map chr(rand(256)), 1..$size*3), "");
    $b =~ s/[\W]/X/g;  # ensure alnum only
    $b;
}


1;


__END__

#line 1115

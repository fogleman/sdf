#line 1 "HTML/HeadParser.pm"
package HTML::HeadParser;

#line 84


require HTML::Parser;
@ISA = qw(HTML::Parser);

use HTML::Entities ();

use strict;
use vars qw($VERSION $DEBUG);
#$DEBUG = 1;
$VERSION = "3.71";

#line 109

sub new
{
    my($class, $header) = @_;
    unless ($header) {
	require HTTP::Headers;
	$header = HTTP::Headers->new;
    }

    my $self = $class->SUPER::new(api_version => 3,
				  start_h => ["start", "self,tagname,attr"],
				  end_h   => ["end",   "self,tagname"],
				  text_h  => ["text",  "self,text"],
				  ignore_elements => [qw(script style)],
				 );
    $self->{'header'} = $header;
    $self->{'tag'} = '';   # name of active element that takes textual content
    $self->{'text'} = '';  # the accumulated text associated with the element
    $self;
}

#line 140

sub header
{
    my $self = shift;
    return $self->{'header'} unless @_;
    $self->{'header'}->header(@_);
}

sub as_string    # legacy
{
    my $self = shift;
    $self->{'header'}->as_string;
}

sub flush_text   # internal
{
    my $self = shift;
    my $tag  = $self->{'tag'};
    my $text = $self->{'text'};
    $text =~ s/^\s+//;
    $text =~ s/\s+$//;
    $text =~ s/\s+/ /g;
    print "FLUSH $tag => '$text'\n"  if $DEBUG;
    if ($tag eq 'title') {
	my $decoded;
	$decoded = utf8::decode($text) if $self->utf8_mode && defined &utf8::decode;
	HTML::Entities::decode($text);
	utf8::encode($text) if $decoded;
	$self->{'header'}->push_header(Title => $text);
    }
    $self->{'tag'} = $self->{'text'} = '';
}

# This is an quote from the HTML3.2 DTD which shows which elements
# that might be present in a <HEAD>...</HEAD>.  Also note that the
# <HEAD> tags themselves might be missing:
#
# <!ENTITY % head.content "TITLE & ISINDEX? & BASE? & STYLE? &
#                            SCRIPT* & META* & LINK*">
#
# <!ELEMENT HEAD O O  (%head.content)>
#
# From HTML 4.01:
#
# <!ENTITY % head.misc "SCRIPT|STYLE|META|LINK|OBJECT">
# <!ENTITY % head.content "TITLE & BASE?">
# <!ELEMENT HEAD O O (%head.content;) +(%head.misc;)>
#
# From HTML 5 as of WD-html5-20090825:
#
# One or more elements of metadata content, [...]
# => base, command, link, meta, noscript, script, style, title

sub start
{
    my($self, $tag, $attr) = @_;  # $attr is reference to a HASH
    print "START[$tag]\n" if $DEBUG;
    $self->flush_text if $self->{'tag'};
    if ($tag eq 'meta') {
	my $key = $attr->{'http-equiv'};
	if (!defined($key) || !length($key)) {
	    if ($attr->{name}) {
		$key = "X-Meta-\u$attr->{name}";
	    } elsif ($attr->{charset}) { # HTML 5 <meta charset="...">
		$key = "X-Meta-Charset";
		$self->{header}->push_header($key => $attr->{charset});
		return;
	    } else {
		return;
	    }
	}
	$key =~ s/:/-/g;
	$self->{'header'}->push_header($key => $attr->{content});
    } elsif ($tag eq 'base') {
	return unless exists $attr->{href};
	(my $base = $attr->{href}) =~ s/^\s+//; $base =~ s/\s+$//; # HTML5
	$self->{'header'}->push_header('Content-Base' => $base);
    } elsif ($tag eq 'isindex') {
	# This is a non-standard header.  Perhaps we should just ignore
	# this element
	$self->{'header'}->push_header(Isindex => $attr->{prompt} || '?');
    } elsif ($tag =~ /^(?:title|noscript|object|command)$/) {
	# Just remember tag.  Initialize header when we see the end tag.
	$self->{'tag'} = $tag;
    } elsif ($tag eq 'link') {
	return unless exists $attr->{href};
	# <link href="http:..." rel="xxx" rev="xxx" title="xxx">
	my $href = delete($attr->{href});
	$href =~ s/^\s+//; $href =~ s/\s+$//; # HTML5
	my $h_val = "<$href>";
	for (sort keys %{$attr}) {
	    next if $_ eq "/";  # XHTML junk
	    $h_val .= qq(; $_="$attr->{$_}");
	}
	$self->{'header'}->push_header(Link => $h_val);
    } elsif ($tag eq 'head' || $tag eq 'html') {
	# ignore
    } else {
	 # stop parsing
	$self->eof;
    }
}

sub end
{
    my($self, $tag) = @_;
    print "END[$tag]\n" if $DEBUG;
    $self->flush_text if $self->{'tag'};
    $self->eof if $tag eq 'head';
}

sub text
{
    my($self, $text) = @_;
    print "TEXT[$text]\n" if $DEBUG;
    unless ($self->{first_chunk}) {
	# drop Unicode BOM if found
	if ($self->utf8_mode) {
	    $text =~ s/^\xEF\xBB\xBF//;
	}
	else {
	    $text =~ s/^\x{FEFF}//;
	}
	$self->{first_chunk}++;
    }
    my $tag = $self->{tag};
    if (!$tag && $text =~ /\S/) {
	# Normal text means start of body
        $self->eof;
	return;
    }
    return if $tag ne 'title';
    $self->{'text'} .= $text;
}

BEGIN {
    *utf8_mode = sub { 1 } unless HTML::Entities::UNICODE_SUPPORT;
}

1;

__END__

#line 315


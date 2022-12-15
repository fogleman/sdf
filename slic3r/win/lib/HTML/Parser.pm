#line 1 "HTML/Parser.pm"
package HTML::Parser;

use strict;
use vars qw($VERSION @ISA);

$VERSION = "3.72";

require HTML::Entities;

require XSLoader;
XSLoader::load('HTML::Parser', $VERSION);

sub new
{
    my $class = shift;
    my $self = bless {}, $class;
    return $self->init(@_);
}


sub init
{
    my $self = shift;
    $self->_alloc_pstate;

    my %arg = @_;
    my $api_version = delete $arg{api_version} || (@_ ? 3 : 2);
    if ($api_version >= 4) {
	require Carp;
	Carp::croak("API version $api_version not supported " .
		    "by HTML::Parser $VERSION");
    }

    if ($api_version < 3) {
	# Set up method callbacks compatible with HTML-Parser-2.xx
	$self->handler(text    => "text",    "self,text,is_cdata");
	$self->handler(end     => "end",     "self,tagname,text");
	$self->handler(process => "process", "self,token0,text");
	$self->handler(start   => "start",
		                  "self,tagname,attr,attrseq,text");

	$self->handler(comment =>
		       sub {
			   my($self, $tokens) = @_;
			   for (@$tokens) {
			       $self->comment($_);
			   }
		       }, "self,tokens");

	$self->handler(declaration =>
		       sub {
			   my $self = shift;
			   $self->declaration(substr($_[0], 2, -1));
		       }, "self,text");
    }

    if (my $h = delete $arg{handlers}) {
	$h = {@$h} if ref($h) eq "ARRAY";
	while (my($event, $cb) = each %$h) {
	    $self->handler($event => @$cb);
	}
    }

    # In the end we try to assume plain attribute or handler
    while (my($option, $val) = each %arg) {
	if ($option =~ /^(\w+)_h$/) {
	    $self->handler($1 => @$val);
	}
        elsif ($option =~ /^(text|start|end|process|declaration|comment)$/) {
	    require Carp;
	    Carp::croak("Bad constructor option '$option'");
        }
	else {
	    $self->$option($val);
	}
    }

    return $self;
}


sub parse_file
{
    my($self, $file) = @_;
    my $opened;
    if (!ref($file) && ref(\$file) ne "GLOB") {
        # Assume $file is a filename
        local(*F);
        open(F, "<", $file) || return undef;
	binmode(F);  # should we? good for byte counts
        $opened++;
        $file = *F;
    }
    my $chunk = '';
    while (read($file, $chunk, 512)) {
	$self->parse($chunk) || last;
    }
    close($file) if $opened;
    $self->eof;
}


sub netscape_buggy_comment  # legacy
{
    my $self = shift;
    require Carp;
    Carp::carp("netscape_buggy_comment() is deprecated.  " .
	       "Please use the strict_comment() method instead");
    my $old = !$self->strict_comment;
    $self->strict_comment(!shift) if @_;
    return $old;
}

# set up method stubs
sub text { }
*start       = \&text;
*end         = \&text;
*comment     = \&text;
*declaration = \&text;
*process     = \&text;

1;

__END__


#line 1235

#line 1 "HTTP/Request.pm"
package HTTP::Request;

use strict;
use warnings;

use base 'HTTP::Message';

our $VERSION = "6.11";

sub new
{
    my($class, $method, $uri, $header, $content) = @_;
    my $self = $class->SUPER::new($header, $content);
    $self->method($method);
    $self->uri($uri);
    $self;
}


sub parse
{
    my($class, $str) = @_;
    my $request_line;
    if ($str =~ s/^(.*)\n//) {
	$request_line = $1;
    }
    else {
	$request_line = $str;
	$str = "";
    }

    my $self = $class->SUPER::parse($str);
    my($method, $uri, $protocol) = split(' ', $request_line);
    $self->method($method) if defined($method);
    $self->uri($uri) if defined($uri);
    $self->protocol($protocol) if $protocol;
    $self;
}


sub clone
{
    my $self = shift;
    my $clone = bless $self->SUPER::clone, ref($self);
    $clone->method($self->method);
    $clone->uri($self->uri);
    $clone;
}


sub method
{
    shift->_elem('_method', @_);
}


sub uri
{
    my $self = shift;
    my $old = $self->{'_uri'};
    if (@_) {
	my $uri = shift;
	if (!defined $uri) {
	    # that's ok
	}
	elsif (ref $uri) {
	    Carp::croak("A URI can't be a " . ref($uri) . " reference")
		if ref($uri) eq 'HASH' or ref($uri) eq 'ARRAY';
	    Carp::croak("Can't use a " . ref($uri) . " object as a URI")
		unless $uri->can('scheme');
	    $uri = $uri->clone;
	    unless ($HTTP::URI_CLASS eq "URI") {
		# Argh!! Hate this... old LWP legacy!
		eval { local $SIG{__DIE__}; $uri = $uri->abs; };
		die $@ if $@ && $@ !~ /Missing base argument/;
	    }
	}
	else {
	    $uri = $HTTP::URI_CLASS->new($uri);
	}
	$self->{'_uri'} = $uri;
        delete $self->{'_uri_canonical'};
    }
    $old;
}

*url = \&uri;  # legacy

sub uri_canonical
{
    my $self = shift;
    return $self->{'_uri_canonical'} ||= $self->{'_uri'}->canonical;
}


sub accept_decodable
{
    my $self = shift;
    $self->header("Accept-Encoding", scalar($self->decodable));
}

sub as_string
{
    my $self = shift;
    my($eol) = @_;
    $eol = "\n" unless defined $eol;

    my $req_line = $self->method || "-";
    my $uri = $self->uri;
    $uri = (defined $uri) ? $uri->as_string : "-";
    $req_line .= " $uri";
    my $proto = $self->protocol;
    $req_line .= " $proto" if $proto;

    return join($eol, $req_line, $self->SUPER::as_string(@_));
}

sub dump
{
    my $self = shift;
    my @pre = ($self->method || "-", $self->uri || "-");
    if (my $prot = $self->protocol) {
	push(@pre, $prot);
    }

    return $self->SUPER::dump(
        preheader => join(" ", @pre),
	@_,
    );
}


1;

__END__

#line 242

#line 1 "HTTP/Config.pm"
package HTTP::Config;

use strict;
use warnings;

use URI;

our $VERSION = "6.11";

sub new {
    my $class = shift;
    return bless [], $class;
}

sub entries {
    my $self = shift;
    @$self;
}

sub empty {
    my $self = shift;
    not @$self;
}

sub add {
    if (@_ == 2) {
        my $self = shift;
        push(@$self, shift);
        return;
    }
    my($self, %spec) = @_;
    push(@$self, \%spec);
    return;
}

sub find2 {
    my($self, %spec) = @_;
    my @found;
    my @rest;
 ITEM:
    for my $item (@$self) {
        for my $k (keys %spec) {
            no warnings 'uninitialized';
            if (!exists $item->{$k} || $spec{$k} ne $item->{$k}) {
                push(@rest, $item);
                next ITEM;
            }
        }
        push(@found, $item);
    }
    return \@found unless wantarray;
    return \@found, \@rest;
}

sub find {
    my $self = shift;
    my $f = $self->find2(@_);
    return @$f if wantarray;
    return $f->[0];
}

sub remove {
    my($self, %spec) = @_;
    my($removed, $rest) = $self->find2(%spec);
    @$self = @$rest if @$removed;
    return @$removed;
}

my %MATCH = (
    m_scheme => sub {
        my($v, $uri) = @_;
        return $uri->_scheme eq $v;  # URI known to be canonical
    },
    m_secure => sub {
        my($v, $uri) = @_;
        my $secure = $uri->can("secure") ? $uri->secure : $uri->_scheme eq "https";
        return $secure == !!$v;
    },
    m_host_port => sub {
        my($v, $uri) = @_;
        return unless $uri->can("host_port");
        return $uri->host_port eq $v, 7;
    },
    m_host => sub {
        my($v, $uri) = @_;
        return unless $uri->can("host");
        return $uri->host eq $v, 6;
    },
    m_port => sub {
        my($v, $uri) = @_;
        return unless $uri->can("port");
        return $uri->port eq $v;
    },
    m_domain => sub {
        my($v, $uri) = @_;
        return unless $uri->can("host");
        my $h = $uri->host;
        $h = "$h.local" unless $h =~ /\./;
        $v = ".$v" unless $v =~ /^\./;
        return length($v), 5 if substr($h, -length($v)) eq $v;
        return 0;
    },
    m_path => sub {
        my($v, $uri) = @_;
        return unless $uri->can("path");
        return $uri->path eq $v, 4;
    },
    m_path_prefix => sub {
        my($v, $uri) = @_;
        return unless $uri->can("path");
        my $path = $uri->path;
        my $len = length($v);
        return $len, 3 if $path eq $v;
        return 0 if length($path) <= $len;
        $v .= "/" unless $v =~ m,/\z,,;
        return $len, 3 if substr($path, 0, length($v)) eq $v;
        return 0;
    },
    m_path_match => sub {
        my($v, $uri) = @_;
        return unless $uri->can("path");
        return $uri->path =~ $v;
    },
    m_uri__ => sub {
        my($v, $k, $uri) = @_;
        return unless $uri->can($k);
        return 1 unless defined $v;
        return $uri->$k eq $v;
    },
    m_method => sub {
        my($v, $uri, $request) = @_;
        return $request && $request->method eq $v;
    },
    m_proxy => sub {
        my($v, $uri, $request) = @_;
        return $request && ($request->{proxy} || "") eq $v;
    },
    m_code => sub {
        my($v, $uri, $request, $response) = @_;
        $v =~ s/xx\z//;
        return unless $response;
        return length($v), 2 if substr($response->code, 0, length($v)) eq $v;
    },
    m_media_type => sub {  # for request too??
        my($v, $uri, $request, $response) = @_;
        return unless $response;
        return 1, 1 if $v eq "*/*";
        my $ct = $response->content_type;
        return 2, 1 if $v =~ s,/\*\z,, && $ct =~ m,^\Q$v\E/,;
        return 3, 1 if $v eq "html" && $response->content_is_html;
        return 4, 1 if $v eq "xhtml" && $response->content_is_xhtml;
        return 10, 1 if $v eq $ct;
        return 0;
    },
    m_header__ => sub {
        my($v, $k, $uri, $request, $response) = @_;
        return unless $request;
        return 1 if $request->header($k) eq $v;
        return 1 if $response && $response->header($k) eq $v;
        return 0;
    },
    m_response_attr__ => sub {
        my($v, $k, $uri, $request, $response) = @_;
        return unless $response;
        return 1 if !defined($v) && exists $response->{$k};
        return 0 unless exists $response->{$k};
        return 1 if $response->{$k} eq $v;
        return 0;
    },
);

sub matching {
    my $self = shift;
    if (@_ == 1) {
        if ($_[0]->can("request")) {
            unshift(@_, $_[0]->request);
            unshift(@_, undef) unless defined $_[0];
        }
        unshift(@_, $_[0]->uri_canonical) if $_[0] && $_[0]->can("uri_canonical");
    }
    my($uri, $request, $response) = @_;
    $uri = URI->new($uri) unless ref($uri);

    my @m;
 ITEM:
    for my $item (@$self) {
        my $order;
        for my $ikey (keys %$item) {
            my $mkey = $ikey;
            my $k;
            $k = $1 if $mkey =~ s/__(.*)/__/;
            if (my $m = $MATCH{$mkey}) {
                #print "$ikey $mkey\n";
                my($c, $o);
                my @arg = (
                    defined($k) ? $k : (),
                    $uri, $request, $response
                );
                my $v = $item->{$ikey};
                $v = [$v] unless ref($v) eq "ARRAY";
                for (@$v) {
                    ($c, $o) = $m->($_, @arg);
                    #print "  - $_ ==> $c $o\n";
                    last if $c;
                }
                next ITEM unless $c;
                $order->[$o || 0] += $c;
            }
        }
        $order->[7] ||= 0;
        $item->{_order} = join(".", reverse map sprintf("%03d", $_ || 0), @$order);
        push(@m, $item);
    }
    @m = sort { $b->{_order} cmp $a->{_order} } @m;
    delete $_->{_order} for @m;
    return @m if wantarray;
    return $m[0];
}

sub add_item {
    my $self = shift;
    my $item = shift;
    return $self->add(item => $item, @_);
}

sub remove_items {
    my $self = shift;
    return map $_->{item}, $self->remove(@_);
}

sub matching_items {
    my $self = shift;
    return map $_->{item}, $self->matching(@_);
}

1;

__END__

#line 439

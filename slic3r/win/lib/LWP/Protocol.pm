#line 1 "LWP/Protocol.pm"
package LWP::Protocol;

use base 'LWP::MemberMixin';

our $VERSION = '6.24';

use strict;
use Carp ();
use HTTP::Status ();
use HTTP::Response ();
use Try::Tiny qw(try catch);

my %ImplementedBy = (); # scheme => classname

sub new
{
    my($class, $scheme, $ua) = @_;

    my $self = bless {
	scheme => $scheme,
	ua => $ua,

	# historical/redundant
        max_size => $ua->{max_size},
    }, $class;

    $self;
}


sub create
{
    my($scheme, $ua) = @_;
    my $impclass = LWP::Protocol::implementor($scheme) or
	Carp::croak("Protocol scheme '$scheme' is not supported");

    # hand-off to scheme specific implementation sub-class
    my $protocol = $impclass->new($scheme, $ua);

    return $protocol;
}


sub implementor
{
    my($scheme, $impclass) = @_;

    if ($impclass) {
	$ImplementedBy{$scheme} = $impclass;
    }
    my $ic = $ImplementedBy{$scheme};
    return $ic if $ic;

    return '' unless $scheme =~ /^([.+\-\w]+)$/;  # check valid URL schemes
    $scheme = $1; # untaint
    $scheme =~ s/[.+\-]/_/g;  # make it a legal module name

    # scheme not yet known, look for a 'use'd implementation
    $ic = "LWP::Protocol::$scheme";  # default location
    $ic = "LWP::Protocol::nntp" if $scheme eq 'news'; #XXX ugly hack
    no strict 'refs';
    # check we actually have one for the scheme:
    unless (@{"${ic}::ISA"}) {
        # try to autoload it
        try {
            (my $class = $ic) =~ s{::}{/}g;
            $class .= '.pm' unless $class =~ /\.pm$/;
            require $class;
        }
        catch {
            my $error = $_;
            if ($error =~ /Can't locate/) {
                $ic = '';
            }
            else {
                die "$error\n";
            }
        };
    }
    $ImplementedBy{$scheme} = $ic if $ic;
    $ic;
}


sub request
{
    my($self, $request, $proxy, $arg, $size, $timeout) = @_;
    Carp::croak('LWP::Protocol::request() needs to be overridden in subclasses');
}


# legacy
sub timeout    { shift->_elem('timeout',    @_); }
sub max_size   { shift->_elem('max_size',   @_); }


sub collect
{
    my ($self, $arg, $response, $collector) = @_;
    my $content;
    my($ua, $max_size) = @{$self}{qw(ua max_size)};

    try {
        local $\; # protect the print below from surprises
        if (!defined($arg) || !$response->is_success) {
            $response->{default_add_content} = 1;
        }
        elsif (!ref($arg) && length($arg)) {
            open(my $fh, ">", $arg) or die "Can't write to '$arg': $!";
	    binmode($fh);
            push(@{$response->{handlers}{response_data}}, {
                callback => sub {
                    print $fh $_[3] or die "Can't write to '$arg': $!";
                    1;
                },
            });
            push(@{$response->{handlers}{response_done}}, {
                callback => sub {
		    close($fh) or die "Can't write to '$arg': $!";
		    undef($fh);
		},
	    });
        }
        elsif (ref($arg) eq 'CODE') {
            push(@{$response->{handlers}{response_data}}, {
                callback => sub {
		    &$arg($_[3], $_[0], $self);
		    1;
                },
            });
        }
        else {
            die "Unexpected collect argument '$arg'";
        }

        $ua->run_handlers("response_header", $response);

        if (delete $response->{default_add_content}) {
            push(@{$response->{handlers}{response_data}}, {
		callback => sub {
		    $_[0]->add_content($_[3]);
		    1;
		},
	    });
        }


        my $content_size = 0;
        my $length = $response->content_length;
        my %skip_h;

        while ($content = &$collector, length $$content) {
            for my $h ($ua->handlers("response_data", $response)) {
                next if $skip_h{$h};
                unless ($h->{callback}->($response, $ua, $h, $$content)) {
                    # XXX remove from $response->{handlers}{response_data} if present
                    $skip_h{$h}++;
                }
            }
            $content_size += length($$content);
            $ua->progress(($length ? ($content_size / $length) : "tick"), $response);
            if (defined($max_size) && $content_size > $max_size) {
                $response->push_header("Client-Aborted", "max_size");
                last;
            }
        }
    }
    catch {
        my $error = $_;
        chomp($error);
        $response->push_header('X-Died' => $error);
        $response->push_header("Client-Aborted", "die");
    };
    delete $response->{handlers}{response_data};
    delete $response->{handlers} unless %{$response->{handlers}};
    return $response;
}


sub collect_once
{
    my($self, $arg, $response) = @_;
    my $content = \ $_[3];
    my $first = 1;
    $self->collect($arg, $response, sub {
	return $content if $first--;
	return \ "";
    });
}

1;


__END__

#line 306

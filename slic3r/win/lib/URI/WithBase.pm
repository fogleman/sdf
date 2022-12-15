#line 1 "URI/WithBase.pm"
package URI::WithBase;

use strict;
use warnings;

use URI;
use Scalar::Util 'blessed';

our $VERSION = "2.20";

use overload '""' => "as_string", fallback => 1;

sub as_string;  # help overload find it

sub new
{
    my($class, $uri, $base) = @_;
    my $ibase = $base;
    if ($base && blessed($base) && $base->isa(__PACKAGE__)) {
	$base = $base->abs;
	$ibase = $base->[0];
    }
    bless [URI->new($uri, $ibase), $base], $class;
}

sub new_abs
{
    my $class = shift;
    my $self = $class->new(@_);
    $self->abs;
}

sub _init
{
    my $class = shift;
    my($str, $scheme) = @_;
    bless [URI->new($str, $scheme), undef], $class;
}

sub eq
{
    my($self, $other) = @_;
    $other = $other->[0] if blessed($other) and $other->isa(__PACKAGE__);
    $self->[0]->eq($other);
}

our $AUTOLOAD;
sub AUTOLOAD
{
    my $self = shift;
    my $method = substr($AUTOLOAD, rindex($AUTOLOAD, '::')+2);
    return if $method eq "DESTROY";
    $self->[0]->$method(@_);
}

sub can {                                  # override UNIVERSAL::can
    my $self = shift;
    $self->SUPER::can(@_) || (
      ref($self)
      ? $self->[0]->can(@_)
      : undef
    )
}

sub base {
    my $self = shift;
    my $base  = $self->[1];

    if (@_) { # set
	my $new_base = shift;
	# ensure absoluteness
	$new_base = $new_base->abs if ref($new_base) && $new_base->isa(__PACKAGE__);
	$self->[1] = $new_base;
    }
    return unless defined wantarray;

    # The base attribute supports 'lazy' conversion from URL strings
    # to URL objects. Strings may be stored but when a string is
    # fetched it will automatically be converted to a URL object.
    # The main benefit is to make it much cheaper to say:
    #   URI::WithBase->new($random_url_string, 'http:')
    if (defined($base) && !ref($base)) {
	$base = ref($self)->new($base);
	$self->[1] = $base unless @_;
    }
    $base;
}

sub clone
{
    my $self = shift;
    my $base = $self->[1];
    $base = $base->clone if ref($base);
    bless [$self->[0]->clone, $base], ref($self);
}

sub abs
{
    my $self = shift;
    my $base = shift || $self->base || return $self->clone;
    $base = $base->as_string if ref($base);
    bless [$self->[0]->abs($base, @_), $base], ref($self);
}

sub rel
{
    my $self = shift;
    my $base = shift || $self->base || return $self->clone;
    $base = $base->as_string if ref($base);
    bless [$self->[0]->rel($base, @_), $base], ref($self);
}

1;

__END__

#line 175

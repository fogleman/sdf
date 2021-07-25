#line 1 "Tie/Handle.pm"
package Tie::Handle;

use 5.006_001;
our $VERSION = '4.2';

# Tie::StdHandle used to be inside Tie::Handle.  For backwards compatibility
# loading Tie::Handle has to make Tie::StdHandle available.
use Tie::StdHandle;

#line 122

use Carp;
use warnings::register;

sub new {
    my $pkg = shift;
    $pkg->TIEHANDLE(@_);
}

# "Grandfather" the new, a la Tie::Hash

sub TIEHANDLE {
    my $pkg = shift;
    if (defined &{"{$pkg}::new"}) {
	warnings::warnif("WARNING: calling ${pkg}->new since ${pkg}->TIEHANDLE is missing");
	$pkg->new(@_);
    }
    else {
	croak "$pkg doesn't define a TIEHANDLE method";
    }
}

sub PRINT {
    my $self = shift;
    if($self->can('WRITE') != \&WRITE) {
	my $buf = join(defined $, ? $, : "",@_);
	$buf .= $\ if defined $\;
	$self->WRITE($buf,length($buf),0);
    }
    else {
	croak ref($self)," doesn't define a PRINT method";
    }
}

sub PRINTF {
    my $self = shift;
    
    if($self->can('WRITE') != \&WRITE) {
	my $buf = sprintf(shift,@_);
	$self->WRITE($buf,length($buf),0);
    }
    else {
	croak ref($self)," doesn't define a PRINTF method";
    }
}

sub READLINE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a READLINE method";
}

sub GETC {
    my $self = shift;
    
    if($self->can('READ') != \&READ) {
	my $buf;
	$self->READ($buf,1);
	return $buf;
    }
    else {
	croak ref($self)," doesn't define a GETC method";
    }
}

sub READ {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a READ method";
}

sub WRITE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a WRITE method";
}

sub CLOSE {
    my $pkg = ref $_[0];
    croak "$pkg doesn't define a CLOSE method";
}

1;

#line 1 "IO.pm"
#

package IO;

use XSLoader ();
use Carp;
use strict;
use warnings;

our $VERSION = "1.36";
XSLoader::load 'IO', $VERSION;

sub import {
    shift;

    warnings::warnif('deprecated', qq{Parameterless "use IO" deprecated})
        if @_ == 0 ;
    
    my @l = @_ ? @_ : qw(Handle Seekable File Pipe Socket Dir);

    eval join("", map { "require IO::" . (/(\w+)/)[0] . ";\n" } @l)
	or croak $@;
}

1;

__END__

#line 68


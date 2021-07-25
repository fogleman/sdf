#line 1 "Tie/StdHandle.pm"
package Tie::StdHandle; 

use strict;

use Tie::Handle;
use vars qw(@ISA $VERSION);
@ISA = 'Tie::Handle';
$VERSION = '4.4';

#line 37

sub TIEHANDLE 
{
 my $class = shift;
 my $fh    = \do { local *HANDLE};
 bless $fh,$class;
 $fh->OPEN(@_) if (@_);
 return $fh;
}

sub EOF     { eof($_[0]) }
sub TELL    { tell($_[0]) }
sub FILENO  { fileno($_[0]) }
sub SEEK    { seek($_[0],$_[1],$_[2]) }
sub CLOSE   { close($_[0]) }
sub BINMODE { binmode($_[0]) }

sub OPEN
{
 $_[0]->CLOSE if defined($_[0]->FILENO);
 @_ == 2 ? open($_[0], $_[1]) : open($_[0], $_[1], $_[2]);
}

sub READ     { &CORE::read(shift, \shift, @_) }
sub READLINE { my $fh = $_[0]; <$fh> }
sub GETC     { getc($_[0]) }

sub WRITE
{
 my $fh = $_[0];
 local $\; # don't print any line terminator
 print $fh substr($_[1], $_[3], $_[2]);
}


1;

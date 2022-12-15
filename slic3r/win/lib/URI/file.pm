#line 1 "URI/file.pm"
package URI::file;

use strict;
use warnings;

use parent 'URI::_generic';
our $VERSION = "4.21";

use URI::Escape qw(uri_unescape);

our $DEFAULT_AUTHORITY = "";

# Map from $^O values to implementation classes.  The Unix
# class is the default.
our %OS_CLASS = (
     os2     => "OS2",
     mac     => "Mac",
     MacOS   => "Mac",
     MSWin32 => "Win32",
     win32   => "Win32",
     msdos   => "FAT",
     dos     => "FAT",
     qnx     => "QNX",
);

sub os_class
{
    my($OS) = shift || $^O;

    my $class = "URI::file::" . ($OS_CLASS{$OS} || "Unix");
    no strict 'refs';
    unless (%{"$class\::"}) {
	eval "require $class";
	die $@ if $@;
    }
    $class;
}

sub host { uri_unescape(shift->authority(@_)) }

sub new
{
    my($class, $path, $os) = @_;
    os_class($os)->new($path);
}

sub new_abs
{
    my $class = shift;
    my $file = $class->new(@_);
    return $file->abs($class->cwd) unless $$file =~ /^file:/;
    $file;
}

sub cwd
{
    my $class = shift;
    require Cwd;
    my $cwd = Cwd::cwd();
    $cwd = VMS::Filespec::unixpath($cwd) if $^O eq 'VMS';
    $cwd = $class->new($cwd);
    $cwd .= "/" unless substr($cwd, -1, 1) eq "/";
    $cwd;
}

sub canonical {
    my $self = shift;
    my $other = $self->SUPER::canonical;

    my $scheme = $other->scheme;
    my $auth = $other->authority;
    return $other if !defined($scheme) && !defined($auth);  # relative

    if (!defined($auth) ||
	$auth eq "" ||
	lc($auth) eq "localhost" ||
	(defined($DEFAULT_AUTHORITY) && lc($auth) eq lc($DEFAULT_AUTHORITY))
       )
    {
	# avoid cloning if $auth already match
	if ((defined($auth) || defined($DEFAULT_AUTHORITY)) &&
	    (!defined($auth) || !defined($DEFAULT_AUTHORITY) || $auth ne $DEFAULT_AUTHORITY)
	   )
	{
	    $other = $other->clone if $self == $other;
	    $other->authority($DEFAULT_AUTHORITY);
        }
    }

    $other;
}

sub file
{
    my($self, $os) = @_;
    os_class($os)->file($self);
}

sub dir
{
    my($self, $os) = @_;
    os_class($os)->dir($self);
}

1;

__END__

#line 265


RFC 1630

   [...]

   There is clearly a danger of confusion that a link made to a local
   file should be followed by someone on a different system, with
   unexpected and possibly harmful results.  Therefore, the convention
   is that even a "file" URL is provided with a host part.  This allows
   a client on another system to know that it cannot access the file
   system, or perhaps to use some other local mechanism to access the
   file.

   The special value "localhost" is used in the host field to indicate
   that the filename should really be used on whatever host one is.
   This for example allows links to be made to files which are
   distributed on many machines, or to "your unix local password file"
   subject of course to consistency across the users of the data.

   A void host field is equivalent to "localhost".

#line 328

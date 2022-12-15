#line 1 "File/Spec/Win32.pm"
package File::Spec::Win32;

use strict;

use vars qw(@ISA $VERSION);
require File::Spec::Unix;

$VERSION = '3.63_01';
$VERSION =~ tr/_//d;

@ISA = qw(File::Spec::Unix);

# Some regexes we use for path splitting
my $DRIVE_RX = '[a-zA-Z]:';
my $UNC_RX = '(?:\\\\\\\\|//)[^\\\\/]+[\\\\/][^\\\\/]+';
my $VOL_RX = "(?:$DRIVE_RX|$UNC_RX)";


#line 40

sub devnull {
    return "nul";
}

sub rootdir { '\\' }


#line 69

sub tmpdir {
    my $tmpdir = $_[0]->_cached_tmpdir(qw(TMPDIR TEMP TMP));
    return $tmpdir if defined $tmpdir;
    $tmpdir = $_[0]->_tmpdir( map( $ENV{$_}, qw(TMPDIR TEMP TMP) ),
			      'SYS:/temp',
			      'C:\system\temp',
			      'C:/temp',
			      '/tmp',
			      '/'  );
    $_[0]->_cache_tmpdir($tmpdir, qw(TMPDIR TEMP TMP));
}

#line 91

sub case_tolerant {
  eval {
    local @INC = @INC;
    pop @INC if $INC[-1] eq '.';
    require Win32API::File;
  } or return 1;
  my $drive = shift || "C:";
  my $osFsType = "\0"x256;
  my $osVolName = "\0"x256;
  my $ouFsFlags = 0;
  Win32API::File::GetVolumeInformation($drive, $osVolName, 256, [], [], $ouFsFlags, $osFsType, 256 );
  if ($ouFsFlags & Win32API::File::FS_CASE_SENSITIVE()) { return 0; }
  else { return 1; }
}

#line 113

sub file_name_is_absolute {

    my ($self,$file) = @_;

    if ($file =~ m{^($VOL_RX)}o) {
      my $vol = $1;
      return ($vol =~ m{^$UNC_RX}o ? 2
	      : $file =~ m{^$DRIVE_RX[\\/]}o ? 2
	      : 0);
    }
    return $file =~  m{^[\\/]} ? 1 : 0;
}

#line 133

sub catfile {
    shift;

    # Legacy / compatibility support
    #
    shift, return _canon_cat( "/", @_ )
	if $_[0] eq "";

    # Compatibility with File::Spec <= 3.26:
    #     catfile('A:', 'foo') should return 'A:\foo'.
    return _canon_cat( ($_[0].'\\'), @_[1..$#_] )
        if $_[0] =~ m{^$DRIVE_RX\z}o;

    return _canon_cat( @_ );
}

sub catdir {
    shift;

    # Legacy / compatibility support
    #
    return ""
    	unless @_;
    shift, return _canon_cat( "/", @_ )
	if $_[0] eq "";

    # Compatibility with File::Spec <= 3.26:
    #     catdir('A:', 'foo') should return 'A:\foo'.
    return _canon_cat( ($_[0].'\\'), @_[1..$#_] )
        if $_[0] =~ m{^$DRIVE_RX\z}o;

    return _canon_cat( @_ );
}

sub path {
    my @path = split(';', $ENV{PATH});
    s/"//g for @path;
    @path = grep length, @path;
    unshift(@path, ".");
    return @path;
}

#line 186

sub canonpath {
    # Legacy / compatibility support
    #
    return $_[1] if !defined($_[1]) or $_[1] eq '';
    return _canon_cat( $_[1] );
}

#line 213

sub splitpath {
    my ($self,$path, $nofile) = @_;
    my ($volume,$directory,$file) = ('','','');
    if ( $nofile ) {
        $path =~ 
            m{^ ( $VOL_RX ? ) (.*) }sox;
        $volume    = $1;
        $directory = $2;
    }
    else {
        $path =~ 
            m{^ ( $VOL_RX ? )
                ( (?:.*[\\/](?:\.\.?\Z(?!\n))?)? )
                (.*)
             }sox;
        $volume    = $1;
        $directory = $2;
        $file      = $3;
    }

    return ($volume,$directory,$file);
}


#line 259

sub splitdir {
    my ($self,$directories) = @_ ;
    #
    # split() likes to forget about trailing null fields, so here we
    # check to be sure that there will not be any before handling the
    # simple case.
    #
    if ( $directories !~ m|[\\/]\Z(?!\n)| ) {
        return split( m|[\\/]|, $directories );
    }
    else {
        #
        # since there was a trailing separator, add a file name to the end, 
        # then do the split, then replace it with ''.
        #
        my( @directories )= split( m|[\\/]|, "${directories}dummy" ) ;
        $directories[ $#directories ]= '' ;
        return @directories ;
    }
}


#line 289

sub catpath {
    my ($self,$volume,$directory,$file) = @_;

    # If it's UNC, make sure the glue separator is there, reusing
    # whatever separator is first in the $volume
    my $v;
    $volume .= $v
        if ( (($v) = $volume =~ m@^([\\/])[\\/][^\\/]+[\\/][^\\/]+\Z(?!\n)@s) &&
             $directory =~ m@^[^\\/]@s
           ) ;

    $volume .= $directory ;

    # If the volume is not just A:, make sure the glue separator is 
    # there, reusing whatever separator is first in the $volume if possible.
    if ( $volume !~ m@^[a-zA-Z]:\Z(?!\n)@s &&
         $volume =~ m@[^\\/]\Z(?!\n)@      &&
         $file   =~ m@[^\\/]@
       ) {
        $volume =~ m@([\\/])@ ;
        my $sep = $1 ? $1 : '\\' ;
        $volume .= $sep ;
    }

    $volume .= $file ;

    return $volume ;
}

sub _same {
  lc($_[1]) eq lc($_[2]);
}

sub rel2abs {
    my ($self,$path,$base ) = @_;

    my $is_abs = $self->file_name_is_absolute($path);

    # Check for volume (should probably document the '2' thing...)
    return $self->canonpath( $path ) if $is_abs == 2;

    if ($is_abs) {
      # It's missing a volume, add one
      my $vol = ($self->splitpath( $self->_cwd() ))[0];
      return $self->canonpath( $vol . $path );
    }

    if ( !defined( $base ) || $base eq '' ) {
      require Cwd ;
      $base = Cwd::getdcwd( ($self->splitpath( $path ))[0] ) if defined &Cwd::getdcwd ;
      $base = $self->_cwd() unless defined $base ;
    }
    elsif ( ! $self->file_name_is_absolute( $base ) ) {
      $base = $self->rel2abs( $base ) ;
    }
    else {
      $base = $self->canonpath( $base ) ;
    }

    my ( $path_directories, $path_file ) =
      ($self->splitpath( $path, 1 ))[1,2] ;

    my ( $base_volume, $base_directories ) =
      $self->splitpath( $base, 1 ) ;

    $path = $self->catpath( 
			   $base_volume, 
			   $self->catdir( $base_directories, $path_directories ), 
			   $path_file
			  ) ;

    return $self->canonpath( $path ) ;
}

#line 383


sub _canon_cat				# @path -> path
{
    my ($first, @rest) = @_;

    my $volume = $first =~ s{ \A ([A-Za-z]:) ([\\/]?) }{}x	# drive letter
    	       ? ucfirst( $1 ).( $2 ? "\\" : "" )
	       : $first =~ s{ \A (?:\\\\|//) ([^\\/]+)
				 (?: [\\/] ([^\\/]+) )?
	       			 [\\/]? }{}xs			# UNC volume
	       ? "\\\\$1".( defined $2 ? "\\$2" : "" )."\\"
	       : $first =~ s{ \A [\\/] }{}x			# root dir
	       ? "\\"
	       : "";
    my $path   = join "\\", $first, @rest;

    $path =~ tr#\\/#\\\\#s;		# xx/yy --> xx\yy & xx\\yy --> xx\yy

    					# xx/././yy --> xx/yy
    $path =~ s{(?:
		(?:\A|\\)		# at begin or after a slash
		\.
		(?:\\\.)*		# and more
		(?:\\|\z) 		# at end or followed by slash
	       )+			# performance boost -- I do not know why
	     }{\\}gx;

    # XXX I do not know whether more dots are supported by the OS supporting
    #     this ... annotation (NetWare or symbian but not MSWin32).
    #     Then .... could easily become ../../.. etc:
    # Replace \.\.\. by (\.\.\.+)  and substitute with
    # { $1 . ".." . "\\.." x (length($2)-2) }gex
	     				# ... --> ../..
    $path =~ s{ (\A|\\)			# at begin or after a slash
    		\.\.\.
		(?=\\|\z) 		# at end or followed by slash
	     }{$1..\\..}gx;
    					# xx\yy\..\zz --> xx\zz
    while ( $path =~ s{(?:
		(?:\A|\\)		# at begin or after a slash
		[^\\]+			# rip this 'yy' off
		\\\.\.
		(?<!\A\.\.\\\.\.)	# do *not* replace ^..\..
		(?<!\\\.\.\\\.\.)	# do *not* replace \..\..
		(?:\\|\z) 		# at end or followed by slash
	       )+			# performance boost -- I do not know why
	     }{\\}sx ) {}

    $path =~ s#\A\\##;			# \xx --> xx  NOTE: this is *not* root
    $path =~ s#\\\z##;			# xx\ --> xx

    if ( $volume =~ m#\\\z# )
    {					# <vol>\.. --> <vol>\
	$path =~ s{ \A			# at begin
		    \.\.
		    (?:\\\.\.)*		# and more
		    (?:\\|\z) 		# at end or followed by slash
		 }{}x;

	return $1			# \\HOST\SHARE\ --> \\HOST\SHARE
	    if    $path eq ""
	      and $volume =~ m#\A(\\\\.*)\\\z#s;
    }
    return $path ne "" || $volume ? $volume.$path : ".";
}

1;

#line 1 "IO/Dir.pm"
# IO::Dir.pm
#
# Copyright (c) 1997-8 Graham Barr <gbarr@pobox.com>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package IO::Dir;

use 5.006;

use strict;
use Carp;
use Symbol;
use Exporter;
use IO::File;
our(@ISA, $VERSION, @EXPORT_OK);
use Tie::Hash;
use File::stat;
use File::Spec;

@ISA = qw(Tie::Hash Exporter);
$VERSION = "1.10";
$VERSION = eval $VERSION;
@EXPORT_OK = qw(DIR_UNLINK);

sub DIR_UNLINK () { 1 }

sub new {
    @_ >= 1 && @_ <= 2 or croak 'usage: IO::Dir->new([DIRNAME])';
    my $class = shift;
    my $dh = gensym;
    if (@_) {
	IO::Dir::open($dh, $_[0])
	    or return undef;
    }
    bless $dh, $class;
}

sub DESTROY {
    my ($dh) = @_;
    local($., $@, $!, $^E, $?);
    no warnings 'io';
    closedir($dh);
}

sub open {
    @_ == 2 or croak 'usage: $dh->open(DIRNAME)';
    my ($dh, $dirname) = @_;
    return undef
	unless opendir($dh, $dirname);
    # a dir name should always have a ":" in it; assume dirname is
    # in current directory
    $dirname = ':' .  $dirname if ( ($^O eq 'MacOS') && ($dirname !~ /:/) );
    ${*$dh}{io_dir_path} = $dirname;
    1;
}

sub close {
    @_ == 1 or croak 'usage: $dh->close()';
    my ($dh) = @_;
    closedir($dh);
}

sub read {
    @_ == 1 or croak 'usage: $dh->read()';
    my ($dh) = @_;
    readdir($dh);
}

sub seek {
    @_ == 2 or croak 'usage: $dh->seek(POS)';
    my ($dh,$pos) = @_;
    seekdir($dh,$pos);
}

sub tell {
    @_ == 1 or croak 'usage: $dh->tell()';
    my ($dh) = @_;
    telldir($dh);
}

sub rewind {
    @_ == 1 or croak 'usage: $dh->rewind()';
    my ($dh) = @_;
    rewinddir($dh);
}

sub TIEHASH {
    my($class,$dir,$options) = @_;

    my $dh = $class->new($dir)
	or return undef;

    $options ||= 0;

    ${*$dh}{io_dir_unlink} = $options & DIR_UNLINK;
    $dh;
}

sub FIRSTKEY {
    my($dh) = @_;
    $dh->rewind;
    scalar $dh->read;
}

sub NEXTKEY {
    my($dh) = @_;
    scalar $dh->read;
}

sub EXISTS {
    my($dh,$key) = @_;
    -e File::Spec->catfile(${*$dh}{io_dir_path}, $key);
}

sub FETCH {
    my($dh,$key) = @_;
    &lstat(File::Spec->catfile(${*$dh}{io_dir_path}, $key));
}

sub STORE {
    my($dh,$key,$data) = @_;
    my($atime,$mtime) = ref($data) ? @$data : ($data,$data);
    my $file = File::Spec->catfile(${*$dh}{io_dir_path}, $key);
    unless(-e $file) {
	my $io = IO::File->new($file,O_CREAT | O_RDWR);
	$io->close if $io;
    }
    utime($atime,$mtime, $file);
}

sub DELETE {
    my($dh,$key) = @_;

    # Only unlink if unlink-ing is enabled
    return 0
	unless ${*$dh}{io_dir_unlink};

    my $file = File::Spec->catfile(${*$dh}{io_dir_path}, $key);

    -d $file
	? rmdir($file)
	: unlink($file);
}

1;

__END__

#line 249

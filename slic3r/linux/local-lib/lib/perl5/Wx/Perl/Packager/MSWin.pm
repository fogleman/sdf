###################################################################################
# Distribution    Wx::Perl::Packager
# File            Wx/Perl/Packager/MSWin.pm
# Description:    module for MSWin specific handlers
# File Revision:  $Id: MSWin.pm 48 2010-04-25 00:26:34Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################
package Wx::Perl::Packager::MSWin;
use strict;
use warnings;
require Wx::Perl::Packager::Base;
use base qw(  Wx::Perl::Packager::Base );
use Win32;
use Win32::File;

our $VERSION = '0.27';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    return $self;
}

sub config_system {
    my $self = shift;

    $self->set_so_module_suffix(''); # different linux dists symlink the .so libraries differently
                                     # BAH. the loaders in Wx::Perl::Packager will look for
                                     # modules ending in '.so'  -  If your modules get packaged
                                     # differently, put the suffix here.
                                     # e.g. if your module when packaged is
                                     # wxlibs_gcc_base.so.0.6.0
                                     # you should $self->set_so_module_suffix('.0.6.0')
    
    $self->set_relocate_pdkcheck(0); # relocate the Wx dlls during PDK Check - never necessary it seems
    
    $self->set_relocate_packaged(1); # relocate the Wx Dlls when running as PerlApp
    
    $self->set_relocate_wx_main(1);  # if set_relocate_packaged is true and we find 'wxmain.dll'
                                     # as a bound file, we load it as Wx.dll ( which it should be
                                     # if user as bound it). This is the current fix for PerlApp
                                     # segmentation fault on exit in Linux. Makes no difference
                                     # in MSWin
    
    $self->set_unlink_relocated(1);  # delete the extracted files - ensures relocated are loaded
    
    $self->set_loadmode_pdkcheck('nullsub'); # standard | nullsub | packload  during pdkcheck
                                             # standard uses normal Wx loading
                                             # nullsub - no extensions are loaded
                                             # packload - extensions are loaded by Wx::Perl::Packager

    $self->set_loadmode_packaged('packload');# as above, when running as PerlApp
    
    $self->set_loadcore_pdkcheck(0); # use DynaLoader to load wx modules listed by
                                     # get_core_modules method (below)during pdkcheck
                                     
    $self->set_loadcore_packaged(1); # as above, when running as PerlApp
    
    $self->set_unload_loaded_core(1);# unload any librefs we loaded
                                     # (uses DynaLoader in an END block )
                                     
    $self->set_unload_loaded_plugins(1); # unload plugins ( html, stc, gl .. etc) that are
                                         # loaded via 'packload'. This seems to be necessary
                                         # to ensure correct unloading order.
                                         # Note - plugins are loaded using
                                         # Wx::_load_plugin  (not DynaLoader);
    
    $self->set_pdkcheck_exit(0);     # because of the current seg fault on exit in linux
                                     # you can't package using PerlApp
                                     # setting this to '1' calls 'exit(0)' after
                                     # Wx has loaded during pdkcheck
                                     # Drastic - but it is the current hack for this failure on linux
    
    $self->set_pdkcheck_handle(1);   # if true, use special handling during pdkcheck
                                     # if false, treat as standard perl ( all other pdkcheck
                                     # options are ignored)
    
    $self->SUPER::config_system;
}


sub delete_file {
    my( $self, $target) = @_;
    return if !-f $target;
    my $attribs = Win32::File::NORMAL|Win32::File::TEMPORARY;
    Win32::File::SetAttributes($target, $attribs);
    unlink $target;
}

sub compare_paths {
    my($self, $one, $two) = @_;
    $one =~ s/\//\\/g;
    $two =~ s/\//\\/g;
    $one = lc(Win32::GetLongPathName($one));
    $two = lc(Win32::GetLongPathName($two));
    return ( $one eq $two );
}

sub get_core_modules { (qw( mingw gdiplus base core adv )) }

sub config_modules {
    my $self = shift;
    
    $self->get_modules->{wx}      = { filename => 'wxmain.dll',   loaded => 0, libref => undef, missing_fatal => 0 };
    
    $self->get_modules->{mingw}   = { filename => 'mingwm10.dll', loaded => 0, libref => undef, missing_fatal => 0 };
    # keep backwards compatibility with gdiplus hack
    $self->get_modules->{gdiplus} = { filename => 'gdiplus.dll',  loaded => 0, libref => undef, missing_fatal => 0 };
    
    $self->SUPER::config_modules;
}

sub setsys_filepath {
    my($self, $filepath) = @_;
    $filepath =~ s/\//\\/g;
    $filepath = Win32::GetLongPathName($filepath) || $filepath;
    return $filepath;
}

sub prepare_perl {
    my $self = shift;
    $self->_set_mingwdll( $self->get_wx_load_path );
};

sub prepare_pdkcheck {
    my $self = shift;
    $self->_set_mingwdll( $self->get_wx_load_path );
    $ENV{PATH} = $self->get_wx_load_path . ';' . $ENV{PATH};
    
    # mingw-w64 built Wx will fault on pdkcheck exit ?
    my $mdll = $self->get_modules->{mingw}->{filename};
    if($mdll =~ /^libgcc/) {
    	$self->set_pdkcheck_exit(1);
    }
}

sub prepare_perlapp {
    my $self = shift;
    require Wx::Perl::Packager::Mini;
    $self->_set_mingwdll( $self->get_app_extract_path );
}

sub _set_mingwdll {
    my($self, $dir) = @_;
    my $defaultmingw = 'mingwm10.dll';
    opendir(MYWXDIR, $dir) or die qq(Unable to open directory $dir : $!);
    my @mingfiles = grep { /^libgcc_/ } readdir(MYWXDIR);
    closedir(MYWXDIR);
    if($mingfiles[0] && (-f qq($dir/$mingfiles[0]))) {
        $defaultmingw = $mingfiles[0];
    }
    $self->debug_print(qq(mingw runtime is $defaultmingw));
    $self->get_modules->{mingw}->{filename} = $defaultmingw;
}



1;

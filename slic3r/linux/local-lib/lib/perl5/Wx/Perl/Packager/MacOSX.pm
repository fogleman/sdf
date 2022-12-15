###################################################################################
# Distribution    Wx::Perl::Packager
# File            Wx/Perl/Packager/MacOSX.pm
# Description:    module for MacOSX specific handlers
# File Revision:  $Id: MacOSX.pm 48 2010-04-25 00:26:34Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################
package Wx::Perl::Packager::MacOSX;
use strict;
use warnings;
require Wx::Perl::Packager::Base;
use base qw(  Wx::Perl::Packager::Base );

our $VERSION = '0.27';

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( @_ );
    
    return $self;
}

sub config_modules {
    my $self = shift;
    
    $self->get_modules->{wx}      = { filename => 'wxmain.bundle', loaded => 0, libref => undef, missing_fatal => 0 };
    
    $self->SUPER::config_modules;
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
    
    $self->set_unlink_relocated(0);  # delete the extracted files - ensures relocated are loaded
    
    $self->set_loadmode_pdkcheck('standard'); # standard | nullsub | packload  during pdkcheck
                                             # standard uses normal Wx loading
                                             # nullsub - no extensions are loaded
                                             # packload - extensions are loaded by Wx::Perl::Packager

    $self->set_loadmode_packaged('standard');# as above, when running as PerlApp
    
    $self->set_loadcore_pdkcheck(0); # use DynaLoader to load wx modules listed by
                                     # get_core_modules method (below)during pdkcheck
                                     
    $self->set_loadcore_packaged(0); # as above, when running as PerlApp
    
    $self->set_unload_loaded_core(0);# unload any librefs we loaded
                                     # (uses DynaLoader in an END block )
                                     
    $self->set_unload_loaded_plugins(0); # unload plugins ( html, stc, gl .. etc) that are
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

sub prepare_pdkcheck {
    my $self = shift;
    die qq(You must set DYLD_LIBRARY_PATH to include the path to wxWidgets dlls before running PerlApp) if not exists($ENV{DYLD_LIBRARY_PATH});
    # set PDK Check EXIT to correct value for OSX 10.4 ( osx v 8)
    my $osxver = $self->get_osx_major_version;
    if($osxver == 8) {
        $self->set_pdkcheck_exit(1);
    }
}

sub get_osx_major_version {
   my $verstr =  `uname -r`;
   if( $verstr =~ /^(\d+)/ ) {
       return $1;
   } else {
       die qq(Could not determine OSX version number);
   }
}


1;

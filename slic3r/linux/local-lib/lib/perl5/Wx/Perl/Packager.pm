###################################################################################
# Distribution    Wx::Perl::Packager
# File            Wx/Perl/Packager.pm
# Description:    Assist packaging wxPerl applicatons
# File Revision:  $Id: Packager.pm 48 2010-04-25 00:26:34Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################

package Wx::Perl::Packager;
use 5.008;
use strict;
use warnings;
require Exporter;
use base qw( Exporter );
our $VERSION = '0.27';
use Wx::Mini;

our $_require_overwite = 0;
our $_debug_print_on   = $ENV{WXPERLPACKAGER_DEBUGPRINT_ON} || 0;
our $handler;

#-----------------------------------------------
# Flag to force some cleanup on MSW
#-----------------------------------------------

$_require_overwite = 0;

for (@ARGV) {
    $_require_overwite = 1 if $_ eq '--force-overwrite-wx-libraries';
    $_debug_print_on   = 1 if $_ eq '--set-wx-perl-packager-debug-on';
}

&_start;

sub _start {
    #-----------------------------------------------
    # Main Handling
    #-----------------------------------------------  
    
    if ($^O =~ /^mswin/i) {
        require Wx::Perl::Packager::MSWin;
        $handler = Wx::Perl::Packager::MSWin->new;
    } elsif($^O =~ /^linux/i) {
        require Wx::Perl::Packager::Linux;
        $handler = Wx::Perl::Packager::Linux->new;
    } elsif($^O =~ /^darwin/i) {
        require Wx::Perl::Packager::MacOSX;
        $handler = Wx::Perl::Packager::MacOSX->new;
    } else {
        warn 'Wx::Perl:Packager is not implemented on this operating system';
    }
        
    $handler->configure if $handler;
    
    $handler->post_configure if $handler;
}

END {
    my $mainthread = 1;
    eval {
        my $threadid = threads->tid();
        $mainthread = ( $threadid ) ? 0 : 1;
        print STDERR qq(Thread ID $threadid\n) if $_debug_print_on;
    };
    $handler->cleanup_on_exit if( $handler && $mainthread );
}

#-----------------------------------------------
# Some utilities (retained for backwards compat)
#-----------------------------------------------

sub runtime {
    return $handler->get_config->get_runtime;
}

sub packaged {
    return $handler->get_config->get_packaged;
}

sub get_wxpath {
    return $handler->get_config->get_wx_load_path;
}

sub get_wxlibraries {
    my @libfiles = ();
    return @libfiles if packaged();
    my $libpath = get_wxpath();
    if( $libpath && (-d $libpath) ) {
        opendir(WXDIR, $libpath) or die qq(Could not open Wx Library Path : $libpath: $!);
        my @files = grep { /\.(so|dll)$/ } readdir(WXDIR);
        closedir(WXDIR);
        for (@files) {
            push( @libfiles, qq($libpath/$_) ) if($_ ne 'gdiplus.dll' );
        }   
    }
    return @libfiles;
}

sub get_wxboundfiles {
    my @libfiles = ();
    return @libfiles if packaged();
    my @files = get_wxlibraries();
    
    for (@files) {
        my $filepath = $_;
        my @vals = split(/[\\\/]/, $filepath);
        my $filename = pop(@vals);
        
        push( @libfiles, { boundfile   => $filename,
                           autoextract => 1,
                           file        => $filepath,
                         }
            );
    }
    return @libfiles;
}


=head1 NAME

Wx::Perl::Packager

=head1 VERSION

Version 0.27

=head1 SYNOPSIS

    For PerlApp/PDK and PAR
    
    At the start of your script ...
    
    #!/usr/bin/perl
    use Wx::Perl::Packager;
    use Wx;
    .....
    
    or if you use threads with your application
    #!/usr/bin/perl
    use threads;
    use threads::shared;
    use Wx::Perl::Packager;
    use Wx;

=head1 Description

    Assist packaging wxPerl applications on Linux (GTK)  and MSWin

    Wx::Perl::Packager must be loaded before any part of Wx so should appear at the
    top of your main script. If you load any part of Wx in a BEGIN block, then you
    must load Wx::Perl::Packager before it in your first BEGIN block. This may cause
    you problems if you use threads within your Wx application. The threads
    documentation advises against loading threads in a BEGIN block - so don't do it.

=head1 For PerlApp on MS Windows

    putting Wx::Perl:Packager at the top of your script as described above may be
    all that is required for recent versions of PerlApp. However, using an x64
    64 bit version on PerlApp and 64 bit Wx PPMs, you may encounter a fault on exit
    when closing the application. This will be apparant when testing the app. You can
    work around this by binding the Wx.dll file as wxmain.dll. That is:
    
    bind somepath..../auto/Wx/Wx.dll
      as
    wxmain.dll
    
    This will fix this issue.
    
    Note that PerlApp 8.0 and greater may report incorrect msvcrtXX.dll dependencies
    for the wxWidgets dll's. These errors can be ignored. The libraries link only
    against the known msvcrt.dll and require no additional MSVCRTXX runtimes.
    
    Windows 2000
    
    Your distributed applications can run on Windows 2000, but you will have to include
    the redistributable gdiplus.dll from Microsoft. Search MSDN for
    'gdiplus redistributable'.
    Once downloaded and extracted, you can simply bind the gdiplus.dll to your
    PerlApp executable.
    
=head1 For PerlApp on Linux

    if you are using the PPMs from http://www.wxperl.co.uk/repository ( add this
    to your repository list), packaging with PerlApp is possible.
    
    You must add each wxWidgets dll that you use as a bound file.
    e.g. <perlpath>/site/lib/Alien../wxbase28u_somename.so.0
    should be bound simply as 'wxbase28u_somename.so.0' and should be
    set to extract automatically.
    
    YOU MUST also bind <perlpath>/site/lib/auto/Wx/Wx.so as
    'wxmain.so' alongside your wxwidgets modules. This is the current work around
    for a segmentation fault when PerlApp exits. Hopefully there will be
    a better solution soon.  

=head1 For PerlApp on MacOSX

    The Wx distribution available as a PPM from http://www.wxperl.co.uk/repository ( add this
    to your repository list), can be packaged using PerlApp and Perl510
    
    For PerlApp packaging and testing, you must set the DYLD_LIBRARY_PATH to the wxWidgets
    dylib files before running PerlApp. If you have installed PPMS and the PDK in default
    locations, the two required commands will look like:
    
    export DYLD_LIBRARY_PATH=/Users/yourusername/Library/ActivePerl-5.10/lib/auto/Wx/wxPerl.app/Contents/Frameworks
    /usr/bin/open "/Applications/ActiveState Perl Dev Kit/PerlApp.app"
    
    Creating and testing the app will work because you have set the DYLD_LIBRARY_PATH environment variable.
    
    Once you have finished working in PerlApp, you will have to make some additions to your created .app .
    
    If your new app is located at mydir/myapp.app, the necessary procedure is
    
    cd mydir.app/Contents
    mkdir Frameworks
    cp -p /Users/yourusername/Library/ActivePerl-5.10/lib/auto/Wx/wxPerl.app/Contents/Frameworks/* Frameworks
    
    and that should be it. Your app should now be distributable and run without the need for a DYLD_LIBRARY_PATH
    
    This works because the Wx .bundle files and wxWidgets dylib files in the PPM distribution are built to find
    dependencies relative to the executable that loads them. If you already have a different packaging method that
    relies on setting DYLD_LIBRARY_PATH at run time, then that too should work without problems.
    
    When run on some MacOSX version / architecture combinations (behaviour has been noted on a MacOSX 10.4 G4 ppc machine)
    your PerlApp application may cause error dialogs on exit ("Application Quit Unexpectedly")
    
    You can fix this by binding the Wx.bundle file as wxmain.bundle. That is, bind
    pathtoyourppminstall/site/lib/auto/Wx/Wx.bundle
       as
    wxmain.bundle
    
    You may wish to apply this fix to all your .app packages.
    

=head1 PerlApp General

    Wx::Perl::Packager does not support the --dyndll option for PerlApp.
    
    Wx::Perl::Packager does not support the --clean option for PerlApp
    
    Wx::Perl::Packager works with PerlApp by moving the following bound or included
    wxWidgets files to a separate temp directory on MSWin and Linux (and Mac OSX
    for wxmain.dylib).
    
    base
    core
    adv
    mingwm10.dll if present for 32 bit executables
    libgcc_s_sjlj-1.dll if present for 64 bit executables
    gdiplus.dll if needed by OS.
    wxmain.(dll|so.0|dylib)
    
    The name of the directory is created using the logged in username, and the full path
    of the executable. This ensures that your application gets the correct Wx dlls whilst
    also ensuring that only one permanent temp directory is ever created for a unique set
    of wxWidgets DLLs
    
    All the wxWidgets dlls,  mingwm10.dll and /or libgcc_s_sjlj-1.dll should be bound as 'dllname.dll'.
    (i.e. not in subdirectories)

=head1 For PAR

    PAR assistant
    
    run 'wxpar' exactly as you would run pp.
        
    e.g.  wxpar --gui --icon=myicon.ico -o myprog.exe myscript.pl

    At the start of your script ...
    
    #!c:/path/to/perl.exe
    use Wx::Perl::Packager;
    use Wx;
    .....
    
    or if you use threads with your application
    #!c:/path/to/perl.exe
    use threads;
    use threads::shared;
    use Wx::Perl::Packager;
    use Wx
    
    Wx::Perl::Packager must be loaded before any part of Wx so should appear at the
    top of your main script. If you load any part of Wx in a BEGIN block, then you
    must load Wx::Perl::Packager before it in your first BEGIN block. This may cause
    you problems if you use threads within your Wx application. The threads
    documentation advises against loading threads in a BEGIN block - so don't do it.
    
    wxpar will accept a single named argument that allows you to define how the
    wxWidgets libraries are named on GTK.
    wxpar ordinarily packages the libraries as wxbase28u_somename.so
    This will always work if using Wx::Perl::Packager.
    However, it maybe that you don't want to use Wx::Perl::Packager, in which case
    you need the correct extension.
    
    If you want librararies packaged as wxbase28u_somename.so.0, then pass the first
    two arguments to wxpar as
    
    wxpar wxextension .0
    
    If you want wxbase28u_somename.so.0.6.0 , for example
    
    wxpar wxextension .0.6.0
    
    which would mean a full line something like
    
    wxpar wxextension .0.6.0 -o myprog.exe myscript.pl
    
    NOTE: the arguments must be FIRST and will break Wx::Perl::Packager (which should
    not be needed in this case).
    
    OF COURSE - the symlinks must actually exist. :-)

=head1 Nasty Internals

    As Commented in Wx:Perl::Packager::Linux the packager is configured with several
    options. Mix and match if you think there's a better way.
    
    $self->set_so_module_suffix(''); # different linux dists symlink the .so libraries differently
                                     # BAH. the loaders in Wx::Perl::Packager will look for
                                     # modules ending in '.so'  - If your modules get packaged
                                     # differently, put the suffix here.
                                     # e.g. if your module when packaged is
                                     # wxlibs_gcc_base.so.0.6.0
                                     # you should $self->set_so_module_suffix('.0.6.0')
    
    $self->set_relocate_pdkcheck(0); # relocate the Wx dlls during PDK Check - never necessary it seems
    
    $self->set_relocate_packaged(1); # relocate the Wx Dlls when running as PerlApp
    
    $self->set_relocate_wx_main(1);  # if set_relocate_packaged is true and we find 'wxmain.so'
                                     # as a bound file, we load it as Wx.so ( which it should be
                                     # if user as bound it). This is the current fix for PerlApp
                                     # segmentation fault on exit in Linux. Makes no difference
                                     # in MSWin
    
    $self->set_unlink_relocated(1);  # delete the extracted files - ensures relocated are loaded
    
    $self->set_loadmode_pdkcheck('packload'); # standard | nullsub | packload  during pdkcheck
                                              # standard uses normal Wx loading
                                              # nullsub - no extensions are loaded
                                              # packload - extensions are loaded by Wx::Perl::Packager

    $self->set_loadmode_packaged('packload');# as above, when running as PerlApp
    
    $self->set_loadcore_pdkcheck(1); # use DynaLoader to load wx modules listed by
                                     # get_core_modules method (below)during pdkcheck
                                     
    $self->set_loadcore_packaged(1); # as above, when running as PerlApp
    
    $self->set_unload_loaded_core(1);# unload any librefs we loaded
                                     # (uses DynaLoader in an END block )
    
    $self->set_unload_loaded_plugins(1); # unload plugins ( html, stc, gl .. etc) that are
                                         # loaded via 'packload'. This seems to be necessary
                                         # to ensure correct unloading order.
                                         # Note - plugins are loaded using
                                         # Wx::_load_plugin  (not DynaLoader);
    
    $self->set_pdkcheck_exit(1);     # because of the current seg fault on exit in linux
                                     # you can't package using PerlApp
                                     # this setting calls 'exit(0)' after
                                     # Wx has loaded.
                                     # Drastic - but it is the current hack for this failure on linux

=head1 Packaging Test Script

    There is a test script at Wx/Perl/Packager/resource/packtest.pl that you can
    use to test your packaging method. (i.e. package it and check if it runs);

=head1 Methods

=item Wx::Perl::Packager::runtime()

    returns PERLAPP, PARLEXE, or PERL to indicate how the script was executed.
    (Under PerlApp, pp packaged PAR, or as a Perl script.

    my $env = Wx::Perl::Packager::runtime();

=item Wx::Perl::Packager::packaged()

    returns 1 or 0 (for true / false ) to indicate if script is running packaged or as
    a Perl script.

    my $packaged = Wx::Perl::Packager::packaged();

=item Wx::Perl::Packager::get_wxpath()

    returns the path to the directory where wxWidgets library modules are stored.
    Only useful when packaging a script.

    my $wxpath = Wx::Perl::Packager::get_wxpath();

=item Wx::Perl::Packager::get_wxboundfiles()

    returns a list of hashrefs where the key value pairs are:
    
    boundfile   =>  the relative name of the file when bound (e.g myfile.dll)
    file        =>  the source file on disc
    autoextract =>  0/1  should the file be extracted on startup
    
    Only useful when packaging a script. If called within a packaged script,
    returns an empty list. In addition to the wxWidgets dlls, this function
    will also return the external and required bound location of the
    gdiplus.dll if present in Alien::wxWidgets. If bound to the packaged
    executable at the required location, Wx::Perl::Packager will ensure that
    gdiplus.dll is on the path if your packaged executable is run on an
    operating system that requires it.
    
    my %wxlibs = Wx::Perl::Packager::get_wxboundfiles();

=item Wx::Perl::Packager::get_wxlibraries()

    This function is deprecated. Use get_wxboundfiles() instead.
    
    returns a list of the full path names of all wxWidgets library modules.
    Only useful when packaging a script. If called within a packaged script,
    returns an empty list.
    
    Use Wx::Perl::Packager::get_wxlibraries();
    my @wxlibs = Wx::Perl::Packager::get_wxlibraries();


=head1 AUTHOR

Mark Dootson, C<< <mdootson at cpan.org> >>

=head1 DOCUMENTATION

You can find documentation for this module with the perldoc command.

    perldoc Wx::Perl::Packager

=head1 ACKNOWLEDGEMENTS

Mattia Barbon for wxPerl.

=head1 COPYRIGHT & LICENSE

Copyright 2006 - 2010 Mark Dootson, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=cut

1;

# End of Wx::Perl::Packager

__END__

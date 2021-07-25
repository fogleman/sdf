###################################################################################
# Distribution    Wx::Perl::Packager
# File            Wx/Perl/Packager/Base.pm
# Description:    base module for OS specific handlers
# File Revision:  $Id: Base.pm 48 2010-04-25 00:26:34Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################

package Wx::Perl::Packager::Base;

use strict;
use warnings;
require Class::Accessor;
use base qw( Class::Accessor );
use File::Copy;
use Digest::MD5;

our $VERSION = '0.27';

#-------------------------------------
# Accessors
#-------------------------------------

__PACKAGE__->follow_best_practice; # I like get/set

__PACKAGE__->mk_ro_accessors( qw( config debug_on is_mswin is_darwin is_linux path_delim dll_suffix) );

__PACKAGE__->mk_accessors( qw( relocate_pdkcheck relocate_packaged
    loadmode_pdkcheck loadmode_packaged loadcore_pdkcheck loadcore_packaged relocateable core_relocated require_overwrite 
    inner_wx_load_path inner_app_extract_path inner_app_relocate_path packaged runtime pdkautopackaged basemodule
    modules unload_loaded_core core_loaded so_module_suffix path_separator pdkcheck_exit unload_loaded_plugins
    unlink_relocated relocate_wx_main pdkcheck_handle
    ));

#---------------------------------------
# Constructor with default configuration
#---------------------------------------

sub new {
    my $class = shift;
    my $self = $class->SUPER::new( {
        debug_on            => $Wx::Perl::Packager::_debug_print_on,
        relocate_pdkcheck   => 0,
        relocate_packaged   => 0,
        relocate_wx_main    => 0,
        loadmode_pdkcheck   => 'standard',  # standard | nullsub | packload
        loadmode_packaged   => 'packload',
        loadcore_pdkcheck   => 0,
        loadcore_packaged   => 0,
        unload_loaded_core  => 1,
        unload_loaded_plugins => 1,
        require_overwrite   => 0,
        runtime             => 'PERL',
        packaged            => 0,
        path_delim          => ( $^O =~ /^mswin/i ) ? ';' : ':',
        dll_suffix          => ( $^O =~ /^mswin/i ) ? '.dll' : '.so',
        relocateable        => 0,
        core_relocated      => 0,
        core_loaded         => 0,
        pdkautopackaged     => 0,
        pdkcheck_exit       => 0,
        pdkcheck_handle     => 0,
        unlink_relocated    => 0,
        path_separator      => ( $^O =~ /^mswin/i ) ? "\\" : '/',
        is_mswin            => ( $^O =~ /^mswin/i ) ? 1 : 0,
        is_linux            => ( $^O =~ /^linux$/i ) ? 1 : 0,
        is_darwin           => ( $^O =~ /^darwin$/i ) ? 1 : 0,
        inner_wx_load_path      => ( $Wx::wx_path ) ? $Wx::wx_path : '',
        inner_app_extract_path  => '',
        inner_app_relocate_path => '',
        modules             => {},
        so_module_suffix    => '',
        }
    );
    $self->debug_print('Initial wx_path is : ' . $self->get_wx_load_path);
    
    return $self;
}

sub cleanup_on_exit { $_[0]->debug_print('Clean up on Exit'); }

sub post_configure {
    my $self = shift;
    my $runtime = $self->get_runtime;
    if($runtime eq 'PDKCHECK') {
        exit(0) if $self->get_pdkcheck_exit;
    }
}

sub debug_print {
    return 1 if !$_[0]->get_debug_on;
    print STDERR 'DEBUG : ' . $_[1] . qq(\n);
}

sub get_core_modules { (qw( base core adv )) }
sub is_missing_fatal { ( $_[1] =~ /^(base|core|adv)$/ ) ? 1 : 0; } # not always same list as get_core_modules

sub configure {
    my ($self, $requireoverwrite) = @_;
    
    $self->set_require_overwrite($requireoverwrite);
    
    $self->config_system();
    $self->config_modules();
    $self->config_environment();
    
    my $runtime = $self->get_runtime;
    $self->debug_print('preparing Wx for runtime ' . $runtime);
    
    $self->prepare_perl     if $runtime eq 'PERL';        
    $self->prepare_pdkcheck if $runtime eq 'PDKCHECK';     
    $self->prepare_perlapp  if $runtime eq 'PERLAPP';     
    $self->prepare_parlexe  if $runtime eq 'PARLEXE';     
        
    $self->debug_print('Runtime ' . $runtime . ' Preparation complete');
    
    #----------------------------------------------------
    # return here for standard perl before Mini is loaded
    #----------------------------------------------------
    
    return if $runtime eq 'PERL';
    
    $self->debug_print('Preparing Load Paths for Wx');
    
    $self->prepare_load_paths;
    
    $self->debug_print('Load Paths Complete');
    
    my $requestrelocate;
    if($runtime eq 'PDKCHECK') {
        $requestrelocate = $self->get_relocate_pdkcheck;
    } elsif( $runtime eq 'PERLAPP') {
        $requestrelocate = $self->get_relocate_packaged;
    }
    
    if ($self->get_relocateable && $requestrelocate) {
        $self->debug_print('Relocating extracted modules for Wx');
        $self->relocate_wx;
        $self->debug_print('Relocation Complete');
    }
    
    $self->debug_print('Preparing and Loading Wx');
    
    #################################################################
    
    $self->run_wx_start; # THIS LOADS WX
    
    #################################################################
    
    $self->debug_print('Wx Load Complete');
    
    $self->before_config_return();
}

sub config_system { 1; }

sub config_modules {
    my $self = shift;
    
    my $modulesuffix = $self->get_so_module_suffix || ''; # module suffix can be undef
    
    foreach my $modulekey ( keys (%{ $Wx::dlls })) {
        if(exists( $Wx::dlls->{$modulekey} ) && $Wx::dlls->{$modulekey}) {
            
            $self->get_modules->{$modulekey} =
                { filename => $Wx::dlls->{$modulekey} . $modulesuffix,
                  loaded => 0,
                  libref => undef,
                  missing_fatal => $self->is_missing_fatal($modulekey),
                };
            }
    }
    
    my $basemodule = ( exists($self->get_modules->{base}) )
        
        ? $self->get_modules->{base}->{filename}
        : $self->get_modules->{core}->{filename};
        
    $self->set_basemodule($basemodule);
}

sub config_environment {
    my $self = shift;
    #------------------------------------------------------------
    # determine if we are run as script, PAR, PerlApp
    #------------------------------------------------------------
    if(my $pdkversion = $PerlApp::VERSION) {
        # PerlApp::VERSION is definitive for PerlApp
        my @verparts = split(/\./, $pdkversion);
        $pdkversion = '';
        for (@verparts) {
            $pdkversion .= sprintf("%04d", $_);
        }
        $pdkversion =~ s/^0+//;
        #die q(This version of Wx::Perl::Packager requires PDK version 7.1 or greater) if( $pdkversion < 700010000 );
        my $execpath = PerlApp::exe();
        
        if($execpath =~ /pdkcheck/) {
            if($self->get_pdkcheck_handle) {
                $self->set_runtime('PDKCHECK');
                $self->set_packaged(0);
            } else {
                $self->set_runtime('PERL');
                $self->set_packaged(0);
            }
        } else {
            $self->set_runtime('PERLAPP');
            $self->set_packaged(1);
        }
        
    } elsif($ENV{PAR_0} && -f($ENV{PAR_0})) {
        $self->set_runtime('PARLEXE');
        $self->set_packaged(1);
    } else {
        # we are perl - reiterate defaults
        $self->set_runtime('PERL');
        $self->set_packaged(0);
    }
    #------------------------------------------------------------
    # set the extract paths and relocate paths
    #------------------------------------------------------------
    
    #------------------------------------
    # RUNTIME PERL
    #------------------------------------
        
    if($self->get_runtime() eq 'PERL') {
        $self->set_relocateable(0);
            
    #------------------------------------
    # RUNTIME PERLAPP & PDKCHECK
    #------------------------------------
    
    } elsif($PerlApp::VERSION) {
        #--------------------------------
        # IS Wx In the PerlApp::RUNLIB
        #--------------------------------
        my $perlappset = 0;
        my $basemodule = $self->get_basemodule;
        my $runlib = $PerlApp::RUNLIB;
        if( $runlib && (-d $PerlApp::RUNLIB )) {
            my $checkpath = $PerlApp::RUNLIB . '/' . $basemodule;
            if(-f  $checkpath ) {
                $self->set_pdkautopackaged(0);
                $self->set_relocateable(0);
                $self->set_wx_load_path( $checkpath );
                $perlappset = 1;
                
                # final check
                die qq(Cannot find directory $checkpath) if !-d $checkpath;
                
            }
        }
        #--------------------------------
        # Were Wx modules bound manually
        #--------------------------------
        if( !$perlappset ) {
            my $basefile = PerlApp::extract_bound_file($basemodule);
            # user packaged
            if( $basefile ) {
                if($basefile =~ /^(.*)[\\\/]\Q$basemodule\E$/) {
                    my $regpath = $1;
                    die qq(Cannot find directory $regpath) if !-d $regpath;
                    $self->set_app_extract_path($regpath);
                    $self->set_wx_load_path($regpath);
                    $self->set_relocateable(1);
                    $self->set_pdkautopackaged(0);
                    $perlappset = 1;
                    # final check
                }
        #------------------------------------------
        # OR Were Wx modules bound by PDK heuristic
        #------------------------------------------
            } else {
            # perlapp packaged (we hope )
                $self->set_pdkautopackaged(1);
                #-------------------------------------------------
                #  see if user has packaged wxmain.dll
                #-------------------------------------------------
                {
                    my $wxmainfile = $self->get_module_filename('wx');
                    $self->debug_print(qq(Module Mainfile Path is $wxmainfile));
                    my $dllfile = PerlApp::extract_bound_file($wxmainfile);
                    if($dllfile && -f $dllfile) {
                        $self->debug_print(qq(Module Mainfile FilePath is $dllfile));
                        if($dllfile =~ /^(.*)[\\\/]\Q$wxmainfile\E$/) {
                            my $regpath = $1;
                            die qq(Cannot find directory $regpath) if !-d $regpath;
                            $self->set_app_extract_path($regpath);
                            $self->set_wx_load_path($regpath);
                            $self->set_relocateable(1);
                            $perlappset = 1;
                            
                        }
                    }
                }
                if(!$perlappset) {
                #-------------------------------------------------
                # user may also set a marker 'wxextractmarker'
                #-------------------------------------------------
                    my $markerfile = PerlApp::extract_bound_file('wxextractmarker');
                    if($markerfile && -f $markerfile) {
                        if($markerfile =~ /^(.*)[\\\/]wxextractmarker$/) {
                            my $regpath = $1;
                            die qq(Cannot find directory $regpath) if !-d $regpath;
                            $self->set_app_extract_path($regpath);
                            $self->set_wx_load_path($regpath);
                            $self->set_relocateable(1);
                            $perlappset = 1;
                        }
                    }
                }
                if(!$perlappset) {
                #-------------------------------------------------
                # No handy marker :-(
                #-------------------------------------------------
                    # check the first item in the path
                    # if author has placed Wx::Perl::Packager at start of
                    # script, that is where it will be.
                    # we will limit search to one level of
                    # path as unexpected stuff may (will) happen
                    # if we traverse further
            
                    my $delim = $self->get_path_delim();
                    my @envpaths = split(/$delim/, $ENV{PATH});
                    my $pdkdirpath = shift @envpaths;
                    $pdkdirpath =~ s/\\/\//g;
                    $pdkdirpath =~ s/\/$//;
                    my $fpath = qq($pdkdirpath/$basemodule);
                    if($fpath && (-f $fpath)) {
                        $self->set_relocateable(1);
                        $perlappset = 1;
                        $self->set_app_extract_path($pdkdirpath);
                        $self->set_wx_load_path($pdkdirpath);
                    }
                }
            }
        }
    #------------------------------------
    # RUNTIME PARLEXE
    #------------------------------------
    
    } elsif($self->get_runtime() eq 'PARLEXE') {
        $self->set_relocateable(0);
        # the extract path we get from PAR
        # could be wxlib + module
        # or just module
        my @ldpath = split(/[\\\/]/, $ENV{PAR_0});
        pop(@ldpath);
        my $loadpath = join('/', @ldpath);
        $self->set_app_extract_path($loadpath);
        $self->set_wx_load_path($loadpath);
    }
}

sub before_config_return { 1; }

sub prepare_perl { 1; };

sub prepare_pdkcheck { 1;}

sub prepare_perlapp {
    require Wx::Perl::Packager::Mini;
}

sub prepare_parlexe { 1;}

sub prepare_load_paths {
    my $self = shift;
    my $loadpath = $self->get_wx_load_path;
    $self->debug_print(qq(Load Path set $loadpath));
}

sub relocate_wx {
    my $self = shift;
    
    # set the relocate path
    $self->config_relocate_path;
    
    my @core = $self->get_core_modules;
    
    my $targetpath = $self->get_app_relocate_path;
    $self->debug_print(qq(Relocate Path is $targetpath));
    die 'relocate path does not exist' if !-d $targetpath;
    
    my $sourcepath = $self->get_app_extract_path;
    $self->debug_print(qq(Extract Path is $sourcepath));
    die 'extract path does not exist' if !-d $sourcepath;
    
    my $forcewrite = $self->get_require_overwrite;

    for my $dllkey ( @core, 'wx' ) { 
        next if !$self->module_exists($dllkey);
        next if(($dllkey eq 'wx') && (!$self->get_relocate_wx_main));
        my $modulefile = $self->get_module_filename($dllkey);
        my $targetmodulepath = qq($targetpath/$modulefile);
        my $sourcemodulepath = qq($sourcepath/$modulefile);
        next if !-f $sourcemodulepath;
        my $copyrequired = 0;
        $copyrequired = 1 if !-f $targetmodulepath;
        $copyrequired = 1 if $forcewrite;
        if( $copyrequired ) {
            $self->delete_file($targetmodulepath);
            $self->copy_file($sourcemodulepath, $targetmodulepath) 
        }
        $self->delete_file($sourcemodulepath) if $self->get_unlink_relocated;
        $self->debug_print(qq(Relocated $dllkey));
    }
    
    $self->set_core_relocated(1);
    
}

sub do_core_load {
    my $self = shift;
    my $runtime = $self->get_runtime;
    my $coreload = 0;
    if($runtime eq 'PDKCHECK') {
        $coreload = $self->get_loadcore_pdkcheck;
        
    } elsif ($runtime eq 'PERLAPP') {
        $coreload = $self->get_loadcore_packaged;
        
    } elsif ($runtime eq 'PARLEXE') {
        $coreload = $self->get_loadcore_packaged;
        
    }
    
    $self->debug_print(qq(Core Load = $coreload));
    
    #--------------------------------------------------------
    # Load Core Modules
    #--------------------------------------------------------
    
    require DynaLoader;
    
    if( $coreload ) {
        
        for my $dll ( $self->get_core_modules ) {
            next if !$self->module_exists($dll);
            my $module = $self->get_modules->{$dll};
            my $filepath = $self->get_module_core_load_path($dll);
            next if( (!-f $filepath) && ( $module->{missing_fatal} == 0) );
            $self->debug_print(qq(Loading Core Module  $dll  from $filepath) );
            my $libref = DynaLoader::dl_load_file($filepath, 0) or die qq(Failed to load $filepath);
            $module->{libref} = $libref;
            $module->{loaded} = 1;
            push(@DynaLoader::dl_librefs,$libref) if $libref;
        }
        $self->set_core_loaded(1);
    }
}

sub run_wx_start {
    my $self = shift;

    $self->do_core_load;
    
    my $runtime = $self->get_runtime;
    my $method = 'standard';
    
    if($runtime eq 'PDKCHECK') {
        
        $method = $self->get_loadmode_pdkcheck;   
    } elsif ($runtime eq 'PERLAPP') {
        
        $method = $self->get_loadmode_packaged;
    } elsif ($runtime eq 'PARLEXE') {
        
        $method = $self->get_loadmode_packaged;
    }
    
    $self->debug_print(qq(Load Method = $method));
    
    return if(!$method || ($method eq 'standard') );
    
    #--------------------------------------------------------
    # Set Load / Unload Subs
    #--------------------------------------------------------
    
    my @loadedmodules = ();

    #---------------------------------
    # start Wx
    #---------------------------------
    
    require Wx;
    
    if( $method eq 'packload' ){
        Wx::set_load_function( sub { my $modulekey = shift;
                        my $module = $self->get_modules->{$modulekey};
                        return if !$module; # maybe mono build
                        # don't load twice
                        return if( $module->{loaded} );
                        
                        my $filepath = $self->get_module_wx_load_path($modulekey);
                        $self->debug_print(qq(Loading Plugin $modulekey from $filepath\n));
                        Wx::_load_plugin( $filepath );
                        push( @loadedmodules, $filepath);
                        
                        $module->{loaded} = 1;
                        
                        1; } );

        Wx::set_end_function( sub {
                        
                        
                        if ( $self->get_unload_loaded_plugins ) {
                            while( my $modulefilename = pop @loadedmodules ) {
                                 $self->debug_print(qq(Unloading Plugin $modulefilename));
                                 Wx::_unload_plugin( $modulefilename );
                            }
                        }
                        
                        # if we don't specifically unload dl refs, we get a fault on
                        # exit if we close the app immediatley after startup without
                        # interacting with controls (e.g STC) from the keyboard
                        
                        # conversely, the rmtree command fails when we DO interact
                        # with controls from the keyboard - which is why we  relocate
                        # to a 'permanent' dir for MSWin
                        
                        if( ( $self->get_core_loaded ) && ( $self->get_unload_loaded_core ) ) {
                        
                            my @core = $self->get_core_modules;
                            
                            while(my $dll = pop(@core) ) {
                                my $libref = $self->get_modules->{$dll}->{libref};
                                if ($libref) {
                                    $self->debug_print( qq(Unloading Core Module $dll) );
                                    DynaLoader::dl_unload_file($libref);
                                }
                            }
                        }
                        
                        1; } );
        
    } elsif( $method eq 'nullsub' ){
        
        Wx::set_load_function( sub { 1; } );
        Wx::set_end_function ( sub { 1; } );
    }  
}

sub delete_file {
    my( $self, $target) = @_;
    return if !-f $target;
    chmod 0700, $target;
    unlink $target;
}

sub copy_file {
    my( $self, $source, $target) = @_;
    File::Copy::copy($source, $target);
}

sub move_file {
    my( $self, $source, $target) = @_;
    File::Copy::move($source, $target);
}

sub compare_paths {
    my($self, $one, $two) = @_;
    $one =~ s/\\/\//g;
    $two =~ s/\\/\//g;
    return ( $one eq $two );
}


#------------------------------
# Overloads for paths
#------------------------------

sub set_app_extract_path { $_[0]->set_inner_app_extract_path( $_[0]->setsys_filepath($_[1]) ); }
sub get_app_extract_path { $_[0]->get_inner_app_extract_path; }

sub set_app_relocate_path { $_[0]->set_inner_app_relocate_path( $_[0]->setsys_filepath($_[1]) ); }
sub get_app_relocate_path { $_[0]->get_inner_app_relocate_path; }

sub set_wx_load_path { $_[0]->set_inner_wx_load_path( $_[0]->setsys_filepath($_[1]) ); }
sub get_wx_load_path { $_[0]->get_inner_wx_load_path; }
    
sub module_exists { exists($_[0]->get_modules->{$_[1]} ); }

sub get_module_filename { $_[0]->module_exists($_[1]) ? $_[0]->get_modules->{$_[1]}->{filename} : undef; }

sub get_module_wx_load_path {
    if(my $filename = $_[0]->get_module_filename($_[1])) {
        my $wxpath = $_[0]->get_wx_load_path();
       
        return ( $wxpath ) ? $wxpath . $_[0]->get_path_separator . $filename : $filename;
    } else {
        return undef;
    }
}

sub get_module_app_relocate_path {
    if(my $filename = $_[0]->get_module_filename($_[1])) {
        my $dirpath = $_[0]->get_app_relocate_path();
        
        return $dirpath . $_[0]->get_path_separator . $filename;
    } else {
        return undef;
    }
}

sub get_module_app_extract_path {
    if(my $filename = $_[0]->get_module_filename($_[1])) {
        my $dirpath = $_[0]->get_app_extract_path();
        
        return $dirpath . $_[0]->get_path_separator . $filename;
    } else {
        return undef;
    }
}

sub get_module_core_load_path {
    if(my $filename = $_[0]->get_module_filename($_[1])) {
        my $dirpath = ( $_[0]->get_core_relocated ) 
            ? $_[0]->get_app_relocate_path
            : $_[0]->get_wx_load_path;
        my $sep = ( $_[0]->get_is_mswin ) ? "\\" : '/';
        
        return ( $dirpath ) ? $dirpath . $sep . $filename : $filename;
    } else {
        return undef;
    }
}
    
sub setsys_filepath {
    my($self, $filepath) = @_;
    $filepath =~ s/\\/\//g;
    return $filepath;
}


#------------------------------------------
# If we have no alternative but to relocate
# wx dlls ........
#------------------------------------------

sub config_relocate_path {
    my $self = shift;
    return if !$self->get_relocateable(); # just in case
    
    # app extract path is writable by us - so create our wxlib extract
    # files side by side
    
    my $appextractpath = $self->get_app_extract_path();
    die qq(error in determining extract paths) if !-d $appextractpath;
    
    # determine where the standard PDK path is
    
    # get a unique extract directory for this application build
    my $runtime = $self->get_runtime();
    my $uid = getlogin || (getpwuid($<))[0];
    my $toplevel = 'wxppl-' . $uid;
    $toplevel =~ s/[^A-Za-z0-9\-_]/_/g;
    
    my $apprelocatedir;
    
    if($runtime eq 'PERLAPP') {
        # get a unique dir for this build in this location
        my $ctx = Digest::MD5->new;
        my $exec = PerlApp::exe();
        $ctx->add( $exec  );
        my $basestatfile = $appextractpath . '/' . $self->get_basemodule();
        $self->debug_print(qq(Base Core extracted module = $basestatfile));
        my $filestat = (-f $basestatfile ) ? (stat($basestatfile))[7]: 'fixed data';
        $ctx->add( $filestat );
        
        if($self->get_relocate_wx_main) {
            # we also relocate wxmain - which means we have to add that to uniqueness
            if( my $wxmain = $self->get_module_filename('wx') ) {
                my $mainstatfile = $appextractpath . '/' . $wxmain;
                $self->debug_print(qq(Wx Main extracted module = $mainstatfile));
                my $mainfilestat = (-f $mainstatfile ) ? (stat($mainstatfile))[7]: 'wxmain data';
                $ctx->add( $mainfilestat );
            }
        }
        
        $apprelocatedir = $ctx->hexdigest;
        
    }   elsif( $runtime eq 'PDKCHECK' ) {
        # we keep the same dir and overwrite
        $apprelocatedir = 'PDKCHECKBUILDING';
    }
    
    # build the directories
    my @paths = split(/[\/\\]/, $appextractpath);
    pop(@paths);
    my $apprunpath = join('/', (@paths, $toplevel));
    mkdir($apprunpath, 0700) if !-d $apprunpath;
    $apprunpath .= '/' . $apprelocatedir;
    mkdir($apprunpath, 0700) if !-d $apprunpath;
    
    $self->set_app_relocate_path($apprunpath);
}

1;

###################################################################################
# Distribution    Wx::Perl::Packager
# File            Wx/Perl/Packager/Mini.pm
# Description:    Overload Wx startup
# File Revision:  $Id: Mini.pm 48 2010-04-25 00:26:34Z  $
# License:        This program is free software; you can redistribute it and/or
#                 modify it under the same terms as Perl itself
# Copyright:      Copyright (c) 2006 - 2010 Mark Dootson
###################################################################################

package Wx::Perl::Packager::Mini;
use Carp;

our $VERSION = '0.27';

#########################################################################################


package
  Wx;
no warnings;

sub _start {
    warnings;
    &Wx::_init_binary_loader;
    my $_xs_version = $Wx::XS_VERSION;
    if ( my $handler = $Wx::Perl::Packager::handler ) {
        my $result = Wx::Perl::Packager::Mini::XSLoader::loadwx($handler, 'Wx', $_xs_version);
        Wx::wx_boot( 'Wx', $_xs_version ) if !$result;
    } else {
        Wx::wx_boot( 'Wx', $_xs_version );
    }
    
    Wx::_boot_Constant( 'Wx', $_xs_version );
    Wx::_boot_GDI( 'Wx', $_xs_version );
    Wx::Load();
}

package Wx::Perl::Packager::Mini::XSLoader;

our $VERSION = '0.27';

sub loadwx {
    
    package
       DynaLoader;
    my $wxloadhandler = shift;
    my $file = $wxloadhandler->get_module_core_load_path('wx');
    return 0 unless( $file && -f $file );
    $wxloadhandler->debug_print('Internal XSLoader used for Wx');
    
    #------------------------------------------
    # From XSLoader
    #------------------------------------------
    
    my($module) = @_;
    
    my $boots = "$module\::bootstrap";
    my $bootname = "boot_$module";
    $bootname =~ s/\W/_/g;
    @DynaLoader::dl_require_symbols = ($bootname);
    my $boot_symbol_ref;
    
    my $libref = dl_load_file($file, 0) or do { 
        Carp::croak("Can't load '$file' for module $module: " . dl_error());
    };
    push(@DynaLoader::dl_librefs,$libref);  # record loaded object

    my @unresolved = dl_undef_symbols();
    if (@unresolved) {
        Carp::carp("Undefined symbols present after loading $file: @unresolved\n");
    }

    $boot_symbol_ref = dl_find_symbol($libref, $bootname) or do {
        Carp::croak("Can't find '$bootname' symbol in $file\n");
    };

    push(@DynaLoader::dl_modules, $module); # record loaded module

    my $xs = dl_install_xsub($boots, $boot_symbol_ref, $file);

    # See comment block above
    push(@DynaLoader::dl_shared_objects, $file); # record files loaded
    return &$xs(@_);

}

1;

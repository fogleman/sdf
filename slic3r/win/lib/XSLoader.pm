#line 1 "XSLoader.pm"
# Generated from XSLoader.pm.PL (resolved %Config::Config value)
# This file is unique for every OS

package XSLoader;

$VERSION = "0.24";

#use strict;

package DynaLoader;

# No prizes for guessing why we don't say 'bootstrap DynaLoader;' here.
# NOTE: All dl_*.xs (including dl_none.xs) define a dl_error() XSUB
boot_DynaLoader('DynaLoader') if defined(&boot_DynaLoader) &&
                                !defined(&dl_error);
package XSLoader;

sub load {
    package DynaLoader;

    my ($caller, $modlibname) = caller();
    my $module = $caller;

    if (@_) {
        $module = $_[0];
    } else {
        $_[0] = $module;
    }

    # work with static linking too
    my $boots = "$module\::bootstrap";
    goto &$boots if defined &$boots;

    goto \&XSLoader::bootstrap_inherit;

    my @modparts = split(/::/,$module);
    my $modfname = $modparts[-1];

    my $modpname = join('/',@modparts);
    my $c = () = split(/::/,$caller,-1);
    $modlibname =~ s,[\\/][^\\/]+$,, while $c--;    # Q&D basename
    # Does this look like a relative path?
    if ($modlibname !~ m{^(?:[A-Za-z]:)?[\\/]}) {
        # Someone may have a #line directive that changes the file name, or
        # may be calling XSLoader::load from inside a string eval.  We cer-
        # tainly do not want to go loading some code that is not in @INC,
        # as it could be untrusted.
        #
        # We could just fall back to DynaLoader here, but then the rest of
        # this function would go untested in the perl core, since all @INC
        # paths are relative during testing.  That would be a time bomb
        # waiting to happen, since bugs could be introduced into the code.
        #
        # So look through @INC to see if $modlibname is in it.  A rela-
        # tive $modlibname is not a common occurrence, so this block is
        # not hot code.
        FOUND: {
            for (@INC) {
                if ($_ eq $modlibname) {
                    last FOUND;
                }
            }
            # Not found.  Fall back to DynaLoader.
            goto \&XSLoader::bootstrap_inherit;
        }
    }
    my $file = "$modlibname/auto/$modpname/$modfname.xs\.dll";

#   print STDERR "XSLoader::load for $module ($file)\n" if $dl_debug;

    my $bs = $file;
    $bs =~ s/(\.\w+)?(;\d*)?$/\.bs/; # look for .bs 'beside' the library

    if (-s $bs) { # only read file if it's not empty
#       print STDERR "BS: $bs ($^O, $dlsrc)\n" if $dl_debug;
        eval { do $bs; };
        warn "$bs: $@\n" if $@;
	goto \&XSLoader::bootstrap_inherit;
    }

    goto \&XSLoader::bootstrap_inherit if not -f $file;

    my $bootname = "boot_$module";
    $bootname =~ s/\W/_/g;
    @DynaLoader::dl_require_symbols = ($bootname);

    my $boot_symbol_ref;

    # Many dynamic extension loading problems will appear to come from
    # this section of code: XYZ failed at line 123 of DynaLoader.pm.
    # Often these errors are actually occurring in the initialisation
    # C code of the extension XS file. Perl reports the error as being
    # in this perl code simply because this was the last perl code
    # it executed.

    my $libref = dl_load_file($file, 0) or do { 
        require Carp;
        Carp::croak("Can't load '$file' for module $module: " . dl_error());
    };
    push(@DynaLoader::dl_librefs,$libref);  # record loaded object

    $boot_symbol_ref = dl_find_symbol($libref, $bootname) or do {
        require Carp;
        Carp::croak("Can't find '$bootname' symbol in $file\n");
    };

    push(@DynaLoader::dl_modules, $module); # record loaded module

  boot:
    my $xs = dl_install_xsub($boots, $boot_symbol_ref, $file);

    # See comment block above
    push(@DynaLoader::dl_shared_objects, $file); # record files loaded
    return &$xs(@_);
}

sub bootstrap_inherit {
    require DynaLoader;
    goto \&DynaLoader::bootstrap_inherit;
}

1;


__END__

#line 378

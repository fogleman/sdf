package PAR::Packer;
use 5.008001;
use strict;
use warnings;

our $VERSION = '1.043';

=head1 NAME

PAR::Packer - PAR Packager

=head1 DESCRIPTION

This module implements the B<App::Packer::Backend> interface, for generating
stand-alone executables, perl scripts and PAR files.

Currently, this module is used by the command line tool B<pp> internally, as
well as by the contributed F<contrib/gui_pp/gpp> program.

Since version 0.97 of PAR, this module and its related tools such as C<pp>
have been stripped from the PAR distribution and are now distributed as
the C<PAR-Packer> distribution so that PAR users need not necessarily
have a C compiler.

=cut

use Config;
use Archive::Zip ();
use ExtUtils::MakeMaker (); # just for maybe_command()
use Cwd qw( abs_path );
use File::Basename;
use File::Find ();
use File::Spec::Functions qw( :ALL );
use File::Temp qw( tempfile );
use Module::ScanDeps ();
use PAR ();
use PAR::Filter ();

use constant OPTIONS => {
    'a|addfile:s@'   => 'Additional files to pack',
    'A|addlist:s@'   => 'File containing list of additional files to pack',
    'B|bundle'       => 'Bundle core modules',
    'C|clean',       => 'Clean up temporary files',
    'c|compile'      => 'Compile code to get dependencies',
    'cd|cachedeps:s' => 'Cache detected dependencies in a file',
    'd|dependent'    => 'Do not include libperl',
    'e|eval:s'       => 'Packing one-liner',
    'E|evalfeature:s'=> 'Packing one-liner with new syntactic features',
    'x|execute'      => 'Execute code to get dependencies',
    'xargs:s'        => 'Args to pass when executing code',
    'X|exclude:s@'   => 'Exclude modules',
    'f|filter:s@'    => 'Input filters for scripts',
    'g|gui'          => 'No console window',
    'I|lib:s@'       => 'Include directories (for perl)',
    'l|link:s@'      => 'Include additional shared libraries',
    'L|log:s'        => 'Where to log packaging process information',
    'F|modfilter:s@' => 'Input filter for perl modules',
    'M|module|add:s@'=> 'Include modules',
    'm|multiarch'    => 'Build PAR file for multiple architectures',
    'n|noscan'       => 'Skips static scanning',
    'o|output:s'     => 'Output file',
    'p|par'          => 'Generate PAR file',
    'P|perlscript'   => 'Generate perl script',
    'r|run'          => 'Run the resulting executable',
    'reusable'       => 'Produce reusable executable',
    'S|save'         => 'Preserve intermediate PAR files',
    's|sign'         => 'Sign PAR files',
    'T|tempcache:s'  => 'Temp cache name',
    'u|unicode'      => 'Include Unicode stuff',
    'v|verbose:i'    => 'Verbosity level',
    'vv|verbose2',   => 'Verbosity level 2',
    'vvv|verbose3',  => 'Verbosity level 3',
    'z|compress:i'   => 'Compression level',
};

my $ValidOptions = {};
my $LongToShort = { map { /^(\w+)\|(\w+)/ ? ($1, $2) : () } grep /\|/, keys %{+OPTIONS} };
my $ShortToLong = { reverse %$LongToShort };
my $PerlExtensionRegex = qr/\.(?:al|ix|p(?:lx|l|h|m))\z/i;
my (%dep_zips, %dep_zip_files);

sub options { sort keys %{+OPTIONS} }

sub new {
    my ($class, $args, $opt, $frontend) = @_;

    $SIG{INT} = sub { exit() } if (!$SIG{INT});

    # exit gracefully and clean up after ourselves.
    # note.. in constructor because of conflict.

    my $self = bless {}, $class;

    $self->set_args($args)      if ($args);
    $self->set_options($opt)    if ($opt);
    $self->set_front($frontend) if ($frontend);

    return ($self);
}

sub set_options {
    my ($self, %opt) = @_;

    $self->{options} = \%opt;
    $self->_translate_options($self->{options});

#    $self->{parl} ||= $self->_extract_parl('PAR::StrippedPARL::Static')
#      or die("Can't find par loader");
#   $self->{parl_is_temporary} = 1;
    $self->{dynperl} ||=
      $Config{useshrplib} && ($Config{useshrplib} ne 'false');
    $self->{script_name} = $opt{script_name} || $0;
}

sub add_options {
    my ($self, %opts) = @_;

    my $opt = $self->{options};
    %$opt = (%$opt, %opts);

    $self->_translate_options($opt);
}

sub _translate_options {
    my ($self, $opt) = @_;

    $self->_create_valid_hash($self->OPTIONS, $ValidOptions);

    foreach my $key (keys(%$opt)) {
        my $value = $opt->{$key};

        if (!$ValidOptions->{$key}) {
            $self->_warn("'$key' is not a valid option!\n");
            $self->_show_usage;
        }
        else {
            $opt->{$key} = $value;
            my $other = $LongToShort->{$key} || $ShortToLong->{$key};
            $opt->{$other} = $value if defined $other;
        }
    }
}

sub add_args {
    my ($self, @arg) = @_;
    push(@{ $self->{args} }, @arg);
}

sub set_args {
    my ($self, @args) = @_;
    $self->{args} = \@args;
}

sub set_front {
    my ($self, $frontend) = @_;

    my $opt = $self->{options};
    $self->{frontend} = $frontend || $opt->{frontend};
}

# check one or more files for read permissions
sub _check_read {
    my ($self, @files) = @_;

    foreach my $file (@files) {
        unless (-r $file) {
            $self->_die("Input file $file is a directory, not a file\n")
              if (-d _);
            unless (-e _) {
                $self->_die("Input file $file was not found\n");
            }
            else {
                $self->_die("Cannot read input file $file: $!\n");
            }
        }
        unless (-f _) {
            # XXX: die?  don't try this on /dev/tty
            $self->_warn("Input $file is not a plain file\n");
        }
    }
}

# check one or more files for write permissions
sub _check_write {
    my ($self, @files) = @_;

    foreach my $file (@files) {
        if (-d $file) {
            $self->_die("Cannot write on $file, is a directory\n");
        }
        if (-e _) {
            $self->_die("Cannot write on $file: $!\n") unless -w _;
        }
    }
}

# check whether a given file might contain perl code (including .par's)
sub _check_perl {
    my ($self, $file) = @_;
    return if ($self->_check_par($file));

    unless (-T $file) {
        $self->_warn("Binary '$file' sure doesn't smell like perl source!\n");

        if (my $file_checker = $self->_can_run("file")) {
            $self->_vprint(0, "Checking file type... ");
            my $checked = `$file_checker $file`;
            if (defined $checked) {
                $self->_vprint(
                    0, "File type checking utility says this "
                      ."about your file:\n$checked\n"
                );
                if ($checked =~ /text/) {
                    $self->_vprint(
                        0, "File is a text file, so we'll accept it."
                    );
                }
                else {
                    $self->_die("Please try a perlier file!\n");
                }
            }
            else {
                $self->_die("Please try a perlier file!\n");
            }
        }
        else {
            $self->_die("Please try a perlier file!\n");
        }
    }

    my $handle = $self->_open($file);

    local $/ = "\n";
    local $_ = readline($handle);
    if (/^#!/ and !/perl/) {
        $self->_die("$file is a ", /^#!\s*(\S+)/, " script, not perl\n");
    }
}

sub _sanity_check {
    my ($self) = @_;

    my $input  = $self->{input};
    my $output = $self->{output};

    # Check the input and output files make sense, are read/writable.
    if ("@$input" eq $output) {
        my $a_out = $self->_a_out();

        if ("@$input" eq $a_out) {
            $self->_die("Packing $a_out to itself is probably not what you want to do.\n");
        }
        else {
            $self->_warn(
                "Will not write output on top of input file, ",
                "packing to $a_out instead\n"
            );
            $self->{output} = $a_out;
        }
    }
}

sub _a_out {
    my ($self) = @_;

    my $opt = $self->{options};

    return 'a' . (
          $opt->{p} ? '.par'
        : $opt->{P} ? '.pl'
        : ($Config{_exe} || '.out')
      );
}

sub _parse_opts {
    my ($self) = @_;

    my $args = $self->{args};
    my $opt  = $self->{options};

    $self->_verify_opts($opt);
    $opt->{L} = (defined($opt->{L})) ? $opt->{L} : '';
    $opt->{p} = 1 if ($opt->{m});
    $opt->{v} = (defined($opt->{v})) ? ($opt->{v} || 1) : 0;
    $opt->{v} = 2 if ($opt->{vv});
    $opt->{v} = 3 if ($opt->{vvv});
    $opt->{B} = 1 unless ($opt->{p} || $opt->{P});
    $opt->{z} = (defined($opt->{z})) ? $opt->{z} : Archive::Zip::COMPRESSION_LEVEL_DEFAULT;
    $opt->{z} = Archive::Zip::COMPRESSION_LEVEL_DEFAULT if $opt->{z} < 0;
    $opt->{z} = 9 if $opt->{z} > 9;

    $opt->{o}            = $opt->{o}            || $self->_a_out();
    $self->{output}      = $opt->{o};
    $self->{script_name} = $self->{script_name} || $opt->{script_name} || $0;

    $self->{logfh} = $self->_open('>>', $opt->{L})
      if length $opt->{L};

    if ($opt->{E}) {
        $opt->{e} = "use $];\n#line 1\n$opt->{E}";
        # XXX This is how we should also include additional default modules in the future instead of in require_modules in par.pl!
        push @{ $opt->{M} ||= [] }, 'feature' if $] >= 5.009;
    }

    if ($opt->{e}) {
        $self->_warn("Using -e 'code' as input file, ignoring @$args\n")
          if (@$args and !$opt->{r});

        my ($fh, $fake_input) = tempfile(
	    "ppXXXXX", SUFFIX => ".pl", TMPDIR => 1, UNLINK => 1);

        print $fh $opt->{e};
        close $fh;
        $self->{input} = [$fake_input];
    }
    else {
        $self->{input} ||= [];

        # Reject main.pl as input file to avoid beginner confusion
        if ( grep /(?:^|[\/\\])main\.pl$/,
             ($opt->{r} ? ($args->[0]) : @$args) )
        {
          # -r means "run this" => extra args are execution parameters

          $self->_die( "Cannot package 'main.pl' script. This file name "
                      ."is used by PAR::Packer internally for bootstrapping.");
        }
        push(@{ $self->{input} }, shift @$args) if (@$args);

        push(@{ $self->{input} }, @$args) if (@$args and !$opt->{r});
        my $in = $self->{input};

        $self->_check_read(@$in) if (@$in);
        $self->_check_perl(@$in) if (@$in);
        $self->_sanity_check();
    }
}

sub _verify_opts {
    my ($self, $opt) = @_;

    $self->_create_valid_hash($self->OPTIONS, $ValidOptions);

    my $show_usage = 0;
    foreach my $key (keys(%$opt)) {
        if (!$ValidOptions->{$key}) {
            $self->_warn("'$key' is not a valid option!\n");
            $show_usage = 1;
        }
    }

    $self->_show_usage() if ($show_usage);
}

sub _create_valid_hash {
    my ($self, $hashin, $hashout) = @_;

    return () if (%$hashout);

    foreach my $key (keys(%$hashin)) {
        my (@keys) = $key =~ /(?<!:)(\w+)/g;
        @{$hashout}{@keys} = ($hashin->{$key}) x @keys;
    }
}

# prints a dump of the OPTIONS hash
sub _show_usage {
    my ($self) = @_;

    foreach my $key ($self->options) {
        print STDERR "\n$key"
          . " " x (20 - length($key))
          . $self->OPTIONS->{$key} . "\n";
    }
    print STDERR "\n\n";
}

sub go {
    my ($self) = @_;

    local $| = 1;
    $self->_parse_opts();

    my $opt = $self->{options};

    $self->_setup_run();
    $self->generate_pack({ nosetup => 1 });
    $self->run_pack({ nosetup => 1 }) if ($opt->{r});
}

sub _setup_run {
    my ($self) = @_;

    my $opt    = $self->{options};
    my $args   = $self->{args};
    my $output = $self->{output};

    $self->_die("No input files specified\n")
      unless @{ $self->{input} } or $opt->{M};

    $self->_check_write($output);
}

sub generate_pack {
    my ($self, $config) = @_;

    $config ||= {};
    $self->_parse_opts() if (!$config->{nosetup});
    $self->_setup_run()  if (!$config->{nosetup});

    my $input = $self->{input};
    my $opt   = $self->{options};

    $self->_vprint(0, "Packing @$input");

    if ($self->_check_par($input->[0])) {
        # invoked as "pp foo.par" - never unlink it
        $self->{par_file} = $input->[0];
        $opt->{S}         = 1;
        $self->_par_to_exe();
    }
    else {
        $self->_compile_par();
    }
}

sub run_pack {
    my ($self, $config) = @_;

    $config ||= {};

    $self->_parse_opts() if (!$config->{nosetup});
    $self->_setup_run()  if (!$config->{nosetup});

    my $opt    = $self->{options};
    my $output = $self->{output};
    my $args   = $self->{args};

    if (!file_name_is_absolute($output)) {
	$output = catfile(".", $output);
    }

    my @loader = ();
    push(@loader, $^X) if ($opt->{P});
    push(@loader, $^X, "-MPAR") if ($opt->{p});
    $self->_vprint(0, "Running @loader $output @$args");
    system(@loader, $output, @$args);
    exit(0);
}

sub _compile_par {
    my ($self) = @_;

    my @SharedLibs;
    local (@INC) = @INC;

    my $lose = $self->{pack_attrib}{lose};
    my $opt  = $self->{options};

    my $par_file = $self->get_par_file();

    $self->_add_pack_manifest();
    $self->_add_add_manifest();
    $self->_make_manifest();
    $self->_write_zip();

    $self->_sign_par() if ($opt->{s});
    $self->_par_to_exe() unless ($opt->{p});

    if ($lose) {
        $self->_vprint(2, "Unlinking $par_file");
        unlink $par_file or $self->_die("Can't unlink $par_file: $!");
    }
}

sub _write_zip {
    my ($self) = @_;

    my $old_member   = $self->{pack_attrib}{old_member};
    my $oldsize      = $self->{pack_attrib}{old_size};
    my $par_file     = $self->{par_file};
    my $add_manifest = $self->add_manifest();

    my $zip = $self->{zip};

    if ($old_member) {
        $zip->overwrite();
    }
    else {
        $zip->writeToFileNamed($par_file);
    }

    my $newsize = -s $par_file;
    $self->_vprint(
        2,
        sprintf(   "*** %s: %d bytes read, %d compressed, %2.2d%% saved.\n",
            $par_file, $oldsize,
            $newsize, (100 - ($newsize / $oldsize * 100))
        )
    );
}

sub _sign_par {
    my ($self) = @_;

    my $opt      = $self->{options};
    my $par_file = $self->{par_file};

    if (eval {
            require PAR::Dist;
            require Module::Signature;
            Module::Signature->VERSION >= 0.25;
        }
      )
    {
        $self->_vprint(0, "Signing $par_file");
        PAR::Dist::sign_par($par_file);
    }
    else {
        $self->_vprint(-1,
"*** Signing requires PAR::Dist with Module::Signature 0.25 or later.  Skipping"
        );
    }
}

sub _add_add_manifest {
    my ($self) = @_;

    my $opt          = $self->{options};
    my $add_manifest = $self->add_manifest_hash();
    my $par_file     = $self->{par_file};

    $self->_vprint(1, "Writing extra files to $par_file") if (%$add_manifest);
    $self->{zip} ||= Archive::Zip->new;
    my $zip = $self->{zip};

    my $in;
    foreach $in (sort keys(%$add_manifest)) {
        my $value = $add_manifest->{$in};
        $self->_add_file($zip, $in, $value);
    }
}

sub _make_manifest {
    my ($self) = @_;

    my $full_manifest = $self->{full_manifest};
    my $add_manifest  = $self->{add_manifest};

    my $opt      = $self->{options};
    my $par_file = $self->{par_file};
    my $output   = $self->{output};

    my $clean     = ($opt->{C} ? 1         : 0);
    my $dist_name = ($opt->{p} ? $par_file : $output);
    my $verbatim = ($ENV{PAR_VERBATIM} || 0);

    my $manifest = join("\n",
'    <!-- accessible as jar:file:///NAME.par!/MANIFEST in compliant browsers -->',
        (sort keys %$full_manifest, keys %$add_manifest),
q(    # <html><body onload="var X=document.body.innerHTML.split(/\n/);var Y='<iframe src=&quot;META.yml&quot; style=&quot;float:right;height:40%;width:40%&quot;></iframe><ul>';for(var x in X){if(!X[x].match(/^\s*#/)&&X[x].length)Y+='<li><a href=&quot;'+X[x]+'&quot;>'+X[x]+'</a>'}document.body.innerHTML=Y">)
    );

    my ($class, $version) = (ref($self), $self->VERSION);
    my $meta_yaml = << "YAML";
build_requires: {}
conflicts: {}
dist_name: $dist_name
distribution_type: par
dynamic_config: 0
generated_by: '$class version $version'
license: unknown
par:
  clean: $clean
  signature: ''
  verbatim: $verbatim
  version: $PAR::VERSION
YAML

    my $zip = $self->{zip};

    if (keys %dep_zips) {
        $self->_vprint(2, "... updating main.pl");
        my $dep_list = join ' ', keys %dep_zips;
        my $main_pl  = $zip->contents('script/main.pl');
        $main_pl = "use PAR qw( $dep_list );\n$main_pl";
        $zip->contents( 'script/main.pl', $main_pl );
        $dep_list = join ', ', keys %dep_zips;
        $self->_vprint(0, "$self->{output} will require $dep_list at runtime");

        $manifest =~ s/\Q$_\E\n// for (keys %dep_zip_files);
    }

    $self->_vprint(2, "... updating $_") for qw(MANIFEST META.yml);
    $zip->contents( 'MANIFEST', $manifest );
    $zip->contents( 'META.yml', $meta_yaml );
}

sub get_par_file {
    my ($self) = @_;

    return ($self->{par_file}) if ($self->{par_file});

    my $input  = $self->{input};
    my $output = $self->{output};

    my $par_file;
    my $cfh;

    my $opt = $self->{options};

    if ($opt->{S} or $opt->{p}) {
        # We need to keep it.

        if ($opt->{e} or !@$input) {
            $par_file = (defined $output ? $output : "a.par");
        }
        else {
            $par_file = $input->[0];

            # File off extension if present
            $par_file =~ s/$PerlExtensionRegex//;
            $par_file .= ".par";
        }

        $par_file = $output if $opt->{p};

        $self->_check_write($par_file);
    }
    else {
        # Don't need to keep it, be safe with a tempfile.

        $self->{pack_attrib}{lose} = 1;
        ($cfh, $par_file) = tempfile(
	    "ppXXXXX", SUFFIX => ".par", TMPDIR => 1, UNLINK => 1);
        close $cfh;    # See comment just below
    }
    $self->{par_file} = $par_file;
    return ($par_file);
}

sub set_par_file {
    my ($self, $file) = @_;

    $self->{par_file} = $file;
    $self->_check_write($file);
}

sub pack_manifest_hash {
    my ($self) = @_;

    my @SharedLibs;
    return ($self->{pack_manifest}) if ($self->{pack_manifest});

    $self->{pack_manifest} ||= {};
    $self->{full_manifest} ||= {};
    my $full_manifest = $self->{full_manifest};
    my $dep_manifest  = $self->{pack_manifest};

    my $sn = $self->{script_name};
    my $fe = $self->{frontend};

    my $opt    = $self->{options};
    my $input  = $self->{input};
    my $output = $self->{output};

    my $root = '';
    $root = "$Config{archname}/" if ($opt->{m});
    $self->{pack_attrib}{root} = '';

    my @mscandeps_cache;
    if (defined $opt->{cachedeps}) {
        @mscandeps_cache = (cache_file => $opt->{cachedeps});
    }

    my $par_file = $self->{par_file};
    my (@modules, @data, @exclude);

    # Search for scannable code in all -I'd paths
    # NOTE: We need this early, because Module::ScanDeps::_find_in_inc 
    # and others refer to @IncludeLibs.
    push @Module::ScanDeps::IncludeLibs, @{$opt->{I}} if $opt->{I};
    
    foreach my $name (@{ $opt->{M} || [] }) {
        if ($name =~ s/^([\w:]+)::(\*{0,2})$/$1/) {
            my $ns = length $2;        # namespace depth indicator

            if ($ns == 0) {
                # "-MFoo::" shorthand for "-MFoo -MFoo::**"
                $self->_name2moddata($name, \@modules, \@data);
                $ns = 2;
            }

            (my $mod = $name) =~ s/::/\//g;
            my @mods_in_ns = $ns == 1
                ? Module::ScanDeps::_glob_in_inc_1($mod, 1)
                : Module::ScanDeps::_glob_in_inc($mod, 1);
            $self->_name2moddata($_, \@modules, \@data) foreach @mods_in_ns;
        } 
        else {
            $self->_name2moddata($name, \@modules, \@data);
        }
    }

    if ($opt->{u}) {
        push @modules, "utf8_heavy.pl";
    }

    # Skip either
    # a) all files from a .par file or
    # b) A module
    foreach my $name ('PAR', @{ $opt->{X} || [] }) {
        if (-f $name and my $dep_zip = Archive::Zip->new($name)) {
            for ($dep_zip->memberNames()) {
                next if ( /MANIFEST/ or /META.yml/ or /^script\// );
                $dep_zip_files{$_} ||= $name;
            }
        }
        else {
            $self->_name2moddata($name, \@exclude, \@exclude);
        }
    }

    my %map;

    unshift(@INC, @{ $opt->{I} || [] });
    unshift(@SharedLibs, map $self->_find_shlib($_), @{ $opt->{l} || [] });

    # Note: _find_in_inc() may return ()
    my %skip = map { $_ => 1 } grep { defined } map { Module::ScanDeps::_find_in_inc($_) } @exclude;
    if ($^O eq 'MSWin32') {
        %skip = (%skip, map { s{\\}{/}g; lc($_) => 1 } @SharedLibs);
    }
    else {
        %skip = (%skip, map { $_ => 1 } @SharedLibs);
    }

    my $add_deps = $self->_obj_function($fe, 'add_deps');

    my @files; # files to scan
    # Apply %Preload to the -M'd modules and add them to the list of
    # files to scan
    foreach my $module (@modules) {
        my $file = Module::ScanDeps::_find_in_inc($module)
          or $self->_die("Cannot find module $module (specified with -M)\n");
        push @files, $file;
        
        my @preload = Module::ScanDeps::_get_preload($module) or next;
        
        $add_deps->(
            used_by => $file,
            rv      => \%map,
            modules => \@preload,
            skip    => \%skip,
#            warn_missing => $args->{warn_missing},
        );
    }
    push @files, @$input;

    if ($opt->{x} && defined $opt->{xargs}) {
        require Text::ParseWords;
        $opt->{x} = [ Text::ParseWords::shellwords($opt->{xargs}) ];
    }

    my $scan_dispatch =
      $opt->{n}
      ? $self->_obj_function($fe, 'scan_deps_runtime')
      : $self->_obj_function($fe, 'scan_deps');


    $scan_dispatch->(
        rv      => \%map,
        files   => \@files,
        execute => $opt->{x},
        compile => $opt->{c},
        skip    => \%skip,
        @mscandeps_cache,
        ($opt->{n}) ? () : (
            recurse => 1,
            first   => 1,
        ),
    );

    # Note: _find_in_inc() may return ()
    %skip = map { $_ => 1 } grep { defined } map { Module::ScanDeps::_find_in_inc($_) } @exclude;
    %skip = (%skip, map { $_ => 1 } @SharedLibs);

    $add_deps->(
        rv      => \%map,
        modules => \@modules,
        skip    => \%skip,
    );

    my %text;

    $text{$_} = ($map{$_}{type} =~ /^(?:module|autoload)$/) for keys %map;
    $map{$_} = $map{$_}{file} for keys %map;

    $self->{pack_attrib}{text}        = \%text;
    $self->{pack_attrib}{map}         = \%map;
    $self->{pack_attrib}{shared_libs} = \@SharedLibs;

    my $size = 0;
    my $old_member;

    if ($opt->{m} and -e $par_file) {
        my $tmpzip = Archive::Zip->new();
        $tmpzip->read($par_file);

        if ($old_member = $tmpzip->memberNamed('MANIFEST')) {
            $full_manifest->{$_} = [ file => $_ ]
              for (grep /^\S/, split(/\n/, $old_member->contents));
            $dep_manifest->{$_} = [ file => $_ ]
              for (grep /^\S/, split(/\n/, $old_member->contents));
        }
        else {
            $old_member = 1;
        }
        $self->{pack_attrib}{old_member} = $old_member;
    }

    # generate a selective set of filters from the options passed in via -F
    my $mod_filter = _generate_filter($opt, 'F');

    (my $privlib = $Config{privlib}) =~ s{\\}{/}g;
    (my $archlib = $Config{archlib}) =~ s{\\}{/}g;
    foreach my $pfile (sort grep length $map{$_}, keys %map) {
        next if !$opt->{B} and (
            ($map{$pfile} eq "$privlib/$pfile") or
            ($map{$pfile} eq "$archlib/$pfile")
        );

        $self->_vprint(2, "... adding $map{$pfile} as ${root}lib/$pfile");

        if ($text{$pfile} or $pfile =~ /utf8_heavy\.pl$/i) {
            my $content_ref = $mod_filter->($map{$pfile}, $pfile);

            $full_manifest->{ $root . "lib/$pfile" } =
              [ string => $content_ref ];
            $dep_manifest->{ $root . "lib/$pfile" } =
              [ string => $content_ref ];
        }
        else {
            $full_manifest->{ $root . "lib/$pfile" } =
              [ file => $map{$pfile} ];
            $dep_manifest->{ $root . "lib/$pfile" } =
              [ file => $map{$pfile} ];
        }
    }

    # For -f, we just accept normal filters - no selection of files.
    my $script_filter = _generate_filter($opt, 'f');
    $script_filter = PAR::Filter->new(@{ $opt->{f} }) if ($opt->{f});

    my $in;
    foreach my $in (@$input) {
        my $name = basename($in);

        if ($script_filter) {
            my $string = $script_filter->apply($in, $name);

            $full_manifest->{"script/$name"} = [ string => $string ];
            $dep_manifest->{"script/$name"}  = [ string => $string ];
        }
        else {
            $full_manifest->{"script/$name"} = [ file => $in ];
            $dep_manifest->{"script/$name"}  = [ file => $in ];
        }

        delete $full_manifest->{$root . "lib/$name"};
        delete $dep_manifest->{$root . "lib/$name"};
    }

    my $shlib = "shlib/$Config{archname}";

    foreach my $in (@SharedLibs) {
        next unless -e $in;

        my $name;

        # try to find the name the runtime loader will be looking for
        if ($^O =~ /linux|solaris|freebsd|openbsd/i) {
            # try "objdump" to extract SONAME
            my $od = qx( objdump -p $in );
            if ($? == 0 && $od =~ /^\s* SONAME \s+ (\S+)/mx) {
                $name = $1;
                $self->_vprint(1, "... objdump: library $in has SONAME $name");
            }
        }
        elsif ($^O eq 'darwin') {
            # try "otool -D $file", expect itwo lines of output like 
            #   $file:
            #   path
            # Note: some versions of otool report just a name in the
            # second line, others report a pathname
            chomp(my @ot = qx( otool -D $in ));
            if ($? == 0) {
                $name = basename($ot[1]);
                $self->_vprint(1, "... otool: library $in has install name $name");
            }
            else {
                # fallback to old "chasing symlinks" method
                $name = basename($self->_chase_lib_darwin($in));
            }
        }

        # fallback to old "chasing symlinks" method if nothing else worked
        $name = basename($self->_chase_lib($in)) unless defined $name;

        $dep_manifest->{"$shlib/$name"}  = [ file => $in ];
        $full_manifest->{"$shlib/$name"} = [ file => $in ];
    }

    foreach my $in (@data) {
        unless (-r $in and !-d $in) {
            $self->_warn("'$in' does not exist or is not readable; skipping\n");
            next;
        }
        $full_manifest->{$in} = [ file => $in ];
        $dep_manifest->{$in} = [ file => $in ];
    }

    if (@$input and (@$input == 1 or !$opt->{p})) {
        my $string =
          (@$input == 1)
          ? $self->_main_pl_single("script/" . basename($input->[0]))
          : $self->_main_pl_multi();

        $full_manifest->{"script/main.pl"} = [ string => $string ];
        $dep_manifest->{"script/main.pl"}  = [ string => $string ];
    }

    $full_manifest->{'MANIFEST'} = [ string => "<<placeholder>>" ];
    $full_manifest->{'META.yml'} = [ string => "<<placeholder>>" ];

    $dep_manifest->{'MANIFEST'} = [ string => "<<placeholder>>" ];
    $dep_manifest->{'META.yml'} = [ string => "<<placeholder>>" ];
    return ($dep_manifest);
}


sub _generate_filter {
    my $opt = shift; # options hash
    my $key = shift; # F or f? modules or script?

    my $verbatim = ($ENV{PAR_VERBATIM} || 0);

    # List of filters. If the regex is undefined or matches the 
    # file name (e.g. Foo/Bar.pm), apply filter to this module.
    my @filters = (
        { regex => undef, filter => PAR::Filter->new('PatchContent') },
    );

    foreach my $option (@{ $opt->{$key} }) {
        my ($filter, $regex) = split /=/, $option, 2;
        push @filters, {
            regex => (defined $regex ? qr/$regex/ : $regex),
            filter => PAR::Filter->new($filter)
        };
    }
    my $podstrip = PAR::Filter->new('PodStrip');

    my $filtersub = sub {
        my $ref = shift;
        my $name = shift;
        my $filtered = 0;
        foreach my $filterspec (@filters) {
            if (
                not defined $filterspec->{regex}
                or $name =~ $filterspec->{regex}
            ) {
                $filtered++;
                $ref = $filterspec->{filter}->apply($ref, $name);
            }
        }

        # PodStrip by default, overridden by -F or $ENV{PAR_VERBATIM}
        if ($filtered == 1 and not $verbatim) {
            $ref = $podstrip->apply($ref, $name);
        }
        return $ref;
    };

    return $filtersub;
}

sub full_manifest_hash {
    my ($self) = @_;

    $self->pack_manifest_hash();
    return ($self->{full_manifest});
}

sub full_manifest {
    my ($self) = @_;

    $self->pack_manifest_hash();
    my $mh = $self->{full_manifest};
    return ([ sort keys(%$mh) ]);
}

sub add_manifest_hash {
    my ($self) = @_;
    return ($self->{add_manifest}) if ($self->{add_manifest});
    my $mh = $self->{add_manifest} = {};

    my $ma = $self->_add_manifest();

    my $elt;

    foreach $elt (@$ma) {
        my ($file, $alias) = @$elt;

        if (!-e $file) {
            $self->_warn("Cannot find file or directory $file for packing\n");
        }
        elsif (!-r _) {
            $self->_warn("Cannot read file or directory $file for packing\n");
        }
        elsif (-d _) {
            my ($files, $aliases) = $self->_expand_dir(@$elt);
            while (@$files) {
                $mh->{ shift(@$aliases) } = [ file => shift(@$files) ];
            }
        }
        else {
            $mh->{ $alias } = [ file => $file ];
        }
    }
    return ($mh);
}

sub _add_manifest {
    my ($self) = @_;

    my $opt    = $self->{options};
    my $return = [];
    my $files  = [];
    my $lists  = [];

    $files = $opt->{a} if ($opt->{a});
    $lists = $opt->{A} if ($opt->{A});

    local $/ = "\n";
    foreach my $list (@$lists) {
        my $fh = $self->_open('<', $list, 'text');
        while (my $line = <$fh>) {
            chomp($line);
            push(@$files, $line);
        }
    }

    foreach my $file (grep length, @$files) {
        $file =~ s{\\}{/}g;

        if ($file =~ /;/) {
            push(@$return, [ split(/;/, $file) ]);
        }
        else {
            my $alias = $file;
            $alias =~ s{^[a-zA-Z]:}{} if $^O eq 'MSWin32';
            $alias =~ s{^/}{};
            push(@$return, [ $file, $alias ]);
        }
    }
    return ($return);
}

sub add_manifest {
    my ($self) = @_;
    my $mh = $self->add_manifest_hash();

    my @ma = sort keys(%$mh);
    return (\@ma);
}

sub _add_pack_manifest {
    my ($self) = @_;

    my $par_file = $self->{par_file};
    my $opt      = $self->{options};

    $self->{zip} ||= Archive::Zip->new;
    my $zip = $self->{zip};

    my $input = $self->{input};

    $self->_vprint(1, "Writing PAR on $par_file");

    $zip->read($par_file) if ($opt->{'m'} and -e $par_file);

    my $pack_manifest = $self->pack_manifest_hash();

    my $map         = $self->{pack_attrib}{map};
    my $root        = $self->{pack_attrib}{root};
    my $shared_libs = $self->{pack_attrib}{shared_libs};

    $zip->addDirectory('', substr($root, 0, -1))->unixFileAttributes(0755)
      if ($root and %$map and $] >= 5.008);
    $zip->addDirectory('', $root . 'lib')->unixFileAttributes(0755) if (%$map and $] >= 5.008);

    my $shlib = "shlib/$Config{archname}";
    $zip->addDirectory('', $shlib)->unixFileAttributes(0755) if (@$shared_libs and $] >= 5.008);

    my @tmp_input = @$input;
    @tmp_input = grep !/\.pm\z/i, @tmp_input;

    $zip->addDirectory('', 'script')->unixFileAttributes(0755) if (@tmp_input and $] >= 5.008);

    my $in;
    foreach $in (sort keys(%$pack_manifest)) {
        my $value = $pack_manifest->{$in};
        $self->_add_file($zip, $in, $value);
    }

}

sub dep_files {
    my ($self) = @_;

    my $dm = $self->{dep_manifest};
    return ([ keys(%$dm) ]) if ($dm);

}

sub _add_file {
    my ($self, $zip, $in, $value, $manifest) = @_;

    my $level = $self->{options}->{z};
    my $method = $level ? Archive::Zip::COMPRESSION_DEFLATED
                        : Archive::Zip::COMPRESSION_STORED;
    my $oldsize       = $self->{pack_attrib}{old_size};
    my $full_manifest = $self->{full_manifest};

    if ($value->[0] eq 'file') {
        my $fn = $value->[1];

        if (-d $fn) {
            my ($files, $aliases) = $self->_expand_dir($fn, $in);

            $self->_vprint(1, "... adding $fn as $in\n");

            while (@$files) {
                my $file  = shift @$files;
                my $alias = shift @$aliases;

                if (exists $dep_zip_files{$alias}) {
                        $dep_zips{$dep_zip_files{$alias}}++;
                        next;
                }
                $self->_vprint(1, "... adding $file as $alias\n");

                $full_manifest->{ $alias } = [ file => $file ];
                $manifest->{ $alias } = [ file => $file ];

                $oldsize += -s $file;
                my $member = $zip->addFile($file, $alias);
                $member->desiredCompressionMethod($method);
                $member->desiredCompressionLevel($level);
            }
        }
        elsif (-e $fn and -r $fn) {
            if (exists $dep_zip_files{$in}) {
                    $dep_zips{$dep_zip_files{$in}}++;
                    return;
            }
            $self->_vprint(1, "... adding $fn as $in\n");

            $oldsize += -s $fn;
            my $member = $zip->addFile($fn => $in);
            $member->desiredCompressionMethod($method);
            $member->desiredCompressionLevel($level);
        }
    }
    else {
        if (exists $dep_zip_files{$in}) {
                $dep_zips{$dep_zip_files{$in}}++;
                return;
        }
        my $str = $value->[1];
        $oldsize += length($str);

        $self->_vprint(1, "... adding <string> as $in");
        my $member = $zip->addString($str => $in);
        $member->unixFileAttributes(0644);
        $member->desiredCompressionMethod($method);
        $member->desiredCompressionLevel($level);
    }

    $self->{pack_attrib}{old_size} = $oldsize;
}

sub _expand_dir {
    my ($self, $fn, $in) = @_;
    my (@return, @alias_return);

    File::Find::find(
        {
            wanted => sub { push(@return, $File::Find::name) if -f },
            follow_fast => ( ($^O eq 'MSWin32') ? 0 : 1 ),
        },
        $fn
    );

    @alias_return = @return;
    s/^\Q$fn\E/$in/ for @alias_return;

    return (\@return, \@alias_return);
}

sub _die {
    my ($self, @args) = @_;
    $self->_log(@args);

    my $sn = $self->{script_name};
    die "$sn: ", @args;
}

sub _warn {
    my ($self, @args) = @_;
    $self->_log(@args);

    my $sn = $self->{script_name};
    warn "$sn: ", @args;
}

sub _log {
    my ($self, @args) = @_;

    my $opt   = $self->{options};
    my $logfh = $self->{logfh};
    my $sn    = $self->{script_name};

    $logfh->print("$sn: ", @args) if ($opt->{L});
}

sub _name2moddata {
    my ($self, $name, $mod, $dat) = @_;

    if ($name =~ /^[\w:]+$/) {
        $name =~ s/::/\//g;
        push @$mod, "$name.pm";
    }
    elsif ($name =~ /$PerlExtensionRegex/) {
        push @$mod, $name;
    }
    else {

        if (!-e $name) {
            $self->_warn( "-M or -X option file not found: $name\n" );
        }
        else {
            $self->_warn(
                "Using -M to add non-library files is deprecated; ",
                "try -a instead\n",
            ) if $mod != $dat;
            push @$dat, $name;
        }
    }
}

sub _par_to_exe {
    my ($self) = @_;

    my $opt      = $self->{options};
    my $output   = $self->{output};
    my $dynperl  = $self->{dynperl};
    my $par_file = $self->{par_file};

    require PAR::StrippedPARL::Static;
    require PAR::StrippedPARL::Dynamic;

    my $parlclass = 'PAR::StrippedPARL::Static';
    my $buf;
    my $parl = 'parl';

    if ($opt->{d} and $dynperl) {
        $parlclass = 'PAR::StrippedPARL::Dynamic';
        $parl = 'parldyn';
    }
    $parl .= $Config{_exe};

    if ($opt->{P}) {
        # write as script
        $parl = 'par.pl';
        unless ( $parl = $self->_can_run($parl, $opt->{P}) ) {
            $self->_die("par.pl not found");
        }
        $self->{parl} = $parl;
    }
    else {
        # binary, either static or dynamic
        $parl = $self->_extract_parl($parlclass)
          or $self->_die("Can't find par loader");
        $self->{parl_is_temporary} = 1;
        $self->{parl} = $parl;
    }

    if ($^O ne 'MSWin32' or $opt->{p} or $opt->{P}) {
        $self->_generate_output();
    }
    else {
        $self->_generate_output();
        $self->_fix_console() if $opt->{g};
    }
}

# extracts a parl (static) or parldyn (dynamic) from the appropriate data class
# using the class' write_parl($file) method. Note that 'write_parl' extracts to
# a temporary file first, then uses that plain parl to embed the core modules into
# the file given as argument. This was taken from the PAR bootstrapping process.
# First argument must be the class name.
# Returns the path and name of the file (or the empty list on failure).
sub _extract_parl {
    my $self = shift;
    my $class = shift;

    $self->_die("First argument to _extract_parl must be a class name")
      if not defined $class;
    $self->_die("Class '$class' is not a PAR(L) data class. Can't call '${class}->write_parl()'")
      if not $class->can('write_parl');

    $self->_vprint(0, "Generating a fresh 'parl'.");
    my ($fh, $filename) = tempfile(
        "parlXXXXXXX", SUFFIX => $Config{_exe}, TMPDIR => 1, UNLINK => 1);
    close $fh;
    
    my $success = $class->write_parl($filename);
    if (not $success) {
        $self->_die("Failed to extract a parl from '$class' to file '$filename'");
    }

    chmod(oct('755'), $filename);
    return $filename;
}


sub _move_parl {
    my ($self) = @_;

    $self->{orig_parl} = $self->{parl};

    my $cfh;
    my $fh = $self->_open($self->{parl});
    ($cfh, $self->{parl}) = tempfile(
        "parlXXXX", SUFFIX => ".exe", TMPDIR => 1, UNLINK => 1);
    binmode($cfh);

    local $/;
    print $cfh readline($fh);
    close $cfh;

    $self->{fh} = $fh;
}

sub _generate_output {
    my ($self) = @_;

    my $opt      = $self->{options};
    my $output   = $self->{output};
    my $par_file = $self->{par_file};

    my @args = ("-O$output", $par_file);
    unshift @args, '-q' unless $opt->{v} > 0;
    if ($opt->{B}) {
        unshift @args, "-B";
    } 
    if ($opt->{L}) {
        unshift @args, "-L".$opt->{L};
    }
    if ($opt->{T}) {
        unshift @args, "-T".$opt->{T};
    }
    if ($opt->{P}) {
        unshift @args, $self->{parl};
        $self->{parl} = $^X;
    }
    $self->_vprint(0, "Running $self->{parl} @args");

    # Make sure the parl is callable. Prepend ./ if it's just a file name.
    my $parl = $self->{parl};
    my ($volume, $path, $file) = splitpath($parl);
    if (not defined $path or $path eq '') {
        $parl = catfile(curdir(), $parl);
    }

    system($parl, @args);
}

sub _fix_console {
    my ($self) = @_;

    my $opt      = $self->{options};
    my $output   = $self->{output};
    my $dynperl  = $self->{dynperl};

    return unless $opt->{g};

    $self->_vprint(1, "Fixing $output to remove its console window");

    my ($record, $magic, $signature, $offset, $size);

    my $exe = $self->_open('+<', $output);
    binmode $exe;
    seek $exe, 0, 0;

    # read IMAGE_DOS_HEADER structure
    read $exe, $record, 64;
    ($magic, $offset) = unpack "Sx58L", $record;

    die "$output is not an MSDOS executable file.\n"
      unless $magic == 0x5a4d;    # "MZ"

    # read signature, IMAGE_FILE_HEADER and first WORD of IMAGE_OPTIONAL_HEADER
    seek $exe, $offset, 0;
    read $exe, $record, 4 + 20 + 2;

    ($signature, $size, $magic) = unpack "Lx16Sx2S", $record;

    die "PE header not found" unless $signature == 0x4550;    # "PE\0\0"

    die "Optional header is neither in NT32 nor in NT64 format"
      unless ($size == 224 && $magic == 0x10b) # IMAGE_NT_OPTIONAL_HDR32_MAGIC
      ||
      ($size == 240 && $magic == 0x20b);    # IMAGE_NT_OPTIONAL_HDR64_MAGIC

    # Offset 68 in the IMAGE_OPTIONAL_HEADER(32|64) is the 16 bit subsystem code
    seek $exe, $offset + 4 + 20 + 68, 0;
    print $exe pack "S", 2;                 # IMAGE_WINDOWS
    close $exe;
}

sub _obj_function {
    my ($self, $module_or_class, $func_name) = @_;

    my $func;
    if (ref($module_or_class)) {
        $func = $module_or_class->can($func_name);
        die "SYSTEM ERROR: $func_name does not exist in $module_or_class\n"
          if (!$func);

        if (%$module_or_class) {
            # hack because Module::ScanDeps isn't really object.
            return sub { $func->($module_or_class, @_) };
        }
        else {
            return ($func);
        }
    }
    else {
        $func = $module_or_class->can($func_name);
        return ($func);
    }
}

sub _vprint {
    my ($self, $level, $msg) = @_;

    my $opt   = $self->{options};
    my $logfh = $self->{logfh};

    $msg .= "\n" unless substr($msg, -1) eq "\n";

    my $verb = $ENV{PAR_VERBOSE} || 0;
    if ($opt->{v} > $level or $verb > $level) {
        if ($opt->{L}) {
            print $logfh "$0: $msg";
        }
        else {
            print "$0: $msg";
        }
    }
}

sub _check_par {
    my ($self, $file) = @_;

    local $/ = \4;
    my $handle = $self->_open($file);
    return (readline($handle) eq "PK\x03\x04");
}

# _chase_lib - find the runtime link of a shared library
# Logic based on info found at the following sites:
# http://lists.debian.org/lsb-spec/1999/05/msg00011.html
# http://docs.sun.com/app/docs/doc/806-0641/6j9vuqujh?a=view#chapter5-97360
sub _chase_lib {
   my ($self, $file) = @_;

   $file = abs_path($file);

   while ($Config::Config{d_symlink} and -l $file) {
       if ($file =~ /^(.*?\.\Q$Config{dlext}\E\.\d+)\..*/) {
           return $1 if -e $1;
       }

       return $file if $file =~ /\.\Q$Config{dlext}\E\.\d+$/;

       my $dir = dirname($file);
       $file = readlink($file);

       unless (file_name_is_absolute($file)) {
           $file = rel2abs($file, $dir);
       }
   }

   if ($file =~ /^(.*?\.\Q$Config{dlext}\E\.\d+)\..*/) {
       return $1 if -e $1;
   }

   return $file;
}

sub _chase_lib_darwin {
   my ($self, $file) = @_;

   $file = abs_path($file);

   while (-l $file) {
       if ($file =~ /^(.*?\.\d+)(\.\d+)*\.dylib$/) {
           my $name = $1 . q/.dylib/;
           return $name if -e $name;
       }

       return $file if $file =~ /\D\.\d+\.dylib$/;

       my $dir = dirname($file);
       $file = readlink($file);

       unless (file_name_is_absolute($file)) {
           $file = rel2abs($file, $dir);
       }
   }

   if ($file =~ /^(.*?\.\d+)(\.\d+)*\.dylib$/) {
       my $name = $1 . q/.dylib/;
       return $name if -e $name;
   }

   return $file;
}


sub _find_shlib {
    my ($self, $file) = @_;

    if (-e $file) {
        my $abs_file = abs_path($file);
        $self->_vprint(1, "... found library $file: $abs_file");
        return $abs_file;
    }

    $self->_die("Shared library (option -l) doesn't exist: $file")
        if $file =~ /[\/\\]/;

    my @libpath;
    if ($^O eq 'MSWin32') {
        @libpath = (path(), '.');       # cwd() is always implicitly searched
    }
    else {
        # NOTE: libpth is actually supposed to be the path searched
        # by the linker (ld) and *not* the path searched by the runtime
        # loader (ld.so). But it's the best guess we've got.
        @libpath = split(' ', $Config{libpth});

        # add $ENV{LD_LIBRARY_PATH} (or equivalent) if defined 
        my $ldlibpath = $ENV{ $Config{ldlibpthname} };
        unshift @libpath, split(/\Q$Config{path_sep}\E/, $ldlibpath)
            if defined $ldlibpath;
    }

    if (my $lib = $self->_find_shlib_in_path($file, @libpath)) {
        $self->_vprint(1, "... found library $file: $lib");
        return $lib;
    }

    $self->_die("Can't find shared library (option -l): $file")
        if $^O eq 'MSWin32' || $file =~ /^lib/;

    # be extra magical and prepend "lib" to the filename
    if (my $lib = $self->_find_shlib_in_path("lib$file", @libpath)) {
        $self->_vprint(1, "... found library $file: $lib");
        return $lib;
    }

    $self->_die("Can't find shared library (option -l): $file (also tried lib$file)");
}

sub _find_shlib_in_path
{
    my ($self, $file, @path) = @_;

    my $dlext = $^O eq 'darwin' ? 'dylib' : $Config{dlext};
    for my $dir (@path)
    {
        $dir = '.' if $dir eq '';      
        foreach my $p (catfile($dir, $file), catfile($dir, "$file.$dlext"))
        {
            return abs_path($p) if -e $p;
        }
    }
    return;
}

sub _can_run {
    my ($self, $command, $no_exec) = @_;

    for my $dir (dirname($0),
        split(/\Q$Config{path_sep}\E/, $ENV{PATH}))
    {
        my $abs = catfile($dir, $command);
        return $abs if $no_exec or $abs = MM->maybe_command($abs);
    }
    return;
}

sub _main_pl_multi {
    my ($self) = @_;
   
    # insert code for @INC cleaning (in case of bundling core modules)
    my $clean_inc = $self->_main_pl_clean();
    # insert code for reusable apps
    my $reuse_app = $self->_main_pl_reuse();

    # FIXME The $reuse_app code was written for _main_pl_single -- is it correct for this as well?
    return $reuse_app . "\n" . <<'__MAIN__' . $clean_inc . "PAR::_run_member(\$member, 1);\n\n";
my $file = $ENV{PAR_PROGNAME};
my $zip = $PAR::LibCache{$ENV{PAR_PROGNAME}} || Archive::Zip->new(__FILE__);
$file =~ s/^.*[\/\\]//;
$file =~ s/\.[^.]*$//i ;
my $member = eval { $zip->memberNamed($file) }
                || $zip->memberNamed("$file.pl")
                || $zip->memberNamed("script/$file")
                || $zip->memberNamed("script/$file.pl")
        or die qq(main.pl: Can't open perl script "$file": No such file or directory);

__MAIN__
}

sub _open {
    my ($self, $mode, $file, $is_text) = @_;
    ($mode, $file) = ('<', $mode) if @_ < 3;
    open(my $fh, $mode, $file) or $self->_die(
        "Cannot open $file for ",
        (($mode =~ '>') ? 'writing' : 'reading'),
        ": $!",
    );
    binmode($fh) unless $is_text;
    return $fh;
}

sub _main_pl_single {
    my ($self, $file) = @_;
    
    # insert code for @INC cleaning (in case of bundling core modules)
    my $clean_inc = $self->_main_pl_clean();
    # insert code for reusable apps
    my $reuse_app = $self->_main_pl_reuse();

    return << "__MAIN__";

$reuse_app

my \$zip = \$PAR::LibCache{\$ENV{PAR_PROGNAME}} || Archive::Zip->new(__FILE__);
my \$member = eval { \$zip->memberNamed('$file') }
        or die qq(main.pl: Can't open perl script "$file": No such file or directory (\$zip));

$clean_inc

PAR::_run_member(\$member, 1);

__MAIN__
}

sub _main_pl_reuse {
    my $self = shift;

    my $opt = $self->{options};

    if (!$opt->{reusable}) {
      return <<'__NOT_REUSABLE__';
if (defined $ENV{PAR_APP_REUSE}) {
    warn "Executable was created without the --reusable option. See 'perldoc pp'.\n";
    exit(1);
}
__NOT_REUSABLE__
    }

    # insert code for @INC cleaning (in case of bundling core modules)
    my $clean_inc = $self->_main_pl_clean();

    my $reuse = <<__REUSE_APP__;
if (defined \$ENV{PAR_APP_REUSE}) {
    my \$filename = \$ENV{PAR_APP_REUSE};
    delete \$ENV{PAR_APP_REUSE};
    \$ENV{PAR_0} = \$filename;

    $clean_inc

    PAR::_run_external_file(\$filename, 1);
    exit();
}
__REUSE_APP__

    return $reuse;
}

sub _main_pl_clean {
    my $self = shift;
    my $opt = $self->{options};
    
    my $clean_inc = '';
    if ($opt->{B}) { # bundle core modules
        # weed out all @INC entries
        # use a canonicalized $ENV{PAR_TEMP}: this path was created by C code
        # and may not be in canonical form (so that the match below will
        # fail); case inpoint: some versions of FreeBSD have
        #  #define P_tmpdir "/var/tmp/"
        # in /usr/include/stdio.h (note the trailing slash)
        $clean_inc = <<'__CLEAN_INC__';
# Remove everything but PAR hooks from @INC
my %keep = (
    \&PAR::find_par => 1,
    \&PAR::find_par_last => 1,
);
my $par_temp_dir = File::Spec->catdir( $ENV{PAR_TEMP} );
@INC =
    grep {
        exists($keep{$_})
        or $_ =~ /^\Q$par_temp_dir\E/;
    }
    @INC;
__CLEAN_INC__
    };

    return $clean_inc;
}

sub DESTROY {
    my ($self) = @_;

    my $par_file = $self->{par_file};
    my $opt      = $self->{options};

    unlink $par_file if ($par_file and !$opt->{S} and !$opt->{p});
    unlink $self->{parl} if $self->{parl_is_temporary};
}



1;

=head1 SEE ALSO

L<PAR>, L<pp>

L<App::Packer>, L<App::Packer::Backend>

=head1 ACKNOWLEDGMENTS

Mattia Barbon for taking the first step in refactoring B<pp> into
B<App::Packer::Backend::PAR>, and Edward S. Peschko for continuing
the work that eventually became this module.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

Steffen Mueller E<lt>smueller@cpan.orgE<gt>

Roderich Schupp E<lt>rschupp@cpan.orgE<gt>

You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par-packer@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2004-2010 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut

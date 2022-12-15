package PAR;
$PAR::VERSION = '1.014';

use 5.006;
use strict;
use warnings;
use Config '%Config';
use Carp qw/croak/;

# If the 'prefork' module is available, we
# register various run-time loaded modules with it.
# That way, there is more shared memory in a forking
# environment.
BEGIN {
    if (eval 'require prefork') {
        prefork->import($_) for qw/
            Archive::Zip
            File::Glob
            File::Spec
            File::Temp
            Fcntl
            LWP::Simple
            PAR::Heavy
        /;
        # not including Archive::Unzip::Burst which only makes sense
        # in the context of a PAR::Packer'ed executable anyway.
    }
}

use PAR::SetupProgname;
use PAR::SetupTemp;

=head1 NAME

PAR - Perl Archive Toolkit

=head1 SYNOPSIS

(If you want to make an executable that contains all module, scripts and
data files, please consult the L<pp> utility instead. L<pp> used to be
part of the PAR distribution but is now shipped as part of the L<PAR::Packer>
distribution instead.)

Following examples assume a F<foo.par> file in Zip format.

To use F<Hello.pm> from F<./foo.par>:

    % perl -MPAR=./foo.par -MHello
    % perl -MPAR=./foo -MHello          # the .par part is optional

Same thing, but search F<foo.par> in the C<@INC>;

    % perl -MPAR -Ifoo.par -MHello
    % perl -MPAR -Ifoo -MHello          # ditto

Following paths inside the PAR file are searched:

    /lib/
    /arch/
    /i386-freebsd/              # i.e. $Config{archname}
    /5.8.0/                     # i.e. $Config{version}
    /5.8.0/i386-freebsd/        # both of the above
    /

PAR files may also (recursively) contain other PAR files.
All files under following paths will be considered as PAR
files and searched as well:

    /par/i386-freebsd/          # i.e. $Config{archname}
    /par/5.8.0/                 # i.e. $Config{version}
    /par/5.8.0/i386-freebsd/    # both of the above
    /par/

Run F<script/test.pl> or F<test.pl> from F<foo.par>:

    % perl -MPAR foo.par test.pl        # only when $0 ends in '.par'

However, if the F<.par> archive contains either F<script/main.pl> or
F<main.pl>, then it is used instead:

    % perl -MPAR foo.par test.pl        # runs main.pl; @ARGV is 'test.pl'

Use in a program:

    use PAR 'foo.par';
    use Hello; # reads within foo.par

    # PAR::read_file() returns a file inside any loaded PARs
    my $conf = PAR::read_file('data/MyConfig.yaml');

    # PAR::par_handle() returns an Archive::Zip handle
    my $zip = PAR::par_handle('foo.par')
    my $src = $zip->memberNamed('lib/Hello.pm')->contents;

You can also use wildcard characters:

    use PAR '/home/foo/*.par';  # loads all PAR files in that directory

Since version 0.950, you can also use a different syntax for loading
F<.par> archives:

    use PAR { file => 'foo.par' }, { file => 'otherfile.par' };

Why? Because you can also do this:

    use PAR { file => 'foo.par, fallback => 1 };
    use Foo::Bar;

Foo::Bar will be searched in the system libs first and loaded from F<foo.par>
if it wasn't found!

    use PAR { file => 'foo.par', run => 'myscript' };

This will load F<foo.par> as usual and then execute the F<script/myscript>
file from the archive. Note that your program will not regain control. When
F<script/myscript> exits, so does your main program. To make this more useful,
you can defer this to runtime: (otherwise equivalent)

    require PAR;
    PAR->import( { file => 'foo.par', run => 'myscript' } );

If you have L<PAR::Repository::Client> installed, you can do this:

    use PAR { repository => 'http://foo/bar/' };
    use Module; # not locally installed!

And PAR will fetch any modules you don't have from the specified PAR
repository. For details on how this works, have a look at the SEE ALSO
section below. Instead of an URL or local path, you can construct an
L<PAR::Repository::Client> object manually and pass that to PAR.
If you specify the C<install =E<gt> 1> option in the C<use PAR>
line above, the distribution containing C<Module> will be permanently
installed on your system. (C<use PAR { repository =E<gt> 'http://foo/bar', install =E<gt> 1 };>)

Furthermore, there is an C<upgrade =E<gt> 1> option that checks for upgrades
in the repository in addition to installing. Please note that an upgraded
version of a module is only loaded on the next run of your application.

Adding the C<dependencies =E<gt> 1> option will enable PAR::Repository::Client's
static dependency resolution (PAR::Repository::Client 0.23 and up).

Finally, you can combine the C<run> and C<repository>
options to run an application directly from a repository! (And you can add
the C<install> option, too.)

  use PAR { repository => 'http://foo/bar/', run => 'my_app' };
  # Will not reach this point as we executed my_app,

=head1 DESCRIPTION

This module lets you use special zip files, called B<P>erl B<Ar>chives, as
libraries from which Perl modules can be loaded. 

It supports loading XS modules by overriding B<DynaLoader> bootstrapping
methods; it writes shared object file to a temporary file at the time it
is needed.

A F<.par> file is mostly a zip of the F<blib/> directory after the build
process of a CPAN distribution. To generate a F<.par> file yourself, all
you have to do is compress the modules under F<arch/> and F<lib/>, e.g.:

    % perl Makefile.PL
    % make
    % cd blib
    % zip -r mymodule.par arch/ lib/

Afterward, you can just use F<mymodule.par> anywhere in your C<@INC>,
use B<PAR>, and it will Just Work. Support for generating F<.par> files
is going to be in the next (beyond 0.2805) release of Module::Build.

For convenience, you can set the C<PERL5OPT> environment variable to
C<-MPAR> to enable C<PAR> processing globally (the overhead is small
if not used); setting it to C<-MPAR=/path/to/mylib.par> will load a
specific PAR file.  Alternatively, consider using the F<par.pl> utility
bundled with the L<PAR::Packer> distribution, or using the
self-contained F<parl> utility which is also distributed with L<PAR::Packer>
on machines without PAR.pm installed.

Note that self-containing scripts and executables created with F<par.pl>
and F<pp> may also be used as F<.par> archives:

    % pp -o packed.exe source.pl        # generate packed.exe (see PAR::Packer)
    % perl -MPAR=packed.exe other.pl    # this also works
    % perl -MPAR -Ipacked.exe other.pl  # ditto

Please see L</SYNOPSIS> for most typical use cases.

=head1 NOTES

Settings in F<META.yml> packed inside the PAR file may affect PAR's
operation.  For example, F<pp> provides the C<-C> (C<--clean>) option
to control the default behavior of temporary file creation.

Currently, F<pp>-generated PAR files may attach four PAR-specific
attributes in F<META.yml>:

    par:
      clean: 0          # default value of PAR_CLEAN
      signature: ''     # key ID of the SIGNATURE file
      verbatim: 0       # was packed prerequisite's PODs preserved?
      version: x.xx     # PAR.pm version that generated this PAR

User-defined environment variables, like I<PAR_GLOBAL_CLEAN>, always
overrides the ones set in F<META.yml>.  The algorithm for generating
caching/temporary directory is as follows:

=over 4

=item *

If I<PAR_GLOBAL_TEMP> is specified, use it as the cache directory for
extracted libraries, and do not clean it up after execution.

=item *

If I<PAR_GLOBAL_TEMP> is not set, but I<PAR_CLEAN> is specified, set
I<PAR_GLOBAL_TEMP> to C<I<TEMP>/par-I<USER>/temp-I<PID>/>, cleaning it
after execution.

=item *

If both are not set,  use C<I<TEMP>/par-I<USER>/cache-I<HASH>/> as the
I<PAR_GLOBAL_TEMP>, reusing any existing files inside.

=back

Here is a description of the variables the previous paths.

=over 4

=item *

I<TEMP> is a temporary directory, which can be set via 
C<$ENV{PAR_GLOBAL_TMPDIR}>,
C<$ENV{TMPDIR}>, C<$ENV{TEMPDIR}>, C<$ENV{TEMP}>
or C<$ENV{TMP}>, in that order of priority.
If none of those are set, I<C:\TEMP>, I</tmp> are checked.  If neither
of them exists, I<.> is used.

=item *

I<USER> is the user name, or SYSTEM if none can be found.  On Win32, 
this is C<$Win32::LoginName>.  On Unix, this is C<$ENV{USERNAME}> or 
C<$ENV{USER}>.

=item *

I<PID> is the process ID.  Forked children use the parent's PID.

=item *

I<HASH> is a crypto-hash of the entire par file or executable,
calculated at creation time.  This value can be overloaded with C<pp>'s
--tempdir parameter.

=back

By default, PAR strips POD sections from bundled modules. In case
that causes trouble, you can turn this off by setting the
environment variable C<PAR_VERBATIM> to C<1>.

=head2 import options

When you "use PAR {...}" or call PAR->import({...}), the following
options are available.

  PAR->import({ file => 'foo.par' });
  # or
  PAR->import({ repository => 'http://foo/bar/' });

=over

=item file

The par filename.

You must pass I<one> option of either 'file' or 'repository'.

=item repository

A par repository (exclusive of file)

=item fallback

Search the system C<@INC> before the par.

Off by default for loading F<.par> files via C<file => ...>.
On by default for PAR repositories.

To prefer loading modules from a repository over the locally
installed modules, you can load the repository as follows:

  use PAR { repository => 'http://foo/bar/', fallback => 0 };

=item run

The name of a script to run in the par.  Exits when done.

=item no_shlib_unpack

Skip unpacking bundled dynamic libraries from shlib/$archname.  The
client may have them installed, or you may wish to cache them yourself.
In either case, they must end up in the standard install location (such
as /usr/local/lib/) or in $ENV{PAR_TEMP} I<before> you require the
module which needs them.  If they are not accessible before you require
the dependent module, perl will die with a message such as "cannot open
shared object file..." 

=back

=cut

use Fcntl ':flock';
use Archive::Zip qw( :ERROR_CODES ); 

use vars qw(@PAR_INC);              # explicitly stated PAR library files (preferred)
use vars qw(@PAR_INC_LAST);         # explicitly stated PAR library files (fallback)
use vars qw(%PAR_INC);              # sets {$par}{$file} for require'd modules
use vars qw(@LibCache %LibCache);   # I really miss pseudohash.
use vars qw($LastAccessedPAR $LastTempFile);
use vars qw(@RepositoryObjects);    # If we have PAR::Repository::Client support, we
                                    # put the ::Client objects in here.
use vars qw(@PriorityRepositoryObjects); # repositories which are preferred over local stuff
use vars qw(@UpgradeRepositoryObjects);  # If we have PAR::Repository::Client's in upgrade mode
                                         # put the ::Client objects in here *as well*.
use vars qw(%FileCache);            # The Zip-file file-name-cache
                                    # Layout:
                                    # $FileCache{$ZipObj}{$FileName} = $Member
use vars qw(%ArchivesExtracted);    # Associates archive-zip-object => full extraction path

my $ver  = $Config{version};
my $arch = $Config{archname};
my $progname = $ENV{PAR_PROGNAME} || $0;
my $is_insensitive_fs = (
    -s $progname
        and (-s lc($progname) || -1) == (-s uc($progname) || -1)
        and (-s lc($progname) || -1) == -s $progname
);

# lexical for import(), and _import_foo() functions to control unpar()
my %unpar_options;

# called on "use PAR"
sub import {
    my $class = shift;

    PAR::SetupProgname::set_progname();
    PAR::SetupTemp::set_par_temp_env();

    $progname = $ENV{PAR_PROGNAME} ||= $0;
    $is_insensitive_fs = (-s $progname and (-s lc($progname) || -1) == (-s uc($progname) || -1));

    my @args = @_;
    
    # Insert PAR hook in @INC.
    unshift @INC, \&find_par   unless grep { $_ eq \&find_par }      @INC;
    push @INC, \&find_par_last unless grep { $_ eq \&find_par_last } @INC;

    # process args to use PAR 'foo.par', { opts }, ...;
    foreach my $par (@args) {
        if (ref($par) eq 'HASH') {
            # we have been passed a hash reference
            _import_hash_ref($par);
        }
        elsif ($par =~ /[?*{}\[\]]/) {
           # implement globbing for PAR archives
           require File::Glob;
           foreach my $matched (File::Glob::glob($par)) {
               push @PAR_INC, unpar($matched, undef, undef, 1);
           }
        }
        else {
            # ordinary string argument => file
            push @PAR_INC, unpar($par, undef, undef, 1);
        }
    }

    return if $PAR::__import;
    local $PAR::__import = 1;

    require PAR::Heavy;
    PAR::Heavy::_init_dynaloader();

    # The following code is executed for the case where the
    # running program is itself a PAR archive.
    # ==> run script/main.pl
    if (unpar($progname)) {
        # XXX - handle META.yml here!
        push @PAR_INC, unpar($progname, undef, undef, 1);

        _extract_inc($progname);
        if ($LibCache{$progname}) {
          # XXX bad: this us just a good guess
          require File::Spec;
          $ArchivesExtracted{$progname} = File::Spec->catdir($ENV{PAR_TEMP}, 'inc');
        }

        my $zip = $LibCache{$progname};
        my $member = _first_member( $zip,
            "script/main.pl",
            "main.pl",
        );

        if ($progname and !$member) {
            require File::Spec;
            my @path = File::Spec->splitdir($progname);
            my $filename = pop @path;
            $member = _first_member( $zip,
                "script/".$filename,
                "script/".$filename.".pl",
                $filename,
                $filename.".pl",
            )
        }

        # finally take $ARGV[0] as the hint for file to run
        if (defined $ARGV[0] and !$member) {
            $member = _first_member( $zip,
                "script/$ARGV[0]",
                "script/$ARGV[0].pl",
                $ARGV[0],
                "$ARGV[0].pl",
            ) or die qq(PAR.pm: Can't open perl script "$ARGV[0]": No such file or directory);
            shift @ARGV;
        }


        if (!$member) {
            die "Usage: $0 script_file_name.\n";
        }

        _run_member($member);
    }
}


# import() helper for the "use PAR {...};" syntax.
sub _import_hash_ref {
    my $opt = shift;

    # hash slice assignment -- pass all of the options into unpar
    local @unpar_options{keys(%$opt)} = values(%$opt);

    # check for incompatible options:
    if ( exists $opt->{repository} and exists $opt->{file} ) {
        croak("Invalid PAR loading options. Cannot have a 'repository' and 'file' option at the same time.");
    }
    elsif (
        exists $opt->{file}
        and (exists $opt->{install} or exists $opt->{upgrade})
    ) {
        my $e = exists($opt->{install}) ? 'install' : 'upgrade';
        croak("Invalid PAR loading options. Cannot combine 'file' and '$e' options.");
    }
    elsif ( not exists $opt->{repository} and not exists $opt->{file} ) {
        croak("Invalid PAR loading options. Need at least one of 'file' or 'repository' options.");
    }

    # load from file
    if (exists $opt->{file}) {
        croak("Cannot load undefined PAR archive")
          if not defined $opt->{file};

        # for files, we default to loading from PAR archive first
        my $fallback = $opt->{fallback};
        $fallback = 0 if not defined $fallback;
        
        if (not $fallback) {
            # load from this PAR arch preferably
            push @PAR_INC, unpar($opt->{file}, undef, undef, 1);
        }
        else {
            # load from this PAR arch as fallback
            push @PAR_INC_LAST, unpar($opt->{file}, undef, undef, 1);
        }
        
    }
    else {
        # Deal with repositories elsewhere
        my $client = _import_repository($opt);
        return() if not $client;

        if (defined $opt->{run}) {
            # run was specified
            # run the specified script from the repository
            $client->run_script( $opt->{run} );
            return 1;
        }
        
        return 1;
    }

    # run was specified
    # run the specified script from inside the PAR file.
    if (defined $opt->{run}) {
        my $script = $opt->{run};
        require PAR::Heavy;
        PAR::Heavy::_init_dynaloader();
        
        # XXX - handle META.yml here!
        _extract_inc($opt->{file});
        
        my $zip = $LibCache{$opt->{file}};
        my $member = _first_member( $zip,
            (($script !~ /^script\//) ? ("script/$script", "script/$script.pl") : ()),
            $script,
            "$script.pl",
        );
        
        if (not defined $member) {
            croak("Cannot run script '$script' from PAR file '$opt->{file}'. Script couldn't be found in PAR file.");
        }
        
        _run_member_from_par($member);
    }

    return();
}


# This sub is invoked by _import_hash_ref if a {repository}
# option is found
# Returns the repository client object on success.
sub _import_repository {
    my $opt = shift;
    my $url = $opt->{repository};

    eval "require PAR::Repository::Client; 1;";
    if ($@ or not eval PAR::Repository::Client->VERSION >= 0.04) {
        croak "In order to use the 'use PAR { repository => 'url' };' syntax, you need to install the PAR::Repository::Client module (version 0.04 or later) from CPAN. This module does not seem to be installed as indicated by the following error message: $@";
    }
    
    if ($opt->{upgrade} and not eval PAR::Repository::Client->VERSION >= 0.22) {
        croak "In order to use the 'upgrade' option, you need to install the PAR::Repository::Client module (version 0.22 or later) from CPAN";
    }

    if ($opt->{dependencies} and not eval PAR::Repository::Client->VERSION >= 0.23) {
        croak "In order to use the 'dependencies' option, you need to install the PAR::Repository::Client module (version 0.23 or later) from CPAN";
    }

    my $obj;

    # Support existing clients passed in as objects.
    if (ref($url) and UNIVERSAL::isa($url, 'PAR::Repository::Client')) {
        $obj = $url;
    }
    else {
        $obj = PAR::Repository::Client->new(
            uri                 => $url,
            auto_install        => $opt->{install},
            auto_upgrade        => $opt->{upgrade},
            static_dependencies => $opt->{dependencies},
        );
    }

    if (exists($opt->{fallback}) and not $opt->{fallback}) {
        unshift @PriorityRepositoryObjects, $obj; # repository beats local stuff
    } else {
        push @RepositoryObjects, $obj; # local stuff beats repository
    }
    # these are tracked separately so we can check for upgrades early
    push @UpgradeRepositoryObjects, $obj if $opt->{upgrade};

    return $obj;
}

# Given an Archive::Zip obj and a list of files/paths,
# this function returns the Archive::Zip::Member for the
# first of the files found in the ZIP. If none is found,
# returns the empty list.
sub _first_member {
    my $zip = shift;
    foreach my $name (@_) {
        my $member = _cached_member_named($zip, $name);
        return $member if $member;
    }
    return;
}

# Given an Archive::Zip object, this finds the first 
# Archive::Zip member whose file name matches the
# regular expression
sub _first_member_matching {
    my $zip = shift;
    my $regex = shift;

    my $cache = $FileCache{$zip};
    $cache = $FileCache{$zip} = _make_file_cache($zip) if not $cache;

    foreach my $name (keys %$cache) {
      if ($name =~ $regex) {
        return $cache->{$name};
      }
    }

    return();
}


sub _run_member_from_par {
    my $member = shift;
    my (undef, $filename) = _tempfile(
        sub {
            my $fh = shift;
            my $file = $member->fileName;
            print $fh "package main;\n",
                      "#line 1 \"$file\"\n";
            $member->extractToFileHandle($fh) == AZ_OK
                or die "Can't extract $file: $!";
        },
        $member->crc32String . ".pl");

    $ENV{PAR_0} = $filename; # for Pod::Usage
    { do $filename;
      CORE::exit($1) if ($@ =~/^_TK_EXIT_\((\d+)\)/);
      die $@ if $@;
      exit;
    }
}

sub _run_member {
    my $member = shift;
    my ($fh, $filename) = _tempfile(
        sub {
            my $fh = shift;
            my $file = $member->fileName;
            print $fh "package main;\n",
                      "#line 1 \"$file\"\n";
            $member->extractToFileHandle($fh) == AZ_OK
                or die "Can't extract $file: $!";
        },
        $member->crc32String . ".pl");

    # NOTE: Perl 5.14.x will print the infamous warning
    # "Use of uninitialized value in do "file" at .../PAR.pm line 636" 
    # when $INC{main} exists, but is undef, when "do 'main'" is called.
    # This typically happens at the second invocation of _run_member() 
    # when running a packed executable (the first invocation is for the 
    # generated script/main.pl, the second for the packed script itself). 
    # Hence shut the warning up by assigning something to $INC{main}. 
    # 5.14.x is the only Perl version since 5.8.1 that shows this behaviour.
    unshift @INC, sub { shift @INC; $INC{$_[1]} = $filename; return $fh };

    $ENV{PAR_0} = $filename; # for Pod::Usage
    { do 'main';
      CORE::exit($1) if ($@ =~/^_TK_EXIT_\((\d+)\)/);
      die $@ if $@;
      exit;
    }
}

sub _run_external_file {
    my $filename = shift;
    open my $ffh, '<', $filename
      or die "Can't open perl script \"$filename\": $!";

    my $string = "package main;\n" .
                 "#line 1 \"$filename\"\n" .
                 do { local $/ = undef; <$ffh> };
    close $ffh;

    open my $fh, '<', \$string
      or die "Can't open file handle to string: $!";

    unshift @INC, sub { shift @INC; return $fh };

    $ENV{PAR_0} = $filename; # for Pod::Usage
    { do 'main';
      CORE::exit($1) if ($@ =~/^_TK_EXIT_\((\d+)\)/);
      die $@ if $@;
      exit;
    }
}

# extract the contents of a .par (or .exe) or any
# Archive::Zip handle to the PAR_TEMP/inc directory.
# returns that directory.
sub _extract_inc {
    my $file_or_azip_handle = shift;
    my $dlext = defined($Config{dlext}) ? $Config::Config{dlext} : '';
    my $is_handle = ref($file_or_azip_handle) && $file_or_azip_handle->isa('Archive::Zip::Archive');

    require File::Spec;

    my $inc = File::Spec->catdir($PAR::SetupTemp::PARTemp, "inc");
    my $inc_lock = "$inc.lock";

    my $canary = File::Spec->catfile($PAR::SetupTemp::PARTemp, $PAR::SetupTemp::Canary);

    # acquire the "wanna extract inc" lock
    open my $lock, ">", $inc_lock or die qq[can't open "$inc_lock": $!];
    flock($lock, LOCK_EX);

    unless (-d $inc && -e $canary)
    {
        mkdir($inc, 0755);

        undef $@;
        if (!$is_handle) {
          # First try to unzip the *fast* way.
          eval {
            require Archive::Unzip::Burst;
            Archive::Unzip::Burst::unzip($file_or_azip_handle, $inc)
              and die "Could not unzip '$file_or_azip_handle' into '$inc'. Error: $!";
              die;
          };

          # This means the fast module is there, but didn't work.
          if ($@ =~ /^Could not unzip/) {
            die $@;
          }
        }

        # either failed to load Archive::Unzip::Burst or got 
        # an Archive::Zip handle: fallback to slow way.
        if ($is_handle || $@) {
          my $zip;
          if (!$is_handle) {
            open my $fh, '<', $file_or_azip_handle
              or die "Cannot find '$file_or_azip_handle': $!";
            binmode($fh);
            bless($fh, 'IO::File');

            $zip = Archive::Zip->new;
            $zip->readFromFileHandle($fh, $file_or_azip_handle) == AZ_OK
                or die "Read '$file_or_azip_handle' error: $!";
          }
          else {
            $zip = $file_or_azip_handle;
          }

          for ( $zip->memberNames() ) {
              s{^/}{};
              my $outfile =  File::Spec->catfile($inc, $_);
              next if -e $outfile and not -w _;
              $zip->extractMember($_, $outfile);
              # Unfortunately Archive::Zip doesn't have an option
              # NOT to restore member timestamps when extracting, hence set 
              # it to "now" (making it younger than the canary file).
              utime(undef, undef, $outfile);
          }
        }

        $ArchivesExtracted{$is_handle ? $file_or_azip_handle->fileName() : $file_or_azip_handle} = $inc;
    
        # touch (and back-date) canary file
        open my $fh, ">", $canary; 
        print $fh <<'...';
This file is used as "canary in the coal mine" to detect when 
files in PAR's cache area are being removed by some clean up 
mechanism (probably based on file modification times).
...
        close $fh;
        my $dateback = time() - $PAR::SetupTemp::CanaryDateBack;
        utime($dateback, $dateback, $canary);
    }

    # release the "wanna extract inc" lock
    flock($lock, LOCK_UN);
    close $lock;

    # add the freshly extracted directories to @INC,
    # but make sure there's no duplicates
    my %inc_exists = map { ($_, 1) } @INC;
    unshift @INC, grep !exists($inc_exists{$_}),
                  grep -d,
                  map File::Spec->catdir($inc, @$_),
                  [ 'lib' ], [ 'arch' ], [ $arch ],
                  [ $ver ], [ $ver, $arch ], [];

    return $inc;
}


# This is the hook placed in @INC for loading PAR's
# before any other stuff in @INC
sub find_par {
    my @args = @_;

    # if there are repositories in upgrade mode, check them
    # first. If so, this is expensive, of course!
    if (@UpgradeRepositoryObjects) {
        my $module = $args[1];
        $module =~ s/\.pm$//;
        $module =~ s/\//::/g;
        foreach my $client (@UpgradeRepositoryObjects) {
            my $local_file = $client->upgrade_module($module);

            # break the require if upgrade_module has been required already
            # to avoid infinite recursion
            if (exists $INC{$args[1]}) {
                # Oh dear. Check for the possible return values of the INC sub hooks in
                # perldoc -f require before trying to understand this.
                # Then, realize that if you pass undef for the file handle, perl (5.8.9)
                # does NOT use the subroutine. Thus the hacky GLOB ref.
                my $line = 1;
                no warnings;
                return (\*I_AM_NOT_HERE, sub {$line ? ($_="1;",$line=0,return(1)) : ($_="",return(0))});
            }

            # Note: This is likely not necessary as the module has been installed
            # into the system by upgrade_module if it was available at all.
            # If it was already loaded, this will not be reached (see return right above).
            # If it could not be loaded from the system and neither found in the repository,
            # we simply want to have the normal error message, too!
            #
            #if ($local_file) {
            #    # XXX load with fallback - is that right?
            #    return _find_par_internals([$PAR_INC_LAST[-1]], @args);
            #}
        }
    }
    my $rv = _find_par_internals(\@PAR_INC, @args);

    return $rv if defined $rv or not @PriorityRepositoryObjects;

    # the repositories that are preferred over locally installed modules
    my $module = $args[1];
    $module =~ s/\.pm$//;
    $module =~ s/\//::/g;
    foreach my $client (@PriorityRepositoryObjects) {
        my $local_file = $client->get_module($module, 0); # 1 == fallback
        if ($local_file) {
            # Not loaded as fallback (cf. PRIORITY) thus look at PAR_INC
            # instead of PAR_INC_LAST
            return _find_par_internals([$PAR_INC[-1]], @args);
        }
    }
    return();
}

# This is the hook placed in @INC for loading PAR's
# AFTER any other stuff in @INC
# It also deals with loading from repositories as a
# fallback-fallback ;)
sub find_par_last {
    my @args = @_;
    # Try the local PAR files first
    my $rv = _find_par_internals(\@PAR_INC_LAST, @args);
    return $rv if defined $rv;

    # No repositories => return
    return $rv if not @RepositoryObjects;

    my $module = $args[1];
    $module =~ s/\.pm$//;
    $module =~ s/\//::/g;
    foreach my $client (@RepositoryObjects) {
        my $local_file = $client->get_module($module, 1); # 1 == fallback
        if ($local_file) {
            # Loaded as fallback thus look at PAR_INC_LAST
            return _find_par_internals([$PAR_INC_LAST[-1]], @args);
        }
    }
    return $rv;
}


# This routine implements loading modules from PARs
# both for loading PARs preferably or as fallback.
# To distinguish the cases, the first parameter should
# be a reference to the corresponding @PAR_INC* array.
sub _find_par_internals {
    my ($INC_ARY, $self, $file, $member_only) = @_;

    my $scheme;
    foreach (@$INC_ARY ? @$INC_ARY : @INC) {
        my $path = $_;
        if ($] < 5.008001) {
            # reassemble from "perl -Ischeme://path" autosplitting
            $path = "$scheme:$path" if !@$INC_ARY
                and $path and $path =~ m!//!
                and $scheme and $scheme =~ /^\w+$/;
            $scheme = $path;
        }
        my $rv = unpar($path, $file, $member_only, 1) or next;
        $PAR_INC{$path}{$file} = 1;
        $INC{$file} = $LastTempFile if (lc($file) =~ /^(?!tk).*\.pm$/);
        return $rv;
    }

    return;
}

sub reload_libs {
    my @par_files = @_;
    @par_files = sort keys %LibCache unless @par_files;

    foreach my $par (@par_files) {
        my $inc_ref = $PAR_INC{$par} or next;
        delete $LibCache{$par};
        delete $FileCache{$par};
        foreach my $file (sort keys %$inc_ref) {
            delete $INC{$file};
            require $file;
        }
    }
}

#sub find_zip_member {
#    my $file = pop;
#
#    foreach my $zip (@LibCache) {
#        my $member = _first_member($zip, $file) or next;
#        return $member;
#    }
#
#    return;
#}

sub read_file {
    my $file = pop;

    foreach my $zip (@LibCache) {
        my $member = _first_member($zip, $file) or next;
        return scalar $member->contents;
    }

    return;
}

sub par_handle {
    my $par = pop;
    return $LibCache{$par};
}

my %escapes;
sub unpar {
    my ($par, $file, $member_only, $allow_other_ext) = @_;
	return if not defined $par;
    my $zip = $LibCache{$par};
    my @rv = $par;

    # a guard against (currently unimplemented) recursion
    return if $PAR::__unpar;
    local $PAR::__unpar = 1;

    unless ($zip) {
        # URL use case ==> download
        if ($par =~ m!^\w+://!) {
            require File::Spec;
            require LWP::Simple;

            # reflector support
            $par .= "pm=$file" if $par =~ /[?&;]/;

            # prepare cache directory
            $ENV{PAR_CACHE} ||= '_par';
            mkdir $ENV{PAR_CACHE}, 0777;
            if (!-d $ENV{PAR_CACHE}) {
                $ENV{PAR_CACHE} = File::Spec->catdir(File::Spec->tmpdir, 'par');
                mkdir $ENV{PAR_CACHE}, 0777;
                return unless -d $ENV{PAR_CACHE};
            }

            # Munge URL into local file name
            # FIXME: This might result in unbelievably long file names!
            # I have run into the file/path length limitations of linux
            # with similar code in PAR::Repository::Client.
            # I suspect this is even worse on Win32.
            # -- Steffen
            my $file = $par;
            if (!%escapes) {
                $escapes{chr($_)} = sprintf("%%%02X", $_) for 0..255;
            }
            {
                use bytes;
                $file =~ s/([^\w\.])/$escapes{$1}/g;
            }

            $file = File::Spec->catfile( $ENV{PAR_CACHE}, $file);
            LWP::Simple::mirror( $par, $file );
            return unless -e $file and -f _;
            $par = $file;
        }
        # Got the .par as a string. (reference to scalar, of course)
        elsif (ref($par) eq 'SCALAR') {
            ($par, undef) = _tempfile(sub {
                    my $fh = shift;
                    print $fh $$par;
                });
        }
        # If the par is not a valid .par file name and we're being strict
        # about this, then also check whether "$par.par" exists
        elsif (!(($allow_other_ext or $par =~ /\.par\z/i) and -f $par)) {
            $par .= ".par";
            return unless -f $par;
        }

        require Archive::Zip;
        $zip = Archive::Zip->new;

        my @file;
        if (!ref $par) {
            @file = $par;

            open my $fh, '<', $par;
            binmode($fh);

            $par = $fh;
            bless($par, 'IO::File');
        }

        Archive::Zip::setErrorHandler(sub {});
        my $rv = $zip->readFromFileHandle($par, @file);
        Archive::Zip::setErrorHandler(undef);
        return unless $rv == AZ_OK;

        push @LibCache, $zip;
        $LibCache{$_[0]} = $zip;
        $FileCache{$_[0]} = _make_file_cache($zip);

        # only recursive case -- appears to be unused and unimplemented
        foreach my $member ( _cached_members_matching($zip, 
            "^par/(?:$Config{version}/)?(?:$Config{archname}/)?"
        ) ) {
            next if $member->isDirectory;
            my $content = $member->contents();
            next unless $content =~ /^PK\003\004/;
            push @rv, unpar(\$content, undef, undef, 1);
        }
        
        # extract all shlib dlls from the .par to $ENV{PAR_TEMP}
        # Intended to fix problem with Alien::wxWidgets/Wx...
        # NOTE auto/foo/foo.so|dll will get handled by the dynaloader
        # hook, so no need to pull it out here.
        # Allow this to be disabled so caller can do their own caching
        # via import({no_shlib_unpack => 1, file => foo.par})
        if(not $unpar_options{no_shlib_unpack} and defined $ENV{PAR_TEMP}) {
            my @members = _cached_members_matching( $zip,
              qr#^shlib/$Config{archname}/.*\.\Q$Config{dlext}\E(?:\.|$)#
            );
            foreach my $member (@members) {
                next if $member->isDirectory;
                my $member_name = $member->fileName;
                next unless $member_name =~ m{
                        \/([^/]+)$
                    }x
                    or $member_name =~ m{
                        ^([^/]+)$
                    };
                my $extract_name = $1;
                my $dest_name = File::Spec->catfile($ENV{PAR_TEMP}, $extract_name);
                # but don't extract it if we've already got one
                unless (-e $dest_name)
                {
                    $member->extractToFileNamed($dest_name) == AZ_OK
                        or die "Can't extract $member_name: $!";
                }
            }
        }

        # Now push this path into usual library search paths
        my $separator = $Config{path_sep};
        my $tempdir = $ENV{PAR_TEMP};
        foreach my $key (qw(
            LD_LIBRARY_PATH
            LIB_PATH
            LIBRARY_PATH
            PATH
            DYLD_LIBRARY_PATH
        )) {
           if (defined $ENV{$key} and $ENV{$key} ne '') {
               # Check whether it's already in the path. If so, don't
               # append the PAR temp dir in order not to overflow the
               # maximum length for ENV vars.
               $ENV{$key} .= $separator . $tempdir
                 unless grep { $_ eq $tempdir } split $separator, $ENV{$key};
           }
           else {
               $ENV{$key} = $tempdir;
           }
       }
    }

    $LastAccessedPAR = $zip;

    return @rv unless defined $file;

    my $member = _first_member($zip,
        "lib/$file",
        "arch/$file",
        "$arch/$file",
        "$ver/$file",
        "$ver/$arch/$file",
        $file,
    ) or return;

    return $member if $member_only;

    (my $fh, $LastTempFile) = _tempfile(
        sub { 
            my $fh = shift; 
            my $file = $member->fileName;
            $member->extractToFileHandle($fh) == AZ_OK
                or die "Can't extract $file: $!";
        },
        $member->crc32String . ".pm");

    return $fh;
}

sub _tempfile {
    my ($callback, $name) = @_;
    
    if ($ENV{PAR_CLEAN} or !defined $name) {
        require File::Temp;

        if (defined &File::Temp::tempfile) {
            # under Win32, the file is created with O_TEMPORARY,
            # and will be deleted by the C runtime; having File::Temp
            # delete it has the only effect of giving ugly warnings
            my ($fh, $filename) = File::Temp::tempfile(
                DIR     => $PAR::SetupTemp::PARTemp,
                UNLINK  => ($^O ne 'MSWin32' and $^O !~ /hpux/),
            ) or die "Cannot create temporary file: $!";
            binmode($fh);
            $callback->($fh);
            seek($fh, 0, 0);
            return ($fh, $filename);
        }
    }

    require File::Spec;

    # untainting tempfile path
    my ($filename) = File::Spec->catfile($PAR::SetupTemp::PARTemp, $name) =~ /^(.+)$/;

    unless (-r $filename) {
        my $tempname = "$filename.$$";

        open my $fh, '>', $tempname or die $!;
        binmode($fh);
        $callback->($fh);
        close($fh);

        # FIXME why?
        rename($tempname, $filename) or unlink($tempname); 
    }

    open my $fh, '<', $filename or die $!;
    binmode($fh);

    return ($fh, $filename);
}

# Given an Archive::Zip object, this generates a hash of
#   file_name_in_zip => file object
# and returns a reference to that.
# If we broke the encapsulation of A::Zip::Member and
# accessed $member->{fileName} directly, that would be
# *significantly* faster.
sub _make_file_cache {
    my $zip = shift;
    if (not ref($zip)) {
        croak("_make_file_cache needs an Archive::Zip object as argument.");
    }
    my $cache = {};
    foreach my $member ($zip->members) {
        $cache->{$member->fileName()} = $member;
    }
    return $cache;
}

# given an Archive::Zip object, this finds the cached hash
# of Archive::Zip member names => members,
# and returns all member objects whose file names match
# a regexp
# Without file caching, it just uses $zip->membersMatching
sub _cached_members_matching {
    my $zip = shift;
    my $regex = shift;

    my $cache = $FileCache{$zip};
    $cache = $FileCache{$zip} = _make_file_cache($zip) if not $cache;

    return map {$cache->{$_}}
        grep { $_ =~ $regex }
        keys %$cache;
}

# access named zip file member through cache. Fall
# back to using Archive::Zip (slow)
sub _cached_member_named {
    my $zip = shift;
    my $name = shift;

    my $cache = $FileCache{$zip};
    $cache = $FileCache{$zip} = _make_file_cache($zip) if not $cache;
    return $cache->{$name};
}


# Attempt to clean up the temporary directory if
# --> We're running in clean mode
# --> It's defined
# --> It's an existing directory
# --> It's empty
END {
  if (exists $ENV{PAR_CLEAN} and $ENV{PAR_CLEAN}
      and exists $ENV{PAR_TEMP} and defined $ENV{PAR_TEMP} and -d $ENV{PAR_TEMP}
  ) {
    local($!); # paranoid: ignore potential errors without clobbering a global variable!
    rmdir($ENV{PAR_TEMP});
  }
}

1;

__END__

=head1 SEE ALSO

L<PAR::Tutorial>, L<PAR::FAQ> 

The L<PAR::Packer> distribution which contains the packaging utilities:
L<par.pl>, L<parl>, L<pp>.

L<PAR::Dist> for details on PAR distributions.

L<PAR::Repository::Client> for details on accessing PAR repositories.
L<PAR::Repository> for details on how to set up such a repository.

L<Archive::Zip>, L<perlfunc/require>

L<ex::lib::zip>, L<Acme::use::strict::with::pride>

Steffen Mueller has detailed slides on using PAR for application
deployment at L<http://steffen-mueller.net/talks/appdeployment/>.

PAR supports the L<prefork> module. It declares various run-time
dependencies so you can use the L<prefork> module to get streamlined
processes in a forking environment.

=head1 ACKNOWLEDGMENTS

Nicholas Clark for pointing out the mad source filter hook within the
(also mad) coderef C<@INC> hook, as well as (even madder) tricks one
can play with PerlIO to avoid source filtering.

Ton Hospel for convincing me to ditch the C<Filter::Simple>
implementation.

Uri Guttman for suggesting C<read_file> and C<par_handle> interfaces.

Antti Lankila for making me implement the self-contained executable
options via C<par.pl -O>.

See the F<AUTHORS> file in the distribution for a list of people who
have sent helpful patches, ideas or comments.

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

Steffen Mueller E<lt>smueller@cpan.orgE<gt>

You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par@rt.cpan.orgE<gt>. If you need
support, however, joining the E<lt>par@perl.orgE<gt> mailing list is
preferred.

=head1 COPYRIGHT

Copyright 2002-2010 by Audrey Tang
E<lt>cpan@audreyt.orgE<gt>.
Copyright 2005-2010 by Steffen Mueller E<lt>smueller@cpan.orgE<gt>

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut

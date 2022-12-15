package Module::Build::WithXSpp;
use strict;
use warnings;

use Module::Build;
use ExtUtils::CppGuess ();

our @ISA = qw(Module::Build);
our $VERSION = '0.14';

# TODO
# - configurable set of xsp and xspt files (and XS typemaps?)
#   => works via directories for now.
# - configurable includes/C-preamble for the XS?
#   => Works in the .xsp files, but the order of XS++ inclusion
#      is undefined.
# - configurable C++ source folder(s) (works, needs docs)
#   => to be documented another time. This is really not a feature that
#      should be commonly used.

sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;

  # This gives us the correct settings for the C++ compile (hopefully)
  my $guess = ExtUtils::CppGuess->new();
  if (defined $args{extra_compiler_flags}) {
    if (ref($args{extra_compiler_flags})) {
      $guess->add_extra_compiler_flags($_) for @{$args{extra_compiler_flags}};
    }
    else {
      $guess->add_extra_compiler_flags($args{extra_compiler_flags})
    }
    delete $args{extra_compiler_flags};
  }

  if (defined $args{extra_linker_flags}) {
    if (ref($args{extra_linker_flags})) {
      $guess->add_extra_linker_flags($_) for @{$args{extra_linker_flags}};
    }
    else {
      $guess->add_extra_linker_flags($args{extra_linker_flags})
    }
    delete $args{extra_linker_flags};
  }

  # add the typemap modules to the build dependencies
  my $build_requires = $args{build_requires}||{};
  my $extra_typemap_modules = $args{extra_typemap_modules}||{};
  # FIXME: This prevents any potential subclasses from fudging with the extra typemaps?
  foreach my $module (keys %$extra_typemap_modules) {
    if (not defined $build_requires->{$module}
        or defined($extra_typemap_modules->{$module})
           && $build_requires->{$module} < $extra_typemap_modules->{$module})
    {
      $build_requires->{$module} = $extra_typemap_modules->{$module};
    }
  }
  $args{build_requires} = $build_requires;

  # Construct object using C++ options guess
  my $self = $class->SUPER::new(
    %args,
    $guess->module_build_options # FIXME find a way to let the user override this
  );

  push @{$self->extra_compiler_flags},
    map "-I$_",
    (@{$self->cpp_source_dirs||[]}, $self->build_dir);

  $self->_init(\%args);

  return $self;
}

sub _init {
  my $self = shift;
  my $args = shift;
}

sub auto_require {
  my ($self) = @_;
  my $p = $self->{properties};

  if ($self->dist_name ne 'Module-Build-WithXSpp'
      and $self->auto_configure_requires)
  {
    if (not exists $p->{configure_requires}{'Module::Build::WithXSpp'}) {
      (my $ver = $VERSION) =~ s/^(\d+\.\d\d).*$/$1/; # last major release only
      $self->_add_prereq('configure_requires', 'Module::Build::WithXSpp', $ver);
    }
    if (not exists $p->{configure_requires}{'ExtUtils::CppGuess'}) {
      (my $ver = $ExtUtils::CppGuess::VERSION) =~ s/^(\d+\.\d\d).*$/$1/; # last major release only
      $self->_add_prereq('configure_requires', 'ExtUtils::CppGuess', $ver);
    }
    if (not exists $p->{build_requires}{'ExtUtils::CppGuess'}
        and eval("require ExtUtils::XSpp;")
        and defined $ExtUtils::XSpp::VERSION)
    {
      (my $ver = $ExtUtils::XSpp::VERSION) =~ s/^(\d+\.\d\d).*$/$1/; # last major release only
      $self->_add_prereq('build_requires', 'ExtUtils::XSpp', $ver);
    }
  }

  $self->SUPER::auto_require();

  return;
}

sub ACTION_create_buildarea {
  my $self = shift;
  mkdir($self->build_dir);
  $self->add_to_cleanup($self->build_dir);
}

sub ACTION_code {
  my $self = shift;
  $self->depends_on('create_buildarea');
  $self->depends_on('generate_typemap');
  $self->depends_on('generate_main_xs');

  my $files = {};
  foreach my $file (@{$self->cpp_source_files}) {
    $files->{$file} = undef;
  }

  foreach my $ext (qw(c cc cxx cpp C)) {
    foreach my $dir (@{$self->cpp_source_dirs||[]}) {
      my $this = $self->_find_file_by_type($ext, $dir);
      $files = $self->_merge_hashes($files, $this);
    }
  }

  my @objects;
  foreach my $file (keys %$files) {
    my $obj = $self->compile_c($file);
    push @objects, $obj;
    $self->add_to_cleanup($obj);
  }

  $self->{properties}{objects} ||= [];
  push @{$self->{properties}{objects}}, @objects;

  return $self->SUPER::ACTION_code(@_);
}

# I guess I should use a module here.
sub _naive_shell_escape {
  my $s = shift;
  $s =~ s/\\/\\\\/g;
  $s =~ s/"/\\"/g;
  $s
}

sub ACTION_generate_main_xs {
  my $self = shift;

  my $xs_files = $self->find_xs_files;
  my $main_xs_file = File::Spec->catfile($self->build_dir, 'main.xs');

  if (keys(%$xs_files) > 1) {
    # user knows what she's doing, do not generate XS
    $self->log_info("Found custom XS files. Not auto-generating main XS file...\n");
    return 1;
  }

  my $xsp_files = $self->find_xsp_files;
  my $xspt_files = $self->find_xsp_typemaps;

  my $newest = $self->_calc_newest(
    keys(%$xsp_files),
    keys(%$xspt_files),
    'Build.PL',
    # Commented out: Do not include generated typemap in -M check
    # because -M granularity causes unnecessary regens.
    # See "_mbwxspp_force_xs_regen"
    #File::Spec->catdir($self->build_dir, 'typemap'),
  );

  my $main_time = 1e99;
  $main_time = -M $main_xs_file
    if defined $main_xs_file and -e $main_xs_file;

  if (keys(%$xs_files) == 1
      && (values(%$xs_files))[0] =~ /\Q$main_xs_file\E$/)
  {
    # is main xs file still current?
    if (!$self->{_mbwxspp_force_xs_regen} && $main_time < $newest) {
      return 1;
    }
  }

  delete $self->{_mbwxspp_force_xs_regen}; # done its job
  $self->log_info("Generating main XS file...\n");

  my $early_includes = join "\n",
                       map {
                         s/^\s*#\s*include\s*//i;
                         /^"/ or $_ = "<$_>";
                         "#include $_"
                       }
                       @{ $self->early_includes || [] };

  my $module_name = $self->module_name;
  my $xs_code = <<"HERE";
/*
 * WARNING: This file was auto-generated. Changes will be lost!
 */

$early_includes

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#undef do_open
#undef do_close
#ifdef __cplusplus
}
#endif

MODULE = $module_name	PACKAGE = $module_name

HERE

  my $typemap_args = '';
  $typemap_args .= '-t "' . _naive_shell_escape(Cwd::abs_path($_)) . '" ' foreach keys %$xspt_files;

  foreach my $xsp_file (keys %$xsp_files) {
    my $full_path_file = _naive_shell_escape( Cwd::abs_path($xsp_file) );
    my $cmd = qq{INCLUDE_COMMAND: \$^X -MExtUtils::XSpp::Cmd -e xspp -- $typemap_args "$full_path_file"\n\n};
    $xs_code .= $cmd;
  }

  my $outfile = File::Spec->catdir($self->build_dir, 'main.xs');
  open my $fh, '>', $outfile
    or die "Could not open '$outfile' for writing: $!";
  print $fh $xs_code;
  close $fh;

  return 1;
}

sub _load_extra_typemap_modules {
  my $self = shift;

  require ExtUtils::Typemaps;
  my $extra_modules = $self->extra_typemap_modules||{};

  foreach my $module (keys %$extra_modules) {
    my $str = $extra_modules->{$module}
              ? "$module $extra_modules->{$module}"
              : $module;
    if (not eval "use $str;1;") {
      $self->log_warn(<<HERE);
ERROR: Required typemap module '$module' version $extra_modules->{$module} not found.
Error message:
$@
HERE
    }
  }
}

sub ACTION_generate_typemap {
  my $self = shift;
  $self->depends_on('create_buildarea');

  require File::Spec;

  my $files = $self->find_map_files;

  $self->_load_extra_typemap_modules();
  my $extra_modules = $self->extra_typemap_modules||{};

  my $newest = $self->_calc_newest(
    keys(%$files),
    'Build.PL',
  );

  my $out_map_file = File::Spec->catfile($self->build_dir, 'typemap');
  if (-f $out_map_file and -M $out_map_file < $newest) {
    return 1;
  }

  $self->log_info("Processing XS typemap files...\n");

  # merge all typemaps into 'buildtmp/typemap'
  # creates empty typemap file if there are no files to merge
  my $merged = ExtUtils::Typemaps->new;
  $merged->merge(typemap => $_->new) for keys %$extra_modules;

  foreach my $file (keys %$files) {
    $merged->merge(typemap => ExtUtils::Typemaps->new(file => $file));
  }
  $merged->write(file => $out_map_file);

  $self->{_mbwxspp_force_xs_regen} = 1;
}

sub find_map_files  {
  my $self = shift;
  my $files = $self->_find_file_by_type('map', 'lib');
  my @extra_files = map glob($_),
                    map File::Spec->catfile($_, '*.map'),
                    (@{$self->extra_xs_dirs||[]});

  $files->{$_} = $_ foreach map $self->localize_file_path($_),
                            @extra_files;

  $files->{'typemap'} = 'typemap' if -f 'typemap';

  return $files;
}


sub find_xsp_files  {
  my $self = shift;

  my @extra_files = map glob($_),
                    map File::Spec->catfile($_, '*.xsp'),
                    (@{$self->extra_xs_dirs||[]});

  my $files = $self->_find_file_by_type('xsp', 'lib');
  $files->{$_} = $_ foreach map $self->localize_file_path($_),
                            @extra_files;

  require File::Basename;
  # XS++ typemaps aren't XSP files in this regard
  foreach my $file (keys %$files) {
    delete $files->{$file}
      if File::Basename::basename($file) eq 'typemap.xsp';
  }

  return $files;
}

sub find_xsp_typemaps {
  my $self = shift;

  my $xsp_files = $self->_find_file_by_type('xsp', 'lib');
  my $xspt_files = $self->_find_file_by_type('xspt', 'lib');

  foreach (keys %$xsp_files) { # merge over 'typemap.xsp's
    next unless File::Basename::basename($_) eq 'typemap.xsp';
    $xspt_files->{$_} = $_
  }

  my @extra_files = grep -e $_,
                    map glob($_),
                    grep defined $_ && /\S/,
                    map { ( File::Spec->catfile($_, 'typemap.xsp'),
                            File::Spec->catfile($_, '*.xspt') ) }
                    @{$self->extra_xs_dirs||[]};
  $xspt_files->{$_} = $_ foreach map $self->localize_file_path($_),
                                 @extra_files;
  return $xspt_files;
}


# This overrides the equivalent in the base class to add the buildtmp and
# the main directory
sub find_xs_files {
  my $self = shift;
  my $xs_files = $self->SUPER::find_xs_files;

  my @extra_files = map glob($_),
                    map File::Spec->catfile($_, '*.xs'),
                    @{$self->extra_xs_dirs||[]};

  $xs_files->{$_} = $_ foreach map $self->localize_file_path($_),
                               @extra_files;

  my $auto_gen_file = File::Spec->catfile($self->build_dir, 'main.xs');
  if (-e $auto_gen_file) {
    $xs_files->{$auto_gen_file} =  $self->localize_file_path($auto_gen_file);
  }
  return $xs_files;
}


# overridden from original. We really require
# EU::ParseXS, so the "if (eval{require EU::PXS})" is gone.
sub compile_xs {
  my ($self, $file, %args) = @_;
  $self->log_verbose("$file -> $args{outfile}\n");

  require ExtUtils::ParseXS;

  my $main_dir = Cwd::abs_path( Cwd::cwd() );
  my $build_dir = Cwd::abs_path( $self->build_dir );
  ExtUtils::ParseXS::process_file(
    filename   => $file,
    prototypes => 0,
    output     => $args{outfile},
    # not default:
    'C++' => 1,
    hiertype => 1,
    typemap    => File::Spec->catfile($build_dir, 'typemap'),
  );
}

# modified from orinal M::B (FIXME: shouldn't do this with private methods)
# Changes from the original:
# - If we're looking at the "main.xs" file in the build
#   directory, override the TARGET paths with the real
#   module name.
# - In that case, also override the file basename for further
#   build products (maybe this should only be done on installation
#   into blib/.../?)
sub _infer_xs_spec {
  my $self = shift;
  my $file = shift;

  my $cf = $self->{config};

  my %spec;

  my( $v, $d, $f ) = File::Spec->splitpath( $file );
  my @d = File::Spec->splitdir( $d );
  (my $file_base = $f) =~ s/\.[^.]+$//i;

  my $build_folder = $self->build_dir;
  if ($d =~ /\Q$build_folder\E/ && $file_base eq 'main') {
    my $name = $self->module_name;
    @d = split /::/, $name;
    $file_base = $d[-1];
    pop @d if @d;
  }
  else {
    # the module name
    shift( @d ) while @d && ($d[0] eq 'lib' || $d[0] eq '');
    pop( @d ) while @d && $d[-1] eq '';
  }

  $spec{base_name} = $file_base;

  $spec{src_dir} = File::Spec->catpath( $v, $d, '' );

  $spec{module_name} = join( '::', (@d, $file_base) );

  $spec{archdir} = File::Spec->catdir($self->blib, 'arch', 'auto',
				      @d, $file_base);

  $spec{bs_file} = File::Spec->catfile($spec{archdir}, "${file_base}.bs");

  $spec{lib_file} = File::Spec->catfile($spec{archdir},
					"${file_base}.".$cf->get('dlext'));

  $spec{c_file} = File::Spec->catfile( $spec{src_dir},
				       "${file_base}.c" );

  $spec{obj_file} = File::Spec->catfile( $spec{src_dir},
					 "${file_base}".$cf->get('obj_ext') );

  return \%spec;
}

__PACKAGE__->add_property( 'cpp_source_files'      => [] );
__PACKAGE__->add_property( 'cpp_source_dirs'       => ['src'] );
__PACKAGE__->add_property( 'build_dir'             => 'buildtmp' );
__PACKAGE__->add_property( 'extra_xs_dirs'         => [".", grep { -d $_ and /^xsp?$/i } glob("*")] );
__PACKAGE__->add_property( 'extra_typemap_modules' => {} );
__PACKAGE__->add_property( 'early_includes'        => [] );


sub _merge_hashes {
  my $self = shift;
  my %h;
  foreach my $m (@_) {
    $h{$_} = $m->{$_} foreach keys %$m;
  }
  return \%h;
}

sub _calc_newest {
  my $self = shift;
  my $newest = 1.e99;
  foreach my $file (@_) {
    next if not defined $file;
    my $age = -M $file;
    $newest = $age if defined $age and $age < $newest;
  }
  return $newest;
}

1;

__END__

=head1 NAME

Module::Build::WithXSpp - XS++ enhanced flavour of Module::Build

=head1 SYNOPSIS

In F<Build.PL>:

  use strict;
  use warnings;
  use 5.006001;
  
  use Module::Build::WithXSpp;
  
  my $build = Module::Build::WithXSpp->new(
    # normal Module::Build arguments...
    # optional: mix in some extra C typemaps:
    extra_typemap_modules => {
      'ExtUtils::Typemaps::ObjectMap' => '0',
    },
  );
  $build->create_build_script;

=head1 DESCRIPTION

This subclass of L<Module::Build> adds some tools and
processes to make it easier to use for wrapping C++
using XS++ (L<ExtUtils::XSpp>).

There are a few minor differences from using C<Module::Build>
for an ordinary XS module and a few conventions that you
should be aware of as an XS++ module author. They are documented
in the L</"FEATURES AND CONVENTIONS"> section below. But if you
can't be bothered to read all that, you may choose skip it and
blindly follow the advice in L</"JUMP START FOR THE IMPATIENT">.

An example of a full distribution based on this build tool
can be found in the L<ExtUtils::XSpp> distribution under
F<examples/XSpp-Example>. Using that example as the basis
for your C<Module::Build::WithXSpp>-based distribution
is probably a good idea.

=head1 FEATURES AND CONVENTIONS

=head2 XS files

By default, C<Module::Build::WithXSpp> will automatically
generate a main XS file for your module which includes
all XS++ files and does the correct incantations to support
C++.

If C<Module::Build::WithXSpp> detects any XS files in your
module, it will skip the generation of this default file
and assume that you wrote a custom main XS file. If
that is not what you want, and wish to simply include
plain XS code, then you should put the XS in a verbatim
block of an F<.xsp> file. In case you need to use the plain-C
part of an XS file for C<#include> directives and other code,
then put your code into a header file and C<#include> it
from an F<.xsp> file:

In F<src/mystuff.h>:

  #include <something>
  using namespace some::thing;

In F<xsp/MyClass.xsp>

  #include "mystuff.h"
  
  %{
    ... verbatim XS here ...
  %}

Note that there is no guarantee about the order in which the
XS++ files are picked up.

=head2 Build directory

When building your XS++ based extension, a temporary
build directory F<buildtmp> is created for the byproducts.
It is automatically cleaned up by C<./Build clean>.

=head2 Source directories

A Perl module distribution typically has the module C<.pm> files
in its F<lib> subdirectory. In a C<Module::Build::WithXSpp> based
distribution, there are two more such conventions about source
directories:

If any C++ source files are present in the F<src> directory, they
will be compiled to object files and linked automatically.

Any C<.xs>, C<.xsp>, and C<.xspt> files in an F<xs> or F<xsp>
subdirectory will be automatically picked up and included
by the build system.

For backwards compatibility, files of the above types are also
recognized in F<lib>.

=head2 Typemaps

In XS++, there are two types of typemaps: The ordinary XS typemaps
which conventionally put in a file called F<typemap>, and XS++ typemaps.

The ordinary XS typemaps will be found in the main directory,
under F<lib>, and in the XS directories (F<xs> and F<xsp>). They are
required to carry the C<.map> extension or to be called F<typemap>.
You may use multiple F<.map> files if the entries do not
collide. They will be merged at build time into a complete F<typemap> file
in the temporary build directory.

The C<extra_typemap_modules> option is the preferred way to do XS typemapping.
It works like any other C<Module::Build> argument that declares dependencies
except that it loads the listed modules at build time and includes their
typemaps into the build.

The XS++ typemaps are required to carry the C<.xspt> extension or (for
backwards compatibility) to be called C<typemap.xsp>.

=head2 Detecting the C++ compiler

C<Module::Build::WithXSpp> uses L<ExtUtils::CppGuess> to detect
a C++ compiler on your system that is compatible with the C compiler
that was used to compile your perl binary. It sets some
additional compiler/linker options.

This is known to work on GCC (Linux, MacOS, Windows, and ?) as well
as the MS VC toolchain. Patches to enable other compilers are
B<very> welcome.

=head2 Automatic dependencies

C<Module::Build::WithXSpp> automatically adds several dependencies
(on the currently running versions) to your distribution.
You can disable this by setting
C<auto_configure_requires =E<gt> 0> in F<Build.PL>.

These are at configure time: C<Module::Build>,
C<Module::Build::WithXSpp> itself, and C<ExtUtils::CppGuess>.
Additionally there will be a build-time dependency on
C<ExtUtils::XSpp>.

You do not have to set these dependencies yourself unless
you need to set the required versions manually.

=head2 Include files

Unfortunately, including the perl headers produces quite some pollution and
redefinition of common symbols. Therefore, it may be necessary to include
some of your headers before including the perl headers. Specifically,
this is the case for MSVC compilers and the standard library headers.

Therefore, if you care about that platform in the least, you should use the C<early_includes>
option when creating a C<Module::Build::WithXSpp> object to list headers
to include before the perl headers. If such a supplied header file starts with
a double quote, C<#include "..."> is used, otherwise C<#include E<lt>...E<gt>>
is the default. Example:

  Module::Build::WithXSpp->new(
    early_includes => [qw(
      "mylocalheader.h"
      <mysystemheader.h>
    )]
  )

=head1 JUMP START FOR THE IMPATIENT

There are as many ways to start a new CPAN distribution as there
are CPAN distributions. Choose your favourite
(I just do C<h2xs -An My::Module>), then apply a few
changes to your setup:

=over 2

=item *

Obliterate any F<Makefile.PL>.

This is what your F<Build.PL> should look like:

  use strict;
  use warnings;
  use 5.006001;
  use Module::Build::WithXSpp;
  
  my $build = Module::Build::WithXSpp->new(
    module_name         => 'My::Module',
    license             => 'perl',
    dist_author         => q{John Doe <john_does_mail_address>},
    dist_version_from   => 'lib/My/Module.pm',
    build_requires => { 'Test::More' => 0, },
    extra_typemap_modules => {
      'ExtUtils::Typemaps::ObjectMap' => '0',
      # ...
    },
  );
  $build->create_build_script;

If you need to link against some library C<libfoo>, add this to
the options:

    extra_linker_flags => [qw(-lfoo)],

There is C<extra_compiler_flags>, too, if you need it.

=item *

You create two folders in the main distribution folder:
F<src> and F<xsp>.

=item *

You put any C++ code that you want to build and include
in the module into F<src/>. All the typical C(++) file
extensions are recognized and will be compiled to object files
and linked into the module. And headers in that folder will
be accessible for C<#include E<lt>myheader.hE<gt>>.

For good measure, move a copy of F<ppport.h> to that directory.
See L<Devel::PPPort>.

=item *

You do not write normal XS files. Instead, you write XS++ and
put it into the F<xsp/> folder in files with the C<.xsp>
extension. Do not worry, you can include verbatim XS blocks
in XS++. For details on XS++, see L<ExtUtils::XSpp>.

=item *

If you need to do any XS type mapping, put your typemaps
into a F<.map> file in the C<xsp> directory. Alternatively,
search CPAN for an appropriate typemap module (cf.
L<ExtUtils::Typemaps::Default> for an explanation).
XS++ typemaps belong into F<.xspt> files in the same directory.

=item *

In this scheme, F<lib/> only contains Perl module files (and POD).
If you started from a pure-Perl distribution, don't forget to add
these magic two lines to your main module:

  require XSLoader;
  XSLoader::load('My::Module', $VERSION);

=back

=head1 SEE ALSO

L<Module::Build> upon which this module is based.

L<ExtUtils::XSpp> implements XS++. The C<ExtUtils::XSpp> distribution
contains an F<examples> directory with a usage example of this module.

L<ExtUtils::Typemaps> implements progammatic modification (merging)
of C/XS typemaps. C<ExtUtils::Typemaps> was renamed from C<ExtUtils::Typemap>
since the original name conflicted with the core F<typemap> file on
case-insensitive file systems.

L<ExtUtils::Typemaps::Default> explains the concept of having typemaps
shipped as modules.

L<ExtUtils::Typemaps::ObjectMap> is such a typemap module and
probably very useful for any XS++ module.

L<ExtUtils::Typemaps::STL::String> implements simple typemapping for
STL C<std::string>s.

=head1 AUTHOR

Steffen Mueller <smueller@cpan.org>

With input and bug fixes from:

Mattia Barbon

Shmuel Fomberg

Florian Schlichting

=head1 COPYRIGHT AND LICENSE

Copyright 2010, 2011, 2012, 2013 Steffen Mueller.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut


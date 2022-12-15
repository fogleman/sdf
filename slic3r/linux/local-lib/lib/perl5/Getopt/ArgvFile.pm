
# = HISTORY SECTION =====================================================================

# ---------------------------------------------------------------------------------------
# version | date   | author   | changes
# ---------------------------------------------------------------------------------------
# 1.11    |17.04.07| JSTENZEL | renamed fileOptions2prefixes() into _fileOptions2prefixes(),
#         |        |          | in order to avoid POD documentation because it is an
#         |        |          | internal helper function;
#         |        | JSTENZEL | slight adaptations after complaints of perlcritic;
#         |        | JSTENZEL | added POD hints that GetOptions() is imported from
#         |        |          | Getopt::Long and not defined in Getopt::ArgvFile;
#         |        | JSTENZEL | POD: bugfix in GetOptions() calls, %options hash needs to
#         |        |          | be passed in as reference;
#         |21.04.07| JSTENZEL | POD: bugfix in -fileOption example;
# 1.10    |05.01.05| JSTENZEL | added options resolveRelativePathes and resolveEnvVars;
# 1.09    |19.10.04| JSTENZEL | option -startupFilename now accepts array references both
#         |        |          | directly set up and supplied by a callback;
#         |20.10.04| JSTENZEL | new option -fileOption allows to use a user defined option
#         |        |          | instead of an option file prefix like "@" (-options options
#         |        |          | instead of @options);
# 1.08    |30.04.04| JSTENZEL | new import() switch "justload";
# 1.07    |29.04.04| JSTENZEL | import() implemented directly: emulating the old behaviour
#         |        |          | of Exporter::import() when necessary, it alternatively
#         |        |          | allows to invoke argvFile() via use();
# 1.06    |03.05.02| JSTENZEL | the startup filename scheme is now configurable by the
#         |        |          | new option "startupFilename";
# 1.05    |30.04.02| JSTENZEL | cosmetics: hash access without quotes;
#         |        | JSTENZEL | corrected and improved inline doc;
#         |        | JSTENZEL | using File::Spec::Functions to build filenames,
#         |        |          | for improved portability;
#         |        | JSTENZEL | using Cwd::abs_path() to check if files were read already;
#         |        | JSTENZEL | added support for default files in *current* directory;
# 1.04    |29.10.00| JSTENZEL | bugfix: options were read twice if both default and home
#         |        |          | startup options were read and the script was installed in
#         |        |          | the users homedirectory;
# 1.03    |25.03.00| JSTENZEL | new parameter "prefix";
#         |        | JSTENZEL | POD in option files is now supported;
#         |        | JSTENZEL | using Test in test suite now;
# 1.02    |27.02.00| JSTENZEL | new parameter "array";
#         |        | JSTENZEL | slight POD adaptions;
# 1.01    |23.03.99| JSTENZEL | README update only;
# 1.00    |16.03.99| JSTENZEL | first CPAN version.
# ---------------------------------------------------------------------------------------

# = POD SECTION =========================================================================

=head1 NAME

Getopt::ArgvFile - interpolates script options from files into @ARGV or another array

=head1 VERSION

This manual describes version B<1.11>.

=head1 SYNOPSIS

One line invocation - option hints are processed while the module is loaded:

  # load module and process option file hints in @ARGV
  use Getopt::ArgvFile default=>1;
   
  # load another module to evaluate the options, e.g.:
  use Getopt::Long;
  ...

  # evaluate options, e.g. this common way:
  GetOptions(\%options, 'any');    # this function is defined in Getopt::Long

Or suppress option hint processing when the module is loaded, to
perform it later on:

  # load module, do *not* process option file hints
  use Getopt::ArgvFile justload=>1;
   
  # load another module to evaluate the options, e.g.:
  use Getopt::Long;
  ...

  # *now*, solve option file hints
  Getopt::ArgvFile::argvFile(default=>1);

  # evaluate options, e.g. this common way:
  GetOptions(\%options, 'any');    # this function is defined in Getopt::Long

Or use the traditional two step invocation of module loading with
I<symbol import> and I<explicit> option file handling:

  # Load the module and import the &argvFile symbol
  # - this will *not* process option hints.
  # Use *this* syntax to do so, *exactly*.
  use Getopt::ArgvFile qw(argvFile);

  # load another module to evaluate the options, e.g.:
  use Getopt::Long;
  ...

  # *now*, solve option file hints
  argvFile(default=>1);

  # evaluate options, e.g. this common way:
  GetOptions(\%options, 'any');    # this function is defined in Getopt::Long


If options should be processed into another array, this can be done this way:

  # prepare target array
  my @options=('@options1', '@options2', '@options3');

  ...

  # replace file hints by the options stored in the files
  argvFile(array=>\@options);

In case you do not like the "@" prefix it is possible to define an option to
be used instead:

  # prepare target array
  my @options=('-options', 'options1', '-options', 'options2');

  ...

  # replace file hints by the options stored in the files
  argvFile(fileOption=>'options', array=>\@options);


=head1 DESCRIPTION

This module simply interpolates option file hints in @ARGV
by the contents of the pointed files. This enables option
reading from I<files> instead of or additional to the usual
reading from the command line.

Alternatively, you can process any array instead of @ARGV
which is used by default and mentioned mostly in this manual.

The interpolated @ARGV could be subsequently processed by
the usual option handling, e.g. by a Getopt::xxx module.
Getopt::ArgvFile does I<not> perform any option handling itself,
it only prepares the array @ARGV.

Option files can significantly simplify the call of a script.
Imagine the following:

=over 4

=item Breaking command line limits

A script may offer a lot of options, with possibly a few of them
even taking parameters. If these options and their parameters
are passed onto the program call directly, the number of characters
accepted by your shells command line may be exceeded.

Perl itself does I<not> limit the number of characters passed to a
script by parameters, but the shell or command interpreter often
I<sets> a limit here. The same problem may occur if you want to
store a long call in a system file like crontab.

If such a limit restricts you, options and parameters may be moved into
option files, which will result in a shorter command line call.

=item Script calls prepared by scripts

Sometimes a script calls another script. The options passed onto the
nested script could depend on variable situations, such as a users
input or the detected environment. In such a case, it I<can> be easier
to generate an intermediate option file which is then passed to
the nested script.

Or imagine two cron jobs one preparing the other: the first may generate
an option file which is then used by the second.

=item Simple access to typical calling scenarios

If several options need to be set, but in certain circumstances
are always the same, it could become sligthly nerveracking to type
them in again and again. With an option file, they can be stored
I<once> and recalled easily as often as necessary.

Further more, option files may be used to group options. Several
settings may set up one certain behaviour of the program, while others
influence another. Or a certain set of options may be useful in one
typical situation, while another one should be used elsewhere. Or there
is a common set of options which has to be used in every call,
while other options are added depending on the current needs. Or there
are a few user groups with different but typical ways to call your script.
In all these cases, option files may collect options belonging together,
and may be combined by the script users to set up a certain call.
In conjunction with the possiblity to I<nest> such collections, this is
perhaps the most powerful feature provided by this method.

=item Individual and installationwide default options

The module allows the programmer to enable user setups of default options;
for both individual users or generally I<all> callers of a script.
This is especially useful for administrators who can configure the
I<default> behaviour of a script by setting up its installationwide
startup option file. All script users are free then to completely
forget every already configured setup option. And if one of them regularly
adds certain options to every call, he could store them in his I<individual>
startup option file.

For example, I use this feature to make my scripts both flexible I<and>
usable. I have several scripts accessing a database via DBI. The database
account parameters as well as the DBI startup settings should not be coded
inside the scripts because this is not very flexible, so I implemented
them by options. But on the other hand, there should be no need for a normal
user to pass all these settings to every script call. My solution for this
is to use I<default> option files set up and maintained by an administrator.
This is very transparent, most of the users know nothing of these
(documented ;-) configuration settings ... and if anything changes, only the
option files have to be adapted.

=back

=cut

# PACKAGE SECTION  ###############################################

# declare namespace
package Getopt::ArgvFile;

# declare your revision (and use it to avoid a warning)
$VERSION=1.11;
$VERSION=$VERSION;

# force Perl version
require 5.003;

=pod

=head1 EXPORTS

No symbol is exported by default, but you may explicitly import
the "argvFile()" function I<using the exact syntax of the following example>:

  use Getopt::ArgvFile qw(argvFile);

Please note that this interface is provided for backwards compatibility with
versions up to 1.06. By loading the module this way, the traditional import
mechanisms take affect and I<C<argvFile()> is not called implicitly>.

This means that while option file hints are usually processed implicitly when
C<Getopt::ArgvFile> is loaded, the syntax

  use Getopt::ArgvFile qw(argvFile);

requires an I<extra> call of I<argvFile()> to process option files.

=cut

# export something (Exporter is not made a base module because we implement import() ourselves,
# which *can* call Exporter::import() (if needed for backwards compatibility) - see import())
require Exporter;
@EXPORT_OK=qw(argvFile);

# CODE SECTION  ##################################################

# set pragmas
use strict;

# load libraries
use Carp;
use File::Basename;
use Text::ParseWords;
use File::Spec::Functions;
use Cwd qw(:DEFAULT abs_path chdir);

# module variables
my $optionPrefixPattern=qr/(-{1,2}|\+)/;

# METHOD SECTION  ################################################

=pod

=head1 FUNCTIONS

There is only one function, I<argvFile()>, which does all the work of
option file hint processing.

Please note that with version 1.07 and above C<argvFile()> is called
I<implicitly> when the module is loaded, except this is done in one of
the following ways:

  # the traditional interface - provided for
  # backwards compatibility - this loads the
  # module and imports the &argvFile symbol
  use Getopt::ArgvFile qw(argvFile);

  --

  # option file processing is explicitly suppressed
  use Getopt::ArgvFile justload=>1;

Except for the traditional loading, the complete interface of C<argvFile()>
is available via C<use>, but in the typical C<use> syntax without
parantheses.

  # implicit call of argvFile(default=>1, home=>1)
  use Getopt::ArgvFile default=>1, home=>1;

See I<ONE LINE INVOCATION> for further details.


=head2 argvFile()

Scans the command line parameters (stored in @ARGV or an alternatively
passed array) for option file hints (see I<Basics> below), reads the
pointed files and makes their contents part of the source array
(@ARGV by default) replacing the hints.

Because the function was intentionally designed to work on @ARGV
and this is still the default behaviour, this manual mostly speaks about
@ARGV. Please note that it is possible to process I<any> other array
as well.

B<Basics>

An option file hint is simply the filename preceeded by (at least) one
"@" character:

  > script -optA argA -optB @optionFile -optC argC

This will cause argvFile() to scan "optionFile" for options.
The element "@optionFile" will be removed from the @ARGV array and
will be replaced by the options found.

Note: you can choose another prefix by using the "prefix" parameter,
see below.

An option file which cannot be found is quietly skipped.

Well, what is I<within> an option file? It is intended to
store I<command line arguments> which should be passed to the called
script. They can be stored exactly as they would be written in
the command line, but may be spread to multiple lines. To make the
file more readable, space and comment lines (starting with a "#")
are allowed additionally. POD comments are supported as well.
For example, the call

  > script -optA argA -optB -optC cArg par1 par2

could be transformed into

  > script @scriptOptions par1 par2

where the file "scriptOptions" may look like this:

  # option a
  -optA argA

C<>

  =pod
  option b
  =cut
  -optB

C<>

  # option c
  -optC cArg

B<Nested option files>

Option files can be nested. Recursion is avoided globally, that means
that every file will be opened only I<once> (the first time argvFile() finds
a hint pointing to it). This is the simplest implementation, indeed, but
should be suitable. (Unfortunately, there are I<LIMITS>.)

By using this feature, you may combine groups of typical options into
a top level option file, e.g.:

  File ab:

C<>

  # option a
  -optA argA
  # option b
  -optB

C<>

  File c:

C<>

  # option c
  -optC cArg

C<>

  File abc:

C<>

  # combine ab and c
  @ab @c

If anyone provides these files, a user can use a very short call:

  > script @abc

and argvFile() will recursively move all the filed program parameters
into @ARGV.


B<Relative pathes>

Pathes in option files might be relative, as in

  -file ../file @../../configs/nested

If written with the (prepared) start directory in mind, that will work,
but it can fail when it was written relatively to the option file location
because by default those pathes will not be resolved when written from
an option file.

Use parameter C<resolveRelativePathes> to switch to path resolution:

   argvFile(resolveRelativePathes=>1);

will cause C<argvFile()> to expand those pathes, both in standard strings
and nested option files.

   With resolveRelativePathes, both pathes
   will be resolved:

   -file ../file @../../configs/nested

A path is resolved I<relative to the option file> it is found in.


B<Environment variables>

Similar to relative pathes, environment variables are handled differently
depending if the option is specified at the commandline or from an option
file, due to bypassed shell processing. By default, C<argvFile()> does
not resolve environment variables. But if required it can be commanded
to do so via parameter C<resolveEnvVars>.

  argvFile(resolveEnvVars=>1);

B<Startup support>

By setting several named parameters, you can enable automatic processing
of I<startup option files>. There are three of them:

The I<default option file> is searched in the installation path
of the calling script, the I<home option file> is searched in the
users home (evaluated via environment variable "HOME"), and the
I<current option script> is searched in the current directory.

By default, all startup option files are expected to be named like
the script, preceeded by a dot, but this can be adapted to individual
needs if preferred, see below.

 Examples:
  If a script located in "/path/script" is invoked in directory
  /the/current/dir by a user "user" whoms "HOME" variable points
  to "/homes/user", the following happens:

C<>

  argvFile()                    # ignores all startup option files;
  argvFile(default=>1)          # searches and expands "/path/.script",
                                # if available (the "default" settings);
  argvFile(home=>1)             # searches and expands "/homes/user/.script",
                                # if available (the "home" settings);
  argvFile(current=>1)          # searches and expands "/the/current/dir/.script",
                                # if available (the "current" settings);
  argvFile(
           default => 1,
           home    => 1,
           current => 1
          )                     # tries to handle all startups.

Any true value will activate the setting it is assigned to.

In case the ".script" name rule does not meet your needs or does not fit
into a certain policy, the expected startup filenames can be set up by
an option C<startupFilename>. The option value may be a scalar used as
the expected filename, or a reference to an array of accepted choices,
or a reference to code returning the name - plainly or as a reference to
an array of names. Such callback code will be called I<once> and will
receive the name of the script.

  # use ".config"
  argvFile(startupFilename => '.config');

  # use ".config" or "config"
  argvFile(startupFilename => [qw(.config config)]);

  # emulate the default behaviour,
  # but use an extra dot postfix
  my $nameBuilder=sub {join('', '.', basename($_[0]), '.');};
  argvFile(startupFilename => $nameBuilder);

  # use .(script)rc or .(script)/config
  my $nameBuilder=sub
                   {
                    my $sname=basename($_[0]);
                    [".${sname}rc", ".${sname}/config"];
                   };
  argvFile(startupFilename => $nameBuilder);

Note that the list variants will use the first matching filename in each
possible startup-file path. For example if your array is C<['.scriptrc',
'.script.config']> and you have both a C<.scriptrc> and a C<.script.config>
file in (say) your current directory, only the C<.scriptrc> file will be
used, as it is the first found.

The contents found in a startup file is placed I<before> all explicitly
set command line arguments. This enables to overwrite a default setting
by an explicit option. If all startup files are read, I<current> startup
files can overwrite I<home> files which have preceedence over I<default>
ones, so that the I<default> startups are most common. In other words,
if the module would not support startup files, you could get the same
result with "script @/path/.script @/homes/user/.script @/the/current/dir/.script".

Note: There is one certain case when overwriting will I<not> work completely
because duplicates are sorted out: if all three types of startup files are
used and the script is started in the installation directory,
the default file will be identical to the current file. The default file is
processed, but the current file is skipped as a duplicate later on and will
I<not> overwrite settings made caused by the intermediately processed home file.
If started in another directory, it I<will> overwrite the home settings.
But the alternative seems to be even more confusing: the script would behave
differently if just started in its installation path. Because a user might
be more aware of configuration editing then of the current path, I choose
the current implementation, but this preceedence might become configurable
in a future version.

If there is no I<HOME> environment variable, the I<home> setting takes no effect
to avoid trouble accessing the root directory.

B<Cascades>

The function supports multi-level (or so called I<cascaded>) option files.
If a filename in an option file hint starts with a "@" again, this complete
name is the resolution written back to @ARGV - assuming there will be
another utility reading option files.

 Examples:
  @rfile          rfile will be opened, its contents is
                  made part of @ARGV.
  @@rfile         cascade: "@rfile" is written back to
                  @ARGV assuming that there is a subsequent
                  tool called by the script to which this
                  hint will be passed to solve it by an own
                  call of argvFile().

The number of cascaded hints is unlimited.

B<Processing an alternative array>

Although the function was designed to process @ARGV, it is possible to
process another array as well if you prefer. To do this, simply pass
a I<reference> to this array by parameter B<array>.

 Examples:
  argvFile()                    # processes @ARGV;
  argvFile(array=>\@options);   # processes @options;

B<Choosing an alternative hint prefix>

By default, "@" is the prefix used to mark an option file. This can
be changed by using the optional parameter B<prefix>:

 Examples:
  argvFile();                   # use "@";
  argvFile(prefix=>'~');        # use "~";

Note that the strings "#", "=", "-" and "+" are reserved and I<cannot>
be chosen here because they are used to start plain or POD comments or
are typically option prefixes.

B<Using an option instead of a hint prefix>

People not familiar with option files might be confused by file prefixes.
This can be avoided by offering an I<option> that can be used instead
of a prefix, using the optional parameter B<fileOption>:

  # install a file option
  # (all lines are equivalent)
  argvFile(fileOption=>'options');
  argvFile(fileOption=>'-options');
  argvFile(fileOption=>'+options');
  argvFile(fileOption=>'--options');

The name of the option can be specified with or without the usual option
prefixes C<->, C<--> and C<+>.

Once an option is declared, it I<can> replace a prefix. (Prefixes remain
in action as well.)

   # with -options declared to be a file option,
   # these sequences are equivalent
   @file
   -options file

   # five equivalent cascades
   @@@@file
   -options @@@file
   -options -options @@file
   -options -options -options @file
   -options -options -options -options file

Please note that prefixes are attached to the filename with no spaces
in between, while the option declared via -fileOption is separated from
the filename by whitespace, as for normal options.


=cut
sub argvFile
 {
  # declare function variables
  my ($maskString, $i, %rfiles, %startup, %seen)=("\0x07\0x06\0x07");

  # detect the host system (to prepare filename handling)
  my $casesensitiveFilenames=$^O!~/^(?:dos|os2|MSWin32)/i;

  # check and get parameters
  confess('[BUG] Getopt::ArgvFile::argvFile() uses named parameters, please provide name value pairs.') if @_ % 2;
  my %switches=@_;

  # perform more parameter checks
  confess('[BUG] The "array" parameter value is no array reference.') if exists $switches{array} and not (ref($switches{array}) and ref($switches{array}) eq 'ARRAY');
  confess('[BUG] The "prefix" parameter value is no defined literal.') if exists $switches{prefix} and (not defined $switches{prefix} or ref($switches{prefix}));
  confess('[BUG] Invalid "prefix" parameter $switches{"prefix"}.') if exists $switches{prefix} and $switches{prefix}=~/^[-#=+]$/;
  confess('[BUG] The "startupFilename" parameter value is neither a scalar nor array or code reference.') if exists $switches{startupFilename} and ref($switches{startupFilename}) and ref($switches{startupFilename})!~/^(ARRAY|CODE)$/;
  confess('[BUG] The "fileOption" parameter value is no defined literal.') if exists $switches{fileOption} and (not defined $switches{fileOption} or ref($switches{fileOption}));

  # check if further operations are suppressed (in case of a call via import())
  {
   my ($callerSub)=(caller(1))[3];
   return if     defined $callerSub and $callerSub eq join('::', __PACKAGE__, 'import')
             and exists $switches{justload};
  }

  # set array reference
  my $arrayRef=exists $switches{array} ? $switches{array} : \@ARGV;

  # set prefix
  my $prefix=exists $switches{prefix} ? $switches{prefix} : '@';

  # set file option
  my $fileOption=exists $switches{fileOption} ? $switches{fileOption} : '';
  $fileOption=~s/^$optionPrefixPattern//;

  # set up startup filename list
  my $startupFilenames=exists  $switches{startupFilename}
                        ?  ref($switches{startupFilename})
                         ? ref($switches{startupFilename}) eq 'CODE'
                          ?    $switches{startupFilename}->($0)
                          :    $switches{startupFilename}
                         :    [$switches{startupFilename}]
                        : [join('', '.', basename($0))];

  # check callback results
  confess('[BUG] The filenames callback did not return a scalar or an array reference.')
   if ref($startupFilenames) and ref($startupFilenames) ne 'ARRAY';

  # a callback might have returned a(n undefined) scalar instead of an array reference
  $startupFilenames=[defined $startupFilenames ? $startupFilenames : ()]
   unless ref($startupFilenames);

  # substitute file options by prefixes, if necessary
  _fileOptions2prefixes($fileOption, $prefix, $arrayRef) if $fileOption;

  # init startup file paths
  (
   $startup{default}{path},
   $startup{home}{path},
   $startup{current}{path},
  )=(
     dirname($0),
     exists $ENV{HOME} ? $ENV{HOME} : 'no HOME variable, sorry',
     cwd(),
    );

  # ignore the "home" switch if there is no HOME environment variable, for reasons
  # of security
  delete $switches{home} unless exists $ENV{HOME};

  # If startup paths are *identical* (script installed in home directory) and
  # both startup flags are set, we can delete one of them (to read the options only once).
  # (Note that we could easily combine this with the subsequent loop, but an extra loop
  # will make it easy to allow extra configuration for "first seen first processed" /
  # "fix processing order" preferences (what if the current directory is the default
  # one, but should overwrite the home settings?).)
  # Also set the first-found startup files while we're finding them. This makes sure we
  # only use *one* file per path.
  my %startupFiles;
  foreach my $type (qw(default home current))
    {
     # skip unused settings
     next unless exists $switches{$type};

     # build filename (use the first existing file built according to the list of choices, if any)
     my $cfg=(grep(-e, map {catfile(abs_path($startup{$type}{path}), $_)} @$startupFilenames))[0];

     # remove this setting if the associated file
     # was already seen before (each file should be read once)
     # - or if there is no such file this call
     delete $switches{$type}, next if not defined $cfg or exists $seen{$cfg};

     # buffer filename for subsequent use - no need to built it twice
     $startupFiles{$type}=$cfg;

     # otherwise, note that we saw this file
     $seen{$cfg}=1;
    }

  # Check all possible startup files for usage - be careful to handle
  # them in the following order (implemented by alphabetical order here!):
  # FIRST, the DEFAULT startup should be read, THEN the HOME one and finally
  # the CURRENT one - this way, all startup options are placed before command
  # line ones, and the CURRENT settings can overwrite the HOME settings which
  # can overwrite the DEFAULT ones - which are the most common.
  # Note that to achieve this reading order, we have to build the array
  # of filenames in reverse order (because we use unshift() for construction).
  foreach my $type (qw(current home default))
    {
     # let's proceed this file first, if there is anything to do
     # - this way, command line options can overwrite configuration
     # settings (we already checked file existence above)
     unshift @$arrayRef, join('', $prefix, $startupFiles{$type})
       if exists $switches{$type};
    }

  # nesting ...
  while (grep(/^$prefix/, @$arrayRef))
    {
     # declare scope variables
     my (%nr, @c, $c);

     # scan the array for option file hints
     for ($i=0; $i<@$arrayRef; $i++)
       {$nr{$i}=1 if substr($arrayRef->[$i], 0, 1) eq $prefix;}

     for ($i=0; $i<@$arrayRef; $i++)
       {
        if ($nr{$i})
          {
           # an option file - handle it

           # remove the option hint
           $arrayRef->[$i]=~s/$prefix//;

           # if there is still an option file hint in the name of the file,
           # this is a cascaded hint - insert it with a special temporary
           # hint (has to be different from $prefix to avoid a subsequent solution
           # by this loop)
           push(@c, $arrayRef->[$i]), next if $arrayRef->[$i]=~s/^$prefix/$maskString/;

           # skip nonexistent or recursively nested files
           next if !-e $arrayRef->[$i] || -d _ || $rfiles{$casesensitiveFilenames ? $arrayRef->[$i] : lc($arrayRef->[$i])};

           # store filename to avoid recursion
           $rfiles{$casesensitiveFilenames ? $arrayRef->[$i] : lc($arrayRef->[$i])}=1;

           # open file and read its contents
           open(OPT, $arrayRef->[$i]);
           {
            # scopy
            my ($pod);

            # handle every line
            while (<OPT>)
              {
               # check for POD directives
               $pod=1 if /^=\w/;
               $pod=0, next if /^=cut/;

               # skip space and comment lines (including POD)
               next if /^\s*$/ || /^\s*\#/ || $pod;

               # remove newlines, leading and trailing spaces
               s/\s*\n?$//; s/^\s*//;

               # get "shellwords", double backslashes before Dollar characters
               # as they would get lost otherwise (other backslash removals are welcome!)
               s/\\\$/\\\\\$/g;
               my (@shellwords)=shellwords($_);

               # replace environment variables, if necessary
               if (exists $switches{resolveEnvVars})
                 {
                  # get *quoted* strings
                  my (@quotedwords)=quotewords('\s+', 1, $_);

                  # process all strings
                  for (my $i=0; $i<@shellwords; ++$i)
                    {
                     # substitute environment variables, except in single quoted strings
                     unless ($quotedwords[$i]=~/^'.+'$/)
                       {
                        # named variables
                        $shellwords[$i]=~s/(?<!\\)\$(\w+)/exists $ENV{$1} ? $ENV{$1} : ''/ge;

                        # symbolic variables
                        $shellwords[$i]=~s/(?<!\\)\$(?:{(\w+)})/exists $ENV{$1} ? $ENV{$1} : ''/ge;

                        # finally, remove the backslashes before Dollar characters we added above
                        $shellwords[$i]=~s/\\\$/\$/g;
                       }
                    }
                 }

               # resolve relative pathes, if requested
               if (exists $switches{resolveRelativePathes})
                 {
                  # process all strings
                  foreach my $string (@shellwords)
                    {
                     # scopy
                     my @p;
                     # replace as necessary
                     @p=(defined($1) ? $1 : '', $2), $string=~s#^$p[0]$p[1]#join('', $p[0], abs_path(catfile(dirname($arrayRef->[$i]), $p[1])))#e
                       if $string=~m#^($prefix)?([./]+)/#;
                    }
                 }

               # supply results
               push(@c, @shellwords);
              }
           }
          }
        else
          {
           # a normal option or parameter - handle it
           push(@c, $arrayRef->[$i]);
          }
       }

     # substitute file options by prefixes, if necessary
     _fileOptions2prefixes($fileOption, $prefix, \@c) if $fileOption;

     # replace original array by expanded array
     @$arrayRef=@c;
    }

  # reset hint character in cascaded hints to $prefix
  @$arrayRef=map {s/^$maskString/$prefix/; $_} @$arrayRef;
 }


# allow one line invokation via "use", but make sure to keep backwards compatibility to
# the traditional interface inherited from Exporter 
sub import
 {
  # check if the caller intended to import symbols
  # (till 1.06, import() was inherited from Exporter and the only symbol to import was argvFile())
  if (@_==2 and $_[-1] eq "argvFile")
   {goto &Exporter::import;}
  else
   {
    # shift away the module name
    shift;

    # invoke argvFile(): now option files are processed while the module is loaded
    argvFile(@_);
   }
 }



# preprocess an array to convert the -fileOption string into a prefix
sub _fileOptions2prefixes
 {
  # get and check parameters
  my ($fileOption, $prefix, $arrayRef)=@_;

  # anything to do?
  if ($fileOption)
   {
    # make options a string and replace all file options by a prefix
    # (to replace the file option and its successor by the prefixed successor)
    my $options=join("\x01\x01\x01", @$arrayRef);
    $options=~s/($optionPrefixPattern$fileOption\x01+)/$prefix/g;

    # replace original array
    @$arrayRef=split(/\x01\x01\x01/, $options);;
   }
 }



# flag this module was read successfully
1;

# POD TRAILER ####################################################

=pod

=head1 ONE LINE INVOCATION

The traditional two line sequence

  # load the module
  use Getopt::ArgvFile qw(argvFile);

  ...

  # solve option files
  argvFile(default=>1);

can be reduced to one line - just pass the parameters of C<argvFile()>
to C<use()>:

  # load module and process option file hints in @ARGV
  use Getopt::ArgvFile default=>1;

Please note that in this case option file hints are processed at compile
time. This means that if you want to process alternative arrays, these
arrays have to be prepared before, usually in a C<BEGIN> block.

In versions 1.07 and above, implicit option file handling is the I<default>
and only suppressed for the traditional

  use Getopt::ArgvFile qw(argvFile);

loading, for reasons of backwards compatibility. A simple loading like

  use Getopt::ArgvFile;

I<will> process option hints! If you want to suppress this, use the
B<C<justload>> switch:

  use Getopt::ArgvFile justload=>1;

See I<FUNCTIONS> for additional informations.

=head1 NOTES

If a script calling C<argvFile()> with the C<default> switch is
invoked using a relative path, it is strongly recommended to
perform the call of C<argvFile()> in the startup directory
because C<argvFile()> then uses the I<relative> script path as
well.


=head1 LIMITS

If an option file does not exist, argvFile() simply ignores it.
No message will be displayed, no special return code will be set.

=head1 AUTHOR

Jochen Stenzel E<lt>mailto:perl@jochen-stenzel.deE<gt>

=head1 LICENSE

Copyright (c) 1993-2007 Jochen Stenzel. All rights reserved.

This program is free software, you can redistribute it and/or modify it
under the terms of the Artistic License distributed with Perl version
5.003 or (at your option) any later version. Please refer to the
Artistic License that came with your Perl distribution for more
details.

=cut

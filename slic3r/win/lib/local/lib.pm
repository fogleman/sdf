#line 1 "local/lib.pm"
package local::lib;
use 5.006;
BEGIN {
  if ($ENV{RELEASE_TESTING}) {
    require strict;
    strict->import;
    require warnings;
    warnings->import;
  }
}
use Config ();

our $VERSION = '2.000024';
$VERSION = eval $VERSION;

BEGIN {
  *_WIN32 = ($^O eq 'MSWin32' || $^O eq 'NetWare' || $^O eq 'symbian')
    ? sub(){1} : sub(){0};
  # punt on these systems
  *_USE_FSPEC = ($^O eq 'MacOS' || $^O eq 'VMS' || $INC{'File/Spec.pm'})
    ? sub(){1} : sub(){0};
}
my $_archname = $Config::Config{archname};
my $_version = $Config::Config{version};
my @_inc_version_list = reverse split / /, $Config::Config{inc_version_list};
my $_path_sep = $Config::Config{path_sep};

our $_DIR_JOIN = _WIN32 ? '\\' : '/';
our $_DIR_SPLIT = (_WIN32 || $^O eq 'cygwin') ? qr{[\\/]}
                                              : qr{/};
our $_ROOT = _WIN32 ? do {
  my $UNC = qr{[\\/]{2}[^\\/]+[\\/][^\\/]+};
  qr{^(?:$UNC|[A-Za-z]:|)$_DIR_SPLIT};
} : qr{^/};
our $_PERL;

sub _perl {
  if (!$_PERL) {
    # untaint and validate
    ($_PERL, my $exe) = $^X =~ /((?:.*$_DIR_SPLIT)?(.+))/;
    $_PERL = 'perl'
      if $exe !~ /perl/;
    if (_is_abs($_PERL)) {
    }
    elsif (-x $Config::Config{perlpath}) {
      $_PERL = $Config::Config{perlpath};
    }
    elsif ($_PERL =~ $_DIR_SPLIT && -x $_PERL) {
      $_PERL = _rel2abs($_PERL);
    }
    else {
      ($_PERL) =
        map { /(.*)/ }
        grep { -x $_ }
        map { ($_, _WIN32 ? ("$_.exe") : ()) }
        map { join($_DIR_JOIN, $_, $_PERL) }
        split /\Q$_path_sep\E/, $ENV{PATH};
    }
  }
  $_PERL;
}

sub _cwd {
  if (my $cwd
    = defined &Cwd::sys_cwd ? \&Cwd::sys_cwd
    : defined &Cwd::cwd     ? \&Cwd::cwd
    : undef
  ) {
    no warnings 'redefine';
    *_cwd = $cwd;
    goto &$cwd;
  }
  my $drive = shift;
  return Win32::Cwd()
    if _WIN32 && defined &Win32::Cwd && !$drive;
  local @ENV{qw(PATH IFS CDPATH ENV BASH_ENV)};
  my $cmd = $drive ? "eval { Cwd::getdcwd(q($drive)) }"
                   : 'getcwd';
  my $perl = _perl;
  my $cwd = `"$perl" -MCwd -le "print $cmd"`;
  chomp $cwd;
  if (!length $cwd && $drive) {
    $cwd = $drive;
  }
  $cwd =~ s/$_DIR_SPLIT?$/$_DIR_JOIN/;
  $cwd;
}

sub _catdir {
  if (_USE_FSPEC) {
    require File::Spec;
    File::Spec->catdir(@_);
  }
  else {
    my $dir = join($_DIR_JOIN, @_);
    $dir =~ s{($_DIR_SPLIT)(?:\.?$_DIR_SPLIT)+}{$1}g;
    $dir;
  }
}

sub _is_abs {
  if (_USE_FSPEC) {
    require File::Spec;
    File::Spec->file_name_is_absolute($_[0]);
  }
  else {
    $_[0] =~ $_ROOT;
  }
}

sub _rel2abs {
  my ($dir, $base) = @_;
  return $dir
    if _is_abs($dir);

  $base = _WIN32 && $dir =~ s/^([A-Za-z]:)// ? _cwd("$1")
        : $base                              ? _rel2abs($base)
                                             : _cwd;
  return _catdir($base, $dir);
}

our $_DEVNULL;
sub _devnull {
  return $_DEVNULL ||=
    _USE_FSPEC      ? (require File::Spec, File::Spec->devnull)
    : _WIN32        ? 'nul'
    : $^O eq 'os2'  ? '/dev/nul'
    : '/dev/null';
}

sub import {
  my ($class, @args) = @_;
  if ($0 eq '-') {
    push @args, @ARGV;
    require Cwd;
  }

  my @steps;
  my %opts;
  my %attr;
  my $shelltype;

  while (@args) {
    my $arg = shift @args;
    # check for lethal dash first to stop processing before causing problems
    # the fancy dash is U+2212 or \xE2\x88\x92
    if ($arg =~ /\xE2\x88\x92/) {
      die <<'DEATH';
WHOA THERE! It looks like you've got some fancy dashes in your commandline!
These are *not* the traditional -- dashes that software recognizes. You
probably got these by copy-pasting from the perldoc for this module as
rendered by a UTF8-capable formatter. This most typically happens on an OS X
terminal, but can happen elsewhere too. Please try again after replacing the
dashes with normal minus signs.
DEATH
    }
    elsif ($arg eq '--self-contained') {
      die <<'DEATH';
FATAL: The local::lib --self-contained flag has never worked reliably and the
original author, Mark Stosberg, was unable or unwilling to maintain it. As
such, this flag has been removed from the local::lib codebase in order to
prevent misunderstandings and potentially broken builds. The local::lib authors
recommend that you look at the lib::core::only module shipped with this
distribution in order to create a more robust environment that is equivalent to
what --self-contained provided (although quite possibly not what you originally
thought it provided due to the poor quality of the documentation, for which we
apologise).
DEATH
    }
    elsif( $arg =~ /^--deactivate(?:=(.*))?$/ ) {
      my $path = defined $1 ? $1 : shift @args;
      push @steps, ['deactivate', $path];
    }
    elsif ( $arg eq '--deactivate-all' ) {
      push @steps, ['deactivate_all'];
    }
    elsif ( $arg =~ /^--shelltype(?:=(.*))?$/ ) {
      $shelltype = defined $1 ? $1 : shift @args;
    }
    elsif ( $arg eq '--no-create' ) {
      $opts{no_create} = 1;
    }
    elsif ( $arg eq '--quiet' ) {
      $attr{quiet} = 1;
    }
    elsif ( $arg =~ /^--/ ) {
      die "Unknown import argument: $arg";
    }
    else {
      push @steps, ['activate', $arg, \%opts];
    }
  }
  if (!@steps) {
    push @steps, ['activate', undef, \%opts];
  }

  my $self = $class->new(%attr);

  for (@steps) {
    my ($method, @args) = @$_;
    $self = $self->$method(@args);
  }

  if ($0 eq '-') {
    print $self->environment_vars_string($shelltype);
    exit 0;
  }
  else {
    $self->setup_local_lib;
  }
}

sub new {
  my $class = shift;
  bless {@_}, $class;
}

sub clone {
  my $self = shift;
  bless {%$self, @_}, ref $self;
}

sub inc { $_[0]->{inc}     ||= \@INC }
sub libs { $_[0]->{libs}   ||= [ \'PERL5LIB' ] }
sub bins { $_[0]->{bins}   ||= [ \'PATH' ] }
sub roots { $_[0]->{roots} ||= [ \'PERL_LOCAL_LIB_ROOT' ] }
sub extra { $_[0]->{extra} ||= {} }
sub quiet { $_[0]->{quiet} }

sub _as_list {
  my $list = shift;
  grep length, map {
    !(ref $_ && ref $_ eq 'SCALAR') ? $_ : (
      defined $ENV{$$_} ? split(/\Q$_path_sep/, $ENV{$$_})
                        : ()
    )
  } ref $list ? @$list : $list;
}
sub _remove_from {
  my ($list, @remove) = @_;
  return @$list
    if !@remove;
  my %remove = map { $_ => 1 } @remove;
  grep !$remove{$_}, _as_list($list);
}

my @_lib_subdirs = (
  [$_version, $_archname],
  [$_version],
  [$_archname],
  (map [$_], @_inc_version_list),
  [],
);

sub install_base_bin_path {
  my ($class, $path) = @_;
  return _catdir($path, 'bin');
}
sub install_base_perl_path {
  my ($class, $path) = @_;
  return _catdir($path, 'lib', 'perl5');
}
sub install_base_arch_path {
  my ($class, $path) = @_;
  _catdir($class->install_base_perl_path($path), $_archname);
}

sub lib_paths_for {
  my ($class, $path) = @_;
  my $base = $class->install_base_perl_path($path);
  return map { _catdir($base, @$_) } @_lib_subdirs;
}

sub _mm_escape_path {
  my $path = shift;
  $path =~ s/\\/\\\\/g;
  if ($path =~ s/ /\\ /g) {
    $path = qq{"$path"};
  }
  return $path;
}

sub _mb_escape_path {
  my $path = shift;
  $path =~ s/\\/\\\\/g;
  return qq{"$path"};
}

sub installer_options_for {
  my ($class, $path) = @_;
  return (
    PERL_MM_OPT =>
      defined $path ? "INSTALL_BASE="._mm_escape_path($path) : undef,
    PERL_MB_OPT =>
      defined $path ? "--install_base "._mb_escape_path($path) : undef,
  );
}

sub active_paths {
  my ($self) = @_;
  $self = ref $self ? $self : $self->new;

  return grep {
    # screen out entries that aren't actually reflected in @INC
    my $active_ll = $self->install_base_perl_path($_);
    grep { $_ eq $active_ll } @{$self->inc};
  } _as_list($self->roots);
}


sub deactivate {
  my ($self, $path) = @_;
  $self = $self->new unless ref $self;
  $path = $self->resolve_path($path);
  $path = $self->normalize_path($path);

  my @active_lls = $self->active_paths;

  if (!grep { $_ eq $path } @active_lls) {
    warn "Tried to deactivate inactive local::lib '$path'\n";
    return $self;
  }

  my %args = (
    bins  => [ _remove_from($self->bins,
      $self->install_base_bin_path($path)) ],
    libs  => [ _remove_from($self->libs,
      $self->install_base_perl_path($path)) ],
    inc   => [ _remove_from($self->inc,
      $self->lib_paths_for($path)) ],
    roots => [ _remove_from($self->roots, $path) ],
  );

  $args{extra} = { $self->installer_options_for($args{roots}[0]) };

  $self->clone(%args);
}

sub deactivate_all {
  my ($self) = @_;
  $self = $self->new unless ref $self;

  my @active_lls = $self->active_paths;

  my %args;
  if (@active_lls) {
    %args = (
      bins => [ _remove_from($self->bins,
        map $self->install_base_bin_path($_), @active_lls) ],
      libs => [ _remove_from($self->libs,
        map $self->install_base_perl_path($_), @active_lls) ],
      inc => [ _remove_from($self->inc,
        map $self->lib_paths_for($_), @active_lls) ],
      roots => [ _remove_from($self->roots, @active_lls) ],
    );
  }

  $args{extra} = { $self->installer_options_for(undef) };

  $self->clone(%args);
}

sub activate {
  my ($self, $path, $opts) = @_;
  $opts ||= {};
  $self = $self->new unless ref $self;
  $path = $self->resolve_path($path);
  $self->ensure_dir_structure_for($path, { quiet => $self->quiet })
    unless $opts->{no_create};

  $path = $self->normalize_path($path);

  my @active_lls = $self->active_paths;

  if (grep { $_ eq $path } @active_lls[1 .. $#active_lls]) {
    $self = $self->deactivate($path);
  }

  my %args;
  if ($opts->{always} || !@active_lls || $active_lls[0] ne $path) {
    %args = (
      bins  => [ $self->install_base_bin_path($path), @{$self->bins} ],
      libs  => [ $self->install_base_perl_path($path), @{$self->libs} ],
      inc   => [ $self->lib_paths_for($path), @{$self->inc} ],
      roots => [ $path, @{$self->roots} ],
    );
  }

  $args{extra} = { $self->installer_options_for($path) };

  $self->clone(%args);
}

sub normalize_path {
  my ($self, $path) = @_;
  $path = ( Win32::GetShortPathName($path) || $path )
    if $^O eq 'MSWin32';
  return $path;
}

sub build_environment_vars_for {
  my $self = $_[0]->new->activate($_[1], { always => 1 });
  $self->build_environment_vars;
}
sub build_activate_environment_vars_for {
  my $self = $_[0]->new->activate($_[1], { always => 1 });
  $self->build_environment_vars;
}
sub build_deactivate_environment_vars_for {
  my $self = $_[0]->new->deactivate($_[1]);
  $self->build_environment_vars;
}
sub build_deact_all_environment_vars_for {
  my $self = $_[0]->new->deactivate_all;
  $self->build_environment_vars;
}
sub build_environment_vars {
  my $self = shift;
  (
    PATH                => join($_path_sep, _as_list($self->bins)),
    PERL5LIB            => join($_path_sep, _as_list($self->libs)),
    PERL_LOCAL_LIB_ROOT => join($_path_sep, _as_list($self->roots)),
    %{$self->extra},
  );
}

sub setup_local_lib_for {
  my $self = $_[0]->new->activate($_[1]);
  $self->setup_local_lib;
}

sub setup_local_lib {
  my $self = shift;

  # if Carp is already loaded, ensure Carp::Heavy is also loaded, to avoid
  # $VERSION mismatch errors (Carp::Heavy loads Carp, so we do not need to
  # check in the other direction)
  require Carp::Heavy if $INC{'Carp.pm'};

  $self->setup_env_hash;
  @INC = @{$self->inc};
}

sub setup_env_hash_for {
  my $self = $_[0]->new->activate($_[1]);
  $self->setup_env_hash;
}
sub setup_env_hash {
  my $self = shift;
  my %env = $self->build_environment_vars;
  for my $key (keys %env) {
    if (defined $env{$key}) {
      $ENV{$key} = $env{$key};
    }
    else {
      delete $ENV{$key};
    }
  }
}

sub print_environment_vars_for {
  print $_[0]->environment_vars_string_for(@_[1..$#_]);
}

sub environment_vars_string_for {
  my $self = $_[0]->new->activate($_[1], { always => 1});
  $self->environment_vars_string;
}
sub environment_vars_string {
  my ($self, $shelltype) = @_;

  $shelltype ||= $self->guess_shelltype;

  my $extra = $self->extra;
  my @envs = (
    PATH                => $self->bins,
    PERL5LIB            => $self->libs,
    PERL_LOCAL_LIB_ROOT => $self->roots,
    map { $_ => $extra->{$_} } sort keys %$extra,
  );
  $self->_build_env_string($shelltype, \@envs);
}

sub _build_env_string {
  my ($self, $shelltype, $envs) = @_;
  my @envs = @$envs;

  my $build_method = "build_${shelltype}_env_declaration";

  my $out = '';
  while (@envs) {
    my ($name, $value) = (shift(@envs), shift(@envs));
    if (
        ref $value
        && @$value == 1
        && ref $value->[0]
        && ref $value->[0] eq 'SCALAR'
        && ${$value->[0]} eq $name) {
      next;
    }
    $out .= $self->$build_method($name, $value);
  }
  my $wrap_method = "wrap_${shelltype}_output";
  if ($self->can($wrap_method)) {
    return $self->$wrap_method($out);
  }
  return $out;
}

sub build_bourne_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '${%s:-}', qr/["\\\$!`]/, '\\%s');

  if (!defined $value) {
    return qq{unset $name;\n};
  }

  $value =~ s/(^|\G|$_path_sep)\$\{$name:-\}$_path_sep/$1\${$name}\${$name:+$_path_sep}/g;
  $value =~ s/$_path_sep\$\{$name:-\}$/\${$name:+$_path_sep\${$name}}/;

  qq{${name}="$value"; export ${name};\n}
}

sub build_csh_env_declaration {
  my ($class, $name, $args) = @_;
  my ($value, @vars) = $class->_interpolate($args, '${%s}', qr/["\$]/, '"\\%s"');
  if (!defined $value) {
    return qq{unsetenv $name;\n};
  }

  my $out = '';
  for my $var (@vars) {
    $out .= qq{if ! \$?$name setenv $name '';\n};
  }

  my $value_without = $value;
  if ($value_without =~ s/(?:^|$_path_sep)\$\{$name\}(?:$_path_sep|$)//g) {
    $out .= qq{if "\${$name}" != '' setenv $name "$value";\n};
    $out .= qq{if "\${$name}" == '' };
  }
  $out .= qq{setenv $name "$value_without";\n};
  return $out;
}

sub build_cmd_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '%%%s%%', qr(%), '%s');
  if (!$value) {
    return qq{\@set $name=\n};
  }

  my $out = '';
  my $value_without = $value;
  if ($value_without =~ s/(?:^|$_path_sep)%$name%(?:$_path_sep|$)//g) {
    $out .= qq{\@if not "%$name%"=="" set "$name=$value"\n};
    $out .= qq{\@if "%$name%"=="" };
  }
  $out .= qq{\@set "$name=$value_without"\n};
  return $out;
}

sub build_powershell_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '$env:%s', qr/["\$]/, '`%s');

  if (!$value) {
    return qq{Remove-Item -ErrorAction 0 Env:\\$name;\n};
  }

  my $maybe_path_sep = qq{\$(if("\$env:$name"-eq""){""}else{"$_path_sep"})};
  $value =~ s/(^|\G|$_path_sep)\$env:$name$_path_sep/$1\$env:$name"+$maybe_path_sep+"/g;
  $value =~ s/$_path_sep\$env:$name$/"+$maybe_path_sep+\$env:$name+"/;

  qq{\$env:$name = \$("$value");\n};
}
sub wrap_powershell_output {
  my ($class, $out) = @_;
  return $out || " \n";
}

sub build_fish_env_declaration {
  my ($class, $name, $args) = @_;
  my $value = $class->_interpolate($args, '$%s', qr/[\\"'$ ]/, '\\%s');
  if (!defined $value) {
    return qq{set -e $name;\n};
  }

  # fish has special handling for PATH, CDPATH, and MANPATH.  They are always
  # treated as arrays, and joined with ; when storing the environment.  Other
  # env vars can be arrays, but will be joined without a separator.  We only
  # really care about PATH, but might as well make this routine more general.
  if ($name =~ /^(?:CD|MAN)?PATH$/) {
    $value =~ s/$_path_sep/ /g;
    my $silent = $name =~ /^(?:CD)?PATH$/ ? " ^"._devnull : '';
    return qq{set -x $name $value$silent;\n};
  }

  my $out = '';
  my $value_without = $value;
  if ($value_without =~ s/(?:^|$_path_sep)\$$name(?:$_path_sep|$)//g) {
    $out .= qq{set -q $name; and set -x $name $value;\n};
    $out .= qq{set -q $name; or };
  }
  $out .= qq{set -x $name $value_without;\n};
  $out;
}

sub _interpolate {
  my ($class, $args, $var_pat, $escape, $escape_pat) = @_;
  return
    unless defined $args;
  my @args = ref $args ? @$args : $args;
  return
    unless @args;
  my @vars = map { $$_ } grep { ref $_ eq 'SCALAR' } @args;
  my $string = join $_path_sep, map {
    ref $_ eq 'SCALAR' ? sprintf($var_pat, $$_) : do {
      s/($escape)/sprintf($escape_pat, $1)/ge; $_;
    };
  } @args;
  return wantarray ? ($string, \@vars) : $string;
}

sub pipeline;

sub pipeline {
  my @methods = @_;
  my $last = pop(@methods);
  if (@methods) {
    \sub {
      my ($obj, @args) = @_;
      $obj->${pipeline @methods}(
        $obj->$last(@args)
      );
    };
  } else {
    \sub {
      shift->$last(@_);
    };
  }
}

sub resolve_path {
  my ($class, $path) = @_;

  $path = $class->${pipeline qw(
    resolve_relative_path
    resolve_home_path
    resolve_empty_path
  )}($path);

  $path;
}

sub resolve_empty_path {
  my ($class, $path) = @_;
  if (defined $path) {
    $path;
  } else {
    '~/perl5';
  }
}

sub resolve_home_path {
  my ($class, $path) = @_;
  $path =~ /^~([^\/]*)/ or return $path;
  my $user = $1;
  my $homedir = do {
    if (! length($user) && defined $ENV{HOME}) {
      $ENV{HOME};
    }
    else {
      require File::Glob;
      File::Glob::bsd_glob("~$user", File::Glob::GLOB_TILDE());
    }
  };
  unless (defined $homedir) {
    require Carp; require Carp::Heavy;
    Carp::croak(
      "Couldn't resolve homedir for "
      .(defined $user ? $user : 'current user')
    );
  }
  $path =~ s/^~[^\/]*/$homedir/;
  $path;
}

sub resolve_relative_path {
  my ($class, $path) = @_;
  _rel2abs($path);
}

sub ensure_dir_structure_for {
  my ($class, $path, $opts) = @_;
  $opts ||= {};
  my @dirs;
  foreach my $dir (
    $class->lib_paths_for($path),
    $class->install_base_bin_path($path),
  ) {
    my $d = $dir;
    while (!-d $d) {
      push @dirs, $d;
      require File::Basename;
      $d = File::Basename::dirname($d);
    }
  }

  warn "Attempting to create directory ${path}\n"
    if !$opts->{quiet} && @dirs;

  my %seen;
  foreach my $dir (reverse @dirs) {
    next
      if $seen{$dir}++;

    mkdir $dir
      or -d $dir
      or die "Unable to create $dir: $!"
  }
  return;
}

sub guess_shelltype {
  my $shellbin
    = defined $ENV{SHELL} && length $ENV{SHELL}
      ? ($ENV{SHELL} =~ /([\w.]+)$/)[-1]
    : ( $^O eq 'MSWin32' && exists $ENV{'!EXITCODE'} )
      ? 'bash'
    : ( $^O eq 'MSWin32' && $ENV{PROMPT} && $ENV{COMSPEC} )
      ? ($ENV{COMSPEC} =~ /([\w.]+)$/)[-1]
    : ( $^O eq 'MSWin32' && !$ENV{PROMPT} )
      ? 'powershell.exe'
    : 'sh';

  for ($shellbin) {
    return
        /csh$/                   ? 'csh'
      : /fish$/                  ? 'fish'
      : /command(?:\.com)?$/i    ? 'cmd'
      : /cmd(?:\.exe)?$/i        ? 'cmd'
      : /4nt(?:\.exe)?$/i        ? 'cmd'
      : /powershell(?:\.exe)?$/i ? 'powershell'
                                 : 'bourne';
  }
}

1;
__END__



#line 1515

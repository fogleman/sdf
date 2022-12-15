use 5.006;
use strict;
use warnings;
package Capture::Tiny;
# ABSTRACT: Capture STDOUT and STDERR from Perl, XS or external programs
our $VERSION = '0.46';
use Carp ();
use Exporter ();
use IO::Handle ();
use File::Spec ();
use File::Temp qw/tempfile tmpnam/;
use Scalar::Util qw/reftype blessed/;
# Get PerlIO or fake it
BEGIN {
  local $@;
  eval { require PerlIO; PerlIO->can('get_layers') }
    or *PerlIO::get_layers = sub { return () };
}

#--------------------------------------------------------------------------#
# create API subroutines and export them
# [do STDOUT flag, do STDERR flag, do merge flag, do tee flag]
#--------------------------------------------------------------------------#

my %api = (
  capture         => [1,1,0,0],
  capture_stdout  => [1,0,0,0],
  capture_stderr  => [0,1,0,0],
  capture_merged  => [1,1,1,0],
  tee             => [1,1,0,1],
  tee_stdout      => [1,0,0,1],
  tee_stderr      => [0,1,0,1],
  tee_merged      => [1,1,1,1],
);

for my $sub ( keys %api ) {
  my $args = join q{, }, @{$api{$sub}};
  eval "sub $sub(&;@) {unshift \@_, $args; goto \\&_capture_tee;}"; ## no critic
}

our @ISA = qw/Exporter/;
our @EXPORT_OK = keys %api;
our %EXPORT_TAGS = ( 'all' => \@EXPORT_OK );

#--------------------------------------------------------------------------#
# constants and fixtures
#--------------------------------------------------------------------------#

my $IS_WIN32 = $^O eq 'MSWin32';

##our $DEBUG = $ENV{PERL_CAPTURE_TINY_DEBUG};
##
##my $DEBUGFH;
##open $DEBUGFH, "> DEBUG" if $DEBUG;
##
##*_debug = $DEBUG ? sub(@) { print {$DEBUGFH} @_ } : sub(){0};

our $TIMEOUT = 30;

#--------------------------------------------------------------------------#
# command to tee output -- the argument is a filename that must
# be opened to signal that the process is ready to receive input.
# This is annoying, but seems to be the best that can be done
# as a simple, portable IPC technique
#--------------------------------------------------------------------------#
my @cmd = ($^X, '-C0', '-e', <<'HERE');
use Fcntl;
$SIG{HUP}=sub{exit};
if ( my $fn=shift ) {
    sysopen(my $fh, qq{$fn}, O_WRONLY|O_CREAT|O_EXCL) or die $!;
    print {$fh} $$;
    close $fh;
}
my $buf; while (sysread(STDIN, $buf, 2048)) {
    syswrite(STDOUT, $buf); syswrite(STDERR, $buf);
}
HERE

#--------------------------------------------------------------------------#
# filehandle manipulation
#--------------------------------------------------------------------------#

sub _relayer {
  my ($fh, $apply_layers) = @_;
  # _debug("# requested layers (@{$layers}) for @{[fileno $fh]}\n");

  # eliminate pseudo-layers
  binmode( $fh, ":raw" );
  # strip off real layers until only :unix is left
  while ( 1 < ( my $layers =()= PerlIO::get_layers( $fh, output => 1 ) ) ) {
      binmode( $fh, ":pop" );
  }
  # apply other layers
  my @to_apply = @$apply_layers;
  shift @to_apply; # eliminate initial :unix
  # _debug("# applying layers  (unix @to_apply) to @{[fileno $fh]}\n");
  binmode($fh, ":" . join(":",@to_apply));
}

sub _name {
  my $glob = shift;
  no strict 'refs'; ## no critic
  return *{$glob}{NAME};
}

sub _open {
  open $_[0], $_[1] or Carp::confess "Error from open(" . join(q{, }, @_) . "): $!";
  # _debug( "# open " . join( ", " , map { defined $_ ? _name($_) : 'undef' } @_ ) . " as " . fileno( $_[0] ) . "\n" );
}

sub _close {
  # _debug( "# closing " . ( defined $_[0] ? _name($_[0]) : 'undef' )  . " on " . fileno( $_[0] ) . "\n" );
  close $_[0] or Carp::confess "Error from close(" . join(q{, }, @_) . "): $!";
}

my %dup; # cache this so STDIN stays fd0
my %proxy_count;
sub _proxy_std {
  my %proxies;
  if ( ! defined fileno STDIN ) {
    $proxy_count{stdin}++;
    if (defined $dup{stdin}) {
      _open \*STDIN, "<&=" . fileno($dup{stdin});
      # _debug( "# restored proxy STDIN as " . (defined fileno STDIN ? fileno STDIN : 'undef' ) . "\n" );
    }
    else {
      _open \*STDIN, "<" . File::Spec->devnull;
      # _debug( "# proxied STDIN as " . (defined fileno STDIN ? fileno STDIN : 'undef' ) . "\n" );
      _open $dup{stdin} = IO::Handle->new, "<&=STDIN";
    }
    $proxies{stdin} = \*STDIN;
    binmode(STDIN, ':utf8') if $] >= 5.008; ## no critic
  }
  if ( ! defined fileno STDOUT ) {
    $proxy_count{stdout}++;
    if (defined $dup{stdout}) {
      _open \*STDOUT, ">&=" . fileno($dup{stdout});
      # _debug( "# restored proxy STDOUT as " . (defined fileno STDOUT ? fileno STDOUT : 'undef' ) . "\n" );
    }
    else {
      _open \*STDOUT, ">" . File::Spec->devnull;
       # _debug( "# proxied STDOUT as " . (defined fileno STDOUT ? fileno STDOUT : 'undef' ) . "\n" );
      _open $dup{stdout} = IO::Handle->new, ">&=STDOUT";
    }
    $proxies{stdout} = \*STDOUT;
    binmode(STDOUT, ':utf8') if $] >= 5.008; ## no critic
  }
  if ( ! defined fileno STDERR ) {
    $proxy_count{stderr}++;
    if (defined $dup{stderr}) {
      _open \*STDERR, ">&=" . fileno($dup{stderr});
       # _debug( "# restored proxy STDERR as " . (defined fileno STDERR ? fileno STDERR : 'undef' ) . "\n" );
    }
    else {
      _open \*STDERR, ">" . File::Spec->devnull;
       # _debug( "# proxied STDERR as " . (defined fileno STDERR ? fileno STDERR : 'undef' ) . "\n" );
      _open $dup{stderr} = IO::Handle->new, ">&=STDERR";
    }
    $proxies{stderr} = \*STDERR;
    binmode(STDERR, ':utf8') if $] >= 5.008; ## no critic
  }
  return %proxies;
}

sub _unproxy {
  my (%proxies) = @_;
  # _debug( "# unproxying: " . join(" ", keys %proxies) . "\n" );
  for my $p ( keys %proxies ) {
    $proxy_count{$p}--;
    # _debug( "# unproxied " . uc($p) . " ($proxy_count{$p} left)\n" );
    if ( ! $proxy_count{$p} ) {
      _close $proxies{$p};
      _close $dup{$p} unless $] < 5.008; # 5.6 will have already closed this as dup
      delete $dup{$p};
    }
  }
}

sub _copy_std {
  my %handles;
  for my $h ( qw/stdout stderr stdin/ ) {
    next if $h eq 'stdin' && ! $IS_WIN32; # WIN32 hangs on tee without STDIN copied
    my $redir = $h eq 'stdin' ? "<&" : ">&";
    _open $handles{$h} = IO::Handle->new(), $redir . uc($h); # ">&STDOUT" or "<&STDIN"
  }
  return \%handles;
}

# In some cases we open all (prior to forking) and in others we only open
# the output handles (setting up redirection)
sub _open_std {
  my ($handles) = @_;
  _open \*STDIN, "<&" . fileno $handles->{stdin} if defined $handles->{stdin};
  _open \*STDOUT, ">&" . fileno $handles->{stdout} if defined $handles->{stdout};
  _open \*STDERR, ">&" . fileno $handles->{stderr} if defined $handles->{stderr};
}

#--------------------------------------------------------------------------#
# private subs
#--------------------------------------------------------------------------#

sub _start_tee {
  my ($which, $stash) = @_; # $which is "stdout" or "stderr"
  # setup pipes
  $stash->{$_}{$which} = IO::Handle->new for qw/tee reader/;
  pipe $stash->{reader}{$which}, $stash->{tee}{$which};
  # _debug( "# pipe for $which\: " .  _name($stash->{tee}{$which}) . " " . fileno( $stash->{tee}{$which} ) . " => " . _name($stash->{reader}{$which}) . " " . fileno( $stash->{reader}{$which}) . "\n" );
  select((select($stash->{tee}{$which}), $|=1)[0]); # autoflush
  # setup desired redirection for parent and child
  $stash->{new}{$which} = $stash->{tee}{$which};
  $stash->{child}{$which} = {
    stdin   => $stash->{reader}{$which},
    stdout  => $stash->{old}{$which},
    stderr  => $stash->{capture}{$which},
  };
  # flag file is used to signal the child is ready
  $stash->{flag_files}{$which} = scalar tmpnam();
  # execute @cmd as a separate process
  if ( $IS_WIN32 ) {
    my $old_eval_err=$@;
    undef $@;

    eval "use Win32API::File qw/GetOsFHandle SetHandleInformation fileLastError HANDLE_FLAG_INHERIT INVALID_HANDLE_VALUE/ ";
    # _debug( "# Win32API::File loaded\n") unless $@;
    my $os_fhandle = GetOsFHandle( $stash->{tee}{$which} );
    # _debug( "# Couldn't get OS handle: " . fileLastError() . "\n") if ! defined $os_fhandle || $os_fhandle == INVALID_HANDLE_VALUE();
    my $result = SetHandleInformation( $os_fhandle, HANDLE_FLAG_INHERIT(), 0);
    # _debug( $result ? "# set no-inherit flag on $which tee\n" : ("# can't disable tee handle flag inherit: " . fileLastError() . "\n"));
    _open_std( $stash->{child}{$which} );
    $stash->{pid}{$which} = system(1, @cmd, $stash->{flag_files}{$which});
    # not restoring std here as it all gets redirected again shortly anyway
    $@=$old_eval_err;
  }
  else { # use fork
    _fork_exec( $which, $stash );
  }
}

sub _fork_exec {
  my ($which, $stash) = @_; # $which is "stdout" or "stderr"
  my $pid = fork;
  if ( not defined $pid ) {
    Carp::confess "Couldn't fork(): $!";
  }
  elsif ($pid == 0) { # child
    # _debug( "# in child process ...\n" );
    untie *STDIN; untie *STDOUT; untie *STDERR;
    _close $stash->{tee}{$which};
    # _debug( "# redirecting handles in child ...\n" );
    _open_std( $stash->{child}{$which} );
    # _debug( "# calling exec on command ...\n" );
    exec @cmd, $stash->{flag_files}{$which};
  }
  $stash->{pid}{$which} = $pid
}

my $have_usleep = eval "use Time::HiRes 'usleep'; 1";
sub _files_exist {
  return 1 if @_ == grep { -f } @_;
  Time::HiRes::usleep(1000) if $have_usleep;
  return 0;
}

sub _wait_for_tees {
  my ($stash) = @_;
  my $start = time;
  my @files = values %{$stash->{flag_files}};
  my $timeout = defined $ENV{PERL_CAPTURE_TINY_TIMEOUT}
              ? $ENV{PERL_CAPTURE_TINY_TIMEOUT} : $TIMEOUT;
  1 until _files_exist(@files) || ($timeout && (time - $start > $timeout));
  Carp::confess "Timed out waiting for subprocesses to start" if ! _files_exist(@files);
  unlink $_ for @files;
}

sub _kill_tees {
  my ($stash) = @_;
  if ( $IS_WIN32 ) {
    # _debug( "# closing handles\n");
    close($_) for values %{ $stash->{tee} };
    # _debug( "# waiting for subprocesses to finish\n");
    my $start = time;
    1 until wait == -1 || (time - $start > 30);
  }
  else {
    _close $_ for values %{ $stash->{tee} };
    waitpid $_, 0 for values %{ $stash->{pid} };
  }
}

sub _slurp {
  my ($name, $stash) = @_;
  my ($fh, $pos) = map { $stash->{$_}{$name} } qw/capture pos/;
  # _debug( "# slurping captured $name from " . fileno($fh) . " at pos $pos with layers: @{[PerlIO::get_layers($fh)]}\n");
  seek( $fh, $pos, 0 ) or die "Couldn't seek on capture handle for $name\n";
  my $text = do { local $/; scalar readline $fh };
  return defined($text) ? $text : "";
}

#--------------------------------------------------------------------------#
# _capture_tee() -- generic main sub for capturing or teeing
#--------------------------------------------------------------------------#

sub _capture_tee {
  # _debug( "# starting _capture_tee with (@_)...\n" );
  my ($do_stdout, $do_stderr, $do_merge, $do_tee, $code, @opts) = @_;
  my %do = ($do_stdout ? (stdout => 1) : (),  $do_stderr ? (stderr => 1) : ());
  Carp::confess("Custom capture options must be given as key/value pairs\n")
    unless @opts % 2 == 0;
  my $stash = { capture => { @opts } };
  for ( keys %{$stash->{capture}} ) {
    my $fh = $stash->{capture}{$_};
    Carp::confess "Custom handle for $_ must be seekable\n"
      unless ref($fh) eq 'GLOB' || (blessed($fh) && $fh->isa("IO::Seekable"));
  }
  # save existing filehandles and setup captures
  local *CT_ORIG_STDIN  = *STDIN ;
  local *CT_ORIG_STDOUT = *STDOUT;
  local *CT_ORIG_STDERR = *STDERR;
  # find initial layers
  my %layers = (
    stdin   => [PerlIO::get_layers(\*STDIN) ],
    stdout  => [PerlIO::get_layers(\*STDOUT, output => 1)],
    stderr  => [PerlIO::get_layers(\*STDERR, output => 1)],
  );
  # _debug( "# existing layers for $_\: @{$layers{$_}}\n" ) for qw/stdin stdout stderr/;
  # get layers from underlying glob of tied filehandles if we can
  # (this only works for things that work like Tie::StdHandle)
  $layers{stdout} = [PerlIO::get_layers(tied *STDOUT)]
    if tied(*STDOUT) && (reftype tied *STDOUT eq 'GLOB');
  $layers{stderr} = [PerlIO::get_layers(tied *STDERR)]
    if tied(*STDERR) && (reftype tied *STDERR eq 'GLOB');
  # _debug( "# tied object corrected layers for $_\: @{$layers{$_}}\n" ) for qw/stdin stdout stderr/;
  # bypass scalar filehandles and tied handles
  # localize scalar STDIN to get a proxy to pick up FD0, then restore later to CT_ORIG_STDIN
  my %localize;
  $localize{stdin}++,  local(*STDIN)
    if grep { $_ eq 'scalar' } @{$layers{stdin}};
  $localize{stdout}++, local(*STDOUT)
    if $do_stdout && grep { $_ eq 'scalar' } @{$layers{stdout}};
  $localize{stderr}++, local(*STDERR)
    if ($do_stderr || $do_merge) && grep { $_ eq 'scalar' } @{$layers{stderr}};
  $localize{stdin}++, local(*STDIN), _open( \*STDIN, "<&=0")
    if tied *STDIN && $] >= 5.008;
  $localize{stdout}++, local(*STDOUT), _open( \*STDOUT, ">&=1")
    if $do_stdout && tied *STDOUT && $] >= 5.008;
  $localize{stderr}++, local(*STDERR), _open( \*STDERR, ">&=2")
    if ($do_stderr || $do_merge) && tied *STDERR && $] >= 5.008;
  # _debug( "# localized $_\n" ) for keys %localize;
  # proxy any closed/localized handles so we don't use fds 0, 1 or 2
  my %proxy_std = _proxy_std();
  # _debug( "# proxy std: @{ [%proxy_std] }\n" );
  # update layers after any proxying
  $layers{stdout} = [PerlIO::get_layers(\*STDOUT, output => 1)] if $proxy_std{stdout};
  $layers{stderr} = [PerlIO::get_layers(\*STDERR, output => 1)] if $proxy_std{stderr};
  # _debug( "# post-proxy layers for $_\: @{$layers{$_}}\n" ) for qw/stdin stdout stderr/;
  # store old handles and setup handles for capture
  $stash->{old} = _copy_std();
  $stash->{new} = { %{$stash->{old}} }; # default to originals
  for ( keys %do ) {
    $stash->{new}{$_} = ($stash->{capture}{$_} ||= File::Temp->new);
    seek( $stash->{capture}{$_}, 0, 2 ) or die "Could not seek on capture handle for $_\n";
    $stash->{pos}{$_} = tell $stash->{capture}{$_};
    # _debug("# will capture $_ on " . fileno($stash->{capture}{$_})."\n" );
    _start_tee( $_ => $stash ) if $do_tee; # tees may change $stash->{new}
  }
  _wait_for_tees( $stash ) if $do_tee;
  # finalize redirection
  $stash->{new}{stderr} = $stash->{new}{stdout} if $do_merge;
  # _debug( "# redirecting in parent ...\n" );
  _open_std( $stash->{new} );
  # execute user provided code
  my ($exit_code, $inner_error, $outer_error, $orig_pid, @result);
  {
    $orig_pid = $$;
    local *STDIN = *CT_ORIG_STDIN if $localize{stdin}; # get original, not proxy STDIN
    # _debug( "# finalizing layers ...\n" );
    _relayer(\*STDOUT, $layers{stdout}) if $do_stdout;
    _relayer(\*STDERR, $layers{stderr}) if $do_stderr;
    # _debug( "# running code $code ...\n" );
    my $old_eval_err=$@;
    undef $@;
    eval { @result = $code->(); $inner_error = $@ };
    $exit_code = $?; # save this for later
    $outer_error = $@; # save this for later
    STDOUT->flush if $do_stdout;
    STDERR->flush if $do_stderr;
    $@ = $old_eval_err;
  }
  # restore prior filehandles and shut down tees
  # _debug( "# restoring filehandles ...\n" );
  _open_std( $stash->{old} );
  _close( $_ ) for values %{$stash->{old}}; # don't leak fds
  # shouldn't need relayering originals, but see rt.perl.org #114404
  _relayer(\*STDOUT, $layers{stdout}) if $do_stdout;
  _relayer(\*STDERR, $layers{stderr}) if $do_stderr;
  _unproxy( %proxy_std );
  # _debug( "# killing tee subprocesses ...\n" ) if $do_tee;
  _kill_tees( $stash ) if $do_tee;
  # return captured output, but shortcut in void context
  # unless we have to echo output to tied/scalar handles;
  my %got;
  if ( $orig_pid == $$ and ( defined wantarray or ($do_tee && keys %localize) ) ) {
    for ( keys %do ) {
      _relayer($stash->{capture}{$_}, $layers{$_});
      $got{$_} = _slurp($_, $stash);
      # _debug("# slurped " . length($got{$_}) . " bytes from $_\n");
    }
    print CT_ORIG_STDOUT $got{stdout}
      if $do_stdout && $do_tee && $localize{stdout};
    print CT_ORIG_STDERR $got{stderr}
      if $do_stderr && $do_tee && $localize{stderr};
  }
  $? = $exit_code;
  $@ = $inner_error if $inner_error;
  die $outer_error if $outer_error;
  # _debug( "# ending _capture_tee with (@_)...\n" );
  return unless defined wantarray;
  my @return;
  push @return, $got{stdout} if $do_stdout;
  push @return, $got{stderr} if $do_stderr && ! $do_merge;
  push @return, @result;
  return wantarray ? @return : $return[0];
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Capture::Tiny - Capture STDOUT and STDERR from Perl, XS or external programs

=head1 VERSION

version 0.46

=head1 SYNOPSIS

  use Capture::Tiny ':all';

  # capture from external command

  ($stdout, $stderr, $exit) = capture {
    system( $cmd, @args );
  };

  # capture from arbitrary code (Perl or external)

  ($stdout, $stderr, @result) = capture {
    # your code here
  };

  # capture partial or merged output

  $stdout = capture_stdout { ... };
  $stderr = capture_stderr { ... };
  $merged = capture_merged { ... };

  # tee output

  ($stdout, $stderr) = tee {
    # your code here
  };

  $stdout = tee_stdout { ... };
  $stderr = tee_stderr { ... };
  $merged = tee_merged { ... };

=head1 DESCRIPTION

Capture::Tiny provides a simple, portable way to capture almost anything sent
to STDOUT or STDERR, regardless of whether it comes from Perl, from XS code or
from an external program.  Optionally, output can be teed so that it is
captured while being passed through to the original filehandles.  Yes, it even
works on Windows (usually).  Stop guessing which of a dozen capturing modules
to use in any particular situation and just use this one.

=head1 USAGE

The following functions are available.  None are exported by default.

=head2 capture

  ($stdout, $stderr, @result) = capture \&code;
  $stdout = capture \&code;

The C<capture> function takes a code reference and returns what is sent to
STDOUT and STDERR as well as any return values from the code reference.  In
scalar context, it returns only STDOUT.  If no output was received for a
filehandle, it returns an empty string for that filehandle.  Regardless of calling
context, all output is captured -- nothing is passed to the existing filehandles.

It is prototyped to take a subroutine reference as an argument. Thus, it
can be called in block form:

  ($stdout, $stderr) = capture {
    # your code here ...
  };

Note that the coderef is evaluated in list context.  If you wish to force
scalar context on the return value, you must use the C<scalar> keyword.

  ($stdout, $stderr, $count) = capture {
    my @list = qw/one two three/;
    return scalar @list; # $count will be 3
  };

Also note that within the coderef, the C<@_> variable will be empty.  So don't
use arguments from a surrounding subroutine without copying them to an array
first:

  sub wont_work {
    my ($stdout, $stderr) = capture { do_stuff( @_ ) };    # WRONG
    ...
  }

  sub will_work {
    my @args = @_;
    my ($stdout, $stderr) = capture { do_stuff( @args ) }; # RIGHT
    ...
  }

Captures are normally done to an anonymous temporary filehandle.  To
capture via a named file (e.g. to externally monitor a long-running capture),
provide custom filehandles as a trailing list of option pairs:

  my $out_fh = IO::File->new("out.txt", "w+");
  my $err_fh = IO::File->new("out.txt", "w+");
  capture { ... } stdout => $out_fh, stderr => $err_fh;

The filehandles must be read/write and seekable.  Modifying the files or
filehandles during a capture operation will give unpredictable results.
Existing IO layers on them may be changed by the capture.

When called in void context, C<capture> saves memory and time by
not reading back from the capture handles.

=head2 capture_stdout

  ($stdout, @result) = capture_stdout \&code;
  $stdout = capture_stdout \&code;

The C<capture_stdout> function works just like C<capture> except only
STDOUT is captured.  STDERR is not captured.

=head2 capture_stderr

  ($stderr, @result) = capture_stderr \&code;
  $stderr = capture_stderr \&code;

The C<capture_stderr> function works just like C<capture> except only
STDERR is captured.  STDOUT is not captured.

=head2 capture_merged

  ($merged, @result) = capture_merged \&code;
  $merged = capture_merged \&code;

The C<capture_merged> function works just like C<capture> except STDOUT and
STDERR are merged. (Technically, STDERR is redirected to the same capturing
handle as STDOUT before executing the function.)

Caution: STDOUT and STDERR output in the merged result are not guaranteed to be
properly ordered due to buffering.

=head2 tee

  ($stdout, $stderr, @result) = tee \&code;
  $stdout = tee \&code;

The C<tee> function works just like C<capture>, except that output is captured
as well as passed on to the original STDOUT and STDERR.

When called in void context, C<tee> saves memory and time by
not reading back from the capture handles, except when the
original STDOUT OR STDERR were tied or opened to a scalar
handle.

=head2 tee_stdout

  ($stdout, @result) = tee_stdout \&code;
  $stdout = tee_stdout \&code;

The C<tee_stdout> function works just like C<tee> except only
STDOUT is teed.  STDERR is not teed (output goes to STDERR as usual).

=head2 tee_stderr

  ($stderr, @result) = tee_stderr \&code;
  $stderr = tee_stderr \&code;

The C<tee_stderr> function works just like C<tee> except only
STDERR is teed.  STDOUT is not teed (output goes to STDOUT as usual).

=head2 tee_merged

  ($merged, @result) = tee_merged \&code;
  $merged = tee_merged \&code;

The C<tee_merged> function works just like C<capture_merged> except that output
is captured as well as passed on to STDOUT.

Caution: STDOUT and STDERR output in the merged result are not guaranteed to be
properly ordered due to buffering.

=head1 LIMITATIONS

=head2 Portability

Portability is a goal, not a guarantee.  C<tee> requires fork, except on
Windows where C<system(1, @cmd)> is used instead.  Not tested on any
particularly esoteric platforms yet.  See the
L<CPAN Testers Matrix|http://matrix.cpantesters.org/?dist=Capture-Tiny>
for test result by platform.

=head2 PerlIO layers

Capture::Tiny does its best to preserve PerlIO layers such as ':utf8' or
':crlf' when capturing (only for Perl 5.8.1+) .  Layers should be applied to
STDOUT or STDERR I<before> the call to C<capture> or C<tee>.  This may not work
for tied filehandles (see below).

=head2 Modifying filehandles before capturing

Generally speaking, you should do little or no manipulation of the standard IO
filehandles prior to using Capture::Tiny.  In particular, closing, reopening,
localizing or tying standard filehandles prior to capture may cause a variety of
unexpected, undesirable and/or unreliable behaviors, as described below.
Capture::Tiny does its best to compensate for these situations, but the
results may not be what you desire.

=head3 Closed filehandles

Capture::Tiny will work even if STDIN, STDOUT or STDERR have been previously
closed.  However, since they will be reopened to capture or tee output, any
code within the captured block that depends on finding them closed will, of
course, not find them to be closed.  If they started closed, Capture::Tiny will
close them again when the capture block finishes.

Note that this reopening will happen even for STDIN or a filehandle not being
captured to ensure that the filehandle used for capture is not opened to file
descriptor 0, as this causes problems on various platforms.

Prior to Perl 5.12, closed STDIN combined with PERL_UNICODE=D leaks filehandles
and also breaks tee() for undiagnosed reasons.  So don't do that.

=head3 Localized filehandles

If code localizes any of Perl's standard filehandles before capturing, the capture
will affect the localized filehandles and not the original ones.  External system
calls are not affected by localizing a filehandle in Perl and will continue
to send output to the original filehandles (which will thus not be captured).

=head3 Scalar filehandles

If STDOUT or STDERR are reopened to scalar filehandles prior to the call to
C<capture> or C<tee>, then Capture::Tiny will override the output filehandle for
the duration of the C<capture> or C<tee> call and then, for C<tee>, send captured
output to the output filehandle after the capture is complete.  (Requires Perl
5.8)

Capture::Tiny attempts to preserve the semantics of STDIN opened to a scalar
reference, but note that external processes will not be able to read from such
a handle.  Capture::Tiny tries to ensure that external processes will read from
the null device instead, but this is not guaranteed.

=head3 Tied output filehandles

If STDOUT or STDERR are tied prior to the call to C<capture> or C<tee>, then
Capture::Tiny will attempt to override the tie for the duration of the
C<capture> or C<tee> call and then send captured output to the tied filehandle after
the capture is complete.  (Requires Perl 5.8)

Capture::Tiny may not succeed resending UTF-8 encoded data to a tied
STDOUT or STDERR filehandle.  Characters may appear as bytes.  If the tied filehandle
is based on L<Tie::StdHandle>, then Capture::Tiny will attempt to determine
appropriate layers like C<:utf8> from the underlying filehandle and do the right
thing.

=head3 Tied input filehandle

Capture::Tiny attempts to preserve the semantics of tied STDIN, but this
requires Perl 5.8 and is not entirely predictable.  External processes
will not be able to read from such a handle.

Unless having STDIN tied is crucial, it may be safest to localize STDIN when
capturing:

  my ($out, $err) = do { local *STDIN; capture { ... } };

=head2 Modifying filehandles during a capture

Attempting to modify STDIN, STDOUT or STDERR I<during> C<capture> or C<tee> is
almost certainly going to cause problems.  Don't do that.

=head3 Forking inside a capture

Forks aren't portable.  The behavior of filehandles during a fork is even
less so.  If Capture::Tiny detects that a fork has occurred within a
capture, it will shortcut in the child process and return empty strings for
captures.  Other problems may occur in the child or parent, as well.
Forking in a capture block is not recommended.

=head3 Using threads

Filehandles are global.  Mixing up I/O and captures in different threads
without coordination is going to cause problems.  Besides, threads are
officially discouraged.

=head3 Dropping privileges during a capture

If you drop privileges during a capture, temporary files created to
facilitate the capture may not be cleaned up afterwards.

=head2 No support for Perl 5.8.0

It's just too buggy when it comes to layers and UTF-8.  Perl 5.8.1 or later
is recommended.

=head2 Limited support for Perl 5.6

Perl 5.6 predates PerlIO.  UTF-8 data may not be captured correctly.

=head1 ENVIRONMENT

=head2 PERL_CAPTURE_TINY_TIMEOUT

Capture::Tiny uses subprocesses internally for C<tee>.  By default,
Capture::Tiny will timeout with an error if such subprocesses are not ready to
receive data within 30 seconds (or whatever is the value of
C<$Capture::Tiny::TIMEOUT>).  An alternate timeout may be specified by setting
the C<PERL_CAPTURE_TINY_TIMEOUT> environment variable.  Setting it to zero will
disable timeouts.  B<NOTE>, this does not timeout the code reference being
captured -- this only prevents Capture::Tiny itself from hanging your process
waiting for its child processes to be ready to proceed.

=head1 SEE ALSO

This module was inspired by L<IO::CaptureOutput>, which provides
similar functionality without the ability to tee output and with more
complicated code and API.  L<IO::CaptureOutput> does not handle layers
or most of the unusual cases described in the L</Limitations> section and
I no longer recommend it.

There are many other CPAN modules that provide some sort of output capture,
albeit with various limitations that make them appropriate only in particular
circumstances.  I'm probably missing some.  The long list is provided to show
why I felt Capture::Tiny was necessary.

=over 4

=item *

L<IO::Capture>

=item *

L<IO::Capture::Extended>

=item *

L<IO::CaptureOutput>

=item *

L<IPC::Capture>

=item *

L<IPC::Cmd>

=item *

L<IPC::Open2>

=item *

L<IPC::Open3>

=item *

L<IPC::Open3::Simple>

=item *

L<IPC::Open3::Utils>

=item *

L<IPC::Run>

=item *

L<IPC::Run::SafeHandles>

=item *

L<IPC::Run::Simple>

=item *

L<IPC::Run3>

=item *

L<IPC::System::Simple>

=item *

L<Tee>

=item *

L<IO::Tee>

=item *

L<File::Tee>

=item *

L<Filter::Handle>

=item *

L<Tie::STDERR>

=item *

L<Tie::STDOUT>

=item *

L<Test::Output>

=back

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/dagolden/Capture-Tiny/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/dagolden/Capture-Tiny>

  git clone https://github.com/dagolden/Capture-Tiny.git

=head1 AUTHOR

David Golden <dagolden@cpan.org>

=head1 CONTRIBUTORS

=for stopwords Dagfinn Ilmari Mannsåker David E. Wheeler fecundf Graham Knop Peter Rabbitson

=over 4

=item *

Dagfinn Ilmari Mannsåker <ilmari@ilmari.org>

=item *

David E. Wheeler <david@justatheory.com>

=item *

fecundf <not.com+github@gmail.com>

=item *

Graham Knop <haarg@haarg.org>

=item *

Peter Rabbitson <ribasushi@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is Copyright (c) 2009 by David Golden.

This is free software, licensed under:

  The Apache License, Version 2.0, January 2004

=cut

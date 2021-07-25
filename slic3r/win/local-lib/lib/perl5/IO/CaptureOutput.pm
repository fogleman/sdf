use strict;
use warnings;

package IO::CaptureOutput;
# ABSTRACT: capture STDOUT and STDERR from Perl code, subprocesses or XS

our $VERSION = '1.1104';

use vars qw/@ISA @EXPORT_OK %EXPORT_TAGS $CarpLevel/;
use Exporter;
use Carp qw/croak/;
@ISA = 'Exporter';
@EXPORT_OK = qw/capture capture_exec qxx capture_exec_combined qxy/;
%EXPORT_TAGS = (all => \@EXPORT_OK);
$CarpLevel = 0; # help capture report errors at the right level

sub _capture (&@) { ## no critic
    my ($code, $output, $error, $output_file, $error_file) = @_;

    # check for valid combinations of input
    {
      local $Carp::CarpLevel = 1;
      my $error = _validate($output, $error, $output_file, $error_file);
      croak $error if $error;
    }

    # if either $output or $error are defined, then we need a variable for
    # results; otherwise we only capture to files and don't waste memory
    if ( defined $output || defined $error ) {
      for ($output, $error) {
          $_ = \do { my $s; $s = ''} unless ref $_;
          $$_ = '' if $_ != \undef && !defined($$_);
      }
    }

    # merge if same refs for $output and $error or if both are undef --
    # i.e. capture \&foo, undef, undef, $merged_file
    # this means capturing into separate files *requires* at least one
    # capture variable
    my $should_merge =
      (defined $error && defined $output && $output == $error) ||
      ( !defined $output && !defined $error ) ||
      0;

    my ($capture_out, $capture_err);

    # undef means capture anonymously; anything other than \undef means
    # capture to that ref; \undef means skip capture
    if ( !defined $output || $output != \undef ) {
        $capture_out = IO::CaptureOutput::_proxy->new(
            'STDOUT', $output, undef, $output_file
        );
    }
    if ( !defined $error || $error != \undef ) {
        $capture_err = IO::CaptureOutput::_proxy->new(
            'STDERR', $error, ($should_merge ? 'STDOUT' : undef), $error_file
        );
    }

    # now that output capture is setup, call the subroutine
    # results get read when IO::CaptureOutput::_proxy objects go out of scope
    &$code();
}

# Extra indirection for symmetry with capture_exec, etc.  Gets error reporting
# to the right level
sub capture (&@) { ## no critic
    return &_capture;
}

sub capture_exec {
    my @args = @_;
    my ($output, $error);
    my $exit = _capture sub { system _shell_quote(@args) }, \$output, \$error;
    my $success = ($exit == 0 ) ? 1 : 0 ;
    $? = $exit;
    return wantarray ? ($output, $error, $success, $exit) : $output;
}

*qxx = \&capture_exec;

sub capture_exec_combined {
    my @args = @_;
    my $output;
    my $exit = _capture sub { system _shell_quote(@args) }, \$output, \$output;
    my $success = ($exit == 0 ) ? 1 : 0 ;
    $? = $exit;
    return wantarray ? ($output, $success, $exit) : $output;
}

*qxy = \&capture_exec_combined;

# extra quoting required on Win32 systems
*_shell_quote = ($^O =~ /MSWin32/) ? \&_shell_quote_win32 : sub {@_};
sub _shell_quote_win32 {
    my @args;
    for (@_) {
        if (/[ \"]/) { # TODO: check if ^ requires escaping
            (my $escaped = $_) =~ s/([\"])/\\$1/g;
            push @args, '"' . $escaped . '"';
            next;
        }
        push @args, $_
    }
    return @args;
}

# detect errors and return an error message or empty string;
sub _validate {
    my ($output, $error, $output_file, $error_file) = @_;

    # default to "ok"
    my $msg = q{};

    # \$out, \$out, $outfile, $errfile
    if (    defined $output && defined $error
        &&  defined $output_file && defined $error_file
        &&  $output == $error
        &&  $output != \undef
        &&  $output_file ne $error_file
    ) {
      $msg = "Merged STDOUT and STDERR, but specified different output and error files";
    }
    # undef, undef, $outfile, $errfile
    elsif ( !defined $output && !defined $error
        &&  defined $output_file && defined $error_file
        &&  $output_file ne $error_file
    ) {
      $msg = "Merged STDOUT and STDERR, but specified different output and error files";
    }

    return $msg;
}

# Captures everything printed to a filehandle for the lifetime of the object
# and then transfers it to a scalar reference
package IO::CaptureOutput::_proxy;
use File::Temp 0.16 'tempfile';
use File::Basename qw/basename/;
use Symbol qw/gensym qualify qualify_to_ref/;
use Carp;

sub _is_wperl { $^O eq 'MSWin32' && basename($^X) eq 'wperl.exe' }

sub new {
    my $class = shift;
    my ($orig_fh, $capture_var, $merge_fh, $capture_file) = @_;
    $orig_fh       = qualify($orig_fh);         # e.g. main::STDOUT
    my $fhref = qualify_to_ref($orig_fh);  # e.g. \*STDOUT

    # Duplicate the filehandle
    my $saved_fh;
    {
        no strict 'refs'; ## no critic - needed for 5.005
        if ( defined fileno($orig_fh) && ! _is_wperl() ) {
            $saved_fh = gensym;
            open $saved_fh, ">&$orig_fh" or croak "Can't redirect <$orig_fh> - $!";
        }
    }

    # Create replacement filehandle if not merging
    my ($newio_fh, $newio_file);
    if ( ! $merge_fh ) {
        $newio_fh = gensym;
        if ($capture_file) {
            $newio_file = $capture_file;
        } else {
            (undef, $newio_file) = tempfile;
        }
        open $newio_fh, "+>$newio_file" or croak "Can't write temp file for $orig_fh - $!";
    }
    else {
        $newio_fh = qualify($merge_fh);
    }

    # Redirect (or merge)
    {
        no strict 'refs'; ## no critic -- needed for 5.005
        open $fhref, ">&".fileno($newio_fh) or croak "Can't redirect $orig_fh - $!";
    }

    bless [$$, $orig_fh, $saved_fh, $capture_var, $newio_fh, $newio_file, $capture_file], $class;
}

sub DESTROY {
    my $self = shift;

    my ($pid, $orig_fh, $saved_fh, $capture_var, $newio_fh,
      $newio_file, $capture_file) = @$self;
    return unless $pid eq $$; # only cleanup in the process that is capturing

    # restore the original filehandle
    my $fh_ref = Symbol::qualify_to_ref($orig_fh);
    select((select ($fh_ref), $|=1)[0]);
    if (defined $saved_fh) {
        open $fh_ref, ">&". fileno($saved_fh) or croak "Can't restore $orig_fh - $!";
    }
    else {
        close $fh_ref;
    }

    # transfer captured data to the scalar reference if we didn't merge
    # $newio_file is undef if this file handle is merged to another
    if (ref $capture_var && $newio_file) {
        # some versions of perl complain about reading from fd 1 or 2
        # which could happen if STDOUT and STDERR were closed when $newio
        # was opened, so we just squelch warnings here and continue
        local $^W;
        seek $newio_fh, 0, 0;
        $$capture_var = do {local $/; <$newio_fh>};
    }
    close $newio_fh if $newio_file;

    # Cleanup
    return unless defined $newio_file && -e $newio_file;
    return if $capture_file; # the "temp" file was explicitly named
    unlink $newio_file or carp "Couldn't remove temp file '$newio_file' - $!";
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

IO::CaptureOutput - capture STDOUT and STDERR from Perl code, subprocesses or XS

=head1 VERSION

version 1.1104

=head1 SYNOPSIS

    use IO::CaptureOutput qw(capture qxx qxy);

    # STDOUT and STDERR separately
    capture { noisy_sub(@args) } \$stdout, \$stderr;

    # STDOUT and STDERR together
    capture { noisy_sub(@args) } \$combined, \$combined;

    # STDOUT and STDERR from external command
    ($stdout, $stderr, $success) = qxx( @cmd );

    # STDOUT and STDERR together from external command
    ($combined, $success) = qxy( @cmd );

=head1 DESCRIPTION

B<This module is no longer recommended by the maintainer> - see
L<Capture::Tiny> instead.

This module provides routines for capturing STDOUT and STDERR from perl
subroutines, forked system calls (e.g. C<system()>, C<fork()>) and from XS
or C modules.

=head1 NAME

=head1 FUNCTIONS

The following functions will be exported on demand.

=head2 capture()

    capture \&subroutine, \$stdout, \$stderr;

Captures everything printed to C<STDOUT> and C<STDERR> for the duration of
C<&subroutine>. C<$stdout> and C<$stderr> are optional scalars that will
contain C<STDOUT> and C<STDERR> respectively.

C<capture()> uses a code prototype so the first argument can be specified
directly within brackets if desired.

    # shorthand with prototype
    capture C< print __PACKAGE__ > \$stdout, \$stderr;

Returns the return value(s) of C<&subroutine>. The sub is called in the
same context as C<capture()> was called e.g.:

    @rv = capture C< wantarray > ; # returns true
    $rv = capture C< wantarray > ; # returns defined, but not true
    capture C< wantarray >;       # void, returns undef

C<capture()> is able to capture output from subprocesses and C code, which
traditional C<tie()> methods of output capture are unable to do.

B<Note:> C<capture()> will only capture output that has been written or
flushed to the filehandle.

If the two scalar references refer to the same scalar, then C<STDERR> will
be merged to C<STDOUT> before capturing and the scalar will hold the
combined output of both.

    capture \&subroutine, \$combined, \$combined;

Normally, C<capture()> uses anonymous, temporary files for capturing
output.  If desired, specific file names may be provided instead as
additional options.

    capture \&subroutine, \$stdout, \$stderr, $out_file, $err_file;

Files provided will be clobbered, overwriting any previous data, but will
persist after the call to C<capture()> for inspection or other
manipulation.

By default, when no references are provided to hold STDOUT or STDERR,
output is captured and silently discarded.

    # Capture STDOUT, discard STDERR
    capture \&subroutine, \$stdout;

    # Discard STDOUT, capture STDERR
    capture \&subroutine, undef, \$stderr;

However, even when using C<undef>, output can be captured to specific
files.

    # Capture STDOUT to a specific file, discard STDERR
    capture \&subroutine, \$stdout, undef, $outfile;

    # Discard STDOUT, capture STDERR to a specific file
    capture \&subroutine, undef, \$stderr, undef, $err_file;

    # Discard both, capture merged output to a specific file
    capture \&subroutine, undef, undef, $mergedfile;

It is a fatal error to merge STDOUT and STDERR and request separate,
specific files for capture.

    # ERROR:
    capture \&subroutine, \$stdout, \$stdout, $out_file, $err_file;
    capture \&subroutine, undef, undef, $out_file, $err_file;

If either STDOUT or STDERR should be passed through to the terminal instead
of captured, provide a reference to undef -- C<\undef> -- instead of a
capture variable.

    # Capture STDOUT, display STDERR
    capture \&subroutine, \$stdout, \undef;

    # Display STDOUT, capture STDERR
    capture \&subroutine, \undef, \$stderr;

=head2 capture_exec()

    ($stdout, $stderr, $success, $exit_code) = capture_exec(@args);

Captures and returns the output from C<system(@args)>. In scalar context,
C<capture_exec()> will return what was printed to C<STDOUT>. In list
context, it returns what was printed to C<STDOUT> and C<STDERR> as well as
a success flag and the exit value.

    $stdout = capture_exec('perl', '-e', 'print "hello world"');

    ($stdout, $stderr, $success, $exit_code) =
        capture_exec('perl', '-e', 'warn "Test"');

C<capture_exec> passes its arguments to C<system()> and on MSWin32 will
protect arguments with shell quotes if necessary.  This makes it a handy
and slightly more portable alternative to backticks, piped C<open()> and
C<IPC::Open3>.

The C<$success> flag returned will be true if the command ran successfully
and false if it did not (if the command could not be run or if it ran and
returned a non-zero exit value).  On failure, the raw exit value of the
C<system()> call is available both in the C<$exit_code> returned and in the
C<$?> variable.

  ($stdout, $stderr, $success, $exit_code) =
      capture_exec('perl', '-e', 'warn "Test" and exit 1');

  if ( ! $success ) {
      print "The exit code was " . ($exit_code >> 8) . "\n";
  }

See L<perlvar> for more information on interpreting a child process exit
code.

=head2 capture_exec_combined()

    ($combined, $success, $exit_code) = capture_exec_combined(
        'perl', '-e', 'print "hello\n"', 'warn "Test\n"
    );

This is just like C<capture_exec()>, except that it merges C<STDERR> with
C<STDOUT> before capturing output.

B<Note:> there is no guarantee that text printed to C<STDOUT> and C<STDERR>
in the subprocess will be appear in order. The actual order will depend on
how IO buffering is handled in the subprocess.

=head2 qxx()

This is an alias for C<capture_exec()>.

=head2 qxy()

This is an alias for C<capture_exec_combined()>.

=head1 SEE ALSO

=over 4

=item *

L<Capture::Tiny>

=item *

L<IPC::Open3>

=item *

L<IO::Capture>

=item *

L<IO::Utils>

=item *

L<IPC::System::Simple>

=back

=for :stopwords cpan testmatrix url annocpan anno bugtracker rt cpants kwalitee diff irc mailto metadata placeholders metacpan

=head1 SUPPORT

=head2 Bugs / Feature Requests

Please report any bugs or feature requests through the issue tracker
at L<https://github.com/dagolden/IO-CaptureOutput/issues>.
You will be notified automatically of any progress on your issue.

=head2 Source Code

This is open source software.  The code repository is available for
public review and contribution under the terms of the license.

L<https://github.com/dagolden/IO-CaptureOutput>

  git clone https://github.com/dagolden/IO-CaptureOutput.git

=head1 AUTHORS

=over 4

=item *

Simon Flack <simonflk@cpan.org>

=item *

David Golden <dagolden@cpan.org>

=back

=head1 CONTRIBUTORS

=for stopwords Mike Latimer Olivier Mengué Tony Cook

=over 4

=item *

Mike Latimer <mlatimer@suse.com>

=item *

Olivier Mengué <dolmen@cpan.org>

=item *

Tony Cook <tony@develop-help.com>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2015 by Simon Flack and David Golden.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

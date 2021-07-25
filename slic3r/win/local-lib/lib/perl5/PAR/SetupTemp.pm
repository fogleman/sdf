package PAR::SetupTemp;
$PAR::SetupTemp::VERSION = '1.002';

use 5.006;
use strict;
use warnings;

use Fcntl ':mode';

use PAR::SetupProgname;

=head1 NAME

PAR::SetupTemp - Setup $ENV{PAR_TEMP}

=head1 SYNOPSIS

PAR guts, beware. Check L<PAR>

=head1 DESCRIPTION

Routines to setup the C<PAR_TEMP> environment variable.
The documentation of how the temporary directories are handled
is currently scattered across the C<PAR> manual and the
C<PAR::Environment> manual.

The C<set_par_temp_env()> subroutine sets up the C<PAR_TEMP>
environment variable.

=cut

# for PAR internal use only!
our $PARTemp;

# name of the canary file
our $Canary = "_CANARY_.txt";
# how much to "date back" the canary file (in seconds)
our $CanaryDateBack = 24 * 3600;        # 1 day

# The C version of this code appears in myldr/mktmpdir.c
# This code also lives in PAR::Packer's par.pl as _set_par_temp!
sub set_par_temp_env {
    PAR::SetupProgname::set_progname()
      unless defined $PAR::SetupProgname::Progname;

    if (defined $ENV{PAR_TEMP} and $ENV{PAR_TEMP} =~ /(.+)/) {
        $PARTemp = $1;
        return;
    }

    my $stmpdir = _get_par_user_tempdir();
    die "unable to create cache directory" unless $stmpdir;

    require File::Spec;
      if (!$ENV{PAR_CLEAN} and my $mtime = (stat($PAR::SetupProgname::Progname))[9]) {
          my $ctx = _get_digester();

          # Workaround for bug in Digest::SHA 5.38 and 5.39
          my $sha_version = eval { $Digest::SHA::VERSION } || 0;
          if ($sha_version eq '5.38' or $sha_version eq '5.39') {
              $ctx->addfile($PAR::SetupProgname::Progname, "b") if ($ctx);
          }
          else {
              if ($ctx and open(my $fh, "<$PAR::SetupProgname::Progname")) {
                  binmode($fh);
                  $ctx->addfile($fh);
                  close($fh);
              }
          }

          $stmpdir = File::Spec->catdir(
              $stmpdir,
              "cache-" . ( $ctx ? $ctx->hexdigest : $mtime )
          );
      }
      else {
          $ENV{PAR_CLEAN} = 1;
          $stmpdir = File::Spec->catdir($stmpdir, "temp-$$");
      }

      $ENV{PAR_TEMP} = $stmpdir;
    mkdir $stmpdir, 0700;

    $PARTemp = $1 if defined $ENV{PAR_TEMP} and $ENV{PAR_TEMP} =~ /(.+)/;
}

# Find any digester
# Used in PAR::Repository::Client!
sub _get_digester {
  my $ctx = eval { require Digest::SHA; Digest::SHA->new(1) }
         || eval { require Digest::SHA1; Digest::SHA1->new }
         || eval { require Digest::MD5; Digest::MD5->new };
  return $ctx;
}

# find the per-user temporary directory (eg /tmp/par-$USER)
# Used in PAR::Repository::Client!
sub _get_par_user_tempdir {
  my $username = _find_username();
  my $temp_path;
  foreach my $path (
    (map $ENV{$_}, qw( PAR_TMPDIR TMPDIR TEMPDIR TEMP TMP )),
      qw( C:\\TEMP /tmp . )
  ) {
    next unless defined $path and -d $path and -w $path;
    # create a temp directory that is unique per user
    # NOTE: $username may be in an unspecified charset/encoding;
    # use a name that hopefully works for all of them;
    # also avoid problems with platform-specific meta characters in the name
    $temp_path = File::Spec->catdir($path, "par-".unpack("H*", $username));
    ($temp_path) = $temp_path =~ /^(.*)$/s;
    unless (mkdir($temp_path, 0700) || $!{EEXIST}) {
      warn "creation of private subdirectory $temp_path failed (errno=$!)"; 
      return;
    }

    unless ($^O eq 'MSWin32') {
        my @st;
        unless (@st = lstat($temp_path)) {
          warn "stat of private subdirectory $temp_path failed (errno=$!)";
          return;
        }
        if (!S_ISDIR($st[2])
            || $st[4] != $<
            || ($st[2] & 0777) != 0700 ) {
          warn "private subdirectory $temp_path is unsafe (please remove it and retry your operation)";
          return;
        }
    }

    last;
  }
  return $temp_path;
}

# tries hard to find out the name of the current user
sub _find_username {
  my $username;
  my $pwuid;
  # does not work everywhere:
  eval {($pwuid) = getpwuid($>) if defined $>;};

  if ( defined(&Win32::LoginName) ) {
    $username = &Win32::LoginName;
  }
  elsif (defined $pwuid) {
    $username = $pwuid;
  }
  else {
    $username = $ENV{USERNAME} || $ENV{USER} || 'SYSTEM';
  }

  return $username;
}

1;

__END__

=head1 SEE ALSO

L<PAR>, L<PAR::Environment>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>,
Steffen Mueller E<lt>smueller@cpan.orgE<gt>

You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par@rt.cpan.orgE<gt>. If you need
support, however, joining the E<lt>par@perl.orgE<gt> mailing list is
preferred.

=head1 COPYRIGHT

Copyright 2002-2010 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

Copyright 2006-2010 by Steffen Mueller E<lt>smueller@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut


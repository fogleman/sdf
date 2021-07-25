package PAR::StrippedPARL::Base;
use 5.008001;
use strict;
use warnings;
our $VERSION = '0.975';

use File::Temp ();
use File::Spec;
use Cwd;
use Config ();

=head1 NAME

PAR::StrippedPARL::Base - Base class for the PARL data packages

=head1 SYNOPSIS

  # Please use one of the siblings of this class instead.
  use base 'PAR::StrippedPARL::Base';

=head1 DESCRIPTION

This class is internal to PAR. Do not use it outside of PAR.

This class is basically just a container for a static binary PAR loader
which doesn't include the PAR code like the F<parl> or F<parl.exe>
you are used to. If you're really curious, I'll tell you it is
just a copy of the F<myldr/static> (or F<myldr/static.exe>) file.

The data is appended during the C<make> phase of the PAR build process.

If the binary data isn't appended during the build process, the two class
methods will return the empty list.

=head1 CLASS METHODS

=head2 write_parl

Takes a file name as argument. Writes the raw binary data in
the package to the specified file and embeds the core modules
to produce a complete PAR loader (I<parl>).

Returns true on success or the empty list on failure.

=cut

sub write_parl {
    my $class = shift;
    my $file = shift;
    if (not defined $file) {
        warn "${class}->write_parl() needs a file name as argument";
        return;
    }

    # write out to a temporary file first
    my ($fh, $tfile) = File::Temp::tempfile(
        "parlXXXX", SUFFIX => $Config::Config{_exe}||'', TMPDIR => 1, UNLINK => 1);
    close $fh;

    if (not $class->write_raw($tfile)) {
        unlink($tfile);
        warn "Could not write temporary parl (class $class) to file '$tfile'";
        return;
    }
    chmod(0755, $tfile);

    # Use this to generate a real parl
    my @libs = ();
    for my $ilib ( @INC ) {
        next if ref $ilib;
        $ilib =~ s/\\$/\\\\/;
        push(@libs, qq(-I$ilib) );
    }

    system(Cwd::abs_path($tfile), @libs, qw( -q -B ), "-O$file");
    unless ($? == 0) {
        warn "Failed to execute temporary parl (class $class) in file '$tfile': $!";
        return;
    }
    return 1;
}

=head2 get_raw

Returns the binary data attached to the data package.

Returns the empty list on failure.

=cut

sub get_raw {
    my $class = shift;
    my $pos = $class->_data_pos(); 
    if (not defined $pos) {
        warn "${class}->_data_pos() did not return the original tell() position of the DATA file handle";
        return();
    }
    my $sym;
    {
        # Is there a better way to do this?
        no strict 'refs';
        $sym = \*{"${class}::DATA"};
    }
    seek $sym, $pos, 0 or die $!;
    binmode $sym;
    local $/ = undef;
    my $data = <$sym>;
    $data =~ s/^\s*//;
    my $binary = unpack 'u', $data;
    return() if not defined $binary or $binary !~ /\S/;
    return $binary;
}


=head2 write_raw

Takes a file name as argument and writes the binary data to the file.

Returns true on success and the empty list on failure.

=cut

sub write_raw {
    my $class = shift;
    my $file = shift;
    if (not defined $file) {
        warn "${class}->write_raw() needs a file name as argument";
        return();
    }
    my $binary = $class->get_raw();
    if (not defined $binary) {
        warn "${class}->get_raw() did not return the raw binary data for a PAR loader";
        return();
    }

    open my $fh, '>', $file or die "Could not open file '$file' for writing: $!";
    binmode $fh;
    print $fh $binary;
    close $fh;

    return 1;
}

=head1 SUBCLASSING

Subclasses need to implement the C<_data_pos> class method which returns
the value of C<tell DATA> as it was after the class was loaded.

=head1 AUTHORS

Steffen Mueller E<lt>smueller@cpan.orgE<gt>,
Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright 2006-2009 by Steffen Mueller E<lt>smueller@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See F<LICENSE>.

=cut

__DATA__


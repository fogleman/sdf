package PAR::SetupProgname;
$PAR::SetupProgname::VERSION = '1.002';

use 5.006;
use strict;
use warnings;
use Config ();

=head1 NAME

PAR::SetupProgname - Setup $ENV{PAR_PROGNAME}

=head1 SYNOPSIS

PAR guts, beware. Check L<PAR>

=head1 DESCRIPTION

Routines to setup the C<PAR_PROGNAME> environment variable.
Read the C<PAR::Environment> manual.

The C<set_progname()> subroutine sets up the C<PAR_PROGNAME>
environment variable

=cut

# for PAR internal use only!
our $Progname = $ENV{PAR_PROGNAME} || $0;

# same code lives in PAR::Packer's par.pl!
sub set_progname {
    require File::Spec;

    if (defined $ENV{PAR_PROGNAME} and $ENV{PAR_PROGNAME} =~ /(.+)/) {
        $Progname = $1;
    }
    $Progname = $0 if not defined $Progname;

    if (( () = File::Spec->splitdir($Progname) ) > 1 or !$ENV{PAR_PROGNAME}) {
        if (open my $fh, $Progname) {
            return if -s $fh;
        }
        if (-s "$Progname$Config::Config{_exe}") {
            $Progname .= $Config::Config{_exe};
            return;
        }
    }

    foreach my $dir (split /\Q$Config::Config{path_sep}\E/, $ENV{PATH}) {
        next if exists $ENV{PAR_TEMP} and $dir eq $ENV{PAR_TEMP};
        my $name = File::Spec->catfile($dir, "$Progname$Config::Config{_exe}");
        if (-s $name) { $Progname = $name; last }
        $name = File::Spec->catfile($dir, "$Progname");
        if (-s $name) { $Progname = $name; last }
    }
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


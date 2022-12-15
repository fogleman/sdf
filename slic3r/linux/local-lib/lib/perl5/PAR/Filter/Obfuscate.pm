package PAR::Filter::Obfuscate;
use 5.006;
use strict;
use warnings;
use base 'PAR::Filter';
use File::Temp ();

=head1 NAME

PAR::Filter::Obfuscate - Obfuscating filter

=head1 SYNOPSIS

    PAR::Filter::Obfuscate->apply(\$code); # transforms $code

=head1 DESCRIPTION

This filter uses L<B::Deobfuscate> (available separately from CPAN) to
turn the script into comment-free, architecture-independent Perl code
with mangled variable names.

=head1 CAVEATS

A harmless message will be displayed during C<pp>:

    /tmp/8ycSoLaSI1 syntax OK

Please just ignore it. :-)

=cut

sub apply {
    my $ref = $_[1];

    my ($fh, $in_file) = File::Temp::tempfile();
    print $fh $$ref;
    close $fh;

    require B::Deobfuscate;
    $$ref = `$^X -MO=Deobfuscate $in_file`;
    warn "Cannot transform $in_file$! ($?)\n" if $?;
}

1;

=head1 SEE ALSO

L<PAR::Filter>, L<B::Deobfuscate>, L<PAR::Filter::Crypto>

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par-packer@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2003-2009 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See F<LICENSE>.

=cut

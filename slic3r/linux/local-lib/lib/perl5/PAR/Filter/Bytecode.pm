package PAR::Filter::Bytecode;
use 5.006;
use strict;
use warnings;
use base 'PAR::Filter';
use File::Temp ();

=head1 NAME

PAR::Filter::Bytecode - Bytecode filter

=head1 SYNOPSIS

    PAR::Filter::Bytecode->apply(\$code); # transforms $code

=head1 DESCRIPTION

B<This filter is deprecated. The B::Bytecode code has been removed from
the newest development series of perl and will not be included in perl
5.10 any more. Please have a look at Steve Hay's L<PAR::Filter::Crypto>
module if you want to hide your sources.>

This filter uses L<B::Bytecode> to turn the script into comment-free,
architecture-specific Perl bytecode, and uses L<ByteLoader> to load
back on execution.

For L<pp> users, please add an extra B<-M> option, like this:

    pp -f Bytecode -M ByteLoader

Otherwise, the implicit dependency on ByteLoader will not be detected.

=head1 CAVEATS

This backend exhibits all bugs listed in L<B::Bytecode>, and then some.

Bytecode support is considered to be extremely fragile on Perl versions
earlier than 5.8.1, and is still far from robust (as of this writing).

Bytecode is not supported by perl 5.9 and later.

=cut

sub apply {
    my $ref = $_[1];

    my ($fh, $in_file) = File::Temp::tempfile();
    print $fh $$ref;
    close $fh;

    my $out_file = File::Temp::tmpnam();
    system($^X, "-MO=Bytecode,-H,-k,-o$out_file", $in_file);
    unless (-e $out_file) {
	warn "Cannot transform $in_file to $out_file: $! ($?)\n";
	return;
    }

    unlink($in_file);

    open my $fh, '<', $out_file or die $!;
    local $/;
    $$ref = <$fh>;
    close $fh;

    unlink($out_file);
}

1;

=head1 SEE ALSO

L<PAR::Filter>, L<B::Bytecode>, L<ByteLoader>

L<Filter::Crypto>, L<PAR::Filter::Crypto>

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

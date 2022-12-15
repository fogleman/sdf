package PAR::Filter;
use 5.006;
use strict;
use warnings;
our $VERSION = '0.03';

=head1 NAME

PAR::Filter - Input filter for PAR

=head1 SYNOPSIS

    $code = 'use strict; print "Hello, World!\n";';
    $ref = PAR::Filter->new('PodStrip', 'Bleach')->apply(\$code);
    print $code;    # pod-stripped and obfuscated code
    print $$ref;    # same thing

    $ref = PAR::Filter->new('PodStrip', 'Bleach')->apply('file.pl');
    print $$ref;    # same thing, applied to file.pl

=head1 DESCRIPTION

Starting with PAR 0.76, C<pp -f> takes a filter name, like C<Bleach>, and
invokes this module to transform the programs with L<PAR::Filter::Bleach>.
Similarly, C<pp -F Bleach> applies the B<Bleach> filter to all included
modules.

It is possible to pass in multiple such filters, which are applied in turn.

The output of each such filter is expected be semantically equivalent to the
input, although possibly obfuscated.

The default list of filters include:

=over 4

=item * L<PAR::Filter::Bleach>

The archetypical obfuscating filter.

=item * L<PAR::Filter::Obfuscate>

Use L<B::Deobfuscate> to strip away indents and comments, as well as mangling
variable names.

=item * L<PAR::Filter::PatchContent>

Fix PAR-incompatible modules, applied to modules by default.

=item * L<PAR::Filter::PodStrip>

Strip away POD sections, applied to modules by default.

=item * L<PAR::Filter::Bytecode>

Use L<B::Bytecode> to strip away indents and comments.
B<This filter is deprecated!> For source hiding,
have a look at L<PAR::Filter::Crypto> instead and make
sure to read about its caveats.

=back

=cut

sub new {
    my $class = shift;
    require "PAR/Filter/$_.pm" foreach @_;
    bless(\@_, $class);
}

sub apply {
    my ($self, $ref, $name) = @_;
    my $filename = $name || '-e';

    if (!ref $ref) {
	$name ||= $filename = $ref;
	local $/;
	open my $fh, $ref or die $!;
	binmode($fh);
	my $content = <$fh>;
	$ref = \$content;
	return $ref unless length($content);
    }

    "PAR::Filter::$_"->new->apply( $ref, $filename, $name ) foreach @$self;

    return $ref;
}

1;

=head1 AUTHORS

Audrey Tang E<lt>cpan@audreyt.orgE<gt>

=head1 COPYRIGHT

Copyright 2003-2009 by Audrey Tang E<lt>cpan@audreyt.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See F<LICENSE>.

=cut

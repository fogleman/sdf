package Sub::Identify;

use strict;
use Exporter;

BEGIN {
    our $VERSION = '0.14';
    our @ISA = ('Exporter');
    our %EXPORT_TAGS = (
        all => [
            our @EXPORT_OK = qw(
                sub_name
                stash_name
                sub_fullname
                get_code_info
                get_code_location
                is_sub_constant
            )
        ]
    );

    our $IsPurePerl = 1;
    unless ($ENV{PERL_SUB_IDENTIFY_PP}) {
        if (
            eval {
                require XSLoader;
                XSLoader::load(__PACKAGE__, $VERSION);
                1;
            }
        ) {
            $IsPurePerl = 0;
        }
        else {
            die $@ if $@ && $@ !~ /object version|loadable object/;
        }
    }

    if ($IsPurePerl) {
        require B;
        *get_code_info = sub ($) {
            my ($coderef) = @_;
            ref $coderef or return;
            my $cv = B::svref_2object($coderef);
            $cv->isa('B::CV') or return;
            # bail out if GV is undefined
            $cv->GV->isa('B::SPECIAL') and return;

            return ($cv->GV->STASH->NAME, $cv->GV->NAME);
        };
        *get_code_location = sub ($) {
            my ($coderef) = @_;
            ref $coderef or return;
            my $cv = B::svref_2object($coderef);
            $cv->isa('B::CV') && $cv->START->isa('B::COP')
                or return;

            return ($cv->START->file, $cv->START->line);
        };
    }
    if ($IsPurePerl || $] < 5.016) {
        require B;
        *is_sub_constant = sub ($) {
            my ($coderef) = @_;
            ref $coderef or return 0;
            my $cv = B::svref_2object($coderef);
            $cv->isa('B::CV') or return 0;
            my $p = prototype $coderef;
            defined $p && $p eq "" or return 0;
            return ($cv->CvFLAGS & B::CVf_CONST()) == B::CVf_CONST();
        };
    }
}

sub stash_name   ($) { (get_code_info($_[0]))[0] }
sub sub_name     ($) { (get_code_info($_[0]))[1] }
sub sub_fullname ($) { join '::', get_code_info($_[0]) }

1;

__END__

=head1 NAME

Sub::Identify - Retrieve names of code references

=head1 SYNOPSIS

    use Sub::Identify ':all';
    my $subname = sub_name( $some_coderef );
    my $packagename = stash_name( $some_coderef );
    # or, to get all at once...
    my $fully_qualified_name = sub_fullname( $some_coderef );
    defined $subname
        and say "this coderef points to sub $subname in package $packagename";
    my ($file, $line) = get_code_location( $some_coderef );
    $file
        and say "this coderef is defined at line $line in file $file";
    is_sub_constant( $some_coderef )
        and say "this coderef points to a constant subroutine";

=head1 DESCRIPTION

C<Sub::Identify> allows you to retrieve the real name of code references.

It provides six functions, all of them taking a code reference.

C<sub_name> returns the name of the code reference passed as an
argument (or C<__ANON__> if it's an anonymous code reference),
C<stash_name> returns its package, and C<sub_fullname> returns the
concatenation of the two.

C<get_code_info> returns a list of two elements, the package and the
subroutine name (in case of you want both and are worried by the speed.)

In case of subroutine aliasing, those functions always return the
original name.

C<get_code_location> returns a two-element list containing the file
name and the line number where the subroutine has been defined.

C<is_sub_constant> returns a boolean value indicating whether the
subroutine is a constant or not.

=head2 Pure-Perl version

By default C<Sub::Identify> tries to load an XS implementation of the
C<get_code_info>, C<get_code_location> and (on perl versions 5.16.0 and later)
C<is_sub_constant> functions, for speed; if that fails, or if the environment
variable C<PERL_SUB_IDENTIFY_PP> is defined to a true value, it will fall
back to a pure perl implementation, that uses perl's introspection mechanism,
provided by the C<B> module.

=head1 SEE ALSO

L<Sub::Util>, part of the module distribution L<Scalar::List::Utils>
since version 1.40. Since this will be a core module starting with perl
5.22.0, it is encouraged to migrate to Sub::Util when possible.

L<Sub::Name>

=head1 SOURCE

A git repository for the sources is at L<https://github.com/rgs/Sub-Identify>.

=head1 LICENSE

(c) Rafael Garcia-Suarez (rgs at consttype dot org) 2005, 2008, 2012, 2014, 2015

This program is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=cut

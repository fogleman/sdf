#############################################################################
## Name:        ext/pperl/carp/Carp.pm
## Purpose:     Wx::Perl::Carp module (a replacement for Carp in Wx
##              applications)
## Author:      D.H. aka PodMaster
## Modified by:
## Created:     12/24/2002
## RCS-ID:      $Id: Carp.pm 2057 2007-06-18 23:03:00Z mbarbon $
## Copyright:   (c) 2002 D.H.
## Licence:     This program is free software; you can redistribute itand/or
##              modify it under the same terms as Perl itself
#############################################################################

=head1 NAME

Wx::Perl::Carp  - a replacement for Carp in Wx applications

=head1 SYNOPSIS

Just like L<Carp>, so go see the L<Carp> pod (cause it's based on L<Ca
+rp>).

    # short example
    Wx::Perl::Carp;
    ...
    carp "i'm warn-ing";
    croak "i'm die-ing";

=head1 SEE ALSO

L<Carp> L<Carp> L<Carp> L<Carp> L<Carp>

=head1 COPYRIGHT

(c) 2002 D.H. aka PodMaster (a proud CPAN author)

=cut

package Wx::Perl::Carp;

BEGIN {
    require Carp;
    require Wx;
}

use Exporter;
$VERSION     = '0.01';
@ISA         = qw( Exporter );
@EXPORT      = qw( confess croak carp die warn);
@EXPORT_OK   = qw( cluck verbose );
@EXPORT_FAIL = qw( verbose );              # hook to enable verbose mode

sub export_fail { Carp::export_fail( @_) } # make verbose work for me
sub croak   { Wx::LogFatalError( Carp::shortmess(@_) ) }
sub confess { Wx::LogFatalError( Carp::longmess(@_) ) }
sub carp    { Wx::LogWarning( Carp::shortmess(@_) ) }
sub cluck   { Wx::LogWarning( Carp::longmess(@_) ) }
sub warn    { Wx::LogWarning( @_ ) }
sub die     { Wx::LogFatalError( @_ ) }

1;

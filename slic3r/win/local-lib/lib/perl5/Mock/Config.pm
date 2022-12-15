package Mock::Config;

use 5.006;
use Config ();

our %MockConfig;

=head1 NAME

Mock::Config - temporarily set Config or XSConfig values

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

XSConfig is readonly, so workaround that.

    use Mock::Config d_fork => 0, perl_patchlevel => '';

The importer works only dynamically, not lexically yet.

    use Mock::Config;
    Mock::Config->import(startperl => '');
    print $Config{startperl}, ' mocked to empty';
    Mock::Config->unimport;

=head1 SUBROUTINES

=head2 import

Set pair of Config values, even for the readonly XSConfig implementation,
as used in cperl.

It does not store the mocked overrides lexically, just dynamically.

=cut

sub _set {
  my ($key, $val) = @_;
  # string context only?
  if (!exists $MockConfig{$key} or $MockConfig{$key} ne $val) {
    if (exists &Config::KEYS) {     # compiled XSConfig
      $MockConfig{$key} = $val;     # cache new value
    } else {
      $MockConfig{$key} = tied(%Config::Config)->{$key}; # store the old value
      tied(%Config::Config)->{$key} = $val;      # set uncompiled Config
    }
  }
}

sub import {
  my $class = shift;
  if (exists &Config::KEYS) {     # compiled XSConfig
    # initialize the mocker
    if (!exists &Config_FETCHorig) {
      *Config_FETCHorig = \&Config::FETCH;
      no warnings 'redefine';
      *Config::FETCH = sub {
        if ($_[0] and exists $MockConfig{$_[1]}) {
          return $MockConfig{$_[1]};
        } else {
          return Config_FETCHorig(@_);
        }
      }
    }
  }
  _set(shift, shift) while @_;
}

=head2 unimport

This is unstacked and not lexical.
It undoes all imported Config values at once.

=cut

sub unimport {
  my $class = shift;
  if (!exists &Config::KEYS) {
    for (keys %MockConfig) {
      tied(%Config::Config)->{$_} = $MockConfig{$_};
    }
  }
  %MockConfig = ();
}


=head1 AUTHOR

Reini Urban, C<< <rurban at cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests at 
L<https://github.com/perl11/Mock-Config/issues>.

We will be notified, and then you'll automatically be notified of
progress on your request as we make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Mock::Config

You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=Mock-Config>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/Mock-Config>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/Mock-Config>

=item * Search CPAN

L<http://search.cpan.org/dist/Mock-Config/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2016 cPanel Inc.

This program is free software; you can redistribute it and/or modify it
under the terms of the the Artistic License (2.0). You may obtain a
copy of the full license at:

L<http://www.perlfoundation.org/artistic_license_2_0>

Any use, modification, and distribution of the Standard or Modified
Versions is governed by this Artistic License. By using, modifying or
distributing the Package, you accept this license. Do not use, modify,
or distribute the Package, if you do not accept this license.

If your Modified Version has been derived from a Modified Version made
by someone other than you, you are nevertheless required to ensure that
your Modified Version complies with the requirements of this license.

This license does not grant you the right to use any trademark, service
mark, tradename, or logo of the Copyright Holder.

This license includes the non-exclusive, worldwide, free-of-charge
patent license to make, have made, use, offer to sell, sell, import and
otherwise transfer the Package with respect to any patent claims
licensable by the Copyright Holder that are necessarily infringed by the
Package. If you institute patent litigation (including a cross-claim or
counterclaim) against any party alleging that the Package constitutes
direct or contributory patent infringement, then this Artistic License
to you shall terminate on the date that such litigation is filed.

Disclaimer of Warranty: THE PACKAGE IS PROVIDED BY THE COPYRIGHT HOLDER
AND CONTRIBUTORS "AS IS' AND WITHOUT ANY EXPRESS OR IMPLIED WARRANTIES.
THE IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
PURPOSE, OR NON-INFRINGEMENT ARE DISCLAIMED TO THE EXTENT PERMITTED BY
YOUR LOCAL LAW. UNLESS REQUIRED BY LAW, NO COPYRIGHT HOLDER OR
CONTRIBUTOR WILL BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, OR
CONSEQUENTIAL DAMAGES ARISING IN ANY WAY OUT OF THE USE OF THE PACKAGE,
EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


=cut

1; # End of Mock::Config

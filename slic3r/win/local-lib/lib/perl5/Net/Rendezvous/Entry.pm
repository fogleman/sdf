package Net::Rendezvous::Entry;

=head1 NAME

Net::Rendezvous::Entry - Support module for mDNS service discovery (Apple's Rendezvous) 

=head1 SYNOPSIS

B<This module is deprecated.  Please see L<Net::Bonjour::Entry> and L<Net::Bonjour>>

=head1 SEE ALSO

L<Net::Bonjour>

=head1 COPYRIGHT

This library is free software and can be distributed or modified under the same terms as Perl itself.

Rendezvous (in this context) is a trademark of Apple Computer, Inc.
Bonjour (in this context) is a trademark of Apple Computer, Inc.

=head1 AUTHORS

The Net::Rendezvous::Entry module was created by George Chlipala <george@walnutcs.com>

=cut

use strict;
use Net::Bonjour::Entry;
use vars qw($AUTOLOAD @ISA);
our @ISA = ('Net::Bonjour::Entry');

1;

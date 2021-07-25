package Net::Rendezvous;

=head1 NAME

Net::Rendezvous - Module for DNS service discovery (Apple's Rendezvous)

=head1 SYNOPSIS 

B<This module is deprecated.  Use L<Net::Bonjour>>.

=head1 SEE ALSO

L<Net::Bonjour>

=head1 COPYRIGHT

This library is free software and can be distributed or modified under the same terms as Perl itself.

Rendezvous (in this context) is a trademark of Apple Computer, Inc.
Bonjour (in this context) is a trademark of Apple Computer, Inc.

=head1 AUTHORS

The Net::Rendezvous module was created by George Chlipala <george@walnutcs.com>

=cut

use strict;
use Net::Bonjour;
use Net::Rendezvous::Entry;
use vars qw($VERSION $AUTOLOAD @ISA);
our $VERSION = '0.92';
our @ISA = ('Net::Bonjour');

1;

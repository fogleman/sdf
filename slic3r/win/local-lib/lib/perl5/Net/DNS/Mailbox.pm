package Net::DNS::Mailbox;

#
# $Id: Mailbox.pm 1527 2017-01-18 21:42:48Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1527 $)[1];


=head1 NAME

Net::DNS::Mailbox - DNS mailbox representation

=head1 SYNOPSIS

    use Net::DNS::Mailbox;

    $mailbox = new Net::DNS::Mailbox('user@example.com');
    $address = $mailbox->address;

=head1 DESCRIPTION

The Net::DNS::Mailbox module implements a subclass of DNS domain name
objects representing the DNS coded form of RFC822 mailbox address.

=cut


use strict;
use warnings;
use integer;
use Carp;

use base qw(Net::DNS::DomainName);


=head1 METHODS

=head2 new

    $mailbox = new Net::DNS::Mailbox('John Doe <john.doe@example.com>');
    $mailbox = new Net::DNS::Mailbox('john.doe@example.com');
    $mailbox = new Net::DNS::Mailbox('john\.doe.example.com');

Creates a mailbox object representing the RFC822 mail address specified by
the character string argument. An encoded domain name is also accepted for
backward compatibility with Net::DNS 0.68 and earlier.

The argument string consists of printable characters from the 7-bit
ASCII repertoire.

=cut

sub new {
	my $class = shift;
	local $_ = shift;
	croak 'undefined mail address' unless defined $_;

	s/^.*<//g;						# strip excess on left
	s/>.*$//g;						# strip excess on right

	s/\\\@/\\064/g;						# disguise escaped @
	s/("[^"]*)\@([^"]*")/$1\\064$2/g;			# disguise quoted @

	my ( $mbox, @host ) = split /\@/;			# split on @ if present
	for ( $mbox ||= '' ) {
		s/^.*"(.*)".*$/$1/;				# strip quotes
		s/\\\./\\046/g;					# disguise escaped dot
		s/\./\\046/g if @host;				# escape dots in local part
	}

	bless __PACKAGE__->SUPER::new( join '.', $mbox, @host ), $class;
}


=head2 address

    $address = $mailbox->address;

Returns a character string containing the RFC822 mailbox address
corresponding to the encoded domain name representation described
in RFC1035 section 8.

=cut

sub address {
	return unless defined wantarray;
	my @label = shift->label;
	local $_ = shift(@label) || return '<>';
	s/\\\\//g;						# delete escaped \
	s/\\\d\d\d//g;						# delete non-printable
	s/\\\./\./g;						# unescape dots
	s/[\\"]//g;						# delete \ "
	s/^(.*)$/"$1"/ if /["(),:;<>@\[\\\]]/;			# quote local part
	return $_ unless scalar(@label);
	join '@', $_, join '.', @label;
}


########################################

=head1 DOMAIN NAME COMPRESSION AND CANONICALISATION

The Net::DNS::Mailbox1035 and Net::DNS::Mailbox2535 subclass
packages implement RFC1035 domain name compression and RFC2535
canonicalisation.

=cut

package Net::DNS::Mailbox1035;

use base qw(Net::DNS::Mailbox);

sub encode { &Net::DNS::DomainName1035::encode; }


package Net::DNS::Mailbox2535;

use base qw(Net::DNS::Mailbox);

sub encode { &Net::DNS::DomainName2535::encode; }


1;
__END__


########################################

=head1 COPYRIGHT

Copyright (c)2009,2012 Dick Franks.

All rights reserved.


=head1 LICENSE

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted, provided
that the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation, and that the name of the author not be used in advertising
or publicity pertaining to distribution of the software without specific
prior written permission.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.


=head1 SEE ALSO

L<perl>, L<Net::DNS>, L<Net::DNS::DomainName>, RFC1035, RFC5322 (RFC822)

=cut


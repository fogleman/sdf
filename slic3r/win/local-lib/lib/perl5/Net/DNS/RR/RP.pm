package Net::DNS::RR::RP;

#
# $Id: RP.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::RP - DNS RP resource record

=cut


use integer;

use Net::DNS::DomainName;
use Net::DNS::Mailbox;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset, @opaque ) = @_;

	( $self->{mbox}, $offset ) = decode Net::DNS::Mailbox2535( $data, $offset, @opaque );
	$self->{txtdname} = decode Net::DNS::DomainName2535( $data, $offset, @opaque );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;
	my ( $offset, @opaque ) = @_;

	my $txtdname = $self->{txtdname} || return '';
	my $rdata = $self->{mbox}->encode( $offset, @opaque );
	$rdata .= $txtdname->encode( $offset + length($rdata), @opaque );
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my $txtdname = $self->{txtdname} || return '';
	my @rdata = ( $self->{mbox}->string, $txtdname->string );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->mbox(shift);
	$self->txtdname(shift);
}


sub mbox {
	my $self = shift;

	$self->{mbox} = new Net::DNS::Mailbox2535(shift) if scalar @_;
	$self->{mbox}->address if $self->{mbox};
}


sub txtdname {
	my $self = shift;

	$self->{txtdname} = new Net::DNS::DomainName2535(shift) if scalar @_;
	$self->{txtdname}->name if $self->{txtdname};
}


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name RP mbox txtdname');

=head1 DESCRIPTION

Class for DNS Responsible Person (RP) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 mbox

    $mbox = $rr->mbox;
    $rr->mbox( $mbox );

A domain name which specifies the mailbox for the person responsible for
this domain. The format in master files uses the DNS encoding convention
for mailboxes, identical to that used for the RNAME mailbox field in the
SOA RR. The root domain name (just ".") may be specified to indicate that
no mailbox is available.

=head2 txtdname

    $txtdname = $rr->txtdname;
    $rr->txtdname( $txtdname );

A domain name identifying TXT RRs. A subsequent query can be performed to
retrieve the associated TXT records. This provides a level of indirection
so that the entity can be referred to from multiple places in the DNS. The
root domain name (just ".") may be specified to indicate that there is no
associated TXT RR.


=head1 COPYRIGHT

Copyright (c)1997 Michael Fuhr. 

All rights reserved.

Package template (c)2009,2012 O.M.Kolkman and R.W.Franks.


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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC1183 Section 2.2

=cut

package Net::DNS::RR::DNAME;

#
# $Id: DNAME.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::DNAME - DNS DNAME resource record

=cut


use integer;

use Net::DNS::DomainName;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;

	$self->{target} = decode Net::DNS::DomainName2535(@_);
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	my $target = $self->{target} || return '';
	$target->encode(@_);
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my $target = $self->{target} || return '';
	$target->string;
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	$self->target(shift);
}


sub target {
	my $self = shift;

	$self->{target} = new Net::DNS::DomainName2535(shift) if scalar @_;
	$self->{target}->name if $self->{target};
}


sub dname { &target; }						# uncoverable pod


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name DNAME target');

=head1 DESCRIPTION

Class for DNS Non-Terminal Name Redirection (DNAME) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 target

    $target = $rr->target;
    $rr->target( $target );

Redirection target domain name which is to be substituted
for its owner as a suffix of a domain name.


=head1 COPYRIGHT

Copyright (c)2002 Andreas Gustafsson. 

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC6672

=cut

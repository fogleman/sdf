package Net::DNS::RR::SRV;

#
# $Id: SRV.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::SRV - DNS SRV resource record

=cut


use integer;

use Net::DNS::DomainName;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset, @opaque ) = @_;

	@{$self}{qw(priority weight port)} = unpack( "\@$offset n3", $$data );

	$self->{target} = decode Net::DNS::DomainName2535( $data, $offset + 6, @opaque );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;
	my ( $offset, @opaque ) = @_;

	my $target = $self->{target} || return '';
	my @nums = ( $self->priority, $self->weight, $self->port );
	pack 'n3 a*', @nums, $target->encode( $offset + 6, @opaque );
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my $target = $self->{target} || return '';
	my @rdata = ( $self->priority, $self->weight, $self->port, $target->string );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	foreach my $attr (qw(priority weight port target)) {
		$self->$attr(shift);
	}
}


sub priority {
	my $self = shift;

	$self->{priority} = 0 + shift if scalar @_;
	$self->{priority} || 0;
}


sub weight {
	my $self = shift;

	$self->{weight} = 0 + shift if scalar @_;
	$self->{weight} || 0;
}


sub port {
	my $self = shift;

	$self->{port} = 0 + shift if scalar @_;
	$self->{port} || 0;
}


sub target {
	my $self = shift;

	$self->{target} = new Net::DNS::DomainName2535(shift) if scalar @_;
	$self->{target}->name if $self->{target};
}


# order RRs by numerically increasing priority, decreasing weight
my $function = sub {
	my ( $a, $b ) = ( $Net::DNS::a, $Net::DNS::b );
	$a->{priority} <=> $b->{priority}
			|| $b->{weight} <=> $a->{weight};
};

__PACKAGE__->set_rrsort_func( 'priority', $function );

__PACKAGE__->set_rrsort_func( 'default_sort', $function );


1;
__END__


=head1 SYNOPSIS

    use Net::DNS;
    $rr = new Net::DNS::RR('name SRV priority weight port target');

=head1 DESCRIPTION

Class for DNS Service (SRV) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 priority

    $priority = $rr->priority;
    $rr->priority( $priority );

Returns the priority for this target host.

=head2 weight

    $weight = $rr->weight;
    $rr->weight( $weight );

Returns the weight for this target host.

=head2 port

    $port = $rr->port;
    $rr->port( $port );

Returns the port number for the service on this target host.

=head2 target

    $target = $rr->target;
    $rr->target( $target );

Returns the domain name of the target host.

=head1 Sorting of SRV Records

By default, rrsort() returns the SRV records sorted from lowest to highest
priority and for equal priorities from highest to lowest weight.

Note: This is NOT the order in which connections should be attempted.


=head1 COPYRIGHT

Copyright (c)1997 Michael Fuhr.

Portions Copyright (c)2005 Olaf Kolkman, NLnet Labs.

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, RFC2782

=cut

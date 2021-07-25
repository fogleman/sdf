package Net::DNS::RR::URI;

#
# $Id: URI.pm 1528 2017-01-18 21:44:58Z willem $
#
our $VERSION = (qw$LastChangedRevision: 1528 $)[1];


use strict;
use warnings;
use base qw(Net::DNS::RR);

=head1 NAME

Net::DNS::RR::URI - DNS URI resource record

=cut


use integer;

use Net::DNS::Text;


sub _decode_rdata {			## decode rdata from wire-format octet string
	my $self = shift;
	my ( $data, $offset ) = @_;

	my $limit = $offset + $self->{rdlength};
	@{$self}{qw(priority weight)} = unpack( "\@$offset n2", $$data );
	$offset += 4;
	$self->{target} = decode Net::DNS::Text( $data, $offset, $limit - $offset );
}


sub _encode_rdata {			## encode rdata as wire-format octet string
	my $self = shift;

	my $target = $self->{target} || return '';
	pack 'n2 a*', @{$self}{qw(priority weight)}, $target->raw;
}


sub _format_rdata {			## format rdata portion of RR string.
	my $self = shift;

	my $target = $self->{target} || return '';
	my @rdata = ( $self->priority, $self->weight, $target->string );
}


sub _parse_rdata {			## populate RR from rdata in argument list
	my $self = shift;

	map $self->$_(shift), qw(priority weight target);
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


sub target {
	my $self = shift;

	$self->{target} = new Net::DNS::Text(shift) if scalar @_;
	$self->{target}->value if $self->{target};
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
    $rr = new Net::DNS::RR('name URI priority weight target');

=head1 DESCRIPTION

Class for DNS Service (URI) resource records.

=head1 METHODS

The available methods are those inherited from the base class augmented
by the type-specific methods defined in this package.

Use of undocumented package features or direct access to internal data
structures is discouraged and could result in program termination or
other unpredictable behaviour.


=head2 priority

    $priority = $rr->priority;
    $rr->priority( $priority );

The priority of the target URI in this RR.
The range of this number is 0-65535.
A client MUST attempt to contact the URI with the lowest-numbered
priority it can reach; weighted selection being used to distribute
load across targets with equal priority.

=head2 weight

    $weight = $rr->weight;
    $rr->weight( $weight );

A server selection mechanism. The weight field specifies a relative
weight for entries with the same priority.  Larger weights SHOULD be
given a proportionately higher probability of being selected.  The
range of this number is 0-65535.

=head2 target

    $target = $rr->target;
    $rr->target( $target );

The URI of the target. Resolution of the URI is according to the
definitions for the Scheme of the URI.


=head1 COPYRIGHT

Copyright (c)2015 Dick Franks. 

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

L<perl>, L<Net::DNS>, L<Net::DNS::RR>, 
RFC7553

=cut

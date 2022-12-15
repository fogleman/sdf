#line 1 "URI/QueryParam.pm"
package URI::QueryParam;

use strict;
use warnings;

our $VERSION = '1.71';
$VERSION = eval $VERSION;

sub URI::_query::query_param {
    my $self = shift;
    my @old = $self->query_form;

    if (@_ == 0) {
	# get keys
	my (%seen, $i);
	return grep !($i++ % 2 || $seen{$_}++), @old;
    }

    my $key = shift;
    my @i = grep $_ % 2 == 0 && $old[$_] eq $key, 0 .. $#old;

    if (@_) {
	my @new = @old;
	my @new_i = @i;
	my @vals = map { ref($_) eq 'ARRAY' ? @$_ : $_ } @_;

	while (@new_i > @vals) {
	    splice @new, pop @new_i, 2;
	}
	if (@vals > @new_i) {
	    my $i = @new_i ? $new_i[-1] + 2 : @new;
	    my @splice = splice @vals, @new_i, @vals - @new_i;

	    splice @new, $i, 0, map { $key => $_ } @splice;
	}
	if (@vals) {
	    #print "SET $new_i[0]\n";
	    @new[ map $_ + 1, @new_i ] = @vals;
	}

	$self->query_form(\@new);
    }

    return wantarray ? @old[map $_+1, @i] : @i ? $old[$i[0]+1] : undef;
}

sub URI::_query::query_param_append {
    my $self = shift;
    my $key = shift;
    my @vals = map { ref $_ eq 'ARRAY' ? @$_ : $_ } @_;
    $self->query_form($self->query_form, $key => \@vals);  # XXX
    return;
}

sub URI::_query::query_param_delete {
    my $self = shift;
    my $key = shift;
    my @old = $self->query_form;
    my @vals;

    for (my $i = @old - 2; $i >= 0; $i -= 2) {
	next if $old[$i] ne $key;
	push(@vals, (splice(@old, $i, 2))[1]);
    }
    $self->query_form(\@old) if @vals;
    return wantarray ? reverse @vals : $vals[-1];
}

sub URI::_query::query_form_hash {
    my $self = shift;
    my @old = $self->query_form;
    if (@_) {
	$self->query_form(@_ == 1 ? %{shift(@_)} : @_);
    }
    my %hash;
    while (my($k, $v) = splice(@old, 0, 2)) {
	if (exists $hash{$k}) {
	    for ($hash{$k}) {
		$_ = [$_] unless ref($_) eq "ARRAY";
		push(@$_, $v);
	    }
	}
	else {
	    $hash{$k} = $v;
	}
    }
    return \%hash;
}

1;

__END__

#line 209

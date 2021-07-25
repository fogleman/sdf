#line 1 "LWP/ConnCache.pm"
package LWP::ConnCache;

use strict;

our $VERSION = '6.24';
our $DEBUG;

sub new {
    my($class, %cnf) = @_;

    my $total_capacity = 1;
    if (exists $cnf{total_capacity}) {
        $total_capacity = delete $cnf{total_capacity};
    }
    if (%cnf && $^W) {
	require Carp;
	Carp::carp("Unrecognised options: @{[sort keys %cnf]}")
    }
    my $self = bless { cc_conns => [] }, $class;
    $self->total_capacity($total_capacity);
    $self;
}


sub deposit {
    my($self, $type, $key, $conn) = @_;
    push(@{$self->{cc_conns}}, [$conn, $type, $key, time]);
    $self->enforce_limits($type);
    return;
}


sub withdraw {
    my($self, $type, $key) = @_;
    my $conns = $self->{cc_conns};
    for my $i (0 .. @$conns - 1) {
	my $c = $conns->[$i];
	next unless $c->[1] eq $type && $c->[2] eq $key;
	splice(@$conns, $i, 1);  # remove it
	return $c->[0];
    }
    return undef;
}


sub total_capacity {
    my $self = shift;
    my $old = $self->{cc_limit_total};
    if (@_) {
	$self->{cc_limit_total} = shift;
	$self->enforce_limits;
    }
    $old;
}


sub capacity {
    my $self = shift;
    my $type = shift;
    my $old = $self->{cc_limit}{$type};
    if (@_) {
	$self->{cc_limit}{$type} = shift;
	$self->enforce_limits($type);
    }
    $old;
}


sub enforce_limits {
    my($self, $type) = @_;
    my $conns = $self->{cc_conns};

    my @types = $type ? ($type) : ($self->get_types);
    for $type (@types) {
	next unless $self->{cc_limit};
	my $limit = $self->{cc_limit}{$type};
	next unless defined $limit;
	for my $i (reverse 0 .. @$conns - 1) {
	    next unless $conns->[$i][1] eq $type;
	    if (--$limit < 0) {
		$self->dropping(splice(@$conns, $i, 1), "$type capacity exceeded");
	    }
	}
    }

    if (defined(my $total = $self->{cc_limit_total})) {
	while (@$conns > $total) {
	    $self->dropping(shift(@$conns), "Total capacity exceeded");
	}
    }
}


sub dropping {
    my($self, $c, $reason) = @_;
    print "DROPPING @$c [$reason]\n" if $DEBUG;
}


sub drop {
    my($self, $checker, $reason) = @_;
    if (ref($checker) ne "CODE") {
	# make it so
	if (!defined $checker) {
	    $checker = sub { 1 };  # drop all of them
	}
	elsif (_looks_like_number($checker)) {
	    my $age_limit = $checker;
	    my $time_limit = time - $age_limit;
	    $reason ||= "older than $age_limit";
	    $checker = sub { $_[3] < $time_limit };
	}
	else {
	    my $type = $checker;
	    $reason ||= "drop $type";
	    $checker = sub { $_[1] eq $type };  # match on type
	}
    }
    $reason ||= "drop";

    local $SIG{__DIE__};  # don't interfere with eval below
    local $@;
    my @c;
    for (@{$self->{cc_conns}}) {
	my $drop;
	eval {
	    if (&$checker(@$_)) {
		$self->dropping($_, $reason);
		$drop++;
	    }
	};
	push(@c, $_) unless $drop;
    }
    @{$self->{cc_conns}} = @c;
}


sub prune {
    my $self = shift;
    $self->drop(sub { !shift->ping }, "ping");
}


sub get_types {
    my $self = shift;
    my %t;
    $t{$_->[1]}++ for @{$self->{cc_conns}};
    return keys %t;
}


sub get_connections {
    my($self, $type) = @_;
    my @c;
    for (@{$self->{cc_conns}}) {
	push(@c, $_->[0]) if !$type || ($type && $type eq $_->[1]);
    }
    @c;
}


sub _looks_like_number {
    $_[0] =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;
}

1;


__END__

#line 351

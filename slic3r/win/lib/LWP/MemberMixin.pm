#line 1 "LWP/MemberMixin.pm"
package LWP::MemberMixin;
$LWP::MemberMixin::VERSION = '6.24';
sub _elem {
    my $self = shift;
    my $elem = shift;
    my $old  = $self->{$elem};
    $self->{$elem} = shift if @_;
    return $old;
}

1;

__END__

#line 47

package Class::Accessor::Fast;
use base 'Class::Accessor';
use strict;
$Class::Accessor::Fast::VERSION = '0.34';

sub make_accessor {
    my($class, $field) = @_;

    return sub {
        return $_[0]->{$field} if scalar(@_) == 1;
        return $_[0]->{$field}  = scalar(@_) == 2 ? $_[1] : [@_[1..$#_]];
    };
}


sub make_ro_accessor {
    my($class, $field) = @_;

    return sub {
        return $_[0]->{$field} if @_ == 1;
        my $caller = caller;
        $_[0]->_croak("'$caller' cannot alter the value of '$field' on objects of class '$class'");
    };
}


sub make_wo_accessor {
    my($class, $field) = @_;

    return sub {
        if (@_ == 1) {
            my $caller = caller;
            $_[0]->_croak("'$caller' cannot access the value of '$field' on objects of class '$class'");
        }
        else {
            return $_[0]->{$field} = $_[1] if @_ == 2;
            return (shift)->{$field} = \@_;
        }
    };
}


1;

__END__

=head1 NAME

Class::Accessor::Fast - Faster, but less expandable, accessors

=head1 SYNOPSIS

  package Foo;
  use base qw(Class::Accessor::Fast);

  # The rest is the same as Class::Accessor but without set() and get().

=head1 DESCRIPTION

This is a faster but less expandable version of Class::Accessor.
Class::Accessor's generated accessors require two method calls to accompish
their task (one for the accessor, another for get() or set()).
Class::Accessor::Fast eliminates calling set()/get() and does the access itself,
resulting in a somewhat faster accessor.

The downside is that you can't easily alter the behavior of your
accessors, nor can your subclasses.  Of course, should you need this
later, you can always swap out Class::Accessor::Fast for
Class::Accessor.

Read the documentation for Class::Accessor for more info.

=head1 EFFICIENCY

L<Class::Accessor/EFFICIENCY> for an efficiency comparison.

=head1 AUTHORS

Copyright 2007 Marty Pauley <marty+perl@kasei.com>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.  That means either (a) the GNU General Public
License or (b) the Artistic License.

=head2 ORIGINAL AUTHOR

Michael G Schwern <schwern@pobox.com>

=head1 SEE ALSO

L<Class::Accessor>

=cut

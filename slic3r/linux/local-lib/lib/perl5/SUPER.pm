# Dear PAUSE: please do not index this
package
    DB;

sub uplevel_args { my @foo = caller(2); return @DB::args }

# Dear PAUSE: nor this
package
    UNIVERSAL;

use strict;
use warnings;

use Scalar::Util 'blessed';

sub super
{
    return ( SUPER::find_parent( @_, '', $_[0] ) )[0];
}

sub SUPER
{
    my $self             = $_[0];
    my $blessed          = blessed( $self );
    my $self_class       = defined $blessed ? $blessed : $self;
    my ($class, $method) = ( caller( 1 ) )[3] =~ /(.+)::(\w+)$/;
    my ($sub, $parent)   =
        SUPER::find_parent( $self_class, $method, $class, $self );

    return unless $sub;
    goto &$sub;
}

package SUPER;
# ABSTRACT: control superclass method dispatch
$SUPER::VERSION = '1.20141117';
use strict;
use warnings;

use Carp;

use Scalar::Util 'blessed';
use Sub::Identify ();

# no need to use Exporter
sub import
{
    my ($class) = @_;
    my $caller  = caller();
    do { no strict 'refs'; *{ $caller . '::super' } = \&super };
}

sub find_parent
{
    my ($class, $method, $prune, $invocant) = @_;
    my $blessed                             = blessed( $class );
    $invocant                             ||= $class;
    $class                                  = $blessed if $blessed;
    $prune                                ||= '';

    my @parents = get_all_parents( $invocant, $class );

    # only check parents above the $prune point
    my $i       = $#parents;
    for my $parent (reverse @parents) {
        last if $parent eq $prune;
        $i--;
    }

    for my $parent ( @parents[$i .. $#parents] )
    {
        if ( my $subref = $parent->can( $method ) )
        {
            my $source = Sub::Identify::sub_fullname( $subref );
            next if $source eq "${prune}::$method";
            return ( $subref, $parent );
        }
    }
}

sub get_all_parents
{
    my ($invocant, $class) = @_;

    my @parents = eval { $invocant->__get_parents() };

    unless ( @parents )
    {
        no strict 'refs';
        @parents = @{ $class . '::ISA' };
    }

    return 'UNIVERSAL' unless @parents;
    return @parents, map { get_all_parents( $_, $_ ) } @parents;
}

sub super()
{
    # Someone's trying to find SUPER's super. Blah.
    goto &UNIVERSAL::super if @_;

    @_ = DB::uplevel_args();

    carp 'You must call super() from a method call' unless $_[0];

    my $caller = ( caller(1) )[3];
    my $self   = caller();
    $caller    =~ s/.*:://;

    goto &{ $self->UNIVERSAL::super($caller) };
}

1;

=head1 NAME

SUPER - control superclass method dispatch

=head1 SYNOPSIS

Find the parent method that would run if this weren't here:

    sub my_method
    {
        my $self = shift;
        my $super = $self->super('my_method'); # Who's your daddy?

        if ($want_to_deal_with_this)
        {
            # ...
        }
        else
        {
            $super->($self, @_)
        }
    }

Or Ruby-style:

    sub my_method
    {
        my $self = shift;

        if ($want_to_deal_with_this)
        {
            # ...
        }
        else
        {
            super;
        }
    }

Or call the super method manually, with respect to inheritance, and passing
different arguments:

    sub my_method
    {
        my $self = shift;

        # parent handles args backwardly
        $self->SUPER( reverse @_ );
    }

=head1 DESCRIPTION

When subclassing a class, you occasionally want to dispatch control to the
superclass -- at least conditionally and temporarily. The Perl syntax for
calling your superclass is ugly and unwieldy:

    $self->SUPER::method(@_);

especially when compared to its Ruby equivalent:

    super;

It's even worse in that the normal Perl redispatch mechanism only dispatches to
the parent of the class containing the method I<at compile time>.  That doesn't work very well for mixins and roles.

This module provides nicer equivalents, along with the universal method
C<super> to determine a class' own superclass. This allows you to do things
such as:

    goto &{$_[0]->super('my_method')};

if you don't like wasting precious stack frames.

If you are using roles or mixins or otherwise pulling in methods from other
packages that need to dispatch to their super methods, or if you want to pass
different arguments to the super method, use the C<SUPER()> method:

    $self->SUPER( qw( other arguments here ) );

=head1 FUNCTIONS and METHODS

This module provides the following functions and methods:

=over

=item C<super()>

This function calls the super method of the currently-executing method, no
matter where the super method is in the hierarchy.

This takes no arguments; it passes the same arguments passed to the
currently-executing method.

The module exports this function by default.

I<Note>: you I<must> have the appropriate C<package> declaration in place for
this to work.  That is, you must have I<compiled> the method in which you use
this function in the package from which you want to use it.  Them's the breaks
with Perl 5.

=item C<find_parent( $class, $method, $prune, $invocant )>

Attempts to find a parent implementation of C<$method> starting with C<$class>.
If you pass C<$prune>, it will not ignore the method found in that package, if
it exists there.  Pass C<$invocant> if the object itself might have a different
idea of its parents.

The module does not export this function by default.  Call it directly.

=item C<get_all_parents( $invocant, $class )>

Returns all of the parents for the C<$invocant>, if it supports the
C<__get_parents()> method or the contents of C<@ISA> for C<$class>.  You
probably oughtn't call this on your own.

=item C<SUPER()>

Calls the super method of the currently-executing method.  You I<can> pass
arguments.  This is a method.

=back

=head1 NOTES

I<Beware:> if you do weird things with code generation, be sure to I<name> your
anonymous subroutines.  See I<Perl Hacks> #57.

Using C<super> doesn't let you pass alternate arguments to your superclass's
method. If you want to pass different arguments, use C<SUPER> instead.  D'oh.

This module does a small amount of Deep Magic to find the arguments of method
I<calling> C<super()> itself.  This may confuse tools such as C<Devel::Cover>.

In your own code, if you do complicated things with proxy objects and the like,
define C<__get_parents()> to return a list of all parents of the object to
which you really want to dispatch.

=head1 AUTHOR

Created by Simon Cozens, C<simon@cpan.org>.  Copyright (c) 2003 Simon Cozens.

Maintained by chromatic, E<lt>chromatic at wgz dot orgE<gt> after version 1.01.
Copyright (c) 2004-2014 chromatic.

Thanks to Joshua ben Jore for bug reports and suggestions.

=head1 LICENSE

You may use and distribute this silly little module under the same terms as
Perl itself.

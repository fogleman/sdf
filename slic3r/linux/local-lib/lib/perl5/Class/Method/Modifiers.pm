use strict;
use warnings;
package Class::Method::Modifiers; # git description: v2.11-20-g6902f76
# ABSTRACT: Provides Moose-like method modifiers
# KEYWORDS: method wrap modification patch
# vim: set ts=8 sts=4 sw=4 tw=115 et :

our $VERSION = '2.12';

use base 'Exporter';

our @EXPORT = qw(before after around);
our @EXPORT_OK = (@EXPORT, qw(fresh install_modifier));
our %EXPORT_TAGS = (
    moose => [qw(before after around)],
    all   => \@EXPORT_OK,
);

BEGIN {
  *_HAS_READONLY = $] >= 5.008 ? sub(){1} : sub(){0};
}

our %MODIFIER_CACHE;

# for backward compatibility
sub _install_modifier; # -w
*_install_modifier = \&install_modifier;

sub install_modifier {
    my $into  = shift;
    my $type  = shift;
    my $code  = pop;
    my @names = @_;

    @names = @{ $names[0] } if ref($names[0]) eq 'ARRAY';

    return _fresh($into, $code, @names) if $type eq 'fresh';

    for my $name (@names) {
        my $hit = $into->can($name) or do {
            require Carp;
            Carp::confess("The method '$name' is not found in the inheritance hierarchy for class $into");
        };

        my $qualified = $into.'::'.$name;
        my $cache = $MODIFIER_CACHE{$into}{$name} ||= {
            before => [],
            after  => [],
            around => [],
        };

        # this must be the first modifier we're installing
        if (!exists($cache->{"orig"})) {
            no strict 'refs';

            # grab the original method (or undef if the method is inherited)
            $cache->{"orig"} = *{$qualified}{CODE};

            # the "innermost" method, the one that "around" will ultimately wrap
            $cache->{"wrapped"} = $cache->{"orig"} || $hit; #sub {
            #    # we can't cache this, because new methods or modifiers may be
            #    # added between now and when this method is called
            #    for my $package (@{ mro::get_linear_isa($into) }) {
            #        next if $package eq $into;
            #        my $code = *{$package.'::'.$name}{CODE};
            #        goto $code if $code;
            #    }
            #    require Carp;
            #    Carp::confess("$qualified\::$name disappeared?");
            #};
        }

        # keep these lists in the order the modifiers are called
        if ($type eq 'after') {
            push @{ $cache->{$type} }, $code;
        }
        else {
            unshift @{ $cache->{$type} }, $code;
        }

        # wrap the method with another layer of around. much simpler than
        # the Moose equivalent. :)
        if ($type eq 'around') {
            my $method = $cache->{wrapped};
            my $attrs = _sub_attrs($code);
            # a bare "sub :lvalue {...}" will be parsed as a label and an
            # indirect method call. force it to be treated as an expression
            # using +
            $cache->{wrapped} = eval "package $into; +sub $attrs { \$code->(\$method, \@_); };";
        }

        # install our new method which dispatches the modifiers, but only
        # if a new type was added
        if (@{ $cache->{$type} } == 1) {

            # avoid these hash lookups every method invocation
            my $before  = $cache->{"before"};
            my $after   = $cache->{"after"};

            # this is a coderef that changes every new "around". so we need
            # to take a reference to it. better a deref than a hash lookup
            my $wrapped = \$cache->{"wrapped"};

            my $attrs = _sub_attrs($cache->{wrapped});

            my $generated = "package $into;\n";
            $generated .= "sub $name $attrs {";

            # before is easy, it doesn't affect the return value(s)
            if (@$before) {
                $generated .= '
                    for my $method (@$before) {
                        $method->(@_);
                    }
                ';
            }

            if (@$after) {
                $generated .= '
                    my $ret;
                    if (wantarray) {
                        $ret = [$$wrapped->(@_)];
                        '.(_HAS_READONLY ? 'Internals::SvREADONLY(@$ret, 1);' : '').'
                    }
                    elsif (defined wantarray) {
                        $ret = \($$wrapped->(@_));
                    }
                    else {
                        $$wrapped->(@_);
                    }

                    for my $method (@$after) {
                        $method->(@_);
                    }

                    wantarray ? @$ret : $ret ? $$ret : ();
                '
            }
            else {
                $generated .= '$$wrapped->(@_);';
            }

            $generated .= '}';

            no strict 'refs';
            no warnings 'redefine';
            no warnings 'closure';
            eval $generated;
        };
    }
}

sub before {
    _install_modifier(scalar(caller), 'before', @_);
}

sub after {
    _install_modifier(scalar(caller), 'after', @_);
}

sub around {
    _install_modifier(scalar(caller), 'around', @_);
}

sub fresh {
    my $code = pop;
    my @names = @_;

    @names = @{ $names[0] } if ref($names[0]) eq 'ARRAY';

    _fresh(scalar(caller), $code, @names);
}

sub _fresh {
    my ($into, $code, @names) = @_;

    for my $name (@names) {
        if ($name !~ /\A [a-zA-Z_] [a-zA-Z0-9_]* \z/xms) {
            require Carp;
            Carp::confess("Invalid method name '$name'");
        }
        if ($into->can($name)) {
            require Carp;
            Carp::confess("Class $into already has a method named '$name'");
        }

        # We need to make sure that the installed method has its CvNAME in
        # the appropriate package; otherwise, it would be subject to
        # deletion if callers use namespace::autoclean.  If $code was
        # compiled in the target package, we can just install it directly;
        # otherwise, we'll need a different approach.  Using Sub::Name would
        # be fine in all cases, at the cost of introducing a dependency on
        # an XS-using, non-core module.  So instead we'll use string-eval to
        # create a new subroutine that wraps $code.
        if (_is_in_package($code, $into)) {
            no strict 'refs';
            *{"$into\::$name"} = $code;
        }
        else {
            no warnings 'closure'; # for 5.8.x
            my $attrs = _sub_attrs($code);
            eval "package $into; sub $name $attrs { \$code->(\@_) }";
        }
    }
}

sub _sub_attrs {
    my ($coderef) = @_;
    local *_sub = $coderef;
    local $@;
    (eval 'sub { _sub = 1 }') ? ':lvalue' : '';
}

sub _is_in_package {
    my ($coderef, $package) = @_;
    require B;
    my $cv = B::svref_2object($coderef);
    return $cv->GV->STASH->NAME eq $package;
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

Class::Method::Modifiers - Provides Moose-like method modifiers

=head1 VERSION

version 2.12

=head1 SYNOPSIS

    package Child;
    use parent 'Parent';
    use Class::Method::Modifiers;

    sub new_method { }

    before 'old_method' => sub {
        carp "old_method is deprecated, use new_method";
    };

    around 'other_method' => sub {
        my $orig = shift;
        my $ret = $orig->(@_);
        return $ret =~ /\d/ ? $ret : lc $ret;
    };

    after 'private', 'protected' => sub {
        debug "finished calling a dangerous method";
    };

    use Class::Method::Modifiers qw(fresh);

    fresh 'not_in_hierarchy' => sub {
        warn "freshly added method\n";
    };

=head1 DESCRIPTION

=for stopwords CLOS

Method modifiers are a convenient feature from the CLOS (Common Lisp Object
System) world.

In its most basic form, a method modifier is just a method that calls
C<< $self->SUPER::foo(@_) >>. I for one have trouble remembering that exact
invocation, so my classes seldom re-dispatch to their base classes. Very bad!

C<Class::Method::Modifiers> provides three modifiers: C<before>, C<around>, and
C<after>. C<before> and C<after> are run just before and after the method they
modify, but can not really affect that original method. C<around> is run in
place of the original method, with a hook to easily call that original method.
See the C<MODIFIERS> section for more details on how the particular modifiers
work.

One clear benefit of using C<Class::Method::Modifiers> is that you can define
multiple modifiers in a single namespace. These separate modifiers don't need
to know about each other. This makes top-down design easy. Have a base class
that provides the skeleton methods of each operation, and have plugins modify
those methods to flesh out the specifics.

Parent classes need not know about C<Class::Method::Modifiers>. This means you
should be able to modify methods in I<any> subclass. See
L<Term::VT102::ZeroBased> for an example of subclassing with
C<Class::Method::Modifiers>.

In short, C<Class::Method::Modifiers> solves the problem of making sure you
call C<< $self->SUPER::foo(@_) >>, and provides a cleaner interface for it.

As of version 1.00, C<Class::Method::Modifiers> is faster in some cases than
L<Moose>. See C<benchmark/method_modifiers.pl> in the L<Moose> distribution.

C<Class::Method::Modifiers> also provides an additional "modifier" type,
C<fresh>; see below.

=head1 MODIFIERS

All modifiers let you modify one or multiple methods at a time. The names of
multiple methods can be provided as a list or as an array-reference. Examples:

 before 'method' => sub { ... };
 before 'method1', 'method2' => sub { ... };
 before [ 'method1', 'method2' ] => sub { ... };

=head2 before method(s) => sub { ... };

C<before> is called before the method it is modifying. Its return value is
totally ignored. It receives the same C<@_> as the method it is modifying
would have received. You can modify the C<@_> the original method will receive
by changing C<$_[0]> and friends (or by changing anything inside a reference).
This is a feature!

=head2 after method(s) => sub { ... };

C<after> is called after the method it is modifying. Its return value is
totally ignored. It receives the same C<@_> as the method it is modifying
received, mostly. The original method can modify C<@_> (such as by changing
C<$_[0]> or references) and C<after> will see the modified version. If you
don't like this behavior, specify both a C<before> and C<after>, and copy the
C<@_> during C<before> for C<after> to use.

=head2 around method(s) => sub { ... };

C<around> is called instead of the method it is modifying. The method you're
overriding is passed in as the first argument (called C<$orig> by convention).
Watch out for contextual return values of C<$orig>.

You can use C<around> to:

=over 4

=item Pass C<$orig> a different C<@_>

    around 'method' => sub {
        my $orig = shift;
        my $self = shift;
        $orig->($self, reverse @_);
    };

=item Munge the return value of C<$orig>

    around 'method' => sub {
        my $orig = shift;
        ucfirst $orig->(@_);
    };

=item Avoid calling C<$orig> -- conditionally

    around 'method' => sub {
        my $orig = shift;
        return $orig->(@_) if time() % 2;
        return "no dice, captain";
    };

=back

=head2 fresh method(s) => sub { ... };

(Available since version 2.00)

Unlike the other modifiers, this does not modify an existing method.
Ordinarily, C<fresh> merely installs the coderef as a method in the
appropriate class; but if the class hierarchy already contains a method of
the same name, an exception is thrown.  The idea of this "modifier" is to
increase safety when subclassing.  Suppose you're writing a subclass of a
class Some::Base, and adding a new method:

    package My::Subclass;
    use base 'Some::Base';

    sub foo { ... }

If a later version of Some::Base also adds a new method named C<foo>, your
method will shadow that method.  Alternatively, you can use C<fresh>
to install the additional method into your subclass:

    package My::Subclass;
    use base 'Some::Base';

    use Class::Method::Modifiers 'fresh';

    fresh 'foo' => sub { ... };

Now upgrading Some::Base to a version with a conflicting C<foo> method will
cause an exception to be thrown; seeing that error will give you the
opportunity to fix the problem (perhaps by picking a different method name
in your subclass, or similar).

Creating fresh methods with C<install_modifier> (see below) provides a way
to get similar safety benefits when adding local monkeypatches to existing
classes; see L<http://aaroncrane.co.uk/talks/monkey_patching_subclassing/>.

For API compatibility reasons, this function is exported only when you ask
for it specifically, or for C<:all>.

=head2 install_modifier $package, $type, @names, sub { ... }

C<install_modifier> is like C<before>, C<after>, C<around>, and C<fresh> but
it also lets you dynamically select the modifier type ('before', 'after',
'around', 'fresh')
and package that the method modifiers are installed into. This expert-level
function is exported only when you ask for it specifically, or for C<:all>.

=head1 NOTES

All three normal modifiers; C<before>, C<after>, and C<around>; are exported
into your namespace by default. You may C<use Class::Method::Modifiers ()> to
avoid modifying your namespace. I may steal more features from L<Moose>, namely
C<super>, C<override>, C<inner>, C<augment>, and whatever the L<Moose> folks
come up with next.

Note that the syntax and semantics for these modifiers is directly borrowed
from L<Moose> (the implementations, however, are not).

L<Class::Trigger> shares a few similarities with C<Class::Method::Modifiers>,
and they even have some overlap in purpose -- both can be used to implement
highly pluggable applications. The difference is that L<Class::Trigger>
provides a mechanism for easily letting parent classes to invoke hooks defined
by other code. C<Class::Method::Modifiers> provides a way of
overriding/augmenting methods safely, and the parent class need not know about
it.

=head2 :lvalue METHODS

When adding C<before> or C<after> modifiers, the wrapper method will be
an lvalue method if the wrapped sub is, and assigning to the method
will propagate to the wrapped method as expected.  For C<around>
modifiers, it is the modifier sub that determines if the wrapper
method is an lvalue method.

=head1 CAVEATS

It is erroneous to modify a method that doesn't exist in your class's
inheritance hierarchy. If this occurs, an exception will be thrown when
the modifier is defined.

It doesn't yet play well with C<caller>. There are some C<TODO> tests for this.
Don't get your hopes up though!

Applying modifiers to array lvalue methods is not fully supported. Attempting
to assign to an array lvalue method that has an C<after> modifier applied will
result in an error.  Array lvalue methods are not well supported by perl in
general, and should be avoided.

=head1 MAJOR VERSION CHANGES

=for stopwords reimplementation

This module was bumped to 1.00 following a complete reimplementation, to
indicate breaking backwards compatibility. The "guard" modifier was removed,
and the internals are completely different.

The new version is a few times faster with half the code. It's now even faster
than Moose.

Any code that just used modifiers should not change in behavior, except to
become more correct. And, of course, faster. :)

=head1 SEE ALSO

=over 4

=item *

L<Class::Method::Modifiers::Fast>

=item *

L<Moose>

=item *

L<Class::Trigger>

=item *

L<Class::MOP::Method::Wrapped>

=item *

L<MRO::Compat>,

=item *

L<CLOS|https://en.wikipedia.org/wiki/Common_Lisp_Object_System>

=back

=head1 ACKNOWLEDGEMENTS

=for stopwords Stevan

Thanks to Stevan Little for L<Moose>, I would never have known about
method modifiers otherwise.

Thanks to Matt Trout and Stevan Little for their advice.

=head1 SUPPORT

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Class-Method-Modifiers>
(or L<bug-Class-Method-Modifiers@rt.cpan.org|mailto:bug-Class-Method-Modifiers@rt.cpan.org>).

=head1 AUTHOR

Shawn M Moore <sartak@gmail.com>

=head1 CONTRIBUTORS

=for stopwords Karen Etheridge Shawn M Moore Graham Knop Aaron Crane Peter Rabbitson Justin Hunter David Steinbrunner gfx mannih

=over 4

=item *

Karen Etheridge <ether@cpan.org>

=item *

Shawn M Moore <code@sartak.org>

=item *

Graham Knop <haarg@haarg.org>

=item *

Aaron Crane <arc@cpan.org>

=item *

Peter Rabbitson <ribasushi@cpan.org>

=item *

Justin Hunter <justin.d.hunter@gmail.com>

=item *

David Steinbrunner <dsteinbrunner@pobox.com>

=item *

gfx <gfuji@cpan.org>

=item *

mannih <github@lxxi.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2007 by Shawn M Moore.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut

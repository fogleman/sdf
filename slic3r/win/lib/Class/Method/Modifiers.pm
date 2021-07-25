#line 1 "Class/Method/Modifiers.pm"
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

#line 566

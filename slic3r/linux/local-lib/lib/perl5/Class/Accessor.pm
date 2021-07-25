package Class::Accessor;
require 5.00502;
use strict;
$Class::Accessor::VERSION = '0.34';

sub new {
    my($proto, $fields) = @_;
    my($class) = ref $proto || $proto;

    $fields = {} unless defined $fields;

    # make a copy of $fields.
    bless {%$fields}, $class;
}

sub mk_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('rw', @fields);
}

if (eval { require Sub::Name }) {
    Sub::Name->import;
}

{
    no strict 'refs';

    sub import {
        my ($class, @what) = @_;
        my $caller = caller;
        for (@what) {
            if (/^(?:antlers|moose-?like)$/i) {
                *{"${caller}::has"} = sub {
                    my ($f, %args) = @_;
                    $caller->_mk_accessors(($args{is}||"rw"), $f);
                };
                *{"${caller}::extends"} = sub {
                    @{"${caller}::ISA"} = @_;
                    unless (grep $_->can("_mk_accessors"), @_) {
                        push @{"${caller}::ISA"}, $class;
                    }
                };
                # we'll use their @ISA as a default, in case it happens to be
                # set already
                &{"${caller}::extends"}(@{"${caller}::ISA"});
            }
        }
    }

    sub follow_best_practice {
        my($self) = @_;
        my $class = ref $self || $self;
        *{"${class}::accessor_name_for"}  = \&best_practice_accessor_name_for;
        *{"${class}::mutator_name_for"}  = \&best_practice_mutator_name_for;
    }

    sub _mk_accessors {
        my($self, $access, @fields) = @_;
        my $class = ref $self || $self;
        my $ra = $access eq 'rw' || $access eq 'ro';
        my $wa = $access eq 'rw' || $access eq 'wo';

        foreach my $field (@fields) {
            my $accessor_name = $self->accessor_name_for($field);
            my $mutator_name = $self->mutator_name_for($field);
            if( $accessor_name eq 'DESTROY' or $mutator_name eq 'DESTROY' ) {
                $self->_carp("Having a data accessor named DESTROY  in '$class' is unwise.");
            }
            if ($accessor_name eq $mutator_name) {
                my $accessor;
                if ($ra && $wa) {
                    $accessor = $self->make_accessor($field);
                } elsif ($ra) {
                    $accessor = $self->make_ro_accessor($field);
                } else {
                    $accessor = $self->make_wo_accessor($field);
                }
                my $fullname = "${class}::$accessor_name";
                my $subnamed = 0;
                unless (defined &{$fullname}) {
                    subname($fullname, $accessor) if defined &subname;
                    $subnamed = 1;
                    *{$fullname} = $accessor;
                }
                if ($accessor_name eq $field) {
                    # the old behaviour
                    my $alias = "${class}::_${field}_accessor";
                    subname($alias, $accessor) if defined &subname and not $subnamed;
                    *{$alias} = $accessor unless defined &{$alias};
                }
            } else {
                my $fullaccname = "${class}::$accessor_name";
                my $fullmutname = "${class}::$mutator_name";
                if ($ra and not defined &{$fullaccname}) {
                    my $accessor = $self->make_ro_accessor($field);
                    subname($fullaccname, $accessor) if defined &subname;
                    *{$fullaccname} = $accessor;
                }
                if ($wa and not defined &{$fullmutname}) {
                    my $mutator = $self->make_wo_accessor($field);
                    subname($fullmutname, $mutator) if defined &subname;
                    *{$fullmutname} = $mutator;
                }
            }
        }
    }

}

sub mk_ro_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('ro', @fields);
}

sub mk_wo_accessors {
    my($self, @fields) = @_;

    $self->_mk_accessors('wo', @fields);
}

sub best_practice_accessor_name_for {
    my ($class, $field) = @_;
    return "get_$field";
}

sub best_practice_mutator_name_for {
    my ($class, $field) = @_;
    return "set_$field";
}

sub accessor_name_for {
    my ($class, $field) = @_;
    return $field;
}

sub mutator_name_for {
    my ($class, $field) = @_;
    return $field;
}

sub set {
    my($self, $key) = splice(@_, 0, 2);

    if(@_ == 1) {
        $self->{$key} = $_[0];
    }
    elsif(@_ > 1) {
        $self->{$key} = [@_];
    }
    else {
        $self->_croak("Wrong number of arguments received");
    }
}

sub get {
    my $self = shift;

    if(@_ == 1) {
        return $self->{$_[0]};
    }
    elsif( @_ > 1 ) {
        return @{$self}{@_};
    }
    else {
        $self->_croak("Wrong number of arguments received");
    }
}

sub make_accessor {
    my ($class, $field) = @_;

    return sub {
        my $self = shift;

        if(@_) {
            return $self->set($field, @_);
        } else {
            return $self->get($field);
        }
    };
}

sub make_ro_accessor {
    my($class, $field) = @_;

    return sub {
        my $self = shift;

        if (@_) {
            my $caller = caller;
            $self->_croak("'$caller' cannot alter the value of '$field' on objects of class '$class'");
        }
        else {
            return $self->get($field);
        }
    };
}

sub make_wo_accessor {
    my($class, $field) = @_;

    return sub {
        my $self = shift;

        unless (@_) {
            my $caller = caller;
            $self->_croak("'$caller' cannot access the value of '$field' on objects of class '$class'");
        }
        else {
            return $self->set($field, @_);
        }
    };
}


use Carp ();

sub _carp {
    my ($self, $msg) = @_;
    Carp::carp($msg || $self);
    return;
}

sub _croak {
    my ($self, $msg) = @_;
    Carp::croak($msg || $self);
    return;
}

1;

__END__

=head1 NAME

  Class::Accessor - Automated accessor generation

=head1 SYNOPSIS

  package Foo;
  use base qw(Class::Accessor);
  Foo->follow_best_practice;
  Foo->mk_accessors(qw(name role salary));

  # or if you prefer a Moose-like interface...
 
  package Foo;
  use Class::Accessor "antlers";
  has name => ( is => "rw", isa => "Str" );
  has role => ( is => "rw", isa => "Str" );
  has salary => ( is => "rw", isa => "Num" );

  # Meanwhile, in a nearby piece of code!
  # Class::Accessor provides new().
  my $mp = Foo->new({ name => "Marty", role => "JAPH" });

  my $job = $mp->role;  # gets $mp->{role}
  $mp->salary(400000);  # sets $mp->{salary} = 400000 # I wish
  
  # like my @info = @{$mp}{qw(name role)}
  my @info = $mp->get(qw(name role));
  
  # $mp->{salary} = 400000
  $mp->set('salary', 400000);


=head1 DESCRIPTION

This module automagically generates accessors/mutators for your class.

Most of the time, writing accessors is an exercise in cutting and
pasting.  You usually wind up with a series of methods like this:

    sub name {
        my $self = shift;
        if(@_) {
            $self->{name} = $_[0];
        }
        return $self->{name};
    }

    sub salary {
        my $self = shift;
        if(@_) {
            $self->{salary} = $_[0];
        }
        return $self->{salary};
    }

  # etc...

One for each piece of data in your object.  While some will be unique,
doing value checks and special storage tricks, most will simply be
exercises in repetition.  Not only is it Bad Style to have a bunch of
repetitious code, but it's also simply not lazy, which is the real
tragedy.

If you make your module a subclass of Class::Accessor and declare your
accessor fields with mk_accessors() then you'll find yourself with a
set of automatically generated accessors which can even be
customized!

The basic set up is very simple:

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_accessors( qw(far bar car) );

Done.  Foo now has simple far(), bar() and car() accessors
defined.

Alternatively, if you want to follow Damian's I<best practice> guidelines 
you can use:

    package Foo;
    use base qw(Class::Accessor);
    Foo->follow_best_practice;
    Foo->mk_accessors( qw(far bar car) );

B<Note:> you must call C<follow_best_practice> before calling C<mk_accessors>.

=head2 Moose-like

By popular demand we now have a simple Moose-like interface.  You can now do:

    package Foo;
    use Class::Accessor "antlers";
    has far => ( is => "rw" );
    has bar => ( is => "rw" );
    has car => ( is => "rw" );

Currently only the C<is> attribute is supported.

=head1 CONSTRUCTOR

Class::Accessor provides a basic constructor, C<new>.  It generates a
hash-based object and can be called as either a class method or an
object method.  

=head2 new

    my $obj = Foo->new;
    my $obj = $other_obj->new;

    my $obj = Foo->new(\%fields);
    my $obj = $other_obj->new(\%fields);

It takes an optional %fields hash which is used to initialize the
object (handy if you use read-only accessors).  The fields of the hash
correspond to the names of your accessors, so...

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_accessors('foo');

    my $obj = Foo->new({ foo => 42 });
    print $obj->foo;    # 42

however %fields can contain anything, new() will shove them all into
your object.

=head1 MAKING ACCESSORS

=head2 follow_best_practice

In Damian's Perl Best Practices book he recommends separate get and set methods
with the prefix set_ and get_ to make it explicit what you intend to do.  If you
want to create those accessor methods instead of the default ones, call:

    __PACKAGE__->follow_best_practice

B<before> you call any of the accessor-making methods.

=head2 accessor_name_for / mutator_name_for

You may have your own crazy ideas for the names of the accessors, so you can
make those happen by overriding C<accessor_name_for> and C<mutator_name_for> in
your subclass.  (I copied that idea from Class::DBI.)

=head2 mk_accessors

    __PACKAGE__->mk_accessors(@fields);

This creates accessor/mutator methods for each named field given in
@fields.  Foreach field in @fields it will generate two accessors.
One called "field()" and the other called "_field_accessor()".  For
example:

    # Generates foo(), _foo_accessor(), bar() and _bar_accessor().
    __PACKAGE__->mk_accessors(qw(foo bar));

See L<CAVEATS AND TRICKS/"Overriding autogenerated accessors">
for details.

=head2 mk_ro_accessors

  __PACKAGE__->mk_ro_accessors(@read_only_fields);

Same as mk_accessors() except it will generate read-only accessors
(ie. true accessors).  If you attempt to set a value with these
accessors it will throw an exception.  It only uses get() and not
set().

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_ro_accessors(qw(foo bar));

    # Let's assume we have an object $foo of class Foo...
    print $foo->foo;  # ok, prints whatever the value of $foo->{foo} is
    $foo->foo(42);    # BOOM!  Naughty you.


=head2 mk_wo_accessors

  __PACKAGE__->mk_wo_accessors(@write_only_fields);

Same as mk_accessors() except it will generate write-only accessors
(ie. mutators).  If you attempt to read a value with these accessors
it will throw an exception.  It only uses set() and not get().

B<NOTE> I'm not entirely sure why this is useful, but I'm sure someone
will need it.  If you've found a use, let me know.  Right now it's here
for orthoginality and because it's easy to implement.

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_wo_accessors(qw(foo bar));

    # Let's assume we have an object $foo of class Foo...
    $foo->foo(42);      # OK.  Sets $self->{foo} = 42
    print $foo->foo;    # BOOM!  Can't read from this accessor.

=head1 Moose!

If you prefer a Moose-like interface to create accessors, you can use C<has> by
importing this module like this:

  use Class::Accessor "antlers";

or

  use Class::Accessor "moose-like";

Then you can declare accessors like this:

  has alpha => ( is => "rw", isa => "Str" );
  has beta  => ( is => "ro", isa => "Str" );
  has gamma => ( is => "wo", isa => "Str" );

Currently only the C<is> attribute is supported.  And our C<is> also supports
the "wo" value to make a write-only accessor.

If you are using the Moose-like interface then you should use the C<extends>
rather than tweaking your C<@ISA> directly.  Basically, replace

  @ISA = qw/Foo Bar/;

with

  extends(qw/Foo Bar/);

=head1 DETAILS

An accessor generated by Class::Accessor looks something like
this:

    # Your foo may vary.
    sub foo {
        my($self) = shift;
        if(@_) {    # set
            return $self->set('foo', @_);
        }
        else {
            return $self->get('foo');
        }
    }

Very simple.  All it does is determine if you're wanting to set a
value or get a value and calls the appropriate method.
Class::Accessor provides default get() and set() methods which
your class can override.  They're detailed later.

=head2 Modifying the behavior of the accessor

Rather than actually modifying the accessor itself, it is much more
sensible to simply override the two key methods which the accessor
calls.  Namely set() and get().

If you -really- want to, you can override make_accessor().

=head2 set

    $obj->set($key, $value);
    $obj->set($key, @values);

set() defines how generally one stores data in the object.

override this method to change how data is stored by your accessors.

=head2 get

    $value  = $obj->get($key);
    @values = $obj->get(@keys);

get() defines how data is retreived from your objects.

override this method to change how it is retreived.

=head2 make_accessor

    $accessor = __PACKAGE__->make_accessor($field);

Generates a subroutine reference which acts as an accessor for the given
$field.  It calls get() and set().

If you wish to change the behavior of your accessors, try overriding
get() and set() before you start mucking with make_accessor().

=head2 make_ro_accessor

    $read_only_accessor = __PACKAGE__->make_ro_accessor($field);

Generates a subroutine refrence which acts as a read-only accessor for
the given $field.  It only calls get().

Override get() to change the behavior of your accessors.

=head2 make_wo_accessor

    $read_only_accessor = __PACKAGE__->make_wo_accessor($field);

Generates a subroutine refrence which acts as a write-only accessor
(mutator) for the given $field.  It only calls set().

Override set() to change the behavior of your accessors.

=head1 EXCEPTIONS

If something goes wrong Class::Accessor will warn or die by calling Carp::carp
or Carp::croak.  If you don't like this you can override _carp() and _croak() in
your subclass and do whatever else you want.

=head1 EFFICIENCY

Class::Accessor does not employ an autoloader, thus it is much faster
than you'd think.  Its generated methods incur no special penalty over
ones you'd write yourself.

  accessors:
              Rate  Basic   Fast Faster Direct
  Basic   367589/s     --   -51%   -55%   -89%
  Fast    747964/s   103%     --    -9%   -77%
  Faster  819199/s   123%    10%     --   -75%
  Direct 3245887/s   783%   334%   296%     --

  mutators:
              Rate    Acc   Fast Faster Direct
  Acc     265564/s     --   -54%   -63%   -91%
  Fast    573439/s   116%     --   -21%   -80%
  Faster  724710/s   173%    26%     --   -75%
  Direct 2860979/s   977%   399%   295%     --

Class::Accessor::Fast is faster than methods written by an average programmer
(where "average" is based on Schwern's example code).

Class::Accessor is slower than average, but more flexible.

Class::Accessor::Faster is even faster than Class::Accessor::Fast.  It uses an
array internally, not a hash.  This could be a good or bad feature depending on
your point of view.

Direct hash access is, of course, much faster than all of these, but it
provides no encapsulation.

Of course, it's not as simple as saying "Class::Accessor is slower than
average".  These are benchmarks for a simple accessor.  If your accessors do
any sort of complicated work (such as talking to a database or writing to a
file) the time spent doing that work will quickly swamp the time spend just
calling the accessor.  In that case, Class::Accessor and the ones you write
will be roughly the same speed.


=head1 EXAMPLES

Here's an example of generating an accessor for every public field of
your class.

    package Altoids;
    
    use base qw(Class::Accessor Class::Fields);
    use fields qw(curiously strong mints);
    Altoids->mk_accessors( Altoids->show_fields('Public') );

    sub new {
        my $proto = shift;
        my $class = ref $proto || $proto;
        return fields::new($class);
    }

    my Altoids $tin = Altoids->new;

    $tin->curiously('Curiouser and curiouser');
    print $tin->{curiously};    # prints 'Curiouser and curiouser'

    
    # Subclassing works, too.
    package Mint::Snuff;
    use base qw(Altoids);

    my Mint::Snuff $pouch = Mint::Snuff->new;
    $pouch->strong('Blow your head off!');
    print $pouch->{strong};     # prints 'Blow your head off!'


Here's a simple example of altering the behavior of your accessors.

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_accessors(qw(this that up down));

    sub get {
        my $self = shift;

        # Note every time someone gets some data.
        print STDERR "Getting @_\n";

        $self->SUPER::get(@_);
    }

    sub set {
        my ($self, $key) = splice(@_, 0, 2);

        # Note every time someone sets some data.
        print STDERR "Setting $key to @_\n";

        $self->SUPER::set($key, @_);
    }


=head1 CAVEATS AND TRICKS

Class::Accessor has to do some internal wackiness to get its
job done quickly and efficiently.  Because of this, there's a few
tricks and traps one must know about.

Hey, nothing's perfect.

=head2 Don't make a field called DESTROY

This is bad.  Since DESTROY is a magical method it would be bad for us
to define an accessor using that name.  Class::Accessor will
carp if you try to use it with a field named "DESTROY".

=head2 Overriding autogenerated accessors

You may want to override the autogenerated accessor with your own, yet
have your custom accessor call the default one.  For instance, maybe
you want to have an accessor which checks its input.  Normally, one
would expect this to work:

    package Foo;
    use base qw(Class::Accessor);
    Foo->mk_accessors(qw(email this that whatever));

    # Only accept addresses which look valid.
    sub email {
        my($self) = shift;
        my($email) = @_;

        if( @_ ) {  # Setting
            require Email::Valid;
            unless( Email::Valid->address($email) ) {
                carp("$email doesn't look like a valid address.");
                return;
            }
        }

        return $self->SUPER::email(@_);
    }

There's a subtle problem in the last example, and it's in this line:

    return $self->SUPER::email(@_);

If we look at how Foo was defined, it called mk_accessors() which
stuck email() right into Foo's namespace.  There *is* no
SUPER::email() to delegate to!  Two ways around this... first is to
make a "pure" base class for Foo.  This pure class will generate the
accessors and provide the necessary super class for Foo to use:

    package Pure::Organic::Foo;
    use base qw(Class::Accessor);
    Pure::Organic::Foo->mk_accessors(qw(email this that whatever));

    package Foo;
    use base qw(Pure::Organic::Foo);

And now Foo::email() can override the generated
Pure::Organic::Foo::email() and use it as SUPER::email().

This is probably the most obvious solution to everyone but me.
Instead, what first made sense to me was for mk_accessors() to define
an alias of email(), _email_accessor().  Using this solution,
Foo::email() would be written with:

    return $self->_email_accessor(@_);

instead of the expected SUPER::email().


=head1 AUTHORS

Copyright 2009 Marty Pauley <marty+perl@kasei.com>

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.  That means either (a) the GNU General Public
License or (b) the Artistic License.

=head2 ORIGINAL AUTHOR

Michael G Schwern <schwern@pobox.com>

=head2 THANKS

Liz and RUZ for performance tweaks.

Tels, for his big feature request/bug report.

Various presenters at YAPC::Asia 2009 for criticising the non-Moose interface.

=head1 SEE ALSO

See L<Class::Accessor::Fast> and L<Class::Accessor::Faster> if speed is more
important than flexibility.

These are some modules which do similar things in different ways
L<Class::Struct>, L<Class::Methodmaker>, L<Class::Generate>,
L<Class::Class>, L<Class::Contract>, L<Moose>, L<Mouse>

See L<Class::DBI> for an example of this module in use.

=cut

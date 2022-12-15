package enum;

use 5.006;
use strict;
use warnings;
no strict 'refs';  # Let's just make this very clear right off

use Carp;
our $VERSION = '1.11';

my $Ident = '[^\W_0-9]\w*';

sub ENUM    () { 1 }
sub BITMASK () { 2 }

sub import {
    my $class   = shift;
    @_ or return;       # Ignore 'use enum;'
    my $pkg     = caller() . '::';
    my $prefix  = '';   # default no prefix 
    my $index   = 0;    # default start index
    my $mode    = ENUM; # default to enum

    ## Pragmas should be as fast as they can be, so we inline some
    ## pieces.
    foreach (@_) {
        ## Plain tag is most common case
        if (/^$Ident$/o) {
            my $n = $index;

            if ($mode == ENUM) {
                $index++;
            }
            elsif ($mode == BITMASK) {
                $index ||= 1;
                $index *= 2;
                if ( $index & ($index - 1) ) {
                    croak (
                        "$index is not a valid single bitmask "
                        . " (Maybe you overflowed your system's max int value?)"
                    );
                }
            }
            else {
                confess qq(Can't Happen: mode $mode invalid);
            }

            *{"$pkg$prefix$_"} = eval "sub () { $n }";
        }

        ## Index change
        elsif (/^($Ident)=(-?)(.+)$/o) {
            my $name= $1;
            my $neg = $2;
            $index  = $3;

            ## Convert non-decimal numerics to decimal
            if ($index =~ /^0x[0-9a-f]+$/i) {    ## Hex
                $index = hex $index;
            }
            elsif ($index =~ /^0[0-9]/) {          ## Octal
                $index = oct $index;
            }
            elsif ($index !~ /[^0-9_]/) {        ## 123_456 notation
                $index =~ s/_//g;
            }

            ## Force numeric context, but only in numeric context
            if ($index =~ /\D/) {
                $index  = "$neg$index";
            }
            else {
                $index  = "$neg$index";
                $index  += 0;
            }

            my $n   = $index;

            if ($mode == BITMASK) {
                ($index & ($index - 1))
                    and croak "$index is not a valid single bitmask";
                $index *= 2;
            }
            elsif ($mode == ENUM) {
                $index++;
            }
            else {
                confess qq(Can't Happen: mode $mode invalid);
            }

            *{"$pkg$prefix$name"} = eval "sub () { $n }";
        }

        ## Prefix/option change
        elsif (/^([A-Z]*):($Ident)?(=?)(-?)(.*)/) {
            ## Option change
            if ($1) {
                if      ($1 eq 'ENUM')      { $mode = ENUM;     $index = 0 }
                elsif   ($1 eq 'BITMASK')   { $mode = BITMASK;  $index = 1 }
                else    { croak qq(Invalid enum option '$1') }
            }

            my $neg = $4;

            ## Index change too?
            if ($3) {
                if (length $5) {
                    $index = $5;

                    ## Convert non-decimal numerics to decimal
                    if ($index =~ /^0x[0-9a-f]+$/i) {    ## Hex
                        $index = hex $index;
                    }
                    elsif ($index =~ /^0[0-9]/) {          ## Oct
                        $index = oct $index;
                    }
                    elsif ($index !~ /[^0-9_]/) {        ## 123_456 notation
                        $index =~ s/_//g;
                    }

                    ## Force numeric context, but only in numeric context
                    if ($index =~ /[^0-9]/) {
                        $index  = "$neg$index";
                    }
                    else {
                        $index  = "$neg$index";
                        $index  += 0;
                    }

                    ## Bitmask mode must check index changes
                    if ($mode == BITMASK) {
                        ($index & ($index - 1))
                            and croak "$index is not a valid single bitmask";
                    }
                }
                else {
                    croak qq(No index value defined after "=");
                }
            }

            ## Incase it's a null prefix
            $prefix = defined $2 ? $2 : '';
        }

        ## A..Z case magic lists
        elsif (/^($Ident)\.\.($Ident)$/o) {
            ## Almost never used, so check last
            foreach my $name ("$1" .. "$2") {
                my $n = $index;

                if ($mode == BITMASK) {
                    ($index & ($index - 1))
                        and croak "$index is not a valid single bitmask";
                    $index *= 2;
                }
                elsif ($mode == ENUM) {
                    $index++;
                }
                else {
                    confess qq(Can't Happen: mode $mode invalid);
                }

                *{"$pkg$prefix$name"} = eval "sub () { $n }";
            }
        }

        else {
            croak qq(Can't define "$_" as enum type (name contains invalid characters));
        }
    }
}

1;

__END__


=head1 NAME

enum - C style enumerated types and bitmask flags in Perl

=head1 SYNOPSIS

  use enum qw(Sun Mon Tue Wed Thu Fri Sat);
  # Sun == 0, Mon == 1, etc

  use enum qw(Forty=40 FortyOne Five=5 Six Seven);
  # Yes, you can change the start indexs at any time as in C

  use enum qw(:Prefix_ One Two Three);
  ## Creates Prefix_One, Prefix_Two, Prefix_Three

  use enum qw(:Letters_ A..Z);
  ## Creates Letters_A, Letters_B, Letters_C, ...

  use enum qw(
      :Months_=0 Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
      :Days_=0   Sun Mon Tue Wed Thu Fri Sat
      :Letters_=20 A..Z
  );
  ## Prefixes can be changed mid list and can have index changes too

  use enum qw(BITMASK:LOCK_ SH EX NB UN);
  ## Creates bitmask constants for LOCK_SH == 1, LOCK_EX == 2,
  ## LOCK_NB == 4, and LOCK_UN == 8.
  ## NOTE: This example is only valid on FreeBSD-2.2.5 however, so don't
  ## actually do this.  Import from Fnctl instead.

=head1 DESCRIPTION

This module is used to define a set of constants with ordered numeric values,
similar to the C<enum> type in the C programming language.
You can also define bitmask constants, where the value assigned to each
constant has exactly one bit set (eg 1, 2, 4, 8, etc).

What are enumerations good for?
Typical uses would be for giving mnemonic names to indexes of arrays.
Such arrays might be a list of months, days, or a return value index from
a function such as localtime():

  use enum qw(
      :Months_=0 Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec
      :Days_=0   Sun Mon Tue Wed Thu Fri Sat
      :LC_=0     Sec Min Hour MDay Mon Year WDay YDay Isdst
  );

  if ((localtime)[LC_Mon] == Months_Jan) {
      print "It's January!\n";
  }
  if ((localtime)[LC_WDay] == Days_Fri) {
      print "It's Friday!\n";
  }

This not only reads easier, but can also be typo-checked at compile time when
run under B<use strict>.  That is, if you misspell B<Days_Fri> as B<Days_Fry>,
you'll generate a compile error.

=head1 BITMASKS

The B<BITMASK> option allows the easy creation of bitmask constants such as
functions like flock() and sysopen() use.  These are also very useful for your
own code as they allow you to efficiently store many true/false options within
a single integer.

    use enum qw(BITMASK: MY_ FOO BAR CAT DOG);

    my $foo = 0;
    $foo |= MY_FOO;
    $foo |= MY_DOG;

    if ($foo & MY_DOG) {
        print "foo has the MY_DOG option set\n";
    }
    if ($foo & (MY_BAR | MY_DOG)) {
        print "foo has either the MY_BAR or MY_DOG option set\n"
    }

    $foo ^= MY_DOG;  ## Turn MY_DOG option off (set its bit to false)

When using bitmasks, remember that you must use the bitwise operators,
B<|>, B<&>, B<^>, and B<~>.
If you try to do an operation like C<$foo += MY_DOG;> and the B<MY_DOG> bit
has already been set,
you'll end up setting other bits you probably didn't want to set.
You'll find the documentation for these operators in the B<perlop> manpage.

You can set a starting index for bitmasks
just as you can for normal B<enum> values.
But if the given index isn't a power of 2,
then it won't resolve to a single bit and therefore
will generate a compile error.
Because of this, whenever you set the B<BITFIELD:> directive,
the index is automatically set to 1.
If you wish to go back to normal B<enum> mode,
use the B<ENUM:> directive.
Similarly to the B<BITFIELD> directive,
the B<ENUM:> directive resets the index to 0.
Here's an example:

  use enum qw(
      BITMASK:BITS_ FOO BAR CAT DOG
      ENUM: FALSE TRUE
      ENUM: NO YES
      BITMASK: ONE TWO FOUR EIGHT SIX_TEEN
  );

In this case, B<BITS_FOO, BITS_BAR, BITS_CAT, and BITS_DOG> equal 1, 2, 4 and
8 respectively.  B<FALSE and TRUE> equal 0 and 1.  B<NO and YES> also equal
0 and 1.  And B<ONE, TWO, FOUR, EIGHT, and SIX_TEEN> equal, you guessed it, 1,
2, 4, 8, and 16.

=head1 BUGS

Enum names can not be the same as method, function, or constant names.  This
is probably a Good Thing[tm].

No way (that I know of) to cause compile time errors when one of these enum names get
redefined.  IMHO, there is absolutely no time when redefining a sub is a Good Thing[tm],
and should be taken out of the language, or at least have a pragma that can cause it
to be a compile time error.

Enumerated types are package scoped just like constants, not block scoped as some
other pragma modules are.

It supports A..Z nonsense.
Can anyone give me a Real World[tm] reason why anyone would
ever use this feature...?

=head1 SEE ALSO

There are a number of modules that can be used to define enumerations:
L<Class::Enum>, L<enum::fields>, L<enum::hash>, L<Readonly::Enum>,
L<Object::Enum>, L<Enumeration>.

If you're using L<Moose>, then L<MooseX::Enumeration> may be of interest.
L<Type::Tiny::Enum> is part of the
L<Type-Tiny|https://metacpan.org/release/Type-Tiny> distribution.

There are many CPAN modules related to defining constants in Perl;
here are some of the best ones:
L<constant>, L<Const::Fast>, L<constant::lexical>, L<constant::our>.

Neil Bowers has written a
L<review of CPAN modules for definining constants|http://neilb.org/reviews/constants.html>,
which covers all such modules.

=head1 REPOSITORY

L<https://github.com/neilb/enum>

=head1 AUTHOR

Originally written by Byron Brummer (ZENIN),
now maintained by Neil Bowers E<lt>neilb@cpan.orgE<gt>.

Based on early versions of the B<constant> module by Tom Phoenix.

Original implementation of an interface of Tom Phoenix's
design by Benjamin Holzman, for which we borrow the basic
parse algorithm layout.

=head1 COPYRIGHT AND LICENSE

Copyright 1998 (c) Byron Brummer.
Copyright 1998 (c) OMIX, Inc.

Permission to use, modify, and redistribute this module granted under
the same terms as Perl itself.

=cut


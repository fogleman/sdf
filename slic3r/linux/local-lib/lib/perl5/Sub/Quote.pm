package Sub::Quote;

sub _clean_eval { eval $_[0] }

use strict;
use warnings;

use Sub::Defer qw(defer_sub);
use Scalar::Util qw(weaken);
use Exporter qw(import);
use Carp qw(croak);
BEGIN { our @CARP_NOT = qw(Sub::Defer) }
use B ();
BEGIN {
  *_HAVE_PERLSTRING = defined &B::perlstring ? sub(){1} : sub(){0};
}

our $VERSION = '2.003001';
$VERSION = eval $VERSION;

our @EXPORT = qw(quote_sub unquote_sub quoted_from_sub qsub);
our @EXPORT_OK = qw(quotify capture_unroll inlinify sanitize_identifier);

our %QUOTED;

sub quotify {
  no warnings 'numeric';
  ! defined $_[0]     ? 'undef()'
  # numeric detection
  : (length( (my $dummy = '') & $_[0] )
    && 0 + $_[0] eq $_[0]
    && $_[0] * 0 == 0
  ) ? $_[0]
  : _HAVE_PERLSTRING  ? B::perlstring($_[0])
  : qq["\Q$_[0]\E"];
}

sub sanitize_identifier {
  my $name = shift;
  $name =~ s/([_\W])/sprintf('_%x', ord($1))/ge;
  $name;
}

sub capture_unroll {
  my ($from, $captures, $indent) = @_;
  join(
    '',
    map {
      /^([\@\%\$])/
        or croak "capture key should start with \@, \% or \$: $_";
      (' ' x $indent).qq{my ${_} = ${1}{${from}->{${\quotify $_}}};\n};
    } keys %$captures
  );
}

sub inlinify {
  my ($code, $args, $extra, $local) = @_;
  my $do = 'do { '.($extra||'');
  if ($code =~ s/^(\s*package\s+([a-zA-Z0-9:]+);)//) {
    $do .= $1;
  }
  if ($code =~ s{
    \A((?:\#\ BEGIN\ quote_sub\ PRELUDE\n.*?\#\ END\ quote_sub\ PRELUDE\n)?\s*)
    (^\s*) my \s* \(([^)]+)\) \s* = \s* \@_;
  }{}xms) {
    my ($pre, $indent, $code_args) = ($1, $2, $3);
    $do .= $pre;
    if ($code_args ne $args) {
      $do .= $indent . 'my ('.$code_args.') = ('.$args.'); ';
    }
  }
  elsif ($local || $args ne '@_') {
    $do .= ($local ? 'local ' : '').'@_ = ('.$args.'); ';
  }
  $do.$code.' }';
}

sub quote_sub {
  # HOLY DWIMMERY, BATMAN!
  # $name => $code => \%captures => \%options
  # $name => $code => \%captures
  # $name => $code
  # $code => \%captures => \%options
  # $code
  my $options =
    (ref($_[-1]) eq 'HASH' and ref($_[-2]) eq 'HASH')
      ? pop
      : {};
  my $captures = ref($_[-1]) eq 'HASH' ? pop : undef;
  undef($captures) if $captures && !keys %$captures;
  my $code = pop;
  my $name = $_[0];
  if ($name) {
    my $subname = $name;
    my $package = $subname =~ s/(.*)::// ? $1 : caller;
    $name = join '::', $package, $subname;
    croak qq{package name "$package" too long!}
      if length $package > 252;
    croak qq{package name "$package" is not valid!}
      unless $package =~ /^[^\d\W]\w*(?:::\w+)*$/;
    croak qq{sub name "$subname" too long!}
      if length $subname > 252;
    croak qq{sub name "$subname" is not valid!}
      unless $subname =~ /^[^\d\W]\w*$/;
  }
  my @caller = caller(0);
  my $attributes = $options->{attributes};
  my $quoted_info = {
    name     => $name,
    code     => $code,
    captures => $captures,
    package      => (exists $options->{package}      ? $options->{package}      : $caller[0]),
    hints        => (exists $options->{hints}        ? $options->{hints}        : $caller[8]),
    warning_bits => (exists $options->{warning_bits} ? $options->{warning_bits} : $caller[9]),
    hintshash    => (exists $options->{hintshash}    ? $options->{hintshash}    : $caller[10]),
    ($attributes ? (attributes => $attributes) : ()),
  };
  my $unquoted;
  weaken($quoted_info->{unquoted} = \$unquoted);
  if ($options->{no_defer}) {
    my $fake = \my $var;
    local $QUOTED{$fake} = $quoted_info;
    my $sub = unquote_sub($fake);
    Sub::Defer::_install_coderef($name, $sub) if $name && !$options->{no_install};
    return $sub;
  }
  else {
    my $deferred = defer_sub +($options->{no_install} ? undef : $name) => sub {
      $unquoted if 0;
      unquote_sub($quoted_info->{deferred});
    }, ($attributes ? { attributes => $attributes } : ());
    weaken($quoted_info->{deferred} = $deferred);
    weaken($QUOTED{$deferred} = $quoted_info);
    return $deferred;
  }
}

sub _context {
  my $info = shift;
  $info->{context} ||= do {
    my ($package, $hints, $warning_bits, $hintshash)
      = @{$info}{qw(package hints warning_bits hintshash)};

    $info->{context}
      ="# BEGIN quote_sub PRELUDE\n"
      ."package $package;\n"
      ."BEGIN {\n"
      ."  \$^H = ".quotify($hints).";\n"
      ."  \${^WARNING_BITS} = ".quotify($warning_bits).";\n"
      ."  \%^H = (\n"
      . join('', map
      "    ".quotify($_)." => ".quotify($hintshash->{$_}).",\n",
        keys %$hintshash)
      ."  );\n"
      ."}\n"
      ."# END quote_sub PRELUDE\n";
  };
}

sub quoted_from_sub {
  my ($sub) = @_;
  my $quoted_info = $QUOTED{$sub||''} or return undef;
  my ($name, $code, $captures, $unquoted, $deferred)
    = @{$quoted_info}{qw(name code captures unquoted deferred)};
  $code = _context($quoted_info) . $code;
  $unquoted &&= $$unquoted;
  if (($deferred && $deferred eq $sub)
      || ($unquoted && $unquoted eq $sub)) {
    return [ $name, $code, $captures, $unquoted, $deferred ];
  }
  return undef;
}

sub unquote_sub {
  my ($sub) = @_;
  my $quoted_info = $QUOTED{$sub} or return undef;
  my $unquoted = $quoted_info->{unquoted};
  unless ($unquoted && $$unquoted) {
    my ($name, $code, $captures, $package, $attributes)
      = @{$quoted_info}{qw(name code captures package attributes)};

    ($package, $name) = $name =~ /(.*)::(.*)/
      if $name;

    my %captures = $captures ? %$captures : ();
    $captures{'$_UNQUOTED'} = \$unquoted;
    $captures{'$_QUOTED'} = \$quoted_info;

    my $make_sub
      = "{\n"
      . capture_unroll("\$_[1]", \%captures, 2)
      . "  package ${package};\n"
      . (
        $name
          # disable the 'variable $x will not stay shared' warning since
          # we're not letting it escape from this scope anyway so there's
          # nothing trying to share it
          ? "  no warnings 'closure';\n  sub ${name} "
          : "  \$\$_UNQUOTED = sub "
      )
      . ($attributes ? join('', map ":$_ ", @$attributes) : '') . "{\n"
      . "  (\$_QUOTED,\$_UNQUOTED) if 0;\n"
      . _context($quoted_info)
      . $code
      . "  }".($name ? "\n  \$\$_UNQUOTED = \\&${name}" : '') . ";\n"
      . "}\n"
      . "1;\n";
    $ENV{SUB_QUOTE_DEBUG} && warn $make_sub;
    {
      no strict 'refs';
      local *{"${package}::${name}"} if $name;
      my ($success, $e);
      {
        local $@;
        $success = _clean_eval($make_sub, \%captures);
        $e = $@;
      }
      unless ($success) {
        croak "Eval went very, very wrong:\n\n${make_sub}\n\n$e";
      }
      weaken($QUOTED{$$unquoted} = $quoted_info);
    }
  }
  $$unquoted;
}

sub qsub ($) {
  goto &quote_sub;
}

sub CLONE {
  %QUOTED = map { defined $_ ? (
    $_->{unquoted} && ${$_->{unquoted}} ? (${ $_->{unquoted} } => $_) : (),
    $_->{deferred} ? ($_->{deferred} => $_) : (),
  ) : () } values %QUOTED;
  weaken($_) for values %QUOTED;
}

1;
__END__

=encoding utf-8

=head1 NAME

Sub::Quote - efficient generation of subroutines via string eval

=head1 SYNOPSIS

 package Silly;

 use Sub::Quote qw(quote_sub unquote_sub quoted_from_sub);

 quote_sub 'Silly::kitty', q{ print "meow" };

 quote_sub 'Silly::doggy', q{ print "woof" };

 my $sound = 0;

 quote_sub 'Silly::dagron',
   q{ print ++$sound % 2 ? 'burninate' : 'roar' },
   { '$sound' => \$sound };

And elsewhere:

 Silly->kitty;  # meow
 Silly->doggy;  # woof
 Silly->dagron; # burninate
 Silly->dagron; # roar
 Silly->dagron; # burninate

=head1 DESCRIPTION

This package provides performant ways to generate subroutines from strings.

=head1 SUBROUTINES

=head2 quote_sub

 my $coderef = quote_sub 'Foo::bar', q{ print $x++ . "\n" }, { '$x' => \0 };

Arguments: ?$name, $code, ?\%captures, ?\%options

C<$name> is the subroutine where the coderef will be installed.

C<$code> is a string that will be turned into code.

C<\%captures> is a hashref of variables that will be made available to the
code.  The keys should be the full name of the variable to be made available,
including the sigil.  The values should be references to the values.  The
variables will contain copies of the values.  See the L</SYNOPSIS>'s
C<Silly::dagron> for an example using captures.

Exported by default.

=head3 options

=over 2

=item C<no_install>

B<Boolean>.  Set this option to not install the generated coderef into the
passed subroutine name on undefer.

=item C<no_defer>

B<Boolean>.  Prevents a Sub::Defer wrapper from being generated for the quoted
sub.  If the sub will most likely be called at some point, setting this is a
good idea.  For a sub that will most likely be inlined, it is not recommended.

=item C<package>

The package that the quoted sub will be evaluated in.  If not specified, the
sub calling C<quote_sub> will be used.

=back

=head2 unquote_sub

 my $coderef = unquote_sub $sub;

Forcibly replace subroutine with actual code.

If $sub is not a quoted sub, this is a no-op.

Exported by default.

=head2 quoted_from_sub

 my $data = quoted_from_sub $sub;

 my ($name, $code, $captures, $compiled_sub) = @$data;

Returns original arguments to quote_sub, plus the compiled version if this
sub has already been unquoted.

Note that $sub can be either the original quoted version or the compiled
version for convenience.

Exported by default.

=head2 inlinify

 my $prelude = capture_unroll '$captures', {
   '$x' => 1,
   '$y' => 2,
 }, 4;

 my $inlined_code = inlinify q{
   my ($x, $y) = @_;

   print $x + $y . "\n";
 }, '$x, $y', $prelude;

Takes a string of code, a string of arguments, a string of code which acts as a
"prelude", and a B<Boolean> representing whether or not to localize the
arguments.

=head2 quotify

 my $quoted_value = quotify $value;

Quotes a single (non-reference) scalar value for use in a code string.  Numbers
aren't treated specially and will be quoted as strings, but undef will quoted as
C<undef()>.

=head2 capture_unroll

 my $prelude = capture_unroll '$captures', {
   '$x' => 1,
   '$y' => 2,
 }, 4;

Arguments: $from, \%captures, $indent

Generates a snippet of code which is suitable to be used as a prelude for
L</inlinify>.  C<$from> is a string will be used as a hashref in the resulting
code.  The keys of C<%captures> are the names of the variables and the values
are ignored.  C<$indent> is the number of spaces to indent the result by.

=head2 qsub

 my $hash = {
  coderef => qsub q{ print "hello"; },
  other   => 5,
 };

Arguments: $code

Works exactly like L</quote_sub>, but includes a prototype to only accept a
single parameter.  This makes it easier to include in hash structures or lists.

Exported by default.

=head2 sanitize_identifier

 my $var_name = '$variable_for_' . sanitize_identifier('@name');
 quote_sub qq{ print \$${var_name} }, { $var_name => \$value };

Arguments: $identifier

Sanitizes a value so that it can be used in an identifier.

=head1 CAVEATS

Much of this is just string-based code-generation, and as a result, a few
caveats apply.

=head2 return

Calling C<return> from a quote_sub'ed sub will not likely do what you intend.
Instead of returning from the code you defined in C<quote_sub>, it will return
from the overall function it is composited into.

So when you pass in:

   quote_sub q{  return 1 if $condition; $morecode }

It might turn up in the intended context as follows:

  sub foo {

    <important code a>
    do {
      return 1 if $condition;
      $morecode
    };
    <important code b>

  }

Which will obviously return from foo, when all you meant to do was return from
the code context in quote_sub and proceed with running important code b.

=head2 pragmas

C<Sub::Quote> preserves the environment of the code creating the
quoted subs.  This includes the package, strict, warnings, and any
other lexical pragmas.  This is done by prefixing the code with a
block that sets up a matching environment.  When inlining C<Sub::Quote>
subs, care should be taken that user pragmas won't effect the rest
of the code.

=head1 SUPPORT

Users' IRC: #moose on irc.perl.org

=for :html
L<(click for instant chatroom login)|http://chat.mibbit.com/#moose@irc.perl.org>

Development and contribution IRC: #web-simple on irc.perl.org

=for :html
L<(click for instant chatroom login)|http://chat.mibbit.com/#web-simple@irc.perl.org>

Bugtracker: L<https://rt.cpan.org/Public/Dist/Display.html?Name=Sub-Quote>

Git repository: L<git://github.com/moose/Sub-Quote.git>

Git browser: L<https://github.com/moose/Sub-Quote>

=head1 AUTHOR

mst - Matt S. Trout (cpan:MSTROUT) <mst@shadowcat.co.uk>

=head1 CONTRIBUTORS

frew - Arthur Axel "fREW" Schmidt (cpan:FREW) <frioux@gmail.com>

ribasushi - Peter Rabbitson (cpan:RIBASUSHI) <ribasushi@cpan.org>

Mithaldu - Christian Walde (cpan:MITHALDU) <walde.christian@googlemail.com>

tobyink - Toby Inkster (cpan:TOBYINK) <tobyink@cpan.org>

haarg - Graham Knop (cpan:HAARG) <haarg@cpan.org>

bluefeet - Aran Deltac (cpan:BLUEFEET) <bluefeet@gmail.com>

ether - Karen Etheridge (cpan:ETHER) <ether@cpan.org>

dolmen - Olivier Mengué (cpan:DOLMEN) <dolmen@cpan.org>

alexbio - Alessandro Ghedini (cpan:ALEXBIO) <alexbio@cpan.org>

getty - Torsten Raudssus (cpan:GETTY) <torsten@raudss.us>

arcanez - Justin Hunter (cpan:ARCANEZ) <justin.d.hunter@gmail.com>

kanashiro - Lucas Kanashiro (cpan:KANASHIRO) <kanashiro.duarte@gmail.com>

=head1 COPYRIGHT

Copyright (c) 2010-2016 the Sub::Quote L</AUTHOR> and L</CONTRIBUTORS>
as listed above.

=head1 LICENSE

This library is free software and may be distributed under the same terms
as perl itself. See L<http://dev.perl.org/licenses/>.

=cut

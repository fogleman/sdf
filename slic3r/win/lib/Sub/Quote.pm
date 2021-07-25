#line 1 "Sub/Quote.pm"
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



#line 503

#line 1 "Data/Dumper.pm"
#
# Data/Dumper.pm
#
# convert perl data structures into perl syntax suitable for both printing
# and eval
#
# Documentation at the __END__
#

package Data::Dumper;

BEGIN {
    $VERSION = '2.161'; # Don't forget to set version and release
}               # date in POD below!

#$| = 1;

use 5.006_001;
require Exporter;
require overload;

use Carp;

BEGIN {
    @ISA = qw(Exporter);
    @EXPORT = qw(Dumper);
    @EXPORT_OK = qw(DumperX);

    # if run under miniperl, or otherwise lacking dynamic loading,
    # XSLoader should be attempted to load, or the pure perl flag
    # toggled on load failure.
    eval {
        require XSLoader;
        XSLoader::load( 'Data::Dumper' );
        1
    }
    or $Useperl = 1;
}

my $IS_ASCII  = ord 'A' ==  65;

# module vars and their defaults
$Indent     = 2         unless defined $Indent;
$Trailingcomma = 0      unless defined $Trailingcomma;
$Purity     = 0         unless defined $Purity;
$Pad        = ""        unless defined $Pad;
$Varname    = "VAR"     unless defined $Varname;
$Useqq      = 0         unless defined $Useqq;
$Terse      = 0         unless defined $Terse;
$Freezer    = ""        unless defined $Freezer;
$Toaster    = ""        unless defined $Toaster;
$Deepcopy   = 0         unless defined $Deepcopy;
$Quotekeys  = 1         unless defined $Quotekeys;
$Bless      = "bless"   unless defined $Bless;
#$Expdepth   = 0         unless defined $Expdepth;
$Maxdepth   = 0         unless defined $Maxdepth;
$Pair       = ' => '    unless defined $Pair;
$Useperl    = 0         unless defined $Useperl;
$Sortkeys   = 0         unless defined $Sortkeys;
$Deparse    = 0         unless defined $Deparse;
$Sparseseen = 0         unless defined $Sparseseen;
$Maxrecurse = 1000      unless defined $Maxrecurse;

#
# expects an arrayref of values to be dumped.
# can optionally pass an arrayref of names for the values.
# names must have leading $ sign stripped. begin the name with *
# to cause output of arrays and hashes rather than refs.
#
sub new {
  my($c, $v, $n) = @_;

  croak "Usage:  PACKAGE->new(ARRAYREF, [ARRAYREF])"
    unless (defined($v) && (ref($v) eq 'ARRAY'));
  $n = [] unless (defined($n) && (ref($n) eq 'ARRAY'));

  my($s) = {
        level      => 0,           # current recursive depth
        indent     => $Indent,     # various styles of indenting
        trailingcomma => $Trailingcomma, # whether to add comma after last elem
        pad        => $Pad,        # all lines prefixed by this string
        xpad       => "",          # padding-per-level
        apad       => "",          # added padding for hash keys n such
        sep        => "",          # list separator
        pair       => $Pair,    # hash key/value separator: defaults to ' => '
        seen       => {},          # local (nested) refs (id => [name, val])
        todump     => $v,          # values to dump []
        names      => $n,          # optional names for values []
        varname    => $Varname,    # prefix to use for tagging nameless ones
        purity     => $Purity,     # degree to which output is evalable
        useqq      => $Useqq,      # use "" for strings (backslashitis ensues)
        terse      => $Terse,      # avoid name output (where feasible)
        freezer    => $Freezer,    # name of Freezer method for objects
        toaster    => $Toaster,    # name of method to revive objects
        deepcopy   => $Deepcopy,   # do not cross-ref, except to stop recursion
        quotekeys  => $Quotekeys,  # quote hash keys
        'bless'    => $Bless,    # keyword to use for "bless"
#        expdepth   => $Expdepth,   # cutoff depth for explicit dumping
        maxdepth   => $Maxdepth,   # depth beyond which we give up
	maxrecurse => $Maxrecurse, # depth beyond which we abort
        useperl    => $Useperl,    # use the pure Perl implementation
        sortkeys   => $Sortkeys,   # flag or filter for sorting hash keys
        deparse    => $Deparse,    # use B::Deparse for coderefs
        noseen     => $Sparseseen, # do not populate the seen hash unless necessary
       };

  if ($Indent > 0) {
    $s->{xpad} = "  ";
    $s->{sep} = "\n";
  }
  return bless($s, $c);
}

# Packed numeric addresses take less memory. Plus pack is faster than sprintf

# Most users of current versions of Data::Dumper will be 5.008 or later.
# Anyone on 5.6.1 and 5.6.2 upgrading will be rare (particularly judging by
# the bug reports from users on those platforms), so for the common case avoid
# complexity, and avoid even compiling the unneeded code.

sub init_refaddr_format {
}

sub format_refaddr {
    require Scalar::Util;
    pack "J", Scalar::Util::refaddr(shift);
};

if ($] < 5.008) {
    eval <<'EOC' or die;
    no warnings 'redefine';
    my $refaddr_format;
    sub init_refaddr_format {
        require Config;
        my $f = $Config::Config{uvxformat};
        $f =~ tr/"//d;
        $refaddr_format = "0x%" . $f;
    }

    sub format_refaddr {
        require Scalar::Util;
        sprintf $refaddr_format, Scalar::Util::refaddr(shift);
    }

    1
EOC
}

#
# add-to or query the table of already seen references
#
sub Seen {
  my($s, $g) = @_;
  if (defined($g) && (ref($g) eq 'HASH'))  {
    init_refaddr_format();
    my($k, $v, $id);
    while (($k, $v) = each %$g) {
      if (defined $v) {
        if (ref $v) {
          $id = format_refaddr($v);
          if ($k =~ /^[*](.*)$/) {
            $k = (ref $v eq 'ARRAY') ? ( "\\\@" . $1 ) :
                 (ref $v eq 'HASH')  ? ( "\\\%" . $1 ) :
                 (ref $v eq 'CODE')  ? ( "\\\&" . $1 ) :
                 (   "\$" . $1 ) ;
          }
          elsif ($k !~ /^\$/) {
            $k = "\$" . $k;
          }
          $s->{seen}{$id} = [$k, $v];
        }
        else {
          carp "Only refs supported, ignoring non-ref item \$$k";
        }
      }
      else {
        carp "Value of ref must be defined; ignoring undefined item \$$k";
      }
    }
    return $s;
  }
  else {
    return map { @$_ } values %{$s->{seen}};
  }
}

#
# set or query the values to be dumped
#
sub Values {
  my($s, $v) = @_;
  if (defined($v)) {
    if (ref($v) eq 'ARRAY')  {
      $s->{todump} = [@$v];        # make a copy
      return $s;
    }
    else {
      croak "Argument to Values, if provided, must be array ref";
    }
  }
  else {
    return @{$s->{todump}};
  }
}

#
# set or query the names of the values to be dumped
#
sub Names {
  my($s, $n) = @_;
  if (defined($n)) {
    if (ref($n) eq 'ARRAY') {
      $s->{names} = [@$n];         # make a copy
      return $s;
    }
    else {
      croak "Argument to Names, if provided, must be array ref";
    }
  }
  else {
    return @{$s->{names}};
  }
}

sub DESTROY {}

sub Dump {
    return &Dumpxs
    unless $Data::Dumper::Useperl || (ref($_[0]) && $_[0]->{useperl})
        || $Data::Dumper::Deparse || (ref($_[0]) && $_[0]->{deparse})

            # Use pure perl version on earlier releases on EBCDIC platforms
        || (! $IS_ASCII && $] lt 5.021_010);
    return &Dumpperl;
}

#
# dump the refs in the current dumper object.
# expects same args as new() if called via package name.
#
sub Dumpperl {
  my($s) = shift;
  my(@out, $val, $name);
  my($i) = 0;
  local(@post);
  init_refaddr_format();

  $s = $s->new(@_) unless ref $s;

  for $val (@{$s->{todump}}) {
    @post = ();
    $name = $s->{names}[$i++];
    $name = $s->_refine_name($name, $val, $i);

    my $valstr;
    {
      local($s->{apad}) = $s->{apad};
      $s->{apad} .= ' ' x (length($name) + 3) if $s->{indent} >= 2 and !$s->{terse};
      $valstr = $s->_dump($val, $name);
    }

    $valstr = "$name = " . $valstr . ';' if @post or !$s->{terse};
    my $out = $s->_compose_out($valstr, \@post);

    push @out, $out;
  }
  return wantarray ? @out : join('', @out);
}

# wrap string in single quotes (escaping if needed)
sub _quote {
    my $val = shift;
    $val =~ s/([\\\'])/\\$1/g;
    return  "'" . $val .  "'";
}

# Old Perls (5.14-) have trouble resetting vstring magic when it is no
# longer valid.
use constant _bad_vsmg => defined &_vstring && (_vstring(~v0)||'') eq "v0";

#
# twist, toil and turn;
# and recurse, of course.
# sometimes sordidly;
# and curse if no recourse.
#
sub _dump {
  my($s, $val, $name) = @_;
  my($out, $type, $id, $sname);

  $type = ref $val;
  $out = "";

  if ($type) {

    # Call the freezer method if it's specified and the object has the
    # method.  Trap errors and warn() instead of die()ing, like the XS
    # implementation.
    my $freezer = $s->{freezer};
    if ($freezer and UNIVERSAL::can($val, $freezer)) {
      eval { $val->$freezer() };
      warn "WARNING(Freezer method call failed): $@" if $@;
    }

    require Scalar::Util;
    my $realpack = Scalar::Util::blessed($val);
    my $realtype = $realpack ? Scalar::Util::reftype($val) : ref $val;
    $id = format_refaddr($val);

    # Note: By this point $name is always defined and of non-zero length.
    # Keep a tab on it so that we do not fall into recursive pit.
    if (exists $s->{seen}{$id}) {
      if ($s->{purity} and $s->{level} > 0) {
        $out = ($realtype eq 'HASH')  ? '{}' :
               ($realtype eq 'ARRAY') ? '[]' :
               'do{my $o}' ;
        push @post, $name . " = " . $s->{seen}{$id}[0];
      }
      else {
        $out = $s->{seen}{$id}[0];
        if ($name =~ /^([\@\%])/) {
          my $start = $1;
          if ($out =~ /^\\$start/) {
            $out = substr($out, 1);
          }
          else {
            $out = $start . '{' . $out . '}';
          }
        }
      }
      return $out;
    }
    else {
      # store our name
      $s->{seen}{$id} = [ (
          ($name =~ /^[@%]/)
            ? ('\\' . $name )
            : ($realtype eq 'CODE' and $name =~ /^[*](.*)$/)
              ? ('\\&' . $1 )
              : $name
        ), $val ];
    }
    my $no_bless = 0;
    my $is_regex = 0;
    if ( $realpack and ($] >= 5.009005 ? re::is_regexp($val) : $realpack eq 'Regexp') ) {
        $is_regex = 1;
        $no_bless = $realpack eq 'Regexp';
    }

    # If purity is not set and maxdepth is set, then check depth:
    # if we have reached maximum depth, return the string
    # representation of the thing we are currently examining
    # at this depth (i.e., 'Foo=ARRAY(0xdeadbeef)').
    if (!$s->{purity}
      and defined($s->{maxdepth})
      and $s->{maxdepth} > 0
      and $s->{level} >= $s->{maxdepth})
    {
      return qq['$val'];
    }

    # avoid recursing infinitely [perl #122111]
    if ($s->{maxrecurse} > 0
        and $s->{level} >= $s->{maxrecurse}) {
        die "Recursion limit of $s->{maxrecurse} exceeded";
    }

    # we have a blessed ref
    my ($blesspad);
    if ($realpack and !$no_bless) {
      $out = $s->{'bless'} . '( ';
      $blesspad = $s->{apad};
      $s->{apad} .= '       ' if ($s->{indent} >= 2);
    }

    $s->{level}++;
    my $ipad = $s->{xpad} x $s->{level};

    if ($is_regex) {
        my $pat;
        my $flags = "";
        if (defined(*re::regexp_pattern{CODE})) {
          ($pat, $flags) = re::regexp_pattern($val);
        }
        else {
          $pat = "$val";
        }
        $pat =~ s <(\\.)|/> { $1 || '\\/' }ge;
        $out .= "qr/$pat/$flags";
    }
    elsif ($realtype eq 'SCALAR' || $realtype eq 'REF'
    || $realtype eq 'VSTRING') {
      if ($realpack) {
        $out .= 'do{\\(my $o = ' . $s->_dump($$val, "\${$name}") . ')}';
      }
      else {
        $out .= '\\' . $s->_dump($$val, "\${$name}");
      }
    }
    elsif ($realtype eq 'GLOB') {
      $out .= '\\' . $s->_dump($$val, "*{$name}");
    }
    elsif ($realtype eq 'ARRAY') {
      my($pad, $mname);
      my($i) = 0;
      $out .= ($name =~ /^\@/) ? '(' : '[';
      $pad = $s->{sep} . $s->{pad} . $s->{apad};
      ($name =~ /^\@(.*)$/) ? ($mname = "\$" . $1) :
    # omit -> if $foo->[0]->{bar}, but not ${$foo->[0]}->{bar}
        ($name =~ /^\\?[\%\@\*\$][^{].*[]}]$/) ? ($mname = $name) :
        ($mname = $name . '->');
      $mname .= '->' if $mname =~ /^\*.+\{[A-Z]+\}$/;
      for my $v (@$val) {
        $sname = $mname . '[' . $i . ']';
        $out .= $pad . $ipad . '#' . $i
          if $s->{indent} >= 3;
        $out .= $pad . $ipad . $s->_dump($v, $sname);
        $out .= ","
            if $i++ < $#$val
            || ($s->{trailingcomma} && $s->{indent} >= 1);
      }
      $out .= $pad . ($s->{xpad} x ($s->{level} - 1)) if $i;
      $out .= ($name =~ /^\@/) ? ')' : ']';
    }
    elsif ($realtype eq 'HASH') {
      my ($k, $v, $pad, $lpad, $mname, $pair);
      $out .= ($name =~ /^\%/) ? '(' : '{';
      $pad = $s->{sep} . $s->{pad} . $s->{apad};
      $lpad = $s->{apad};
      $pair = $s->{pair};
      ($name =~ /^\%(.*)$/) ? ($mname = "\$" . $1) :
    # omit -> if $foo->[0]->{bar}, but not ${$foo->[0]}->{bar}
        ($name =~ /^\\?[\%\@\*\$][^{].*[]}]$/) ? ($mname = $name) :
        ($mname = $name . '->');
      $mname .= '->' if $mname =~ /^\*.+\{[A-Z]+\}$/;
      my $sortkeys = defined($s->{sortkeys}) ? $s->{sortkeys} : '';
      my $keys = [];
      if ($sortkeys) {
        if (ref($s->{sortkeys}) eq 'CODE') {
          $keys = $s->{sortkeys}($val);
          unless (ref($keys) eq 'ARRAY') {
            carp "Sortkeys subroutine did not return ARRAYREF";
            $keys = [];
          }
        }
        else {
          $keys = [ sort keys %$val ];
        }
      }

      # Ensure hash iterator is reset
      keys(%$val);

      my $key;
      while (($k, $v) = ! $sortkeys ? (each %$val) :
         @$keys ? ($key = shift(@$keys), $val->{$key}) :
         () )
      {
        my $nk = $s->_dump($k, "");

        # _dump doesn't quote numbers of this form
        if ($s->{quotekeys} && $nk =~ /^(?:0|-?[1-9][0-9]{0,8})\z/) {
          $nk = $s->{useqq} ? qq("$nk") : qq('$nk');
        }
        elsif (!$s->{quotekeys} and $nk =~ /^[\"\']([A-Za-z_]\w*)[\"\']$/) {
          $nk = $1
        }

        $sname = $mname . '{' . $nk . '}';
        $out .= $pad . $ipad . $nk . $pair;

        # temporarily alter apad
        $s->{apad} .= (" " x (length($nk) + 4))
          if $s->{indent} >= 2;
        $out .= $s->_dump($val->{$k}, $sname) . ",";
        $s->{apad} = $lpad
          if $s->{indent} >= 2;
      }
      if (substr($out, -1) eq ',') {
        chop $out if !$s->{trailingcomma} || !$s->{indent};
        $out .= $pad . ($s->{xpad} x ($s->{level} - 1));
      }
      $out .= ($name =~ /^\%/) ? ')' : '}';
    }
    elsif ($realtype eq 'CODE') {
      if ($s->{deparse}) {
        require B::Deparse;
        my $sub =  'sub ' . (B::Deparse->new)->coderef2text($val);
        $pad    =  $s->{sep} . $s->{pad} . $s->{apad} . $s->{xpad} x ($s->{level} - 1);
        $sub    =~ s/\n/$pad/gse;
        $out   .=  $sub;
      }
      else {
        $out .= 'sub { "DUMMY" }';
        carp "Encountered CODE ref, using dummy placeholder" if $s->{purity};
      }
    }
    else {
      croak "Can't handle '$realtype' type";
    }

    if ($realpack and !$no_bless) { # we have a blessed ref
      $out .= ', ' . _quote($realpack) . ' )';
      $out .= '->' . $s->{toaster} . '()'
        if $s->{toaster} ne '';
      $s->{apad} = $blesspad;
    }
    $s->{level}--;
  }
  else {                                 # simple scalar

    my $ref = \$_[1];
    my $v;
    # first, catalog the scalar
    if ($name ne '') {
      $id = format_refaddr($ref);
      if (exists $s->{seen}{$id}) {
        if ($s->{seen}{$id}[2]) {
          $out = $s->{seen}{$id}[0];
          #warn "[<$out]\n";
          return "\${$out}";
        }
      }
      else {
        #warn "[>\\$name]\n";
        $s->{seen}{$id} = ["\\$name", $ref];
      }
    }
    $ref = \$val;
    if (ref($ref) eq 'GLOB') {  # glob
      my $name = substr($val, 1);
      if ($name =~ /^[A-Za-z_][\w:]*$/ && $name ne 'main::') {
        $name =~ s/^main::/::/;
        $sname = $name;
      }
      else {
        $sname = $s->_dump(
          $name eq 'main::' || $] < 5.007 && $name eq "main::\0"
            ? ''
            : $name,
          "",
        );
        $sname = '{' . $sname . '}';
      }
      if ($s->{purity}) {
        my $k;
        local ($s->{level}) = 0;
        for $k (qw(SCALAR ARRAY HASH)) {
          my $gval = *$val{$k};
          next unless defined $gval;
          next if $k eq "SCALAR" && ! defined $$gval;  # always there

          # _dump can push into @post, so we hold our place using $postlen
          my $postlen = scalar @post;
          $post[$postlen] = "\*$sname = ";
          local ($s->{apad}) = " " x length($post[$postlen]) if $s->{indent} >= 2;
          $post[$postlen] .= $s->_dump($gval, "\*$sname\{$k\}");
        }
      }
      $out .= '*' . $sname;
    }
    elsif (!defined($val)) {
      $out .= "undef";
    }
    elsif (defined &_vstring and $v = _vstring($val)
      and !_bad_vsmg || eval $v eq $val) {
      $out .= $v;
    }
    elsif (!defined &_vstring
       and ref $ref eq 'VSTRING' || eval{Scalar::Util::isvstring($val)}) {
      $out .= sprintf "%vd", $val;
    }
    # \d here would treat "1\x{660}" as a safe decimal number
    elsif ($val =~ /^(?:0|-?[1-9][0-9]{0,8})\z/) { # safe decimal number
      $out .= $val;
    }
    else {                 # string
      if ($s->{useqq} or $val =~ tr/\0-\377//c) {
        # Fall back to qq if there's Unicode
        $out .= qquote($val, $s->{useqq});
      }
      else {
        $out .= _quote($val);
      }
    }
  }
  if ($id) {
    # if we made it this far, $id was added to seen list at current
    # level, so remove it to get deep copies
    if ($s->{deepcopy}) {
      delete($s->{seen}{$id});
    }
    elsif ($name) {
      $s->{seen}{$id}[2] = 1;
    }
  }
  return $out;
}

#
# non-OO style of earlier version
#
sub Dumper {
  return Data::Dumper->Dump([@_]);
}

# compat stub
sub DumperX {
  return Data::Dumper->Dumpxs([@_], []);
}

#
# reset the "seen" cache
#
sub Reset {
  my($s) = shift;
  $s->{seen} = {};
  return $s;
}

sub Indent {
  my($s, $v) = @_;
  if (defined($v)) {
    if ($v == 0) {
      $s->{xpad} = "";
      $s->{sep} = "";
    }
    else {
      $s->{xpad} = "  ";
      $s->{sep} = "\n";
    }
    $s->{indent} = $v;
    return $s;
  }
  else {
    return $s->{indent};
  }
}

sub Trailingcomma {
  my($s, $v) = @_;
  defined($v) ? (($s->{trailingcomma} = $v), return $s) : $s->{trailingcomma};
}

sub Pair {
    my($s, $v) = @_;
    defined($v) ? (($s->{pair} = $v), return $s) : $s->{pair};
}

sub Pad {
  my($s, $v) = @_;
  defined($v) ? (($s->{pad} = $v), return $s) : $s->{pad};
}

sub Varname {
  my($s, $v) = @_;
  defined($v) ? (($s->{varname} = $v), return $s) : $s->{varname};
}

sub Purity {
  my($s, $v) = @_;
  defined($v) ? (($s->{purity} = $v), return $s) : $s->{purity};
}

sub Useqq {
  my($s, $v) = @_;
  defined($v) ? (($s->{useqq} = $v), return $s) : $s->{useqq};
}

sub Terse {
  my($s, $v) = @_;
  defined($v) ? (($s->{terse} = $v), return $s) : $s->{terse};
}

sub Freezer {
  my($s, $v) = @_;
  defined($v) ? (($s->{freezer} = $v), return $s) : $s->{freezer};
}

sub Toaster {
  my($s, $v) = @_;
  defined($v) ? (($s->{toaster} = $v), return $s) : $s->{toaster};
}

sub Deepcopy {
  my($s, $v) = @_;
  defined($v) ? (($s->{deepcopy} = $v), return $s) : $s->{deepcopy};
}

sub Quotekeys {
  my($s, $v) = @_;
  defined($v) ? (($s->{quotekeys} = $v), return $s) : $s->{quotekeys};
}

sub Bless {
  my($s, $v) = @_;
  defined($v) ? (($s->{'bless'} = $v), return $s) : $s->{'bless'};
}

sub Maxdepth {
  my($s, $v) = @_;
  defined($v) ? (($s->{'maxdepth'} = $v), return $s) : $s->{'maxdepth'};
}

sub Maxrecurse {
  my($s, $v) = @_;
  defined($v) ? (($s->{'maxrecurse'} = $v), return $s) : $s->{'maxrecurse'};
}

sub Useperl {
  my($s, $v) = @_;
  defined($v) ? (($s->{'useperl'} = $v), return $s) : $s->{'useperl'};
}

sub Sortkeys {
  my($s, $v) = @_;
  defined($v) ? (($s->{'sortkeys'} = $v), return $s) : $s->{'sortkeys'};
}

sub Deparse {
  my($s, $v) = @_;
  defined($v) ? (($s->{'deparse'} = $v), return $s) : $s->{'deparse'};
}

sub Sparseseen {
  my($s, $v) = @_;
  defined($v) ? (($s->{'noseen'} = $v), return $s) : $s->{'noseen'};
}

# used by qquote below
my %esc = (
    "\a" => "\\a",
    "\b" => "\\b",
    "\t" => "\\t",
    "\n" => "\\n",
    "\f" => "\\f",
    "\r" => "\\r",
    "\e" => "\\e",
);

my $low_controls = ($IS_ASCII)

                   # This includes \177, because traditionally it has been
                   # output as octal, even though it isn't really a "low"
                   # control
                   ? qr/[\0-\x1f\177]/

                     # EBCDIC low controls.
                   : qr/[\0-\x3f]/;

# put a string value in double quotes
sub qquote {
  local($_) = shift;
  s/([\\\"\@\$])/\\$1/g;

  # This efficiently changes the high ordinal characters to \x{} if the utf8
  # flag is on.  On ASCII platforms, the high ordinals are all the
  # non-ASCII's.  On EBCDIC platforms, we don't include in these the non-ASCII
  # controls whose ordinals are less than SPACE, excluded below by the range
  # \0-\x3f.  On ASCII platforms this range just compiles as part of :ascii:.
  # On EBCDIC platforms, there is just one outlier high ordinal control, and
  # it gets output as \x{}.
  my $bytes; { use bytes; $bytes = length }
  s/([^[:ascii:]\0-\x3f])/sprintf("\\x{%x}",ord($1))/ge
    if $bytes > length

       # The above doesn't get the EBCDIC outlier high ordinal control when
       # the string is UTF-8 but there are no UTF-8 variant characters in it.
       # We want that to come out as \x{} anyway.  We need is_utf8() to do
       # this.
       || (! $IS_ASCII && $] ge 5.008_001 && utf8::is_utf8($_));

  return qq("$_") unless /[[:^print:]]/;  # fast exit if only printables

  # Here, there is at least one non-printable to output.  First, translate the
  # escapes.
  s/([\a\b\t\n\f\r\e])/$esc{$1}/g;

  # no need for 3 digits in escape for octals not followed by a digit.
  s/($low_controls)(?!\d)/'\\'.sprintf('%o',ord($1))/eg;

  # But otherwise use 3 digits
  s/($low_controls)/'\\'.sprintf('%03o',ord($1))/eg;

    # all but last branch below not supported --BEHAVIOR SUBJECT TO CHANGE--
  my $high = shift || "";
    if ($high eq "iso8859") {   # Doesn't escape the Latin1 printables
      if ($IS_ASCII) {
        s/([\200-\240])/'\\'.sprintf('%o',ord($1))/eg;
      }
      elsif ($] ge 5.007_003) {
        my $high_control = utf8::unicode_to_native(0x9F);
        s/$high_control/sprintf('\\%o',ord($1))/eg;
      }
    } elsif ($high eq "utf8") {
#     Some discussion of what to do here is in
#       https://rt.perl.org/Ticket/Display.html?id=113088
#     use utf8;
#     $str =~ s/([^\040-\176])/sprintf "\\x{%04x}", ord($1)/ge;
    } elsif ($high eq "8bit") {
        # leave it as it is
    } else {
      s/([[:^ascii:]])/'\\'.sprintf('%03o',ord($1))/eg;
      #s/([^\040-\176])/sprintf "\\x{%04x}", ord($1)/ge;
    }

  return qq("$_");
}

# helper sub to sort hash keys in Perl < 5.8.0 where we don't have
# access to sortsv() from XS
sub _sortkeys { [ sort keys %{$_[0]} ] }

sub _refine_name {
    my $s = shift;
    my ($name, $val, $i) = @_;
    if (defined $name) {
      if ($name =~ /^[*](.*)$/) {
        if (defined $val) {
            $name = (ref $val eq 'ARRAY') ? ( "\@" . $1 ) :
              (ref $val eq 'HASH')  ? ( "\%" . $1 ) :
              (ref $val eq 'CODE')  ? ( "\*" . $1 ) :
              ( "\$" . $1 ) ;
        }
        else {
          $name = "\$" . $1;
        }
      }
      elsif ($name !~ /^\$/) {
        $name = "\$" . $name;
      }
    }
    else { # no names provided
      $name = "\$" . $s->{varname} . $i;
    }
    return $name;
}

sub _compose_out {
    my $s = shift;
    my ($valstr, $postref) = @_;
    my $out = "";
    $out .= $s->{pad} . $valstr . $s->{sep};
    if (@{$postref}) {
        $out .= $s->{pad} .
            join(';' . $s->{sep} . $s->{pad}, @{$postref}) .
            ';' .
            $s->{sep};
    }
    return $out;
}

1;
__END__

#line 1482

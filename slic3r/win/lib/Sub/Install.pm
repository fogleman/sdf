#line 1 "Sub/Install.pm"
use strict;
use warnings;
package Sub::Install;
# ABSTRACT: install subroutines into packages easily
$Sub::Install::VERSION = '0.928';
use Carp;
use Scalar::Util ();

#pod =head1 SYNOPSIS
#pod
#pod   use Sub::Install;
#pod
#pod   Sub::Install::install_sub({
#pod     code => sub { ... },
#pod     into => $package,
#pod     as   => $subname
#pod   });
#pod
#pod =head1 DESCRIPTION
#pod
#pod This module makes it easy to install subroutines into packages without the
#pod unsightly mess of C<no strict> or typeglobs lying about where just anyone can
#pod see them.
#pod
#pod =func install_sub
#pod
#pod   Sub::Install::install_sub({
#pod    code => \&subroutine,
#pod    into => "Finance::Shady",
#pod    as   => 'launder',
#pod   });
#pod
#pod This routine installs a given code reference into a package as a normal
#pod subroutine.  The above is equivalent to:
#pod
#pod   no strict 'refs';
#pod   *{"Finance::Shady" . '::' . "launder"} = \&subroutine;
#pod
#pod If C<into> is not given, the sub is installed into the calling package.
#pod
#pod If C<code> is not a code reference, it is looked for as an existing sub in the
#pod package named in the C<from> parameter.  If C<from> is not given, it will look
#pod in the calling package.
#pod
#pod If C<as> is not given, and if C<code> is a name, C<as> will default to C<code>.
#pod If C<as> is not given, but if C<code> is a code ref, Sub::Install will try to
#pod find the name of the given code ref and use that as C<as>.
#pod
#pod That means that this code:
#pod
#pod   Sub::Install::install_sub({
#pod     code => 'twitch',
#pod     from => 'Person::InPain',
#pod     into => 'Person::Teenager',
#pod     as   => 'dance',
#pod   });
#pod
#pod is the same as:
#pod
#pod   package Person::Teenager;
#pod
#pod   Sub::Install::install_sub({
#pod     code => Person::InPain->can('twitch'),
#pod     as   => 'dance',
#pod   });
#pod
#pod =func reinstall_sub
#pod
#pod This routine behaves exactly like C<L</install_sub>>, but does not emit a
#pod warning if warnings are on and the destination is already defined.
#pod
#pod =cut

sub _name_of_code {
  my ($code) = @_;
  require B;
  my $name = B::svref_2object($code)->GV->NAME;
  return $name unless $name =~ /\A__ANON__/;
  return;
}

# See also Params::Util, to which this code was donated.
sub _CODELIKE {
  (Scalar::Util::reftype($_[0])||'') eq 'CODE'
  || Scalar::Util::blessed($_[0])
  && (overload::Method($_[0],'&{}') ? $_[0] : undef);
}

# do the heavy lifting
sub _build_public_installer {
  my ($installer) = @_;

  sub {
    my ($arg) = @_;
    my ($calling_pkg) = caller(0);

    # I'd rather use ||= but I'm whoring for Devel::Cover.
    for (qw(into from)) { $arg->{$_} = $calling_pkg unless $arg->{$_} }

    # This is the only absolutely required argument, in many cases.
    Carp::croak "named argument 'code' is not optional" unless $arg->{code};

    if (_CODELIKE($arg->{code})) {
      $arg->{as} ||= _name_of_code($arg->{code});
    } else {
      Carp::croak
        "couldn't find subroutine named $arg->{code} in package $arg->{from}"
        unless my $code = $arg->{from}->can($arg->{code});

      $arg->{as}   = $arg->{code} unless $arg->{as};
      $arg->{code} = $code;
    }

    Carp::croak "couldn't determine name under which to install subroutine"
      unless $arg->{as};

    $installer->(@$arg{qw(into as code) });
  }
}

# do the ugly work

my $_misc_warn_re;
my $_redef_warn_re;
BEGIN {
  $_misc_warn_re = qr/
    Prototype\ mismatch:\ sub\ .+?  |
    Constant subroutine .+? redefined
  /x;
  $_redef_warn_re = qr/Subroutine\ .+?\ redefined/x;
}

my $eow_re;
BEGIN { $eow_re = qr/ at .+? line \d+\.\Z/ };

sub _do_with_warn {
  my ($arg) = @_;
  my $code = delete $arg->{code};
  my $wants_code = sub {
    my $code = shift;
    sub {
      my $warn = $SIG{__WARN__} ? $SIG{__WARN__} : sub { warn @_ }; ## no critic
      local $SIG{__WARN__} = sub {
        my ($error) = @_;
        for (@{ $arg->{suppress} }) {
            return if $error =~ $_;
        }
        for (@{ $arg->{croak} }) {
          if (my ($base_error) = $error =~ /\A($_) $eow_re/x) {
            Carp::croak $base_error;
          }
        }
        for (@{ $arg->{carp} }) {
          if (my ($base_error) = $error =~ /\A($_) $eow_re/x) {
            return $warn->(Carp::shortmess $base_error);
          }
        }
        ($arg->{default} || $warn)->($error);
      };
      $code->(@_);
    };
  };
  return $wants_code->($code) if $code;
  return $wants_code;
}

sub _installer {
  sub {
    my ($pkg, $name, $code) = @_;
    no strict 'refs'; ## no critic ProhibitNoStrict
    *{"$pkg\::$name"} = $code;
    return $code;
  }
}

BEGIN {
  *_ignore_warnings = _do_with_warn({
    carp => [ $_misc_warn_re, $_redef_warn_re ]
  });

  *install_sub = _build_public_installer(_ignore_warnings(_installer));

  *_carp_warnings =  _do_with_warn({
    carp     => [ $_misc_warn_re ],
    suppress => [ $_redef_warn_re ],
  });

  *reinstall_sub = _build_public_installer(_carp_warnings(_installer));

  *_install_fatal = _do_with_warn({
    code     => _installer,
    croak    => [ $_redef_warn_re ],
  });
}

#pod =func install_installers
#pod
#pod This routine is provided to allow Sub::Install compatibility with
#pod Sub::Installer.  It installs C<install_sub> and C<reinstall_sub> methods into
#pod the package named by its argument.
#pod
#pod  Sub::Install::install_installers('Code::Builder'); # just for us, please
#pod  Code::Builder->install_sub({ name => $code_ref });
#pod
#pod  Sub::Install::install_installers('UNIVERSAL'); # feeling lucky, punk?
#pod  Anything::At::All->install_sub({ name => $code_ref });
#pod
#pod The installed installers are similar, but not identical, to those provided by
#pod Sub::Installer.  They accept a single hash as an argument.  The key/value pairs
#pod are used as the C<as> and C<code> parameters to the C<install_sub> routine
#pod detailed above.  The package name on which the method is called is used as the
#pod C<into> parameter.
#pod
#pod Unlike Sub::Installer's C<install_sub> will not eval strings into code, but
#pod will look for named code in the calling package.
#pod
#pod =cut

sub install_installers {
  my ($into) = @_;

  for my $method (qw(install_sub reinstall_sub)) {
    my $code = sub {
      my ($package, $subs) = @_;
      my ($caller) = caller(0);
      my $return;
      for (my ($name, $sub) = %$subs) {
        $return = Sub::Install->can($method)->({
          code => $sub,
          from => $caller,
          into => $package,
          as   => $name
        });
      }
      return $return;
    };
    install_sub({ code => $code, into => $into, as => $method });
  }
}

#pod =head1 EXPORTS
#pod
#pod Sub::Install exports C<install_sub> and C<reinstall_sub> only if they are
#pod requested.
#pod
#pod =head2 exporter
#pod
#pod Sub::Install has a never-exported subroutine called C<exporter>, which is used
#pod to implement its C<import> routine.  It takes a hashref of named arguments,
#pod only one of which is currently recognize: C<exports>.  This must be an arrayref
#pod of subroutines to offer for export.
#pod
#pod This routine is mainly for Sub::Install's own consumption.  Instead, consider
#pod L<Sub::Exporter>.
#pod
#pod =cut

sub exporter {
  my ($arg) = @_;

  my %is_exported = map { $_ => undef } @{ $arg->{exports} };

  sub {
    my $class = shift;
    my $target = caller;
    for (@_) {
      Carp::croak "'$_' is not exported by $class" if !exists $is_exported{$_};
      install_sub({ code => $_, from => $class, into => $target });
    }
  }
}

BEGIN { *import = exporter({ exports => [ qw(install_sub reinstall_sub) ] }); }

#pod =head1 SEE ALSO
#pod
#pod =over
#pod
#pod =item L<Sub::Installer>
#pod
#pod This module is (obviously) a reaction to Damian Conway's Sub::Installer, which
#pod does the same thing, but does it by getting its greasy fingers all over
#pod UNIVERSAL.  I was really happy about the idea of making the installation of
#pod coderefs less ugly, but I couldn't bring myself to replace the ugliness of
#pod typeglobs and loosened strictures with the ugliness of UNIVERSAL methods.
#pod
#pod =item L<Sub::Exporter>
#pod
#pod This is a complete Exporter.pm replacement, built atop Sub::Install.
#pod
#pod =back
#pod
#pod =head1 EXTRA CREDITS
#pod
#pod Several of the tests are adapted from tests that shipped with Damian Conway's
#pod Sub-Installer distribution.
#pod
#pod =cut

1;

__END__

#line 452

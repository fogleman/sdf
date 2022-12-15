#line 1 "Sub/Defer.pm"
package Sub::Defer;
use strict;
use warnings;
use Exporter qw(import);
use Scalar::Util qw(weaken);
use Carp qw(croak);

our $VERSION = '2.003001';
$VERSION = eval $VERSION;

our @EXPORT = qw(defer_sub undefer_sub undefer_all);
our @EXPORT_OK = qw(undefer_package defer_info);

our %DEFERRED;

sub _getglob { no strict 'refs'; \*{$_[0]} }

BEGIN {
  my $no_subname;
  *_subname
    = defined &Sub::Util::set_subname ? \&Sub::Util::set_subname
    : defined &Sub::Name::subname     ? \&Sub::Name::subname
    : (eval { require Sub::Util } && defined &Sub::Util::set_subname) ? \&Sub::Util::set_subname
    : (eval { require Sub::Name } && defined &Sub::Name::subname    ) ? \&Sub::Name::subname
    : ($no_subname = 1, sub { $_[1] });
  *_CAN_SUBNAME = $no_subname ? sub(){0} : sub(){1};
}

sub _name_coderef {
  shift if @_ > 2; # three args is (target, name, sub)
  _CAN_SUBNAME ? _subname(@_) : $_[1];
}

sub _install_coderef {
  my ($glob, $code) = (_getglob($_[0]), _name_coderef(@_));
  no warnings 'redefine';
  if (*{$glob}{CODE}) {
    *{$glob} = $code;
  }
  # perl will sometimes warn about mismatched prototypes coming from the
  # inheritance cache, so disable them if we aren't redefining a sub
  else {
    no warnings 'prototype';
    *{$glob} = $code;
  }
}

sub undefer_sub {
  my ($deferred) = @_;
  my ($target, $maker, $undeferred_ref) = @{
    $DEFERRED{$deferred}||return $deferred
  };
  return ${$undeferred_ref}
    if ${$undeferred_ref};
  ${$undeferred_ref} = my $made = $maker->();

  # make sure the method slot has not changed since deferral time
  if (defined($target) && $deferred eq *{_getglob($target)}{CODE}||'') {
    no warnings 'redefine';

    # I believe $maker already evals with the right package/name, so that
    # _install_coderef calls are not necessary --ribasushi
    *{_getglob($target)} = $made;
  }
  $DEFERRED{$made} = $DEFERRED{$deferred};
  weaken $DEFERRED{$made}
    unless $target;

  return $made;
}

sub undefer_all {
  undefer_sub($_) for keys %DEFERRED;
  return;
}

sub undefer_package {
  my $package = shift;
  undefer_sub($_)
    for grep {
      my $name = $DEFERRED{$_} && $DEFERRED{$_}[0];
      $name && $name =~ /^${package}::[^:]+$/
    } keys %DEFERRED;
  return;
}

sub defer_info {
  my ($deferred) = @_;
  my $info = $DEFERRED{$deferred||''} or return undef;
  [ @$info ];
}

sub defer_sub {
  my ($target, $maker, $options) = @_;
  my $package;
  my $subname;
  ($package, $subname) = $target =~ /^(.*)::([^:]+)$/
    or croak "$target is not a fully qualified sub name!"
    if $target;
  $package ||= $options && $options->{package} || caller;
  my @attributes = @{$options && $options->{attributes} || []};
  my $deferred;
  my $undeferred;
  my $deferred_info = [ $target, $maker, \$undeferred ];
  if (@attributes || $target && !_CAN_SUBNAME) {
    my $code
      =  q[#line ].(__LINE__+2).q[ "].__FILE__.qq["\n]
      . qq[package $package;\n]
      . ($target ? "sub $subname" : '+sub') . join(' ', map ":$_", @attributes)
      . q[ {
        package Sub::Defer;
        # uncoverable subroutine
        # uncoverable statement
        $undeferred ||= undefer_sub($deferred_info->[3]);
        goto &$undeferred; # uncoverable statement
        $undeferred; # fake lvalue return
      }]."\n"
      . ($target ? "\\&$subname" : '');
    my $e;
    $deferred = do {
      no warnings qw(redefine closure);
      local $@;
      eval $code or $e = $@; # uncoverable branch true
    };
    die $e if defined $e; # uncoverable branch true
  }
  else {
    # duplicated from above
    $deferred = sub {
      $undeferred ||= undefer_sub($deferred_info->[3]);
      goto &$undeferred;
    };
    _install_coderef($target, $deferred)
      if $target;
  }
  weaken($deferred_info->[3] = $deferred);
  weaken($DEFERRED{$deferred} = $deferred_info);
  return $deferred;
}

sub CLONE {
  %DEFERRED = map { defined $_ && $_->[3] ? ($_->[3] => $_) : () } values %DEFERRED;
  foreach my $info (values %DEFERRED) {
    weaken($info)
      unless $info->[0] && ${$info->[2]};
  }
}

1;
__END__

#line 234

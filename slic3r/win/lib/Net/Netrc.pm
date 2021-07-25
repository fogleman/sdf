#line 1 "Net/Netrc.pm"
# Net::Netrc.pm
#
# Versions up to 2.13 Copyright (c) 1995-1998 Graham Barr <gbarr@pobox.com>.
# All rights reserved.
# Changes in Version 2.13_01 onwards Copyright (C) 2013-2014 Steve Hay.  All
# rights reserved.
# This module is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself, i.e. under the terms of either the GNU General
# Public License or the Artistic License, as specified in the F<LICENCE> file.

package Net::Netrc;

use 5.008001;

use strict;
use warnings;

use Carp;
use FileHandle;

our $VERSION = "3.10";

our $TESTING;

my %netrc = ();

sub _readrc {
  my($class, $host) = @_;
  my ($home, $file);

  if ($^O eq "MacOS") {
    $home = $ENV{HOME} || `pwd`;
    chomp($home);
    $file = ($home =~ /:$/ ? $home . "netrc" : $home . ":netrc");
  }
  else {

    # Some OS's don't have "getpwuid", so we default to $ENV{HOME}
    $home = eval { (getpwuid($>))[7] } || $ENV{HOME};
    $home ||= $ENV{HOMEDRIVE} . ($ENV{HOMEPATH} || '') if defined $ENV{HOMEDRIVE};
    if (-e $home . "/.netrc") {
      $file = $home . "/.netrc";
    }
    elsif (-e $home . "/_netrc") {
      $file = $home . "/_netrc";
    }
    else {
      return unless $TESTING;
    }
  }

  my ($login, $pass, $acct) = (undef, undef, undef);
  my $fh;
  local $_;

  $netrc{default} = undef;

  # OS/2 and Win32 do not handle stat in a way compatible with this check :-(
  unless ($^O eq 'os2'
    || $^O eq 'MSWin32'
    || $^O eq 'MacOS'
    || $^O =~ /^cygwin/)
  {
    my @stat = stat($file);

    if (@stat) {
      if ($stat[2] & 077) { ## no critic (ValuesAndExpressions::ProhibitLeadingZeros)
        carp "Bad permissions: $file";
        return;
      }
      if ($stat[4] != $<) {
        carp "Not owner: $file";
        return;
      }
    }
  }

  if ($fh = FileHandle->new($file, "r")) {
    my ($mach, $macdef, $tok, @tok) = (0, 0);

    while (<$fh>) {
      undef $macdef if /\A\n\Z/;

      if ($macdef) {
        push(@$macdef, $_);
        next;
      }

      s/^\s*//;
      chomp;

      while (length && s/^("((?:[^"]+|\\.)*)"|((?:[^\\\s]+|\\.)*))\s*//) {
        (my $tok = $+) =~ s/\\(.)/$1/g;
        push(@tok, $tok);
      }

    TOKEN:
      while (@tok) {
        if ($tok[0] eq "default") {
          shift(@tok);
          $mach = bless {}, $class;
          $netrc{default} = [$mach];

          next TOKEN;
        }

        last TOKEN
          unless @tok > 1;

        $tok = shift(@tok);

        if ($tok eq "machine") {
          my $host = shift @tok;
          $mach = bless {machine => $host}, $class;

          $netrc{$host} = []
            unless exists($netrc{$host});
          push(@{$netrc{$host}}, $mach);
        }
        elsif ($tok =~ /^(login|password|account)$/) {
          next TOKEN unless $mach;
          my $value = shift @tok;

          # Following line added by rmerrell to remove '/' escape char in .netrc
          $value =~ s/\/\\/\\/g;
          $mach->{$1} = $value;
        }
        elsif ($tok eq "macdef") {
          next TOKEN unless $mach;
          my $value = shift @tok;
          $mach->{macdef} = {}
            unless exists $mach->{macdef};
          $macdef = $mach->{machdef}{$value} = [];
        }
      }
    }
    $fh->close();
  }
}


sub lookup {
  my ($class, $mach, $login) = @_;

  $class->_readrc()
    unless exists $netrc{default};

  $mach ||= 'default';
  undef $login
    if $mach eq 'default';

  if (exists $netrc{$mach}) {
    if (defined $login) {
      foreach my $m (@{$netrc{$mach}}) {
        return $m
          if (exists $m->{login} && $m->{login} eq $login);
      }
      return;
    }
    return $netrc{$mach}->[0];
  }

  return $netrc{default}->[0]
    if defined $netrc{default};

  return;
}


sub login {
  my $me = shift;

  exists $me->{login}
    ? $me->{login}
    : undef;
}


sub account {
  my $me = shift;

  exists $me->{account}
    ? $me->{account}
    : undef;
}


sub password {
  my $me = shift;

  exists $me->{password}
    ? $me->{password}
    : undef;
}


sub lpa {
  my $me = shift;
  ($me->login, $me->password, $me->account);
}

1;

__END__

#line 348

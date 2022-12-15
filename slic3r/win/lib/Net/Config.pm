#line 1 "Net/Config.pm"
# Net::Config.pm
#
# Versions up to 1.11 Copyright (c) 2000 Graham Barr <gbarr@pobox.com>.
# All rights reserved.
# Changes in Version 1.11_01 onwards Copyright (C) 2013-2014 Steve Hay.  All
# rights reserved.
# This module is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself, i.e. under the terms of either the GNU General
# Public License or the Artistic License, as specified in the F<LICENCE> file.

package Net::Config;

use 5.008001;

use strict;
use warnings;

use Exporter;
use Socket qw(inet_aton inet_ntoa);

our @EXPORT  = qw(%NetConfig);
our @ISA     = qw(Net::LocalCfg Exporter);
our $VERSION = "3.10";

our($CONFIGURE, $LIBNET_CFG);

eval {
  local @INC = @INC;
  pop @INC if $INC[-1] eq '.';
  local $SIG{__DIE__};
  require Net::LocalCfg;
};

our %NetConfig = (
  nntp_hosts      => [],
  snpp_hosts      => [],
  pop3_hosts      => [],
  smtp_hosts      => [],
  ph_hosts        => [],
  daytime_hosts   => [],
  time_hosts      => [],
  inet_domain     => undef,
  ftp_firewall    => undef,
  ftp_ext_passive => 1,
  ftp_int_passive => 1,
  test_hosts      => 1,
  test_exist      => 1,
);

#
# Try to get as much configuration info as possible from InternetConfig
#
{
## no critic (BuiltinFunctions::ProhibitStringyEval)
$^O eq 'MacOS' and eval <<TRY_INTERNET_CONFIG;
use Mac::InternetConfig;

{
my %nc = (
    nntp_hosts      => [ \$InternetConfig{ kICNNTPHost() } ],
    pop3_hosts      => [ \$InternetConfig{ kICMailAccount() } =~ /\@(.*)/ ],
    smtp_hosts      => [ \$InternetConfig{ kICSMTPHost() } ],
    ftp_testhost    => \$InternetConfig{ kICFTPHost() } ? \$InternetConfig{ kICFTPHost()} : undef,
    ph_hosts        => [ \$InternetConfig{ kICPhHost() }   ],
    ftp_ext_passive => \$InternetConfig{"646F676F\xA5UsePassiveMode"} || 0,
    ftp_int_passive => \$InternetConfig{"646F676F\xA5UsePassiveMode"} || 0,
    socks_hosts     => 
        \$InternetConfig{ kICUseSocks() }    ? [ \$InternetConfig{ kICSocksHost() }    ] : [],
    ftp_firewall    => 
        \$InternetConfig{ kICUseFTPProxy() } ? [ \$InternetConfig{ kICFTPProxyHost() } ] : [],
);
\@NetConfig{keys %nc} = values %nc;
}
TRY_INTERNET_CONFIG
}

my $file = __FILE__;
my $ref;
$file =~ s/Config.pm/libnet.cfg/;
if (-f $file) {
  $ref = eval { local $SIG{__DIE__}; do $file };
  if (ref($ref) eq 'HASH') {
    %NetConfig = (%NetConfig, %{$ref});
    $LIBNET_CFG = $file;
  }
}
if ($< == $> and !$CONFIGURE) {
  my $home = eval { local $SIG{__DIE__}; (getpwuid($>))[7] } || $ENV{HOME};
  $home ||= $ENV{HOMEDRIVE} . ($ENV{HOMEPATH} || '') if defined $ENV{HOMEDRIVE};
  if (defined $home) {
    $file      = $home . "/.libnetrc";
    $ref       = eval { local $SIG{__DIE__}; do $file } if -f $file;
    %NetConfig = (%NetConfig, %{$ref})
      if ref($ref) eq 'HASH';
  }
}
my ($k, $v);
while (($k, $v) = each %NetConfig) {
  $NetConfig{$k} = [$v]
    if ($k =~ /_hosts$/ and $k ne "test_hosts" and defined($v) and !ref($v));
}

# Take a hostname and determine if it is inside the firewall


sub requires_firewall {
  shift;    # ignore package
  my $host = shift;

  return 0 unless defined $NetConfig{'ftp_firewall'};

  $host = inet_aton($host) or return -1;
  $host = inet_ntoa($host);

  if (exists $NetConfig{'local_netmask'}) {
    my $quad = unpack("N", pack("C*", split(/\./, $host)));
    my $list = $NetConfig{'local_netmask'};
    $list = [$list] unless ref($list);
    foreach (@$list) {
      my ($net, $bits) = (m#^(\d+\.\d+\.\d+\.\d+)/(\d+)$#) or next;
      my $mask = ~0 << (32 - $bits);
      my $addr = unpack("N", pack("C*", split(/\./, $net)));

      return 0 if (($addr & $mask) == ($quad & $mask));
    }
    return 1;
  }

  return 0;
}

*is_external = \&requires_firewall;

1;

__END__

#line 346

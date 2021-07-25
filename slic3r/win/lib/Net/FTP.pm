#line 1 "Net/FTP.pm"
# Net::FTP.pm
#
# Versions up to 2.77_2 Copyright (c) 1995-2004 Graham Barr <gbarr@pobox.com>.
# All rights reserved.
# Changes in Version 2.77_3 onwards Copyright (C) 2013-2015 Steve Hay.  All
# rights reserved.
# This module is free software; you can redistribute it and/or modify it under
# the same terms as Perl itself, i.e. under the terms of either the GNU General
# Public License or the Artistic License, as specified in the F<LICENCE> file.
#
# Documentation (at end) improved 1996 by Nathan Torkington <gnat@frii.com>.

package Net::FTP;

use 5.008001;

use strict;
use warnings;

use Carp;
use Fcntl qw(O_WRONLY O_RDONLY O_APPEND O_CREAT O_TRUNC);
use IO::Socket;
use Net::Cmd;
use Net::Config;
use Socket;
use Time::Local;

our $VERSION = '3.10';

our $IOCLASS;
my $family_key;
BEGIN {
  # Code for detecting if we can use SSL
  my $ssl_class = eval {
    require IO::Socket::SSL;
    # first version with default CA on most platforms
    no warnings 'numeric';
    IO::Socket::SSL->VERSION(2.007);
  } && 'IO::Socket::SSL';

  my $nossl_warn = !$ssl_class &&
    'To use SSL please install IO::Socket::SSL with version>=2.007';

  # Code for detecting if we can use IPv6
  my $inet6_class = eval {
    require IO::Socket::IP;
    no warnings 'numeric';
    IO::Socket::IP->VERSION(0.25);
  } && 'IO::Socket::IP' || eval {
    require IO::Socket::INET6;
    no warnings 'numeric';
    IO::Socket::INET6->VERSION(2.62);
  } && 'IO::Socket::INET6';

  sub can_ssl   { $ssl_class };
  sub can_inet6 { $inet6_class };

  $IOCLASS = $ssl_class || $inet6_class || 'IO::Socket::INET';
  $family_key =
    ( $ssl_class ? $ssl_class->can_ipv6 : $inet6_class || '' )
      eq 'IO::Socket::IP'
      ? 'Family' : 'Domain';
}

our @ISA = ('Exporter','Net::Cmd',$IOCLASS);

use constant TELNET_IAC => 255;
use constant TELNET_IP  => 244;
use constant TELNET_DM  => 242;

use constant EBCDIC => $^O eq 'os390';

sub new {
  my $pkg = shift;
  my ($peer, %arg);
  if (@_ % 2) {
    $peer = shift;
    %arg  = @_;
  }
  else {
    %arg  = @_;
    $peer = delete $arg{Host};
  }

  my $host      = $peer;
  my $fire      = undef;
  my $fire_type = undef;

  if (exists($arg{Firewall}) || Net::Config->requires_firewall($peer)) {
         $fire = $arg{Firewall}
      || $ENV{FTP_FIREWALL}
      || $NetConfig{ftp_firewall}
      || undef;

    if (defined $fire) {
      $peer = $fire;
      delete $arg{Port};
           $fire_type = $arg{FirewallType}
        || $ENV{FTP_FIREWALL_TYPE}
        || $NetConfig{firewall_type}
        || undef;
    }
  }

  my %tlsargs;
  if (can_ssl()) {
    # for name verification strip port from domain:port, ipv4:port, [ipv6]:port
    (my $hostname = $host) =~s{(?<!:):\d+$}{};
    %tlsargs = (
      SSL_verifycn_scheme => 'ftp',
      SSL_verifycn_name => $hostname,
      # use SNI if supported by IO::Socket::SSL
      $pkg->can_client_sni ? (SSL_hostname => $hostname):(),
      # reuse SSL session of control connection in data connections
      SSL_session_cache => Net::FTP::_SSL_SingleSessionCache->new,
    );
    # user defined SSL arg
    $tlsargs{$_} = $arg{$_} for(grep { m{^SSL_} } keys %arg);

  } elsif ($arg{SSL}) {
    croak("IO::Socket::SSL >= 2.007 needed for SSL support");
  }

  my $ftp = $pkg->SUPER::new(
    PeerAddr  => $peer,
    PeerPort  => $arg{Port} || ($arg{SSL} ? 'ftps(990)' : 'ftp(21)'),
    LocalAddr => $arg{'LocalAddr'},
    $family_key => $arg{Domain} || $arg{Family},
    Proto     => 'tcp',
    Timeout   => defined $arg{Timeout} ? $arg{Timeout} : 120,
    %tlsargs,
    $arg{SSL} ? ():( SSL_startHandshake => 0 ),
  ) or return;

  ${*$ftp}{'net_ftp_host'}    = $host;                             # Remote hostname
  ${*$ftp}{'net_ftp_type'}    = 'A';                               # ASCII/binary/etc mode
  ${*$ftp}{'net_ftp_blksize'} = abs($arg{'BlockSize'} || 10240);

  ${*$ftp}{'net_ftp_localaddr'} = $arg{'LocalAddr'};
  ${*$ftp}{'net_ftp_domain'} = $arg{Domain} || $arg{Family};

  ${*$ftp}{'net_ftp_firewall'} = $fire
    if (defined $fire);
  ${*$ftp}{'net_ftp_firewall_type'} = $fire_type
    if (defined $fire_type);

  ${*$ftp}{'net_ftp_passive'} =
      int exists $arg{Passive} ? $arg{Passive}
    : exists $ENV{FTP_PASSIVE} ? $ENV{FTP_PASSIVE}
    : defined $fire            ? $NetConfig{ftp_ext_passive}
    : $NetConfig{ftp_int_passive};    # Whew! :-)

  ${*$ftp}{net_ftp_tlsargs} = \%tlsargs if %tlsargs;
  if ($arg{SSL}) {
    ${*$ftp}{net_ftp_tlsprot} = 'P';
    ${*$ftp}{net_ftp_tlsdirect} = 1;
  }

  $ftp->hash(exists $arg{Hash} ? $arg{Hash} : 0, 1024);

  $ftp->autoflush(1);

  $ftp->debug(exists $arg{Debug} ? $arg{Debug} : undef);

  unless ($ftp->response() == CMD_OK) {
    $ftp->close();
    # keep @$ if no message. Happens, when response did not start with a code.
    $@ = $ftp->message || $@;
    undef $ftp;
  }

  $ftp;
}

##
## User interface methods
##


sub host {
  my $me = shift;
  ${*$me}{'net_ftp_host'};
}

sub passive {
  my $ftp = shift;
  return ${*$ftp}{'net_ftp_passive'} unless @_;
  ${*$ftp}{'net_ftp_passive'} = shift;
}


sub hash {
  my $ftp = shift;    # self

  my ($h, $b) = @_;
  unless ($h) {
    delete ${*$ftp}{'net_ftp_hash'};
    return [\*STDERR, 0];
  }
  ($h, $b) = (ref($h) ? $h : \*STDERR, $b || 1024);
  select((select($h), $| = 1)[0]);
  $b = 512 if $b < 512;
  ${*$ftp}{'net_ftp_hash'} = [$h, $b];
}


sub quit {
  my $ftp = shift;

  $ftp->_QUIT;
  $ftp->close;
}


sub DESTROY { }


sub ascii  { shift->type('A', @_); }
sub binary { shift->type('I', @_); }


sub ebcdic {
  carp "TYPE E is unsupported, shall default to I";
  shift->type('E', @_);
}


sub byte {
  carp "TYPE L is unsupported, shall default to I";
  shift->type('L', @_);
}

# Allow the user to send a command directly, BE CAREFUL !!


sub quot {
  my $ftp = shift;
  my $cmd = shift;

  $ftp->command(uc $cmd, @_);
  $ftp->response();
}


sub site {
  my $ftp = shift;

  $ftp->command("SITE", @_);
  $ftp->response();
}


sub mdtm {
  my $ftp  = shift;
  my $file = shift;

  # Server Y2K bug workaround
  #
  # sigh; some idiotic FTP servers use ("19%d",tm.tm_year) instead of
  # ("%d",tm.tm_year+1900).  This results in an extra digit in the
  # string returned. To account for this we allow an optional extra
  # digit in the year. Then if the first two digits are 19 we use the
  # remainder, otherwise we subtract 1900 from the whole year.

  $ftp->_MDTM($file)
    && $ftp->message =~ /((\d\d)(\d\d\d?))(\d\d)(\d\d)(\d\d)(\d\d)(\d\d)/
    ? timegm($8, $7, $6, $5, $4 - 1, $2 eq '19' ? $3 : ($1 - 1900))
    : undef;
}


sub size {
  my $ftp  = shift;
  my $file = shift;
  my $io;
  if ($ftp->supported("SIZE")) {
    return $ftp->_SIZE($file)
      ? ($ftp->message =~ /(\d+)\s*(bytes?\s*)?$/)[0]
      : undef;
  }
  elsif ($ftp->supported("STAT")) {
    my @msg;
    return
      unless $ftp->_STAT($file) && (@msg = $ftp->message) == 3;
    foreach my $line (@msg) {
      return (split(/\s+/, $line))[4]
        if $line =~ /^[-rwxSsTt]{10}/;
    }
  }
  else {
    my @files = $ftp->dir($file);
    if (@files) {
      return (split(/\s+/, $1))[4]
        if $files[0] =~ /^([-rwxSsTt]{10}.*)$/;
    }
  }
  undef;
}


sub starttls {
  my $ftp = shift;
  can_ssl() or croak("IO::Socket::SSL >= 2.007 needed for SSL support");
  $ftp->is_SSL and croak("called starttls within SSL session");
  $ftp->_AUTH('TLS') == CMD_OK or return;

  $ftp->connect_SSL or return;
  $ftp->prot('P');
  return 1;
}

sub prot {
  my ($ftp,$prot) = @_;
  $prot eq 'C' or $prot eq 'P' or croak("prot must by C or P");
  $ftp->_PBSZ(0) or return;
  $ftp->_PROT($prot) or return;
  ${*$ftp}{net_ftp_tlsprot} = $prot;
  return 1;
}

sub stoptls {
  my $ftp = shift;
  $ftp->is_SSL or croak("called stoptls outside SSL session");
  ${*$ftp}{net_ftp_tlsdirect} and croak("cannot stoptls direct SSL session");
  $ftp->_CCC() or return;
  $ftp->stop_SSL();
  return 1;
}

sub login {
  my ($ftp, $user, $pass, $acct) = @_;
  my ($ok, $ruser, $fwtype);

  unless (defined $user) {
    require Net::Netrc;

    my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_host'});

    ($user, $pass, $acct) = $rc->lpa()
      if ($rc);
  }

  $user ||= "anonymous";
  $ruser = $user;

  $fwtype = ${*$ftp}{'net_ftp_firewall_type'}
    || $NetConfig{'ftp_firewall_type'}
    || 0;

  if ($fwtype && defined ${*$ftp}{'net_ftp_firewall'}) {
    if ($fwtype == 1 || $fwtype == 7) {
      $user .= '@' . ${*$ftp}{'net_ftp_host'};
    }
    else {
      require Net::Netrc;

      my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_firewall'});

      my ($fwuser, $fwpass, $fwacct) = $rc ? $rc->lpa() : ();

      if ($fwtype == 5) {
        $user = join('@', $user, $fwuser, ${*$ftp}{'net_ftp_host'});
        $pass = $pass . '@' . $fwpass;
      }
      else {
        if ($fwtype == 2) {
          $user .= '@' . ${*$ftp}{'net_ftp_host'};
        }
        elsif ($fwtype == 6) {
          $fwuser .= '@' . ${*$ftp}{'net_ftp_host'};
        }

        $ok = $ftp->_USER($fwuser);

        return 0 unless $ok == CMD_OK || $ok == CMD_MORE;

        $ok = $ftp->_PASS($fwpass || "");

        return 0 unless $ok == CMD_OK || $ok == CMD_MORE;

        $ok = $ftp->_ACCT($fwacct)
          if defined($fwacct);

        if ($fwtype == 3) {
          $ok = $ftp->command("SITE", ${*$ftp}{'net_ftp_host'})->response;
        }
        elsif ($fwtype == 4) {
          $ok = $ftp->command("OPEN", ${*$ftp}{'net_ftp_host'})->response;
        }

        return 0 unless $ok == CMD_OK || $ok == CMD_MORE;
      }
    }
  }

  $ok = $ftp->_USER($user);

  # Some dumb firewalls don't prefix the connection messages
  $ok = $ftp->response()
    if ($ok == CMD_OK && $ftp->code == 220 && $user =~ /\@/);

  if ($ok == CMD_MORE) {
    unless (defined $pass) {
      require Net::Netrc;

      my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_host'}, $ruser);

      ($ruser, $pass, $acct) = $rc->lpa()
        if ($rc);

      $pass = '-anonymous@'
        if (!defined $pass && (!defined($ruser) || $ruser =~ /^anonymous/o));
    }

    $ok = $ftp->_PASS($pass || "");
  }

  $ok = $ftp->_ACCT($acct)
    if (defined($acct) && ($ok == CMD_MORE || $ok == CMD_OK));

  if ($fwtype == 7 && $ok == CMD_OK && defined ${*$ftp}{'net_ftp_firewall'}) {
    my ($f, $auth, $resp) = _auth_id($ftp);
    $ftp->authorize($auth, $resp) if defined($resp);
  }

  $ok == CMD_OK;
}


sub account {
  @_ == 2 or croak 'usage: $ftp->account( ACCT )';
  my $ftp  = shift;
  my $acct = shift;
  $ftp->_ACCT($acct) == CMD_OK;
}


sub _auth_id {
  my ($ftp, $auth, $resp) = @_;

  unless (defined $resp) {
    require Net::Netrc;

    $auth ||= eval { (getpwuid($>))[0] } || $ENV{NAME};

    my $rc = Net::Netrc->lookup(${*$ftp}{'net_ftp_firewall'}, $auth)
      || Net::Netrc->lookup(${*$ftp}{'net_ftp_firewall'});

    ($auth, $resp) = $rc->lpa()
      if ($rc);
  }
  ($ftp, $auth, $resp);
}


sub authorize {
  @_ >= 1 || @_ <= 3 or croak 'usage: $ftp->authorize( [AUTH [, RESP]])';

  my ($ftp, $auth, $resp) = &_auth_id;

  my $ok = $ftp->_AUTH($auth || "");

  return $ftp->_RESP($resp || "")
    if ($ok == CMD_MORE);

  $ok == CMD_OK;
}


sub rename {
  @_ == 3 or croak 'usage: $ftp->rename(FROM, TO)';

  my ($ftp, $from, $to) = @_;

  $ftp->_RNFR($from)
    && $ftp->_RNTO($to);
}


sub type {
  my $ftp    = shift;
  my $type   = shift;
  my $oldval = ${*$ftp}{'net_ftp_type'};

  return $oldval
    unless (defined $type);

  return
    unless ($ftp->_TYPE($type, @_));

  ${*$ftp}{'net_ftp_type'} = join(" ", $type, @_);

  $oldval;
}


sub alloc {
  my $ftp    = shift;
  my $size   = shift;
  my $oldval = ${*$ftp}{'net_ftp_allo'};

  return $oldval
    unless (defined $size);

  return
    unless ($ftp->supported("ALLO") and $ftp->_ALLO($size, @_));

  ${*$ftp}{'net_ftp_allo'} = join(" ", $size, @_);

  $oldval;
}


sub abort {
  my $ftp = shift;

  send($ftp, pack("CCC", TELNET_IAC, TELNET_IP, TELNET_IAC), MSG_OOB);

  $ftp->command(pack("C", TELNET_DM) . "ABOR");

  ${*$ftp}{'net_ftp_dataconn'}->close()
    if defined ${*$ftp}{'net_ftp_dataconn'};

  $ftp->response();

  $ftp->status == CMD_OK;
}


sub get {
  my ($ftp, $remote, $local, $where) = @_;

  my ($loc, $len, $buf, $resp, $data);
  local *FD;

  my $localfd = ref($local) || ref(\$local) eq "GLOB";

  ($local = $remote) =~ s#^.*/##
    unless (defined $local);

  croak("Bad remote filename '$remote'\n")
    if $remote =~ /[\r\n]/s;

  ${*$ftp}{'net_ftp_rest'} = $where if defined $where;
  my $rest = ${*$ftp}{'net_ftp_rest'};

  delete ${*$ftp}{'net_ftp_port'};
  delete ${*$ftp}{'net_ftp_pasv'};

  $data = $ftp->retr($remote)
    or return;

  if ($localfd) {
    $loc = $local;
  }
  else {
    $loc = \*FD;

    unless (sysopen($loc, $local, O_CREAT | O_WRONLY | ($rest ? O_APPEND: O_TRUNC))) {
      carp "Cannot open Local file $local: $!\n";
      $data->abort;
      return;
    }
  }

  if ($ftp->type eq 'I' && !binmode($loc)) {
    carp "Cannot binmode Local file $local: $!\n";
    $data->abort;
    close($loc) unless $localfd;
    return;
  }

  $buf = '';
  my ($count, $hashh, $hashb, $ref) = (0);

  ($hashh, $hashb) = @$ref
    if ($ref = ${*$ftp}{'net_ftp_hash'});

  my $blksize = ${*$ftp}{'net_ftp_blksize'};
  local $\;    # Just in case

  while (1) {
    last unless $len = $data->read($buf, $blksize);

    if (EBCDIC && $ftp->type ne 'I') {
      $buf = $ftp->toebcdic($buf);
      $len = length($buf);
    }

    if ($hashh) {
      $count += $len;
      print $hashh "#" x (int($count / $hashb));
      $count %= $hashb;
    }
    unless (print $loc $buf) {
      carp "Cannot write to Local file $local: $!\n";
      $data->abort;
      close($loc)
        unless $localfd;
      return;
    }
  }

  print $hashh "\n" if $hashh;

  unless ($localfd) {
    unless (close($loc)) {
      carp "Cannot close file $local (perhaps disk space) $!\n";
      return;
    }
  }

  unless ($data->close())    # implied $ftp->response
  {
    carp "Unable to close datastream";
    return;
  }

  return $local;
}


sub cwd {
  @_ == 1 || @_ == 2 or croak 'usage: $ftp->cwd( [ DIR ] )';

  my ($ftp, $dir) = @_;

  $dir = "/" unless defined($dir) && $dir =~ /\S/;

  $dir eq ".."
    ? $ftp->_CDUP()
    : $ftp->_CWD($dir);
}


sub cdup {
  @_ == 1 or croak 'usage: $ftp->cdup()';
  $_[0]->_CDUP;
}


sub pwd {
  @_ == 1 || croak 'usage: $ftp->pwd()';
  my $ftp = shift;

  $ftp->_PWD();
  $ftp->_extract_path;
}

# rmdir( $ftp, $dir, [ $recurse ] )
#
# Removes $dir on remote host via FTP.
# $ftp is handle for remote host
#
# If $recurse is TRUE, the directory and deleted recursively.
# This means all of its contents and subdirectories.
#
# Initial version contributed by Dinkum Software
#
sub rmdir {
  @_ == 2 || @_ == 3 or croak('usage: $ftp->rmdir( DIR [, RECURSE ] )');

  # Pick off the args
  my ($ftp, $dir, $recurse) = @_;
  my $ok;

  return $ok
    if $ok = $ftp->_RMD($dir)
    or !$recurse;

  # Try to delete the contents
  # Get a list of all the files in the directory, excluding the current and parent directories
  my @filelist = map { /^(?:\S+;)+ (.+)$/ ? ($1) : () } grep { !/^(?:\S+;)*type=[cp]dir;/ } $ftp->_list_cmd("MLSD", $dir);

  # Fallback to using the less well-defined NLST command if MLSD fails
  @filelist = grep { !/^\.{1,2}$/ } $ftp->ls($dir)
    unless @filelist;

  return
    unless @filelist;    # failed, it is probably not a directory

  return $ftp->delete($dir)
    if @filelist == 1 and $dir eq $filelist[0];

  # Go thru and delete each file or the directory
  foreach my $file (map { m,/, ? $_ : "$dir/$_" } @filelist) {
    next                 # successfully deleted the file
      if $ftp->delete($file);

    # Failed to delete it, assume its a directory
    # Recurse and ignore errors, the final rmdir() will
    # fail on any errors here
    return $ok
      unless $ok = $ftp->rmdir($file, 1);
  }

  # Directory should be empty
  # Try to remove the directory again
  # Pass results directly to caller
  # If any of the prior deletes failed, this
  # rmdir() will fail because directory is not empty
  return $ftp->_RMD($dir);
}


sub restart {
  @_ == 2 || croak 'usage: $ftp->restart( BYTE_OFFSET )';

  my ($ftp, $where) = @_;

  ${*$ftp}{'net_ftp_rest'} = $where;

  return;
}


sub mkdir {
  @_ == 2 || @_ == 3 or croak 'usage: $ftp->mkdir( DIR [, RECURSE ] )';

  my ($ftp, $dir, $recurse) = @_;

  $ftp->_MKD($dir) || $recurse
    or return;

  my $path = $dir;

  unless ($ftp->ok) {
    my @path = split(m#(?=/+)#, $dir);

    $path = "";

    while (@path) {
      $path .= shift @path;

      $ftp->_MKD($path);

      $path = $ftp->_extract_path($path);
    }

    # If the creation of the last element was not successful, see if we
    # can cd to it, if so then return path

    unless ($ftp->ok) {
      my ($status, $message) = ($ftp->status, $ftp->message);
      my $pwd = $ftp->pwd;

      if ($pwd && $ftp->cwd($dir)) {
        $path = $dir;
        $ftp->cwd($pwd);
      }
      else {
        undef $path;
      }
      $ftp->set_status($status, $message);
    }
  }

  $path;
}


sub delete {
  @_ == 2 || croak 'usage: $ftp->delete( FILENAME )';

  $_[0]->_DELE($_[1]);
}


sub put        { shift->_store_cmd("stor", @_) }
sub put_unique { shift->_store_cmd("stou", @_) }
sub append     { shift->_store_cmd("appe", @_) }


sub nlst { shift->_data_cmd("NLST", @_) }
sub list { shift->_data_cmd("LIST", @_) }
sub retr { shift->_data_cmd("RETR", @_) }
sub stor { shift->_data_cmd("STOR", @_) }
sub stou { shift->_data_cmd("STOU", @_) }
sub appe { shift->_data_cmd("APPE", @_) }


sub _store_cmd {
  my ($ftp, $cmd, $local, $remote) = @_;
  my ($loc, $sock, $len, $buf);
  local *FD;

  my $localfd = ref($local) || ref(\$local) eq "GLOB";

  if (!defined($remote) and 'STOU' ne uc($cmd)) {
    croak 'Must specify remote filename with stream input'
      if $localfd;

    require File::Basename;
    $remote = File::Basename::basename($local);
  }
  if (defined ${*$ftp}{'net_ftp_allo'}) {
    delete ${*$ftp}{'net_ftp_allo'};
  }
  else {

    # if the user hasn't already invoked the alloc method since the last
    # _store_cmd call, figure out if the local file is a regular file(not
    # a pipe, or device) and if so get the file size from stat, and send
    # an ALLO command before sending the STOR, STOU, or APPE command.
    my $size = do { local $^W; -f $local && -s _ };    # no ALLO if sending data from a pipe
    ${*$ftp}{'net_ftp_allo'} = $size if $size;
  }
  croak("Bad remote filename '$remote'\n")
    if defined($remote) and $remote =~ /[\r\n]/s;

  if ($localfd) {
    $loc = $local;
  }
  else {
    $loc = \*FD;

    unless (sysopen($loc, $local, O_RDONLY)) {
      carp "Cannot open Local file $local: $!\n";
      return;
    }
  }

  if ($ftp->type eq 'I' && !binmode($loc)) {
    carp "Cannot binmode Local file $local: $!\n";
    return;
  }

  delete ${*$ftp}{'net_ftp_port'};
  delete ${*$ftp}{'net_ftp_pasv'};

  $sock = $ftp->_data_cmd($cmd, grep { defined } $remote)
    or return;

  $remote = ($ftp->message =~ /\w+\s*:\s*(.*)/)[0]
    if 'STOU' eq uc $cmd;

  my $blksize = ${*$ftp}{'net_ftp_blksize'};

  my ($count, $hashh, $hashb, $ref) = (0);

  ($hashh, $hashb) = @$ref
    if ($ref = ${*$ftp}{'net_ftp_hash'});

  while (1) {
    last unless $len = read($loc, $buf = "", $blksize);

    if (EBCDIC && $ftp->type ne 'I') {
      $buf = $ftp->toascii($buf);
      $len = length($buf);
    }

    if ($hashh) {
      $count += $len;
      print $hashh "#" x (int($count / $hashb));
      $count %= $hashb;
    }

    my $wlen;
    unless (defined($wlen = $sock->write($buf, $len)) && $wlen == $len) {
      $sock->abort;
      close($loc)
        unless $localfd;
      print $hashh "\n" if $hashh;
      return;
    }
  }

  print $hashh "\n" if $hashh;

  close($loc)
    unless $localfd;

  $sock->close()
    or return;

  if ('STOU' eq uc $cmd and $ftp->message =~ m/unique\s+file\s*name\s*:\s*(.*)\)|"(.*)"/) {
    require File::Basename;
    $remote = File::Basename::basename($+);
  }

  return $remote;
}


sub port {
    @_ == 1 || @_ == 2 or croak 'usage: $self->port([PORT])';
    return _eprt('PORT',@_);
}

sub eprt {
  @_ == 1 || @_ == 2 or croak 'usage: $self->eprt([PORT])';
  return _eprt('EPRT',@_);
}

sub _eprt {
  my ($cmd,$ftp,$port) = @_;
  delete ${*$ftp}{net_ftp_intern_port};
  unless ($port) {
    my $listen = ${*$ftp}{net_ftp_listen} ||= $IOCLASS->new(
      Listen    => 1,
      Timeout   => $ftp->timeout,
      LocalAddr => $ftp->sockhost,
      $family_key  => $ftp->sockdomain,
      can_ssl() ? (
        %{ ${*$ftp}{net_ftp_tlsargs} },
        SSL_startHandshake => 0,
      ):(),
    );
    ${*$ftp}{net_ftp_intern_port} = 1;
    my $fam = ($listen->sockdomain == AF_INET) ? 1:2;
    if ( $cmd eq 'EPRT' || $fam == 2 ) {
      $port = "|$fam|".$listen->sockhost."|".$listen->sockport."|";
      $cmd = 'EPRT';
    } else {
      my $p = $listen->sockport;
      $port = join(',',split(m{\.},$listen->sockhost),$p >> 8,$p & 0xff);
    }
  } elsif (ref($port) eq 'ARRAY') {
    $port = join(',',split(m{\.},@$port[0]),@$port[1] >> 8,@$port[1] & 0xff);
  }
  my $ok = $cmd eq 'EPRT' ? $ftp->_EPRT($port) : $ftp->_PORT($port);
  ${*$ftp}{net_ftp_port} = $port if $ok;
  return $ok;
}


sub ls  { shift->_list_cmd("NLST", @_); }
sub dir { shift->_list_cmd("LIST", @_); }


sub pasv {
  my $ftp = shift;
  @_ and croak 'usage: $ftp->port()';
  return $ftp->epsv if $ftp->sockdomain != AF_INET;
  delete ${*$ftp}{net_ftp_intern_port};

  if ( $ftp->_PASV &&
    $ftp->message =~ m{(\d+,\d+,\d+,\d+),(\d+),(\d+)} ) {
    my $port = 256 * $2 + $3;
    ( my $ip = $1 ) =~s{,}{.}g;
    return ${*$ftp}{net_ftp_pasv} = [ $ip,$port ];
  }
  return;
}

sub epsv {
  my $ftp = shift;
  @_ and croak 'usage: $ftp->epsv()';
  delete ${*$ftp}{net_ftp_intern_port};

  $ftp->_EPSV && $ftp->message =~ m{\(([\x33-\x7e])\1\1(\d+)\1\)}
    ? ${*$ftp}{net_ftp_pasv} = [ $ftp->peerhost, $2 ]
    : undef;
}


sub unique_name {
  my $ftp = shift;
  ${*$ftp}{'net_ftp_unique'} || undef;
}


sub supported {
  @_ == 2 or croak 'usage: $ftp->supported( CMD )';
  my $ftp  = shift;
  my $cmd  = uc shift;
  my $hash = ${*$ftp}{'net_ftp_supported'} ||= {};

  return $hash->{$cmd}
    if exists $hash->{$cmd};

  return $hash->{$cmd} = 1
    if $ftp->feature($cmd);

  return $hash->{$cmd} = 0
    unless $ftp->_HELP($cmd);

  my $text = $ftp->message;
  if ($text =~ /following.+commands/i) {
    $text =~ s/^.*\n//;
    while ($text =~ /(\*?)(\w+)(\*?)/sg) {
      $hash->{"\U$2"} = !length("$1$3");
    }
  }
  else {
    $hash->{$cmd} = $text !~ /unimplemented/i;
  }

  $hash->{$cmd} ||= 0;
}

##
## Deprecated methods
##


sub lsl {
  carp "Use of Net::FTP::lsl deprecated, use 'dir'"
    if $^W;
  goto &dir;
}


sub authorise {
  carp "Use of Net::FTP::authorise deprecated, use 'authorize'"
    if $^W;
  goto &authorize;
}


##
## Private methods
##


sub _extract_path {
  my ($ftp, $path) = @_;

  # This tries to work both with and without the quote doubling
  # convention (RFC 959 requires it, but the first 3 servers I checked
  # didn't implement it).  It will fail on a server which uses a quote in
  # the message which isn't a part of or surrounding the path.
  $ftp->ok
    && $ftp->message =~ /(?:^|\s)\"(.*)\"(?:$|\s)/
    && ($path = $1) =~ s/\"\"/\"/g;

  $path;
}

##
## Communication methods
##


sub _dataconn {
  my $ftp = shift;
  my $pkg = "Net::FTP::" . $ftp->type;
  eval "require " . $pkg ## no critic (BuiltinFunctions::ProhibitStringyEval)
    or croak("cannot load $pkg required for type ".$ftp->type);
  $pkg =~ s/ /_/g;
  delete ${*$ftp}{net_ftp_dataconn};

  my $conn;
  my $pasv = ${*$ftp}{net_ftp_pasv};
  if ($pasv) {
    $conn = $pkg->new(
      PeerAddr  => $pasv->[0],
      PeerPort  => $pasv->[1],
      LocalAddr => ${*$ftp}{net_ftp_localaddr},
      $family_key => ${*$ftp}{net_ftp_domain},
      Timeout   => $ftp->timeout,
      can_ssl() ? (
        SSL_startHandshake => 0,
        $ftp->is_SSL ? (
          SSL_reuse_ctx => $ftp,
          SSL_verifycn_name => ${*$ftp}{net_ftp_tlsargs}{SSL_verifycn_name},
          # This will cause the use of SNI if supported by IO::Socket::SSL.
          $ftp->can_client_sni ? (
            SSL_hostname  => ${*$ftp}{net_ftp_tlsargs}{SSL_hostname}
          ):(),
        ) :( %{${*$ftp}{net_ftp_tlsargs}} ),
      ):(),
    ) or return;
  } elsif (my $listen =  delete ${*$ftp}{net_ftp_listen}) {
    $conn = $listen->accept($pkg) or return;
    $conn->timeout($ftp->timeout);
    close($listen);
  } else {
    croak("no listener in active mode");
  }

  if (( ${*$ftp}{net_ftp_tlsprot} || '') eq 'P') {
    if ($conn->connect_SSL) {
      # SSL handshake ok
    } else {
      carp("failed to ssl upgrade dataconn: $IO::Socket::SSL::SSL_ERROR");
      return;
    }
  }

  ${*$ftp}{net_ftp_dataconn} = $conn;
  ${*$conn} = "";
  ${*$conn}{net_ftp_cmd} = $ftp;
  ${*$conn}{net_ftp_blksize} = ${*$ftp}{net_ftp_blksize};
  return $conn;
}


sub _list_cmd {
  my $ftp = shift;
  my $cmd = uc shift;

  delete ${*$ftp}{'net_ftp_port'};
  delete ${*$ftp}{'net_ftp_pasv'};

  my $data = $ftp->_data_cmd($cmd, @_);

  return
    unless (defined $data);

  require Net::FTP::A;
  bless $data, "Net::FTP::A";    # Force ASCII mode

  my $databuf = '';
  my $buf     = '';
  my $blksize = ${*$ftp}{'net_ftp_blksize'};

  while ($data->read($databuf, $blksize)) {
    $buf .= $databuf;
  }

  my $list = [split(/\n/, $buf)];

  $data->close();

  if (EBCDIC) {
    for (@$list) { $_ = $ftp->toebcdic($_) }
  }

  wantarray
    ? @{$list}
    : $list;
}


sub _data_cmd {
  my $ftp   = shift;
  my $cmd   = uc shift;
  my $ok    = 1;
  my $where = delete ${*$ftp}{'net_ftp_rest'} || 0;
  my $arg;

  for my $arg (@_) {
    croak("Bad argument '$arg'\n")
      if $arg =~ /[\r\n]/s;
  }

  if ( ${*$ftp}{'net_ftp_passive'}
    && !defined ${*$ftp}{'net_ftp_pasv'}
    && !defined ${*$ftp}{'net_ftp_port'})
  {
    return unless defined $ftp->pasv;

    if ($where and !$ftp->_REST($where)) {
      my ($status, $message) = ($ftp->status, $ftp->message);
      $ftp->abort;
      $ftp->set_status($status, $message);
      return;
    }

    # first send command, then open data connection
    # otherwise the peer might not do a full accept (with SSL
    # handshake if PROT P)
    $ftp->command($cmd, @_);
    my $data = $ftp->_dataconn();
    if (CMD_INFO == $ftp->response()) {
      $data->reading
        if $data && $cmd =~ /RETR|LIST|NLST|MLSD/;
      return $data;
    }
    $data->_close if $data;

    return;
  }

  $ok = $ftp->port
    unless (defined ${*$ftp}{'net_ftp_port'}
    || defined ${*$ftp}{'net_ftp_pasv'});

  $ok = $ftp->_REST($where)
    if $ok && $where;

  return
    unless $ok;

  if ($cmd =~ /(STOR|APPE|STOU)/ and exists ${*$ftp}{net_ftp_allo} and
      $ftp->supported("ALLO"))
  {
    $ftp->_ALLO(delete ${*$ftp}{net_ftp_allo})
      or return;
  }

  $ftp->command($cmd, @_);

  return 1
    if (defined ${*$ftp}{'net_ftp_pasv'});

  $ok = CMD_INFO == $ftp->response();

  return $ok
    unless exists ${*$ftp}{'net_ftp_intern_port'};

  if ($ok) {
    my $data = $ftp->_dataconn();

    $data->reading
      if $data && $cmd =~ /RETR|LIST|NLST|MLSD/;

    return $data;
  }


  close(delete ${*$ftp}{'net_ftp_listen'});

  return;
}

##
## Over-ride methods (Net::Cmd)
##


sub debug_text { $_[2] =~ /^(pass|resp|acct)/i ? "$1 ....\n" : $_[2]; }


sub command {
  my $ftp = shift;

  delete ${*$ftp}{'net_ftp_port'};
  $ftp->SUPER::command(@_);
}


sub response {
  my $ftp  = shift;
  my $code = $ftp->SUPER::response() || 5;    # assume 500 if undef

  delete ${*$ftp}{'net_ftp_pasv'}
    if ($code != CMD_MORE && $code != CMD_INFO);

  $code;
}


sub parse_response {
  return ($1, $2 eq "-")
    if $_[1] =~ s/^(\d\d\d)([- ]?)//o;

  my $ftp = shift;

  # Darn MS FTP server is a load of CRAP !!!!
  # Expect to see undef here.
  return ()
    unless 0 + (${*$ftp}{'net_cmd_code'} || 0);

  (${*$ftp}{'net_cmd_code'}, 1);
}

##
## Allow 2 servers to talk directly
##


sub pasv_xfer_unique {
  my ($sftp, $sfile, $dftp, $dfile) = @_;
  $sftp->pasv_xfer($sfile, $dftp, $dfile, 1);
}


sub pasv_xfer {
  my ($sftp, $sfile, $dftp, $dfile, $unique) = @_;

  ($dfile = $sfile) =~ s#.*/##
    unless (defined $dfile);

  my $port = $sftp->pasv
    or return;

  $dftp->port($port)
    or return;

  return
    unless ($unique ? $dftp->stou($dfile) : $dftp->stor($dfile));

  unless ($sftp->retr($sfile) && $sftp->response == CMD_INFO) {
    $sftp->retr($sfile);
    $dftp->abort;
    $dftp->response();
    return;
  }

  $dftp->pasv_wait($sftp);
}


sub pasv_wait {
  @_ == 2 or croak 'usage: $ftp->pasv_wait(NON_PASV_FTP)';

  my ($ftp, $non_pasv) = @_;
  my ($file, $rin, $rout);

  vec($rin = '', fileno($ftp), 1) = 1;
  select($rout = $rin, undef, undef, undef);

  my $dres = $ftp->response();
  my $sres = $non_pasv->response();

  return
    unless $dres == CMD_OK && $sres == CMD_OK;

  return
    unless $ftp->ok() && $non_pasv->ok();

  return $1
    if $ftp->message =~ /unique file name:\s*(\S*)\s*\)/;

  return $1
    if $non_pasv->message =~ /unique file name:\s*(\S*)\s*\)/;

  return 1;
}


sub feature {
  @_ == 2 or croak 'usage: $ftp->feature( NAME )';
  my ($ftp, $feat) = @_;

  my $feature = ${*$ftp}{net_ftp_feature} ||= do {
    my @feat;

    # Example response
    # 211-Features:
    #  MDTM
    #  REST STREAM
    #  SIZE
    # 211 End

    @feat = map { /^\s+(.*\S)/ } $ftp->message
      if $ftp->_FEAT;

    \@feat;
  };

  return grep { /^\Q$feat\E\b/i } @$feature;
}


sub cmd { shift->command(@_)->response() }

########################################
#
# RFC959 + RFC2428 + RFC4217 commands
#


sub _ABOR { shift->command("ABOR")->response() == CMD_OK }
sub _ALLO { shift->command("ALLO", @_)->response() == CMD_OK }
sub _CDUP { shift->command("CDUP")->response() == CMD_OK }
sub _NOOP { shift->command("NOOP")->response() == CMD_OK }
sub _PASV { shift->command("PASV")->response() == CMD_OK }
sub _QUIT { shift->command("QUIT")->response() == CMD_OK }
sub _DELE { shift->command("DELE", @_)->response() == CMD_OK }
sub _CWD  { shift->command("CWD", @_)->response() == CMD_OK }
sub _PORT { shift->command("PORT", @_)->response() == CMD_OK }
sub _RMD  { shift->command("RMD", @_)->response() == CMD_OK }
sub _MKD  { shift->command("MKD", @_)->response() == CMD_OK }
sub _PWD  { shift->command("PWD", @_)->response() == CMD_OK }
sub _TYPE { shift->command("TYPE", @_)->response() == CMD_OK }
sub _RNTO { shift->command("RNTO", @_)->response() == CMD_OK }
sub _RESP { shift->command("RESP", @_)->response() == CMD_OK }
sub _MDTM { shift->command("MDTM", @_)->response() == CMD_OK }
sub _SIZE { shift->command("SIZE", @_)->response() == CMD_OK }
sub _HELP { shift->command("HELP", @_)->response() == CMD_OK }
sub _STAT { shift->command("STAT", @_)->response() == CMD_OK }
sub _FEAT { shift->command("FEAT", @_)->response() == CMD_OK }
sub _PBSZ { shift->command("PBSZ", @_)->response() == CMD_OK }
sub _PROT { shift->command("PROT", @_)->response() == CMD_OK }
sub _CCC  { shift->command("CCC", @_)->response() == CMD_OK }
sub _EPRT { shift->command("EPRT", @_)->response() == CMD_OK }
sub _EPSV { shift->command("EPSV", @_)->response() == CMD_OK }
sub _APPE { shift->command("APPE", @_)->response() == CMD_INFO }
sub _LIST { shift->command("LIST", @_)->response() == CMD_INFO }
sub _NLST { shift->command("NLST", @_)->response() == CMD_INFO }
sub _RETR { shift->command("RETR", @_)->response() == CMD_INFO }
sub _STOR { shift->command("STOR", @_)->response() == CMD_INFO }
sub _STOU { shift->command("STOU", @_)->response() == CMD_INFO }
sub _RNFR { shift->command("RNFR", @_)->response() == CMD_MORE }
sub _REST { shift->command("REST", @_)->response() == CMD_MORE }
sub _PASS { shift->command("PASS", @_)->response() }
sub _ACCT { shift->command("ACCT", @_)->response() }
sub _AUTH { shift->command("AUTH", @_)->response() }


sub _USER {
  my $ftp = shift;
  my $ok  = $ftp->command("USER", @_)->response();

  # A certain brain dead firewall :-)
  $ok = $ftp->command("user", @_)->response()
    unless $ok == CMD_MORE or $ok == CMD_OK;

  $ok;
}


sub _SMNT { shift->unsupported(@_) }
sub _MODE { shift->unsupported(@_) }
sub _SYST { shift->unsupported(@_) }
sub _STRU { shift->unsupported(@_) }
sub _REIN { shift->unsupported(@_) }

{
  # Session Cache with single entry
  # used to make sure that we reuse same session for control and data channels
  package Net::FTP::_SSL_SingleSessionCache;
  sub new { my $x; return bless \$x,shift }
  sub add_session {
    my ($cache,$key,$session) = @_;
    Net::SSLeay::SESSION_free($$cache) if $$cache;
    $$cache = $session;
  }
  sub get_session {
    my $cache = shift;
    return $$cache
  }
  sub DESTROY {
    my $cache = shift;
    Net::SSLeay::SESSION_free($$cache) if $$cache;
  }
}

1;

__END__

#line 2050

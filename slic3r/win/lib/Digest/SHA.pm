#line 1 "Digest/SHA.pm"
package Digest::SHA;

require 5.003000;

use strict;
use warnings;
use vars qw($VERSION @ISA @EXPORT_OK);
use Fcntl qw(O_RDONLY);
use integer;

$VERSION = '5.96';

require Exporter;
require DynaLoader;
@ISA = qw(Exporter DynaLoader);
@EXPORT_OK = qw(
	hmac_sha1	hmac_sha1_base64	hmac_sha1_hex
	hmac_sha224	hmac_sha224_base64	hmac_sha224_hex
	hmac_sha256	hmac_sha256_base64	hmac_sha256_hex
	hmac_sha384	hmac_sha384_base64	hmac_sha384_hex
	hmac_sha512	hmac_sha512_base64	hmac_sha512_hex
	hmac_sha512224	hmac_sha512224_base64	hmac_sha512224_hex
	hmac_sha512256	hmac_sha512256_base64	hmac_sha512256_hex
	sha1		sha1_base64		sha1_hex
	sha224		sha224_base64		sha224_hex
	sha256		sha256_base64		sha256_hex
	sha384		sha384_base64		sha384_hex
	sha512		sha512_base64		sha512_hex
	sha512224	sha512224_base64	sha512224_hex
	sha512256	sha512256_base64	sha512256_hex);

# Inherit from Digest::base if possible

eval {
	require Digest::base;
	push(@ISA, 'Digest::base');
};

# The following routines aren't time-critical, so they can be left in Perl

sub new {
	my($class, $alg) = @_;
	$alg =~ s/\D+//g if defined $alg;
	if (ref($class)) {	# instance method
		if (!defined($alg) || ($alg == $class->algorithm)) {
			sharewind($class);
			return($class);
		}
		return shainit($class, $alg) ? $class : undef;
	}
	$alg = 1 unless defined $alg;
	return $class->newSHA($alg);
}

BEGIN { *reset = \&new }

sub add_bits {
	my($self, $data, $nbits) = @_;
	unless (defined $nbits) {
		$nbits = length($data);
		$data = pack("B*", $data);
	}
	$nbits = length($data) * 8 if $nbits > length($data) * 8;
	shawrite($data, $nbits, $self);
	return($self);
}

sub _bail {
	my $msg = shift;

	$msg .= ": $!";
	require Carp;
	Carp::croak($msg);
}

{
	my $_can_T_filehandle;

	sub _istext {
		local *FH = shift;
		my $file = shift;

		if (! defined $_can_T_filehandle) {
			local $^W = 0;
			my $istext = eval { -T FH };
			$_can_T_filehandle = $@ ? 0 : 1;
			return $_can_T_filehandle ? $istext : -T $file;
		}
		return $_can_T_filehandle ? -T FH : -T $file;
	}
}

sub _addfile {
	my ($self, $handle) = @_;

	my $n;
	my $buf = "";

	while (($n = read($handle, $buf, 4096))) {
		$self->add($buf);
	}
	_bail("Read failed") unless defined $n;

	$self;
}

sub addfile {
	my ($self, $file, $mode) = @_;

	return(_addfile($self, $file)) unless ref(\$file) eq 'SCALAR';

	$mode = defined($mode) ? $mode : "";
	my ($binary, $UNIVERSAL, $BITS, $portable) =
		map { $_ eq $mode } ("b", "U", "0", "p");

		## Always interpret "-" to mean STDIN; otherwise use
		## sysopen to handle full range of POSIX file names

	local *FH;
	$file eq '-' and open(FH, '< -')
		or sysopen(FH, $file, O_RDONLY)
			or _bail('Open failed');

	if ($BITS) {
		my ($n, $buf) = (0, "");
		while (($n = read(FH, $buf, 4096))) {
			$buf =~ s/[^01]//g;
			$self->add_bits($buf);
		}
		_bail("Read failed") unless defined $n;
		close(FH);
		return($self);
	}

	binmode(FH) if $binary || $portable || $UNIVERSAL;
	if ($UNIVERSAL && _istext(*FH, $file)) {
		$self->_addfileuniv(*FH);
	}
	elsif ($portable && _istext(*FH, $file)) {
		while (<FH>) {
			s/\015?\015\012/\012/g;
			s/\015/\012/g;
			$self->add($_);
		}
	}
	else { $self->_addfilebin(*FH) }
	close(FH);

	$self;
}

sub getstate {
	my $self = shift;

	my $alg = $self->algorithm or return;
	my $state = $self->_getstate or return;
	my $nD = $alg <= 256 ?  8 :  16;
	my $nH = $alg <= 256 ? 32 :  64;
	my $nB = $alg <= 256 ? 64 : 128;
	my($H, $block, $blockcnt, $lenhh, $lenhl, $lenlh, $lenll) =
		$state =~ /^(.{$nH})(.{$nB})(.{4})(.{4})(.{4})(.{4})(.{4})$/s;
	for ($alg, $H, $block, $blockcnt, $lenhh, $lenhl, $lenlh, $lenll) {
		return unless defined $_;
	}

	my @s = ();
	push(@s, "alg:" . $alg);
	push(@s, "H:" . join(":", unpack("H*", $H) =~ /.{$nD}/g));
	push(@s, "block:" . join(":", unpack("H*", $block) =~ /.{2}/g));
	push(@s, "blockcnt:" . unpack("N", $blockcnt));
	push(@s, "lenhh:" . unpack("N", $lenhh));
	push(@s, "lenhl:" . unpack("N", $lenhl));
	push(@s, "lenlh:" . unpack("N", $lenlh));
	push(@s, "lenll:" . unpack("N", $lenll));
	join("\n", @s) . "\n";
}

sub putstate {
	my($class, $state) = @_;

	my %s = ();
	for (split(/\n/, $state)) {
		s/^\s+//;
		s/\s+$//;
		next if (/^(#|$)/);
		my @f = split(/[:\s]+/);
		my $tag = shift(@f);
		$s{$tag} = join('', @f);
	}

	# H and block may contain arbitrary values, but check everything else
	grep { $_ == $s{'alg'} } (1,224,256,384,512,512224,512256) or return;
	length($s{'H'}) == ($s{'alg'} <= 256 ? 64 : 128) or return;
	length($s{'block'}) == ($s{'alg'} <= 256 ? 128 : 256) or return;
	{
		no integer;
		for (qw(blockcnt lenhh lenhl lenlh lenll)) {
			0 <= $s{$_} or return;
			$s{$_} <= 4294967295 or return;
		}
		$s{'blockcnt'} < ($s{'alg'} <= 256 ? 512 : 1024) or return;
	}

	my $packed_state = (
		pack("H*", $s{'H'}) .
		pack("H*", $s{'block'}) .
		pack("N",  $s{'blockcnt'}) .
		pack("N",  $s{'lenhh'}) .
		pack("N",  $s{'lenhl'}) .
		pack("N",  $s{'lenlh'}) .
		pack("N",  $s{'lenll'})
	);

	return $class->new($s{'alg'})->_putstate($packed_state);
}

sub dump {
	my $self = shift;
	my $file = shift;

	my $state = $self->getstate or return;
	$file = "-" if (!defined($file) || $file eq "");

	local *FH;
	open(FH, "> $file") or return;
	print FH $state;
	close(FH);

	return($self);
}

sub load {
	my $class = shift;
	my $file = shift;

	$file = "-" if (!defined($file) || $file eq "");

	local *FH;
	open(FH, "< $file") or return;
	my $str = join('', <FH>);
	close(FH);

	$class->putstate($str);
}

Digest::SHA->bootstrap($VERSION);

1;
__END__

#line 824

#line 1 "URI/data.pm"
package URI::data;  # RFC 2397

use strict;
use warnings;

use parent 'URI';

our $VERSION = '1.71';
$VERSION = eval $VERSION;

use MIME::Base64 qw(encode_base64 decode_base64);
use URI::Escape  qw(uri_unescape);

sub media_type
{
    my $self = shift;
    my $opaque = $self->opaque;
    $opaque =~ /^([^,]*),?/ or die;
    my $old = $1;
    my $base64;
    $base64 = $1 if $old =~ s/(;base64)$//i;
    if (@_) {
	my $new = shift;
	$new = "" unless defined $new;
	$new =~ s/%/%25/g;
	$new =~ s/,/%2C/g;
	$base64 = "" unless defined $base64;
	$opaque =~ s/^[^,]*,?/$new$base64,/;
	$self->opaque($opaque);
    }
    return uri_unescape($old) if $old;  # media_type can't really be "0"
    "text/plain;charset=US-ASCII";      # default type
}

sub data
{
    my $self = shift;
    my($enc, $data) = split(",", $self->opaque, 2);
    unless (defined $data) {
	$data = "";
	$enc  = "" unless defined $enc;
    }
    my $base64 = ($enc =~ /;base64$/i);
    if (@_) {
	$enc =~ s/;base64$//i if $base64;
	my $new = shift;
	$new = "" unless defined $new;
	my $uric_count = _uric_count($new);
	my $urienc_len = $uric_count + (length($new) - $uric_count) * 3;
	my $base64_len = int((length($new)+2) / 3) * 4;
	$base64_len += 7;  # because of ";base64" marker
	if ($base64_len < $urienc_len || $_[0]) {
	    $enc .= ";base64";
	    $new = encode_base64($new, "");
	} else {
	    $new =~ s/%/%25/g;
	}
	$self->opaque("$enc,$new");
    }
    return unless defined wantarray;
    $data = uri_unescape($data);
    return $base64 ? decode_base64($data) : $data;
}

# I could not find a better way to interpolate the tr/// chars from
# a variable.
my $ENC = $URI::uric;
$ENC =~ s/%//;

eval <<EOT; die $@ if $@;
sub _uric_count
{
    \$_[0] =~ tr/$ENC//;
}
EOT

1;

__END__

#line 144

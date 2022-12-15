#line 1 "HTTP/Headers/Util.pm"
package HTTP::Headers::Util;

use strict;
use warnings;

our $VERSION = "6.11";

use base 'Exporter';

our @EXPORT_OK=qw(split_header_words _split_header_words join_header_words);


sub split_header_words {
    my @res = &_split_header_words;
    for my $arr (@res) {
	for (my $i = @$arr - 2; $i >= 0; $i -= 2) {
	    $arr->[$i] = lc($arr->[$i]);
	}
    }
    return @res;
}

sub _split_header_words
{
    my(@val) = @_;
    my @res;
    for (@val) {
	my @cur;
	while (length) {
	    if (s/^\s*(=*[^\s=;,]+)//) {  # 'token' or parameter 'attribute'
		push(@cur, $1);
		# a quoted value
		if (s/^\s*=\s*\"([^\"\\]*(?:\\.[^\"\\]*)*)\"//) {
		    my $val = $1;
		    $val =~ s/\\(.)/$1/g;
		    push(@cur, $val);
		# some unquoted value
		}
		elsif (s/^\s*=\s*([^;,\s]*)//) {
		    my $val = $1;
		    $val =~ s/\s+$//;
		    push(@cur, $val);
		# no value, a lone token
		}
		else {
		    push(@cur, undef);
		}
	    }
	    elsif (s/^\s*,//) {
		push(@res, [@cur]) if @cur;
		@cur = ();
	    }
	    elsif (s/^\s*;// || s/^\s+//) {
		# continue
	    }
	    else {
		die "This should not happen: '$_'";
	    }
	}
	push(@res, \@cur) if @cur;
    }
    @res;
}


sub join_header_words
{
    @_ = ([@_]) if @_ && !ref($_[0]);
    my @res;
    for (@_) {
	my @cur = @$_;
	my @attr;
	while (@cur) {
	    my $k = shift @cur;
	    my $v = shift @cur;
	    if (defined $v) {
		if ($v =~ /[\x00-\x20()<>@,;:\\\"\/\[\]?={}\x7F-\xFF]/ || !length($v)) {
		    $v =~ s/([\"\\])/\\$1/g;  # escape " and \
		    $k .= qq(="$v");
		}
		else {
		    # token
		    $k .= "=$v";
		}
	    }
	    push(@attr, $k);
	}
	push(@res, join("; ", @attr)) if @attr;
    }
    join(", ", @res);
}


1;

__END__

#line 198

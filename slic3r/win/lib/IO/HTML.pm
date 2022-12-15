#line 1 "IO/HTML.pm"
#---------------------------------------------------------------------
package IO::HTML;
#
# Copyright 2014 Christopher J. Madsen
#
# Author: Christopher J. Madsen <perl@cjmweb.net>
# Created: 14 Jan 2012
#
# This program is free software; you can redistribute it and/or modify
# it under the same terms as Perl itself.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either the
# GNU General Public License or the Artistic License for more details.
#
# ABSTRACT: Open an HTML file with automatic charset detection
#---------------------------------------------------------------------

use 5.008;
use strict;
use warnings;

use Carp 'croak';
use Encode 2.10 qw(decode find_encoding); # need utf-8-strict encoding
use Exporter 5.57 'import';

our $VERSION = '1.001';
# This file is part of IO-HTML 1.001 (June 28, 2014)

our $default_encoding ||= 'cp1252';

our @EXPORT    = qw(html_file);
our @EXPORT_OK = qw(find_charset_in html_file_and_encoding html_outfile
                    sniff_encoding);

our %EXPORT_TAGS = (
  rw  => [qw( html_file html_file_and_encoding html_outfile )],
  all => [ @EXPORT, @EXPORT_OK ],
);

#=====================================================================


sub html_file
{
  (&html_file_and_encoding)[0]; # return just the filehandle
} # end html_file


# Note: I made html_file and html_file_and_encoding separate functions
# (instead of making html_file context-sensitive) because I wanted to
# use html_file in function calls (i.e. list context) without having
# to write "scalar html_file" all the time.

sub html_file_and_encoding
{
  my ($filename, $options) = @_;

  $options ||= {};

  open(my $in, '<:raw', $filename) or croak "Failed to open $filename: $!";


  my ($encoding, $bom) = sniff_encoding($in, $filename, $options);

  if (not defined $encoding) {
    croak "No default encoding specified"
        unless defined($encoding = $default_encoding);
    $encoding = find_encoding($encoding) if $options->{encoding};
  } # end if we didn't find an encoding

  binmode $in, sprintf(":encoding(%s):crlf",
                       $options->{encoding} ? $encoding->name : $encoding);

  return ($in, $encoding, $bom);
} # end html_file_and_encoding
#---------------------------------------------------------------------


sub html_outfile
{
  my ($filename, $encoding, $bom) = @_;

  if (not defined $encoding) {
    croak "No default encoding specified"
        unless defined($encoding = $default_encoding);
  } # end if we didn't find an encoding
  elsif (ref $encoding) {
    $encoding = $encoding->name;
  }

  open(my $out, ">:encoding($encoding)", $filename)
      or croak "Failed to open $filename: $!";

  print $out "\x{FeFF}" if $bom;

  return $out;
} # end html_outfile
#---------------------------------------------------------------------


sub sniff_encoding
{
  my ($in, $filename, $options) = @_;

  $filename = 'file' unless defined $filename;
  $options ||= {};

  my $pos = tell $in;
  croak "Could not seek $filename: $!" if $pos < 0;

  croak "Could not read $filename: $!" unless defined read $in, my $buf, 1024;

  seek $in, $pos, 0 or croak "Could not seek $filename: $!";


  # Check for BOM:
  my $bom;
  my $encoding = do {
    if ($buf =~ /^\xFe\xFF/) {
      $bom = 2;
      'UTF-16BE';
    } elsif ($buf =~ /^\xFF\xFe/) {
      $bom = 2;
      'UTF-16LE';
    } elsif ($buf =~ /^\xEF\xBB\xBF/) {
      $bom = 3;
      'utf-8-strict';
    } else {
      find_charset_in($buf, $options); # check for <meta charset>
    }
  }; # end $encoding

  if ($bom) {
    seek $in, $bom, 1 or croak "Could not seek $filename: $!";
    $bom = 1;
  }
  elsif (not defined $encoding) { # try decoding as UTF-8
    my $test = decode('utf-8-strict', $buf, Encode::FB_QUIET);
    if ($buf =~ /^(?:                   # nothing left over
         | [\xC2-\xDF]                  # incomplete 2-byte char
         | [\xE0-\xEF] [\x80-\xBF]?     # incomplete 3-byte char
         | [\xF0-\xF4] [\x80-\xBF]{0,2} # incomplete 4-byte char
        )\z/x and $test =~ /[^\x00-\x7F]/) {
      $encoding = 'utf-8-strict';
    } # end if valid UTF-8 with at least one multi-byte character:
  } # end if testing for UTF-8

  if (defined $encoding and $options->{encoding} and not ref $encoding) {
    $encoding = find_encoding($encoding);
  } # end if $encoding is a string and we want an object

  return wantarray ? ($encoding, $bom) : $encoding;
} # end sniff_encoding

#=====================================================================
# Based on HTML5 8.2.2.2 Determining the character encoding:

# Get attribute from current position of $_
sub _get_attribute
{
  m!\G[\x09\x0A\x0C\x0D /]+!gc; # skip whitespace or /

  return if /\G>/gc or not /\G(=?[^\x09\x0A\x0C\x0D =]*)/gc;

  my ($name, $value) = (lc $1, '');

  if (/\G[\x09\x0A\x0C\x0D ]*=[\x09\x0A\x0C\x0D ]*/gc
      and (/\G"([^"]*)"?/gc or
           /\G'([^']*)'?/gc or
           /\G([^\x09\x0A\x0C\x0D >]*)/gc)) {
    $value = lc $1;
  } # end if attribute has value

  return wantarray ? ($name, $value) : 1;
} # end _get_attribute

# Examine a meta value for a charset:
sub _get_charset_from_meta
{
  for (shift) {
    while (/charset[\x09\x0A\x0C\x0D ]*=[\x09\x0A\x0C\x0D ]*/ig) {
      return $1 if (/\G"([^"]*)"/gc or
                    /\G'([^']*)'/gc or
                    /\G(?!['"])([^\x09\x0A\x0C\x0D ;]+)/gc);
    }
  } # end for value

  return undef;
} # end _get_charset_from_meta
#---------------------------------------------------------------------


sub find_charset_in
{
  for (shift) {
    my $options = shift || {};
    my $stop = length > 1024 ? 1024 : length; # search first 1024 bytes

    my $expect_pragma = (defined $options->{need_pragma}
                         ? $options->{need_pragma} : 1);

    pos() = 0;
    while (pos() < $stop) {
      if (/\G<!--.*?(?<=--)>/sgc) {
      } # Skip comment
      elsif (m!\G<meta(?=[\x09\x0A\x0C\x0D /])!gic) {
        my ($got_pragma, $need_pragma, $charset);

        while (my ($name, $value) = &_get_attribute) {
          if ($name eq 'http-equiv' and $value eq 'content-type') {
            $got_pragma = 1;
          } elsif ($name eq 'content' and not defined $charset) {
            $need_pragma = $expect_pragma
                if defined($charset = _get_charset_from_meta($value));
          } elsif ($name eq 'charset') {
            $charset = $value;
            $need_pragma = 0;
          }
        } # end while more attributes in this <meta> tag

        if (defined $need_pragma and (not $need_pragma or $got_pragma)) {
          $charset = 'UTF-8'  if $charset =~ /^utf-?16/;
          $charset = 'cp1252' if $charset eq 'iso-8859-1'; # people lie
          if (my $encoding = find_encoding($charset)) {
            return $options->{encoding} ? $encoding : $encoding->name;
          } # end if charset is a recognized encoding
        } # end if found charset
      } # end elsif <meta
      elsif (m!\G</?[a-zA-Z][^\x09\x0A\x0C\x0D >]*!gc) {
        1 while &_get_attribute;
      } # end elsif some other tag
      elsif (m{\G<[!/?][^>]*}gc) {
      } # skip unwanted things
      elsif (m/\G</gc) {
      } # skip < that doesn't open anything we recognize

      # Advance to the next <:
      m/\G[^<]+/gc;
    } # end while not at search boundary
  } # end for string

  return undef;                 # Couldn't find a charset
} # end find_charset_in
#---------------------------------------------------------------------


# Shortcuts for people who don't like exported functions:
*file               = \&html_file;
*file_and_encoding  = \&html_file_and_encoding;
*outfile            = \&html_outfile;

#=====================================================================
# Package Return Value:

1;

__END__

#line 576

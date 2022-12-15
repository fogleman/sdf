package ExtUtils::XSpp::Exception::unknown;
use strict;
use warnings;

use base 'ExtUtils::XSpp::Exception';

sub init {
  my $this = shift;
  $this->SUPER::init(@_);
}

sub handler_code {
  my $this = shift;
  my $no_spaces_indent = shift;
  $no_spaces_indent = 4 if not defined $no_spaces_indent;

  my $msg = "Caught C++ exception of unknown type";
  my $code = <<HERE;
catch (...) {
  croak("$msg");
}
HERE
  return $this->indent_code($code, $no_spaces_indent);
}

1;

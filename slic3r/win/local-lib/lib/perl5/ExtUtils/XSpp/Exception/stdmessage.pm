package ExtUtils::XSpp::Exception::stdmessage;
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

  my $ctype = $this->cpp_type;
  my $msg = "Caught C++ exception of type or derived from '$ctype': \%s";
  my $code = <<HERE;
catch ($ctype& e) {
  croak("$msg", e.what());
}
HERE
  return $this->indent_code($code, $no_spaces_indent);
}

1;

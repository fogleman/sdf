package ExtUtils::XSpp::Exception::code;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Exception';

sub _dl { return defined( $_[0] ) && length( $_[0] ) ? $_[0] : undef }

sub init {
  my $this = shift;
  $this->SUPER::init(@_);
  my %args = @_;

  $this->{HANDLER_CODE} = _dl( $args{handler_code} || $args{arg1} );
}

sub handler_code {
  my $this = shift;
  my $no_spaces_indent = shift;
  $no_spaces_indent = 4 if not defined $no_spaces_indent;

  my $ctype = $this->cpp_type;
  my $user_code = $this->{HANDLER_CODE};
  $user_code =~ s/^\s+//;
  $user_code =~ s/\s+$//;
  $user_code = $this->indent_code($user_code, 2);
  my $code = <<HERE;
catch ($ctype& e) {
$user_code
}
HERE
  return $this->indent_code($code, $no_spaces_indent);
}

1;

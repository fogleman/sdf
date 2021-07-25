package ExtUtils::XSpp::Exception::object;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Exception';

sub _dl { return defined( $_[0] ) && length( $_[0] ) ? $_[0] : undef }

sub init {
  my $this = shift;
  $this->SUPER::init(@_);
  my %args = @_;

  $this->{PERL_EXCEPTION_CLASS} = _dl( $args{perl_class} || $args{arg1} );
}

sub handler_code {
  my $this = shift;
  my $no_spaces_indent = shift;
  $no_spaces_indent = 4 if not defined $no_spaces_indent;

  my $ctype = $this->cpp_type;
  my $pclass = $this->{PERL_EXCEPTION_CLASS};
  $pclass =~ s/^\s+//;
  $pclass =~ s/\s+$//;
  my $code = <<HERE;
catch ($ctype& e) {
  SV* errsv;
  SV* objsv;
  objsv = eval_pv("$pclass->new()", 1);
  errsv = get_sv("@", TRUE);
  sv_setsv(errsv, exception_object);
  croak(NULL);
}
HERE
  return $this->indent_code($code, $no_spaces_indent);
}

1;

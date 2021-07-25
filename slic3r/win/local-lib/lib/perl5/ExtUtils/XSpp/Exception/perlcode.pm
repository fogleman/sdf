package ExtUtils::XSpp::Exception::perlcode;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Exception';

sub _dl { return defined( $_[0] ) && length( $_[0] ) ? $_[0] : undef }

sub init {
  my $this = shift;
  $this->SUPER::init(@_);
  my %args = @_;

  $this->{PERL_CODE} = _dl( $args{perl_code} || $args{arg1} );
}

sub handler_code {
  my $this = shift;
  my $no_spaces_indent = shift;
  $no_spaces_indent = 4 if not defined $no_spaces_indent;

  my $ctype = $this->cpp_type;
  my $pcode = $this->{PERL_CODE};
  $pcode =~ s/^\s+//;
  $pcode =~ s/\s+$//;
  $pcode =~ s/\\/\\\\/g;
  $pcode =~ s/"/\\"/g;
  my @lines = split /\n/, $pcode;
  $pcode = '"' . join(qq{"\n"}, @lines) . qq{"};
  $pcode = $this->indent_code($pcode, 4);
  my $code = <<HERE;
catch ($ctype& e) {
  SV* errsv;
  SV* excsv;
  excsv = eval_pv(
$pcode,
    1
  );
  errsv = get_sv("@", TRUE);
  sv_setsv(errsv, excsv);
  croak(NULL);
}
HERE
  return $this->indent_code($code, $no_spaces_indent);
}

1;

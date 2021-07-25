package ExtUtils::Typemaps::STL::Vector;

use strict;
use warnings;
use ExtUtils::Typemaps;

our $VERSION = '1.05';

our @ISA = qw(ExtUtils::Typemaps);

=head1 NAME

ExtUtils::Typemaps::STL::Vector - A set of typemaps for STL std::vectors

=head1 SYNOPSIS

  use ExtUtils::Typemaps::STL::Vector;
  # First, read my own type maps:
  my $private_map = ExtUtils::Typemaps->new(file => 'my.map');
  
  # Then, get the object map set and merge it into my maps
  $private_map->merge(typemap => ExtUtils::Typemaps::STL::Vector->new);
  
  # Now, write the combined map to an output file
  $private_map->write(file => 'typemap');

=head1 DESCRIPTION

C<ExtUtils::Typemaps::STL::Vector> is an C<ExtUtils::Typemaps>
subclass that provides a set of mappings for C++ STL vectors.
These are:

  TYPEMAP
  std::vector<double>		T_STD_VECTOR_DOUBLE
  std::vector<double>*		T_STD_VECTOR_DOUBLE_PTR
  
  std::vector<int>		T_STD_VECTOR_INT
  std::vector<int>*		T_STD_VECTOR_INT_PTR
  
  std::vector<unsigned int>	T_STD_VECTOR_UINT
  std::vector<unsigned int>*	T_STD_VECTOR_UINT_PTR
  
  std::vector<std::string>	T_STD_VECTOR_STD_STRING
  std::vector<std::string>*	T_STD_VECTOR_STD_STRING_PTR
  
  std::vector<char*>	T_STD_VECTOR_CSTRING
  std::vector<char*>*	T_STD_VECTOR_CSTRING_PTR

All of these mean that the vectors are converted to references
to Perl arrays and vice versa.

=head1 METHODS

These are the overridden methods:

=head2 new

Creates a new C<ExtUtils::Typemaps::STL::Vector> object.
It acts as any other C<ExtUtils::Typemaps> object, except that
it has the vector type maps initialized.

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);
  my $input_tmpl = <<'HERE';
!TYPENAME!
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int len = av_len(av)+1;
	  $var = std::vector<!TYPE!>(len);
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL)
	      ${var}[i] = Sv!SHORTTYPE!V(*elem);
	    else
	      ${var}[i] = !DEFAULT!;
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

!TYPENAME!_PTR
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int len = av_len(av)+1;
	  $var = new std::vector<!TYPE!>(len);
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL)
	      (*$var)[i] = Sv!SHORTTYPE!V(*elem);
	    else
	      (*$var)[i] = 0.;
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

HERE

  my $output_tmpl = <<'HERE';
!TYPENAME!
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var.size();
        if (len)
          av_extend(av, len-1);
	for (unsigned int i = 0; i < len; i++) {
	  av_store(av, i, newSV!SHORTTYPELC!v(${var}[i]));
	}

!TYPENAME!_PTR
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var->size();
        if (len)
          av_extend(av, len-1);
	for (unsigned int i = 0; i < len; i++) {
	  av_store(av, i, newSV!SHORTTYPELC!v((*$var)[i]));
	}

HERE

  my ($output_code, $input_code);
  # TYPENAME, TYPE, SHORTTYPE, SHORTTYPELC, DEFAULT
  foreach my $type ([qw(T_STD_VECTOR_DOUBLE double N n 0.)],
                    [qw(T_STD_VECTOR_INT int I i 0)],
                    [qw(T_STD_VECTOR_UINT), "unsigned int", qw(U u 0)])
  {
    my @type = @$type;
    my $otmpl = $output_tmpl;
    my $itmpl = $input_tmpl;

    for ($otmpl, $itmpl) {
      s/!TYPENAME!/$type[0]/g;
      s/!TYPE!/$type[1]/g;
      s/!SHORTTYPE!/$type[2]/g;
      s/!SHORTTYPELC!/$type[3]/g;
      s/!DEFAULT!/$type[4]/g;
    }

    $output_code .= $otmpl;
    $input_code  .= $itmpl;
  }

  # add a static part
  $output_code .= <<'END_OUTPUT';
T_STD_VECTOR_STD_STRING
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var.size();
        if (len)
          av_extend(av, len-1);
	for (unsigned int i = 0; i < len; i++) {
	  const std::string& str = ${var}[i];
	  STRLEN len = str.length();
	  av_store(av, i, newSVpv(str.c_str(), len));
	}

T_STD_VECTOR_STD_STRING_PTR
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var->size();
        if (len)
          av_extend(av, len-1);
	for (unsigned int i = 0; i < len; i++) {
	  const std::string& str = (*$var)[i];
	  STRLEN len = str.length();
	  av_store(av, i, newSVpv(str.c_str(), len));
	}

T_STD_VECTOR_CSTRING
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var.size();
        if (len)
          av_extend(av, len-1);
	for (unsigned int i = 0; i < len; i++) {
	  STRLEN len = strlen(${var}[i]);
	  av_store(av, i, newSVpv(${var}[i], len));
	}

T_STD_VECTOR_CSTRING_PTR
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var->size();
        if (len)
          av_extend(av, len-1);
	for (unsigned int i = 0; i < len; i++) {
	  STRLEN len = strlen((*$var)[i]);
	  av_store(av, i, newSVpv((*$var)[i], len));
	}

END_OUTPUT

  # add a static part to input
  $input_code .= <<'END_INPUT';
T_STD_VECTOR_STD_STRING
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int alen = av_len(av)+1;
	  $var = std::vector<std::string>(alen);
	  STRLEN len;
	  char* tmp;
	  SV** elem;
	  for (unsigned int i = 0; i < alen; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	    tmp = SvPV(*elem, len);
	      ${var}[i] = std::string(tmp, len);
	    }
	    else
	      ${var}[i] = std::string(\"\");
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

T_STD_VECTOR_STD_STRING_PTR
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int alen = av_len(av)+1;
	  $var = new std::vector<std::string>(alen);
	  STRLEN len;
	  char* tmp;
	  SV** elem;
	  for (unsigned int i = 0; i < alen; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	      tmp = SvPV(*elem, len);
	      (*$var)[i] = std::string(tmp, len);
	    }
	    else
	      (*$var)[i] = std::string(\"\");
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

T_STD_VECTOR_CSTRING
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int len = av_len(av)+1;
	  $var = std::vector<char*>(len);
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	      ${var}[i] = SvPV_nolen(*elem);
	    else
	      ${var}[i] = NULL;
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

T_STD_VECTOR_CSTRING_PTR
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int len = av_len(av)+1;
	  $var = new std::vector<char*>(len);
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	      (*$var)[i] = SvPV_nolen(*elem);
	    else
	      (*$var)[i] = NULL;
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");
END_INPUT

  my $typemap_code = <<'END_TYPEMAP';
TYPEMAP
std::vector<double>*	T_STD_VECTOR_DOUBLE_PTR
std::vector<double>	T_STD_VECTOR_DOUBLE
std::vector<int>*	T_STD_VECTOR_INT_PTR
std::vector<int>	T_STD_VECTOR_INT
std::vector<unsigned int>*	T_STD_VECTOR_UINT_PTR
std::vector<unsigned int>	T_STD_VECTOR_UINT
std::vector<std::string>	T_STD_VECTOR_STD_STRING
std::vector<std::string>*	T_STD_VECTOR_STD_STRING_PTR
std::vector<char*>	T_STD_VECTOR_CSTRING
std::vector<char*>*	T_STD_VECTOR_CSTRING_PTR

INPUT
END_TYPEMAP
  $typemap_code .= $input_code;
  $typemap_code .= "\nOUTPUT\n";
  $typemap_code .= $output_code;
  $typemap_code .= "\n";

  $self->add_string(string => $typemap_code);

  return $self;
}

1;

__END__

=head1 SEE ALSO

L<ExtUtils::Typemaps>, L<ExtUtils::Typemaps::Default>, L<ExtUtils::Typemaps::ObjectMap>,
L<ExtUtils::Typemaps::STL>, L<ExtUtils::Typemaps::STL::String>

=head1 AUTHOR

Steffen Mueller <smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2010, 2011, 2012, 2013 by Steffen Mueller

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

package ExtUtils::Typemaps::STL::List;

use strict;
use warnings;
use ExtUtils::Typemaps;

our $VERSION = '1.05';

our @ISA = qw(ExtUtils::Typemaps);

=head1 NAME

ExtUtils::Typemaps::STL::List - A set of typemaps for STL std::lists

=head1 SYNOPSIS

  use ExtUtils::Typemaps::STL::List;
  # First, read my own type maps:
  my $private_map = ExtUtils::Typemaps->new(file => 'my.map');
  
  # Then, get the object map set and merge it into my maps
  $private_map->merge(typemap => ExtUtils::Typemaps::STL::List->new);
  
  # Now, write the combined map to an output file
  $private_map->write(file => 'typemap');

=head1 DESCRIPTION

C<ExtUtils::Typemaps::STL::List> is an C<ExtUtils::Typemaps>
subclass that provides a set of mappings for C++ STL lists.
These are:

  TYPEMAP
  std::list<double>		T_STD_LIST_DOUBLE
  std::list<double>*		T_STD_LIST_DOUBLE_PTR
  
  std::list<int>		T_STD_LIST_INT
  std::list<int>*		T_STD_LIST_INT_PTR
  
  std::list<unsigned int>	T_STD_LIST_UINT
  std::list<unsigned int>*	T_STD_LIST_UINT_PTR
  
  std::list<std::string>	T_STD_LIST_STD_STRING
  std::list<std::string>*	T_STD_LIST_STD_STRING_PTR
  
  std::list<char*>		T_STD_LIST_CSTRING
  std::list<char*>*		T_STD_LIST_CSTRING_PTR

All of these mean that the lists are converted to references
to Perl arrays and vice versa.

=head1 METHODS

These are the overridden methods:

=head2 new

Creates a new C<ExtUtils::Typemaps::STL::List> object.
It acts as any other C<ExtUtils::Typemaps> object, except that
it has the list type maps initialized.

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);
  my $input_tmpl = <<'HERE';
!TYPENAME!
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int len = av_len(av)+1;
	  $var = std::list<!TYPE!>();
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL)
	      ${var}.push_back(Sv!SHORTTYPE!V(*elem));
	    else
	      ${var}[i].push_back(!DEFAULT!);
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
	  $var = new std::list<!TYPE!>();
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL)
	      (*$var).push_back(Sv!SHORTTYPE!V(*elem));
	    else
	      (*$var).push_back(!DEFAULT!);
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
	const unsigned int len = $var.size(); // Technically may be linear...
	av_extend(av, len-1);
	unsigned int i = 0;
	std::list<!TYPE!>::const_iterator lend = $var.cend();
	std::list<!TYPE!>::const_iterator lit  = $var.cbegin();
	for (; lit != lend; ++lit) {
	  av_store(av, i++, newSV!SHORTTYPELC!v(*lit));
	}

!TYPENAME!_PTR
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var->size(); // Technically may be linear...
	av_extend(av, len-1);
	unsigned int i = 0;
	std::list<!TYPE!>::const_iterator lend = (*$var).cend();
	std::list<!TYPE!>::const_iterator lit  = (*$var).cbegin();
	for (; lit != lend; ++lit) {
	  av_store(av, i++, newSV!SHORTTYPELC!v(*lit));
	}

HERE

  my ($output_code, $input_code);
  # TYPENAME, TYPE, SHORTTYPE, SHORTTYPELC, DEFAULT
  foreach my $type ([qw(T_STD_LIST_DOUBLE double N n 0.)],
                    [qw(T_STD_LIST_INT int I i 0)],
                    [qw(T_STD_LIST_UINT), "unsigned int", qw(U u 0)])
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
T_STD_LIST_STD_STRING
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var.size(); // Technically may be linear...
	av_extend(av, len-1);
	unsigned int i = 0;
	std::list<std::string>::const_iterator lend = $var.cend();
	std::list<std::string>::const_iterator lit  = $var.cbegin();
	for (; lit != lend; ++lit) {
	  const std::string& str = *lit;
	  STRLEN len = str.length();
	  av_store(av, i++, newSVpv(str.c_str(), len));
	}

T_STD_LIST_STD_STRING_PTR
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var->size(); // Technically may be linear...
	av_extend(av, len-1);
	unsigned int i = 0;
	std::list<std::string>::const_iterator lend = (*$var).cend();
	std::list<std::string>::const_iterator lit  = (*$var).cbegin();
	for (; lit != lend; ++lit) {
	  const std::string& str = *lit;
	  STRLEN len = str.length();
	  av_store(av, i++, newSVpv(str.c_str(), len));
	}

T_STD_LIST_CSTRING
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var.size();
	av_extend(av, len-1);
	unsigned int i = 0;
	std::list<char *>::const_iterator lend = $var.cend();
	std::list<char *>::const_iterator lit  = $var.cbegin();
	for (; lit != lend; ++lit) {
	  av_store(av, i, newSVpv(*lit, (STRLEN)strlen(*lit)));
	}

T_STD_LIST_CSTRING_PTR
	AV* av = newAV();
	$arg = newRV_noinc((SV*)av);
	const unsigned int len = $var->size();
	av_extend(av, len-1);
	unsigned int i = 0;
	std::list<char *>::const_iterator lend = (*$var).cend();
	std::list<char *>::const_iterator lit  = (*$var).cbegin();
	for (; lit != lend; ++lit) {
	  av_store(av, i, newSVpv(*lit, (STRLEN)strlen(*lit)));
	}

END_OUTPUT

  # add a static part to input
  $input_code .= <<'END_INPUT';
T_STD_LIST_STD_STRING
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int alen = av_len(av)+1;
	  $var = std::list<std::string>();
	  STRLEN len;
	  char* tmp;
	  SV** elem;
	  for (unsigned int i = 0; i < alen; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	      tmp = SvPV(*elem, len);
	      ${var}.push_back(std::string(tmp, len));
	    }
	    else
	      ${var}.push_back(std::string(\"\"));
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

T_STD_LIST_STD_STRING_PTR
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int alen = av_len(av)+1;
	  $var = new std::list<std::string>(alen);
	  STRLEN len;
	  char* tmp;
	  SV** elem;
	  for (unsigned int i = 0; i < alen; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	      tmp = SvPV(*elem, len);
	      (*$var).push_back(std::string(tmp, len));
	    }
	    else
	      (*$var).push_back(std::string(\"\"));
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

T_STD_LIST_CSTRING
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int len = av_len(av)+1;
	  $var = std::list<char*>();
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	      ${var}.push_back(SvPV_nolen(*elem));
	    else
	      ${var}.push_back(NULL);
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");

T_STD_LIST_CSTRING_PTR
	if (SvROK($arg) && SvTYPE(SvRV($arg))==SVt_PVAV) {
	  AV* av = (AV*)SvRV($arg);
	  const unsigned int len = av_len(av)+1;
	  $var = new std::list<char*>();
	  SV** elem;
	  for (unsigned int i = 0; i < len; i++) {
	    elem = av_fetch(av, i, 0);
	    if (elem != NULL) {
	      (*$var).push_back(SvPV_nolen(*elem));
	    else
	      (*$var).push_back(NULL);
	  }
	}
	else
	  Perl_croak(aTHX_ \"%s: %s is not an array reference\",
	             ${$ALIAS?\q[GvNAME(CvGV(cv))]:\qq[\"$pname\"]},
	             \"$var\");
END_INPUT

  my $typemap_code = <<'END_TYPEMAP';
TYPEMAP
std::list<double>*		T_STD_LIST_DOUBLE_PTR
std::list<double>		T_STD_LIST_DOUBLE
std::list<int>*			T_STD_LIST_INT_PTR
std::list<int>			T_STD_LIST_INT
std::list<unsigned int>*	T_STD_LIST_UINT_PTR
std::list<unsigned int>		T_STD_LIST_UINT
std::list<std::string>		T_STD_LIST_STD_STRING
std::list<std::string>*		T_STD_LIST_STD_STRING_PTR
std::list<string>		T_STD_LIST_STD_STRING
std::list<string>*		T_STD_LIST_STD_STRING_PTR
std::list<char*>		T_STD_LIST_CSTRING
std::list<char*>*		T_STD_LIST_CSTRING_PTR
list<double>*			T_STD_LIST_DOUBLE_PTR
list<double>			T_STD_LIST_DOUBLE
list<int>*			T_STD_LIST_INT_PTR
list<int>			T_STD_LIST_INT
list<unsigned int>*		T_STD_LIST_UINT_PTR
list<unsigned int>		T_STD_LIST_UINT
list<std::string>		T_STD_LIST_STD_STRING
list<std::string>*		T_STD_LIST_STD_STRING_PTR
list<string>			T_STD_LIST_STD_STRING
list<string>*			T_STD_LIST_STD_STRING_PTR
list<char*>			T_STD_LIST_CSTRING
list<char*>*			T_STD_LIST_CSTRING_PTR

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
L<ExtUtils::Typemaps::STL>, L<ExtUtils::Typemaps::STL::String>, L<ExtUtils::Typemaps::STL::Vector>

=head1 AUTHOR

Steffen Mueller <smueller@cpan.org>

=head1 COPYRIGHT AND LICENSE

Copyright 2013 by Steffen Mueller

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

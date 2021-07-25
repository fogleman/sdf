package ExtUtils::Typemaps::ObjectMap;

use strict;
use warnings;
use ExtUtils::Typemaps;

our $VERSION = '1.05';

our @ISA = qw(ExtUtils::Typemaps);

=head1 NAME

ExtUtils::Typemaps::ObjectMap - A set of typemaps for opaque C/C++ objects

=head1 SYNOPSIS

  use ExtUtils::Typemaps::ObjectMap;
  # First, read my own type maps:
  my $private_map = ExtUtils::Typemaps->new(file => 'my.map');
  
  # Then, get the object map set and merge it into my maps
  $private_map->merge(typemap => ExtUtils::Typemaps::ObjectMap->new);
  
  # Now, write the combined map to an output file
  $private_map->write(file => 'typemap');

=head1 DESCRIPTION

C<ExtUtils::Typemaps::ObjectMap> is an C<ExtUtils::Typemaps>
subclass that provides a set of mappings for using pointers to
C/C++ objects as opaque objects from Perl.

These mappings are taken verbatim from Dean Roehrich's C<perlobject.map>.
They are:

  # "perlobject.map"  Dean Roehrich, version 19960302
  #
  # TYPEMAPs
  #
  # HV *		-> unblessed Perl HV object.
  # AV *		-> unblessed Perl AV object.
  #
  # INPUT/OUTPUT maps
  #
  # O_*		-> opaque blessed objects
  # T_*		-> opaque blessed or unblessed objects
  #
  # O_OBJECT	-> link an opaque C or C++ object to a blessed Perl object.
  # T_OBJECT	-> link an opaque C or C++ object to an unblessed Perl object.
  # O_HvRV	-> a blessed Perl HV object.
  # T_HvRV	-> an unblessed Perl HV object.
  # O_AvRV	-> a blessed Perl AV object.
  # T_AvRV	-> an unblessed Perl AV object.

=head1 METHODS

These are the overridden methods:

=head2 new

Creates a new C<ExtUtils::Typemaps::ObjectMap> object.
It acts as any other C<ExtUtils::Typemaps> object, except that
it has the object maps initialized.

=cut

sub new {
  my $class = shift;

  my $self = $class->SUPER::new(@_);
  $self->add_string(string => <<'END_TYPEMAP');
# "perlobject.map"  Dean Roehrich, version 19960302
#
# TYPEMAPs
#
# HV *		-> unblessed Perl HV object.
# AV *		-> unblessed Perl AV object.
#
# INPUT/OUTPUT maps
#
# O_*		-> opaque blessed objects
# T_*		-> opaque blessed or unblessed objects
#
# O_OBJECT	-> link an opaque C or C++ object to a blessed Perl object.
# T_OBJECT	-> link an opaque C or C++ object to an unblessed Perl object.
# O_HvRV	-> a blessed Perl HV object.
# T_HvRV	-> an unblessed Perl HV object.
# O_AvRV	-> a blessed Perl AV object.
# T_AvRV	-> an unblessed Perl AV object.

TYPEMAP

HV *		T_HvRV
AV *		T_AvRV


######################################################################
OUTPUT

# The Perl object is blessed into 'CLASS', which should be a
# char* having the name of the package for the blessing.
O_OBJECT
	sv_setref_pv( $arg, CLASS, (void*)$var );

T_OBJECT
	sv_setref_pv( $arg, Nullch, (void*)$var );

# Cannot use sv_setref_pv() because that will destroy
# the HV-ness of the object.  Remember that newRV() will increment
# the refcount.
O_HvRV
	$arg = sv_bless( newRV((SV*)$var), gv_stashpv(CLASS,1) );

T_HvRV
	$arg = newRV((SV*)$var);

# Cannot use sv_setref_pv() because that will destroy
# the AV-ness of the object.  Remember that newRV() will increment
# the refcount.
O_AvRV
	$arg = sv_bless( newRV((SV*)$var), gv_stashpv(CLASS,1) );

T_AvRV
	$arg = newRV((SV*)$var);


######################################################################
INPUT

O_OBJECT
	if( sv_isobject($arg) && (SvTYPE(SvRV($arg)) == SVt_PVMG) )
		$var = ($type)SvIV((SV*)SvRV( $arg ));
	else{
		warn( \"${Package}::$func_name() -- $var is not a blessed SV reference\" );
		XSRETURN_UNDEF;
	}

T_OBJECT
	if( SvROK($arg) )
		$var = ($type)SvIV((SV*)SvRV( $arg ));
	else{
		warn( \"${Package}::$func_name() -- $var is not an SV reference\" );
		XSRETURN_UNDEF;
	}

O_HvRV
	if( sv_isobject($arg) && (SvTYPE(SvRV($arg)) == SVt_PVHV) )
		$var = (HV*)SvRV( $arg );
	else {
		warn( \"${Package}::$func_name() -- $var is not a blessed HV reference\" );
		XSRETURN_UNDEF;
	}

T_HvRV
	if( SvROK($arg) && (SvTYPE(SvRV($arg)) == SVt_PVHV) )
		$var = (HV*)SvRV( $arg );
	else {
		warn( \"${Package}::$func_name() -- $var is not an HV reference\" );
		XSRETURN_UNDEF;
	}

O_AvRV
	if( sv_isobject($arg) && (SvTYPE(SvRV($arg)) == SVt_PVAV) )
		$var = (AV*)SvRV( $arg );
	else {
		warn( \"${Package}::$func_name() -- $var is not a blessed AV reference\" );
		XSRETURN_UNDEF;
	}

T_AvRV
	if( SvROK($arg) && (SvTYPE(SvRV($arg)) == SVt_PVAV) )
		$var = (AV*)SvRV( $arg );
	else {
		warn( \"${Package}::$func_name() -- $var is not an AV reference\" );
		XSRETURN_UNDEF;
	}

END_TYPEMAP

  return $self;
}

1;

__END__

=head1 SEE ALSO

L<ExtUtils::Typemaps>, L<ExtUtils::Typemaps::Default>, L<ExtUtils::Typemaps::STL::String>

=head1 AUTHOR

The module was written by Steffen Mueller <smueller@cpan.org>,
but the important bit, the typemap, was written by Dean Roehrich.

=head1 COPYRIGHT AND LICENSE

Copyright 2010, 2011, 2012, 2013 by Steffen Mueller

Except for the typemap code, which is copyright 1996 Dean Roehrich

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

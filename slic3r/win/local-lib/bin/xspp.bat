@rem = '--*-Perl-*--
@echo off
if "%OS%" == "Windows_NT" goto WinNT
perl -x -S "%0" %1 %2 %3 %4 %5 %6 %7 %8 %9
goto endofperl
:WinNT
perl -x -S %0 %*
if NOT "%COMSPEC%" == "%SystemRoot%\system32\cmd.exe" goto endofperl
if %errorlevel% == 9009 echo You do not have Perl in your PATH.
if errorlevel 1 goto script_failed_so_exit_with_non_zero_val 2>nul
goto endofperl
@rem ';
#!C:\strawberry\perl\bin\perl.exe -w
#line 15
#############################################################################
## Name:        script/xspp
## Purpose:     XS++ preprocessor
## Author:      Mattia Barbon
## Modified by:
## Created:     01/03/2003
## RCS-ID:      $Id: wxperl_xspp 2334 2008-01-21 22:38:57Z mbarbon $
## Copyright:   (c) 2003-2004, 2006, 2008 Mattia Barbon
## Licence:     This program is free software; you can redistribute it and/or
##              modify it under the same terms as Perl itself
#############################################################################

use strict;

=head1 NAME

xspp - XS++ preprocessor

=head1 SYNOPSIS

    xspp [--typemap=typemap.xsp [--typemap=typemap2.xsp]]
         [--xsubpp[=/path/to/xsubpp] [--xsubpp-args="xsubpp args"]
         Foo.xsp

or

    perl -MExtUtils::XSpp::Cmd -e xspp -- <xspp options and arguments>

=head1 DOCUMENTATION

See L<ExtUtils::XSpp>.

=cut

use ExtUtils::XSpp::Cmd;

exit xspp;

__END__
:endofperl

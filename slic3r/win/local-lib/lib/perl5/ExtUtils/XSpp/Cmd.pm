package ExtUtils::XSpp::Cmd;

use strict;

=head1 NAME

ExtUtils::XSpp::Cmd - implementation of xspp

=head1 SYNOPSIS

  perl -MExtUtils::XSpp::Cmd -e xspp -- <xspp options/arguments>

In Foo.xs

  INCLUDE_COMMAND: $^X -MExtUtils::XSpp::Cmd -e xspp -- <xspp options/arguments>

Using C<ExtUtils::XSpp::Cmd> is equivalent to using the C<xspp>
command line script, except that there is no guarantee for C<xspp> to
be installed in the system PATH.

=head1 DOCUMENTATION

See L<ExtUtils::XSpp>, L<xspp>.

=cut

use Exporter 'import';
use Getopt::Long;

use ExtUtils::XSpp::Driver;

our @EXPORT = qw(xspp);

sub xspp {
    my( @typemap_files, $xsubpp, $xsubpp_args );
    GetOptions( 'typemap=s'       => \@typemap_files,
                'xsubpp:s'        => \$xsubpp,
                'xsubpp-args=s'   => \$xsubpp_args,
                );
    $xsubpp = 'xsubpp' if defined $xsubpp && !length $xsubpp;

    my $driver = ExtUtils::XSpp::Driver->new
      ( typemaps    => \@typemap_files,
        file        => shift @ARGV,
        xsubpp      => $xsubpp,
        xsubpp_args => $xsubpp_args,
        );
    my $success = $driver->process ? 0 : 1;

    exit $success unless defined wantarray;
    return $success;
}

1;

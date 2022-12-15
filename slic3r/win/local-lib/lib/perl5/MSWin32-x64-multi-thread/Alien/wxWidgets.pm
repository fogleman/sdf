package Alien::wxWidgets;

=head1 NAME

Alien::wxWidgets - building, finding and using wxWidgets binaries

=head1 SYNOPSIS

    use Alien::wxWidgets <options>;

    my $version = Alien::wxWidgets->version;
    my $config = Alien::wxWidgets->config;
    my $compiler = Alien::wxWidgets->compiler;
    my $linker = Alien::wxWidgets->linker;
    my $include_path = Alien::wxWidgets->include_path;
    my $defines = Alien::wxWidgets->defines;
    my $cflags = Alien::wxWidgets->c_flags;
    my $linkflags = Alien::wxWidgets->link_flags;
    my $libraries = Alien::wxWidgets->libraries( qw(gl adv core base) );
    my @libraries = Alien::wxWidgets->link_libraries( qw(gl adv core base) );
    my @implib = Alien::wxWidgets->import_libraries( qw(gl adv core base) );
    my @shrlib = Alien::wxWidgets->shared_libraries( qw(gl adv core base) );
    my @keys = Alien::wxWidgets->library_keys; # 'gl', 'adv', ...
    my $library_path = Alien::wxWidgets->shared_library_path;
    my $key = Alien::wxWidgets->key;
    my $prefix = Alien::wxWidgets->prefix;

=head1 DESCRIPTION

Please see L<Alien> for the manifesto of the Alien namespace.

In short C<Alien::wxWidgets> can be used to detect and get
configuration settings from an installed wxWidgets.

=cut

use strict;
use Carp;
use Alien::wxWidgets::Utility qw(awx_sort_config awx_grep_config
                                 awx_smart_config);
use Module::Pluggable sub_name      => '_list',
                      search_path   => 'Alien::wxWidgets::Config',
                      instantiate   => 'config';

our $AUTOLOAD;
our $VERSION = '0.67';
our %VALUES;
our $dont_remap;

*_remap = \&Alien::wxWidgets::Utility::_awx_remap;

sub AUTOLOAD {
    my $name = $AUTOLOAD;

    $name =~ s/.*:://;
    croak "Can not use '", $name, "'" unless exists $VALUES{$name};

    return _remap( $VALUES{$name} );
}

sub import {
    my $class = shift;
    if( @_ == 1 ) {
        $class->dump_configurations if $_[0] eq ':dump';
        $class->show_configurations if $_[0] eq ':show';
        return;
    }

    $class->load( @_ );
}

sub load {
    my $class = shift;
    my %crit = awx_smart_config @_;

    my @configs = awx_sort_config awx_grep_config [ $class->_list ], %crit ;

    unless( @configs ) {
        my @all_configs = $class->get_configurations;

        my $message = "Searching configuration for:\n";
        $message .= _pretty_print_criteria( \%crit );
        $message .= "\nAvailable configurations:\n";
        if( @all_configs ) {
            $message .= _pretty_print_configuration( $_ ) foreach @all_configs;
        } else {
            $message .= "No wxWidgets build found\n";
        }

        die $message;
    }

    %VALUES = $configs[0]->{package}->values;
}

sub _pretty_print_criteria {
    my $criteria = shift;
    my %display = %$criteria;

    $display{version} = join '-', @{$display{version}} if ref $display{version};
    $display{version} = '(any version)' unless $display{version};
    $display{toolkit} = '(any toolkit)' unless $display{toolkit};
    $display{compiler_kind} = '(any compiler)' unless $display{compiler_kind};
    $display{compiler_version} = '(any version)' unless $display{compiler_version};

    return _pretty_print_configuration( \%display );
}

sub _pretty_print_configuration {
    my $config = shift;
    my @options = map { !defined $config->{$_} ? () :
                                 $config->{$_} ? ( $_ ) :
                                                 ( "no $_" ) }
                      qw(debug unicode mslu);

    return "wxWidgets $config->{version} for $config->{toolkit}; " .
           "compiler compatibility: $config->{compiler_kind} " .
           $config->{compiler_version} . '; ' .
           ( @options ? 'options: ' . join( ', ', @options ) : '' ) .
           "\n";
}

sub show_configurations {
    my $class = shift;
    my @configs = $class->get_configurations( @_ );

    print _pretty_print_configuration( $_ ) foreach @configs;
}

sub dump_configurations {
    my $class = shift;
    my @configs = $class->get_configurations( @_ );

    require Data::Dumper;
    print Data::Dumper->Dump( \@configs );
}

sub get_configurations {
    my $class = shift;

    return awx_sort_config awx_grep_config [ $class->_list ], @_;
}

my $lib_nok  = 'adv|base|html|net|xml|media';
my $lib_mono_28 = 'adv|base|html|net|xml|xrc|media|aui|richtext';
my $lib_mono_29 = 'adv|base|html|net|xml|xrc|media|aui|richtext|stc';

sub _grep_libraries {
    my $lib_filter = $VALUES{version} >= 2.005001 ? qr/(?!a)a/ : # no match
                     $^O =~ /MSWin32/             ? qr/^(?:$lib_nok|gl)$/ :
                                                    qr/^(?:$lib_nok)$/;

    my( $type, @libs ) = @_;

    my $dlls = $VALUES{_libraries};

    @libs = keys %$dlls unless @libs;
    push @libs, 'core', 'base'  unless grep /^core|mono$/, @libs;

    my $lib_mono = $VALUES{version} >= 2.009 ? $lib_mono_29 : $lib_mono_28;
    if( ( $VALUES{config}{build} || '' ) eq 'mono' ) {
        @libs = map { $_ eq 'core'            ? ( 'mono' ) :
                      $_ =~ /^(?:$lib_mono)$/ ? () :
                      $_ } @libs;
        @libs = qw(mono) unless @libs;
    }

    return map  { _remap( $_ ) }
           map  { defined( $dlls->{$_}{$type} ) ? $dlls->{$_}{$type} :
                      croak "No such '$type' library: '$_'" }
           grep !/$lib_filter/, @libs;
}

sub link_libraries { shift; return _grep_libraries( 'link', @_ ) }
sub shared_libraries { shift; return _grep_libraries( 'dll', @_ ) }
sub import_libraries { shift; return _grep_libraries( 'lib', @_ ) }
sub library_keys { shift; return keys %{$VALUES{_libraries}} }

sub libraries {
    my $class = shift;

    return ( _remap( $VALUES{link_libraries} ) || '' ) . ' ' .
           join ' ', map { _remap( $_ ) }
                         $class->link_libraries( @_ );
}

1;

__END__

=head1 METHODS

=head2 load/import

    use Alien::wxWidgets version          => 2.004 | [ 2.004, 2.005 ],
                         compiler_kind    => 'gcc' | 'cl', # Windows only
                         compiler_version => '3.3', # only GCC for now
                         toolkit          => 'gtk2',
                         debug            => 0 | 1,
                         unicode          => 0 | 1,
                         mslu             => 0 | 1,
                         key              => $key,
                         ;

    Alien::wxWidgets->load( <same as the above> );

Using C<Alien::wxWidgets> without parameters will load a default
configuration (for most people this will be the only installed
confiuration). Additional parameters allow to be more selective.

If there is no matching configuration the method will C<die()>.

In case no arguments are passed in the C<use>, C<Alien::wxWidgets>
will try to find a reasonable default configuration.

Please note that when the version is pecified as C<version => 2.004>
it means "any version >= 2.004" while when specified as
C<version => [ 2.004, 2.005 ]> it means "any version => 2.004 and < 2.005".

=head2 key

    my $key = Alien::wxWidgets key;

Returns an unique key that can be used to reload the
currently-loaded configuration.

=head2 version

    my $version = Alien::wxWidgets->version;

Returns the wxWidgets version for this C<Alien::wxWidgets>
installation in the form MAJOR + MINOR / 1_000 + RELEASE / 1_000_000
e.g. 2.008012 for wxWidgets 2.8.12 and 2.009 for wxWidgets 2.9.0.

=head2 config

    my $config = Alien::wxWidgets->config;

Returns some miscellaneous configuration informations for wxWidgets
in the form

    { toolkit   => 'msw' | 'gtk' | 'motif' | 'x11' | 'cocoa' | 'mac',
      debug     => 1 | 0,
      unicode   => 1 | 0,
      mslu      => 1 | 0,
      }

=head2 include_path

    my $include_path = Alien::wxWidgets->include_path;

Returns the include paths to be used in a format suitable for the
compiler (usually something like "-I/usr/local/include -I/opt/wx/include").

=head2 defines

    my $defines = Alien::wxWidgets->defines;

Returns the compiler defines to be used in a format suitable for the
compiler (usually something like "-D__WXDEBUG__ -DFOO=bar").

=head2 c_flags

    my $cflags = Alien::wxWidgets->c_flags;

Returns additional compiler flags to be used.

=head2 compiler

    my $compiler = Alien::wxWidgets->compiler;

Returns the (C++) compiler used for compiling wxWidgets.

=head2 linker

    my $linker = Alien::wxWidgets->linker;

Returns a linker suitable for linking C++ binaries.

=head2 link_flags

    my $linkflags = Alien::wxWidgets->link_flags;

Returns additional link flags.

=head2 libraries

    my $libraries = Alien::wxWidgets->libraries( qw(gl adv core base) );

Returns link flags for linking the libraries passed as arguments. This
usually includes some search path specification in addition to the
libraries themselves. The caller is responsible for the correct order
of the libraries.

=head2 link_libraries

    my @libraries = Alien::wxWidgets->link_libraries( qw(gl adv core base) );

Returns a list of linker flags that can be used to link the libraries
passed as arguments.

=head2 import_libraries

    my @implib = Alien::wxWidgets->import_libraries( qw(gl adv core base) );

Windows specific. Returns a list of import libraries corresponding to
the libraries passed as arguments.

=head2 shared_libraries

    my @shrlib = Alien::wxWidgets->shared_libraries( qw(gl adv core base) );

Returns a list of shared libraries corresponding to the libraries
passed as arguments.

=head2 library_keys

    my @keys = Alien::wxWidgets->library_keys;

Returns a list of keys that can be passed to C<shared_libraries>,
C<import_libraries> and C<link_libraries>.

=head2 library_path

    my $library_path = Alien::wxWidgets->shared_library_path;

Windows specific. Returns the path at which the private copy
of wxWidgets libraries has been installed.

=head2 prefix

    my $prefix = Alien::wxWidgets->prefix;

Returns the install prefix for wxWidgets.

=head2 dump_configurations

    Alien::wxWidgets->dump_configurations( %filters );

Prints a list of available configurations (mainly useful for
interactive use/debugging).

=head2 show_configurations

    Alien::wxWidgets->show_configurations( %filters );

Prints a human-readable list of available configurations (mainly
useful for interactive use/debugging).

=head2 get_configurations

   my $configs = Alien::wxWidgets->get_configurations( %filters );

Returns a list of configurations matching the given filters.

=head1 AUTHOR

Mattia Barbon <mbarbon@cpan.org>

=head1 LICENSE

=over 4

=item Alien::wxWidgets

Copyright (c) 2005-2012 Mattia Barbon <mbarbon@cpan.org>

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself

=item inc/bin/patch

was taken from the Perl Power Tools distributions

Copyright (c) 1999 Moogle Stuffy Software <tgy@chocobo.org>

You may play with this software in accordance with the Perl Artistic License.

You may use this documentation under the auspices of the GNU General Public
License.

=item inc/bin/patch.exe

was downloaded from http://gnuwin32.sourceforge.net/packages/patch.htm
ad is copyrighted by its authors, sources are included inside the
inc/src directory.

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program; if not, write to the Free Software
Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

=item bundled files from CPAN

    inc/File/Fetch/Item.pm
    inc/File/Fetch.pm
    inc/File/Spec/Unix.pm
    inc/IPC/Cmd.pm
    inc/Locale/Maketext/Simple.pm
    inc/Module/Load/Conditional.pm
    inc/Module/Load.pm
    inc/Params/Check.pm
    inc/Archive/Extract.pm

Are copyright their respective authors an can be used according
to the license specified in their CPAN distributions.

=back

=cut

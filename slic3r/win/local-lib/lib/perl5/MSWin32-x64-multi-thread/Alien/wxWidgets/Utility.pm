package Alien::wxWidgets::Utility;

=head1 NAME

Alien::wxWidgets::Utility - INTERNAL: do not use

=cut

use strict;
use base qw(Exporter);
use Config;
use File::Basename qw();

BEGIN {
    if( $^O eq 'MSWin32' && $Config{_a} ne $Config{lib_ext} ) {
        print STDERR <<EOT;

\$Config{_a} is '$Config{_a}' and \$Config{lib_ext} is '$Config{lib_ext}':
they need to be equal for the build to succeed. If you are using ActivePerl
with MinGW/GCC, please:

- install ExtUtils::FakeConfig
- set PERL5OPT=-MConfig_m
- rerun Build.PL

EOT
        exit 1;
    }
}

our $VERSION = '0.59';

our @EXPORT_OK = qw(awx_capture awx_cc_is_gcc awx_cc_version awx_cc_abi_version
                    awx_sort_config awx_grep_config awx_smart_config);

my $quotes = $^O =~ /MSWin32/ ? '"' : "'";
my $compiler_checked = '';

sub _exename {
    return File::Basename::basename( lc $_[0], '.exe' );
}

sub _warn_nonworking_compiler {
    my( $cc ) = @_;

    return if $compiler_checked eq $cc;

    eval { require ExtUtils::CBuilder; };
    return if $@; # avoid failing when called a Build.PL time

    # a C++ compiler can act as a linker, except for MS cl.exe
    my $ld = _exename( $Config{cc} ) eq 'cl' ? 'link' : $cc;
    my $b = ExtUtils::CBuilder->new( config => { cc => $cc, ld => $ld },
                                     quiet  => 1,
                                     );

    if( !$b->have_compiler ) {
        print STDERR <<EOT;

ATTENTION: It apperars '$cc' is not a working compiler, please make
sure all necessary packages are installed.

EOT
        sleep 5;
    }

    $compiler_checked = $cc;
}

sub awx_capture {
    qx!$^X -e ${quotes}open STDERR, q[>&STDOUT]; exec \@ARGV${quotes} -- $_[0]!;
}

sub awx_cc_is_msvc {
    my( $cc ) = @_;

    return ( $^O =~ /MSWin32/ and $cc =~ /^cl/i ) ? 1 : 0;
}

sub awx_cc_is_gcc {
    my( $cc ) = @_;

    return    scalar( awx_capture( "$cc --version" ) =~ m/g(cc|\+\+)/i ) # 3.x
           || scalar( awx_capture( "$cc" ) =~ m/gcc/i );          # 2.95
}

sub awx_cc_abi_version {
    my( $cc ) = @_;

    _warn_nonworking_compiler( $cc );

    my $is_gcc = awx_cc_is_gcc( $cc );
    my $is_msvc = awx_cc_is_msvc( $cc );
    return 0 unless $is_gcc || $is_msvc;
    my $ver = awx_cc_version( $cc );
    if( $is_gcc ) {
        return 0 unless $ver > 0;
        return '3.4' if $ver >= 3.4;
        return '3.2' if $ver >= 3.2;
        return $ver;
    } elsif( $is_msvc ) {
        return 0 if $ver < 7;
        return $ver;
    }
}

sub awx_cc_version {
    my( $cc ) = @_;

    _warn_nonworking_compiler( $cc );

    my $is_gcc = awx_cc_is_gcc( $cc );
    my $is_msvc = awx_cc_is_msvc( $cc );
    return 0 unless $is_gcc || $is_msvc;

    if( $is_gcc ) {
        my $ver = awx_capture( "$cc --version" );
        $ver =~ m/(\d+\.\d+)(?:\.\d+)?/ or return 0;
        return $1;
    } elsif( $is_msvc ) {
        my $ver = awx_capture( $cc );
        $ver =~ m/(\d+\.\d+)\.\d+/ or return 0;
        return 8.0 if $1 >= 14;
        return 7.1 if $1 >= 13.10;
        return 7.0 if $1 >= 13;
        return 6.0 if $1 >= 12;
        return 5.0 if $1 >= 11;
        return 0;
    }
}

sub awx_compiler_kind {
    my( $cc ) = @_;

    _warn_nonworking_compiler( $cc );

    return 'gcc' if awx_cc_is_gcc( $cc );
    return 'cl'  if awx_cc_is_msvc( $cc );

    return 'nc'; # as in 'No Clue'
}

# sort a list of configurations by version, debug/release, unicode/ansi, mslu
sub awx_sort_config {
    # comparison functions treating undef as 0 or ''
    # numerico comparison
    my $make_cmpn = sub {
        my $k = shift;
        sub { exists $a->{$k} && exists $b->{$k} ? $a->{$k} <=> $b->{$k} :
              exists $a->{$k}                    ? 1                     :
              exists $b->{$k}                    ? -1                    :
                                                   0 }
    };
    # string comparison
    my $make_cmps = sub {
        my $k = shift;
        sub { exists $a->{$k} && exists $b->{$k} ? $a->{$k} cmp $b->{$k} :
              exists $a->{$k}                    ? 1                     :
              exists $b->{$k}                    ? -1                    :
                                                   0 }
    };
    # reverse comparison
    my $rev = sub { my $cmp = shift; sub { -1 * &$cmp } };
    # compare by different criteria, using the first nonzero as tie-breaker
    my $crit_sort = sub {
        my @crit = @_;
        sub {
            foreach ( @crit ) {
                my $cmp = &$_;
                return $cmp if $cmp;
            }

            return 0;
        }
    };

    my $cmp = $crit_sort->( $make_cmpn->( 'version' ),
                            $rev->( $make_cmpn->( 'debug' ) ),
                            $make_cmpn->( 'unicode' ),
                            $make_cmpn->( 'mslu' ) );

    return reverse sort $cmp @_;
}

sub awx_grep_config {
    my( $cfgs ) = shift;
    my( %a ) = @_;
    # compare to a numeric range or value
    # low extreme included, high extreme excluded
    # if $a{key} = [ lo, hi ] then range else low extreme
    my $make_cmpr = sub {
        my $k = shift;
        sub {
            return 1 unless exists $a{$k};
            ref $a{$k} ? $a{$k}[0] <= $_->{$k} && $_->{$k} < $a{$k}[1] :
                         $a{$k}    <= $_->{$k};
        }
    };
    # compare for numeric equality
    my $make_cmpn = sub {
        my $k = shift;
        sub { exists $a{$k} ? $a{$k} == $_->{$k} : 1 }
    };
    # compare for string equality
    my $make_cmps = sub {
        my $k = shift;
        sub { exists $a{$k} ? $a{$k} eq $_->{$k} : 1 }
    };
    my $compare_tk = sub {
        return 1 unless exists $a{toolkit};
        my $atk = $a{toolkit} eq 'mac'   ? 'osx_carbon' :
                                           $a{toolkit};
        my $btk = $_->{toolkit} eq 'mac' ? 'osx_carbon' :
                                           $_->{toolkit};
        return $atk eq $btk;
    };

    # note tha if the criteria was not supplied, the comparison is a noop
    my $wver = $make_cmpr->( 'version' );
    my $ckind = $make_cmps->( 'compiler_kind' );
    my $cver = $make_cmpn->( 'compiler_version' );
    my $tkit = $compare_tk;
    my $deb = $make_cmpn->( 'debug' );
    my $uni = $make_cmpn->( 'unicode' );
    my $mslu = $make_cmpn->( 'mslu' );
    my $key = $make_cmps->( 'key' );

    grep { &$wver  } grep { &$ckind } grep { &$cver  }
    grep { &$tkit  } grep { &$deb   } grep { &$uni   }
    grep { &$mslu  } grep { &$key   }
         @{$cfgs}
}

# automatically add compiler data unless the key was supplied
sub awx_smart_config {
    my( %args ) = @_;
    # the key already identifies the configuration
    return %args if $args{key};

    my $cc = $ENV{CXX} || $ENV{CC} || $Config{ccname} || $Config{cc};
    my $kind = awx_compiler_kind( $cc );
    my $version = awx_cc_abi_version( $cc );

    $args{compiler_kind} ||= $kind;
    $args{compiler_version} ||= $version;

    return %args;
}

# allow to remap srings in the configuration; useful when building
# archives
my @prefixes;

BEGIN {
    if( $ENV{ALIEN_WX_PREFIXES} ) {
        my @kv = split /,\s*/, $ENV{ALIEN_WX_PREFIXES};

        while( @kv ) {
            my( $match, $repl ) = ( shift( @kv ) || '', shift( @kv ) || '' );

            push @prefixes, [ $match, $^O eq 'MSWin32' ?
                                          qr/\Q$match\E/i :
                                          qr/\Q$match\E/, $repl ];
        }
    }
}

sub _awx_remap {
    my( $string ) = @_;
    return $string if ref $string;
    return $string if $Alien::wxWidgets::dont_remap;

    foreach my $prefix ( @prefixes ) {
        my( $str, $rx, $repl ) = @$prefix;

        $string =~ s{$rx(\S*)}{$repl$1}g;
    }

    return $string;
}

1;

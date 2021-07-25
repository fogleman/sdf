package Wx::build::Options;

use strict;

=head1 NAME

Wx::build::Options - retrieve wxWidgets/wxPerl build options

=head1 METHODS

=cut

use Getopt::Long;

my $help         = 0;
my $mksymlinks   = 0;
my $extra_libs   = '';
my $extra_cflags = '';
my $alien_key    = '';
my %subdirs      = ();
my %wx           = ();
my $options;

sub _wx_version {
    my( $o, $v ) = @_;

    $v =~ m/(\d+)\.(\d+)(?:\.(\d+))?/
      or die 'Invalid version specification: ', $v, "\n";

    if( defined $3 ) {
        $wx{version} = [ $1 + ( $2 + $3 / 1000 ) / 1000,
                         $1 + ( $2 + ( $3 + 1 ) / 1000 ) / 1000 ];
    } else {
        $wx{version} = [ $1 + $2 / 1000,
                         $1 + ( $2 + 1 ) / 1000 ];
    }
}

sub _load_options {
  return if $options;

  $options = do 'Wx/build/Opt.pm';
  die "Unable to load options: $@" unless $options;

  ( $extra_cflags, $extra_libs, $alien_key )
    = @{$options}{qw(extra_cflags extra_libs alien_key)};

  require Alien::wxWidgets;
  Alien::wxWidgets->load( key => $alien_key );
}

my $parsed = 0;
my @argv;

sub _parse_options {
  return if $parsed;

  $parsed = 1;

  my $result = GetOptions( 'help'           => \$help,
                           'mksymlinks'     => \$mksymlinks,
                           'extra-libs=s'   => \$extra_libs,
                           'extra-cflags=s' => \$extra_cflags,
                           # for Alien::wxWidgets
                           'wx-debug!'      => \($wx{debug}),
                           'wx-unicode!'    => \($wx{unicode}),
                           'wx-mslu!'       => \($wx{mslu}),
                           'wx-version=s'   => \&_wx_version,
                           'wx-toolkit=s'   => \($wx{toolkit}),
                           '<>'             => \&_process_options,
                         );

  @ARGV = @argv; @argv = ();

  if( !$result || $help ) {
    print <<HELP;
Usage: perl Makefile.PL [options]
  --enable/disable-foo where foo is one of: dnd filesys grid help
                       html mdi print xrc stc docview calendar datetime 
  --help               you are reading it
  --mksymlinks         create a symlink tree
  --extra-libs=libs    specify extra linking flags
  --extra-cflags=flags specify extra compilation flags

  --[no-]wx-debug      [Non-] debugging wxWidgets
  --[no-]wx-unicode    [Non-] Unicode wxWidgets
  --[no-]wx-mslu       [Non-] MSLU wxWidgets (Windows only)
  --wx-version=2.9[.4] 
  --wx-toolkit=msw|gtk|gtk2|motif|mac|wce|...
HELP

    exit !$result;
  }

  if( $wx{toolkit} && $wx{toolkit} eq 'wce' ) {
    $wx{compiler_kind} = 'evc';
  }

  if( Alien::wxWidgets->can( 'load' ) ) {
      Alien::wxWidgets->load( map  { $_ => $wx{$_} }
                              grep { defined $wx{$_} }
                                   keys %wx );
      $alien_key = Alien::wxWidgets->key;
  }
}

sub _process_options {
  my $i = shift;

  unless( $i =~ m/^-/ ) {
    push @argv, $i;
    return;
  }

  if( $i =~ m/^--(enable|disable)-(\w+)$/ ) {
    $subdirs{$2} = ( $1 eq 'enable' ? 1 : 0 );
  } else {
    die "invalid option $i";
  }
}

=head2 get_makemaker_options

  my %mm_options = Wx::build::Options->get_makemaker_options;

Returns options meaningful at wxPerl building time.

  my %options = ( mksymlinks   => 0,
                  extra_libs   => '',
                  extra_cflags => '',
                  subdirs      => { stc => 1,
                                    xrc => 0 } )

=cut

sub get_makemaker_options {
  my $ref = shift;
  my $from = shift || '';

  if( $from eq 'saved' ) {
    _load_options();
  } else {
    _parse_options();
  }

  return ( mksymlinks   => $mksymlinks,
           extra_libs   => $extra_libs,
           extra_cflags => $extra_cflags,
           subdirs      => \%subdirs );
}

=head2 write_config_file

  my $ok = Wx::build::Options->write_config_file( '/path/to/file' );

Writes a machine-readable representation of command-line options given to
top-level Makefile.PL

=cut

sub write_config_file {
  my $class = shift;
  my $file = shift;

  require Data::Dumper;
  my $str = Data::Dumper->Dump( [ { extra_libs   => $extra_libs,
                                    extra_cflags => $extra_cflags,
                                    alien_key    => $alien_key,
                                  } ] );

  Wx::build::Utils::write_string( $file, $str );
}

1;

# local variables:
# mode: cperl
# end:

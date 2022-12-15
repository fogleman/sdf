package Wx::build::MakeMaker::Win32_MSVC;

use strict;
use base 'Wx::build::MakeMaker::Win32';

use Wx::build::Utils qw(pipe_stderr);

sub _res_file { 'Wx.res' }
sub _res_command { 'rc -I%incdir %src' }
sub _strip_command {
return <<'EOT';
	$(NOOP)
EOT
}

my $cl_version;

{
    my @head = pipe_stderr( "cl /help" );
    $head[0] =~ /Version (\d+\.+).\d+/ and $cl_version = $1;
}

sub dynamic_lib {
  my $this = shift;
  my $text = $this->SUPER::dynamic_lib( @_ );

  return $text if $cl_version < 14 || eval ExtUtils::MakeMaker->VERSION >= 6.33;

  $text .= <<'EOT' if $text && $text =~ /\$\@/;
	mt -manifest $@.manifest -outputresource:$@;2
EOT

  return $text;
}

=pod

sub post_initialize {
    my( $self ) = @_;

    $self->{PERL_LIB} = 'C:\Programmi\Devel\Perl\ActivePerl\588.817\xlib\wince-arm-pocket-wce300';
    $self->{PERL_ARCHLIB} = 'C:\Programmi\Devel\Perl\ActivePerl\588.817\xlib\wince-arm-pocket-wce300';
    $self->{PERL_INC} = $self->catdir( $self->{PERL_LIB}, "CORE" );

    return '';
}

sub tool_xsubpp {
    my( $self ) = @_;

    package MY;
    local $self->{PERL_LIB} = 'C:\Programmi\Devel\Perl\ActivePerl\588.817\lib';
    return $self->SUPER::tool_xsubpp;
}

=cut

1;

# local variables:
# mode: cperl
# end:

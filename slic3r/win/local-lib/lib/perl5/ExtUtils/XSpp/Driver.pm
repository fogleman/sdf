package ExtUtils::XSpp::Driver;

use strict;
use warnings;

use File::Basename ();
use File::Path ();

use ExtUtils::XSpp::Parser;

sub new {
    my( $class, %args ) = @_;
    my $self = bless \%args, $class;

    return $self;
}

sub generate {
    my( $self ) = @_;

    foreach my $typemap ( $self->typemaps ) {
        ExtUtils::XSpp::Parser->new( file => $typemap )->parse;
    }

    my $parser = ExtUtils::XSpp::Parser->new( file   => $self->file,
                                              string => $self->string,
                                              );
    my $success = $parser->parse;
    return() if not $success;
    my $generated = $self->_emit( $parser );

    my $typemap_code = ExtUtils::XSpp::Typemap::get_xs_typemap_code_for_all_typemaps();
    if (defined $typemap_code && $typemap_code =~ /\S/) {
        if (exists $generated->{'-'} and $generated->{'-'} ne '') {
            $generated->{'-'} = $typemap_code . $generated->{'-'};
        }
        elsif (my @files = grep !/^-$/, keys %$generated) {
            $generated->{$files[0]} = $typemap_code . ($generated->{$files[0]}||'');
        }
        else {
            $generated->{'-'} = $typemap_code . ($generated->{'-'}||'');
        }
    }

    return $generated;
}

sub process {
    my( $self ) = @_;

    my $generated = $self->generate;
    return () if not $generated;
    return $self->_write( $generated );
}

sub _write {
    my( $self, $out ) = @_;

    foreach my $f ( keys %$out ) {
        if( $f eq '-' ) {
            if( $self->xsubpp ) {
                require IPC::Open2;

                my $cmd = $self->xsubpp . ' ' . ( $self->xsubpp_args || '' )
                          . ' -';
                my $pid = IPC::Open2::open2( '>&STDOUT', my $fh, $cmd );

                print $fh $$out{$f} or die "Error writing to xsubpp: $!";
                close $fh or die "Error writing to xsubpp: $!";
                waitpid( $pid, 0 );
                my $exit_code = $? >> 8;

                return 0 if $exit_code;
            } else {
                print $$out{$f} or die "Error writing output";
            }
        } else {
            File::Path::mkpath( File::Basename::dirname( $f ) );

            open my $fh, '>', $f or die "open '$f': $!";
            binmode $fh;
            print $fh $$out{$f} or die "Error writing to '$f': $!";
            close $fh or die "close '$f': $!";
        }
    }

    return 1;
}

sub _emit {
    my( $self, $parser ) = @_;
    my $data = $parser->get_data;
    my %out;
    my $out_file = '-';
    my %state = ( current_module => undef );

    foreach my $plugin ( @{$parser->post_process_plugins} ) {
        my $method = $plugin->{method};

        $plugin->{plugin}->$method( $data );
    }

    $out{'-'} = preamble();
    foreach my $e ( @$data ) {
        if( $e->isa( 'ExtUtils::XSpp::Node::Module' ) ) {
            $state{current_module} = $e;
        }
        if( $e->isa( 'ExtUtils::XSpp::Node::File' ) ) {
            $out_file = $e->file;
            $out{$out_file} ||= preamble();
        }
        $out{$out_file} .= $e->print( \%state );
    }

    return \%out;
}

sub preamble {
  return <<EOT
#include <exception>
#undef  xsp_constructor_class
#define xsp_constructor_class(c) (c)


EOT
}

sub typemaps { @{$_[0]->{typemaps} || []} }
sub file     { $_[0]->{file} }
sub string   { $_[0]->{string} }
sub output   { $_[0]->{output} }
sub xsubpp   { $_[0]->{xsubpp} }
sub xsubpp_args { $_[0]->{xsubpp_args} }

1;

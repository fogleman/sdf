package build::Wx::XSP::Enum;
# Allow use when installed for other Wx based modules
# but always use this when building Wx
package Wx::XSP::Enum; @ISA = qw( build::Wx::XSP::Enum );
package build::Wx::XSP::Enum;

use strict;
use warnings;

sub new { return bless { parser => $_[1], exporttag => '' }, $_[0] }

sub register_plugin {
    my( $class, $parser ) = @_;
    my $instance = $class->new( $parser );
    $parser->add_post_process_plugin( plugin => $instance );
    $parser->add_toplevel_tag_plugin( plugin => $instance, tag => 'EnumExportTag' );
}

sub handle_toplevel_tag {
    my( $self, $empty, $tag, %args ) = @_;
    my $checktag = $args{any_positional_arguments}[0];
    die qq(Invalid Export Tag $checktag) if $checktag !~ /^[a-z]+$/;
    $self->{exporttag} = $checktag;
    1; # we handled the tag
}

sub post_process {
    my( $self, $nodes ) = @_;
    my $parser = $self->{parser};
    my $exporttag = $self->{exporttag};
    
    my( %constants, %conditions );

    foreach my $node ( @$nodes ) {
        next unless $node->isa( 'ExtUtils::XSpp::Node::Enum' );

        $conditions{$node->condition_expression} ||= 1 if $node->condition_expression;
        foreach my $val ( @{$node->elements} ) {
            next unless $val->isa( 'ExtUtils::XSpp::Node::EnumValue' );
            $constants{$val->name} ||= [ $val->condition ];
            $conditions{$val->condition_expression} ||= 1 if $val->condition_expression;
        }
    }

    ( my $name = File::Basename::basename( $parser->current_file ) ) =~ tr/./_/;
    my $file = "xspp/const_$name.h";
    my @defines;
    while( my( $k, $v ) = each %constants ) {
        if( $v->[0] ) {
            push @defines, "#ifdef $v->[0]",
                           "    r( $k );",
                           "#endif",
        } else {
            push @defines, "    r( $k );",
        }
    }
    my $consts = join "\n", @defines;
    my $all_conditions = join ' && ', 1, keys %conditions;
    my @lines = sprintf <<'EOT', $all_conditions, $name, $exporttag, $consts, $name, $name;
#if %s

#include "cpp/constants.h"

static double %s_constant( const char* name, int arg )
{
#define r( n ) \
    if( strEQ( name, #n ) ) \
        return n;

    WX_PL_CONSTANT_INIT();

    // !package: Wx
    // !tag: %s
    // !parser: sub { $_[0] =~ m<^\s*r\w*\(\s*(\w+)\s*\);\s*(?://(.*))?$> }

//    switch( fl )
//    {
%s
//    default:
//        break;
//    }
#undef r

    WX_PL_CONSTANT_CLEANUP();
}

static wxPlConstants %s_module( &%s_constant );

#endif
EOT

    push @$nodes,
         ExtUtils::XSpp::Node::Raw->new( rows => [ qq{#include "$file"} ] ),
         ExtUtils::XSpp::Node::File->new( file => $file ),
         ExtUtils::XSpp::Node::Raw->new( rows => \@lines ),
         ExtUtils::XSpp::Node::File->new( file => '-' );
}

1;

package build::Wx::XSP::Overload;
# Allow use when installed for other Wx based modules
# but always use this when building Wx
package Wx::XSP::Overload; @ISA = qw( build::Wx::XSP::Overload );
package build::Wx::XSP::Overload;

use strict;
use warnings;

my $overload_number_types = [
    'int', 'unsigned', 'short', 'long',
    'unsigned int', 'unsigned short',
    'unsigned long', 'float', 'double',
    'wxAlignment', 'wxBrushStyle',
    'size_t', 'ssize_t', 'wxCoord',
    'wxUint32', 'wxDirection', 'wxBitmapType',
];

my $overload_any_types = [
    'Wx_UserDataO', 'Wx_UserDataCD', 'wxVariantArg'
];

sub new {
    return bless { overload_methods => {},
                   }, $_[0]
}

sub register_plugin {
    my( $class, $parser ) = @_;
    my $instance = $class->new;

    $parser->add_post_process_plugin( plugin => $instance );
    $parser->add_method_tag_plugin( plugin => $instance, tag => 'Overload' );
    $parser->add_toplevel_tag_plugin ( plugin => $instance, tag => 'OverloadNumberType' );
    $parser->add_toplevel_tag_plugin ( plugin => $instance, tag => 'OverloadAnyType' );
}


sub handle_toplevel_tag {
    my( $self, $empty, $tag, %args ) = @_;
    
    if( $tag eq 'OverloadNumberType' ) {
        my $newtype = $args{any_positional_arguments}[0];
        die qq(Invalid Number Type) if !$newtype;
        push( @$overload_number_types, $newtype );
    }
    
    if( $tag eq 'OverloadAnyType' ) {
        my $newtype = $args{any_positional_arguments}[0];
        die qq(Invalid Number Type) if !$newtype;
        push( @$overload_any_types, $newtype );
    }
    
    1;
}


sub handle_method_tag {
    my( $self, $method, $tag, %args ) = @_;

    $self->{overload_methods}{$method} = 1;

    1;
}

sub post_process {
    my( $self, $nodes ) = @_;

    foreach my $node ( @$nodes ) {
        next unless $node->isa( 'ExtUtils::XSpp::Node::Class' );
        my %all_methods;

        foreach my $method ( @{$node->methods} ) {
            next unless $method->isa( 'ExtUtils::XSpp::Node::Method' );
            next if $method->isa( 'ExtUtils::XSpp::Node::Destructor' );
            next if    $method->cpp_name ne $method->perl_name
                    && !$self->{overload_methods}{$method};
            push @{$all_methods{$method->cpp_name} ||= []}, $method;
        }

        my @ovl_methods = grep { @{$all_methods{$_}} > 1 }
                               keys %all_methods;

        if( @ovl_methods ) {
            $node->add_methods( ExtUtils::XSpp::Node::Raw->new( rows => [ '#include "cpp/overload.h"' ] ) );
        }

        foreach my $method_name ( @ovl_methods ) {
            _add_overload( $self, $node, $all_methods{$method_name} );
        }
    }
}

=pod

void
wxCaret::Move( ... )
  PPCODE:
    BEGIN_OVERLOAD()
        MATCH_REDISP( wxPliOvl_wpoi, MovePoint )
        MATCH_REDISP( wxPliOvl_n_n, MoveXY )
    END_OVERLOAD( Wx::Caret::Move )

=cut

sub is_bool {
    my( $type ) = @_;
    return 0 if $type->is_pointer;

    return $type->base_type eq 'bool';
}

sub is_string {
    my( $type ) = @_;
    # TODO wxPerl-specific types
    return 1 if $type->base_type eq 'char' && $type->is_pointer == 1;
    return 1 if $type->base_type eq 'wxChar' && $type->is_pointer == 1;
    return 0 if $type->is_pointer;

    return $type->base_type eq 'wxString';
}

sub is_number {
    my( $type ) = @_;
    return 0 if $type->is_pointer;
    # TODO wxPerl-specific types
    return grep $type->base_type eq $_, @$overload_number_types;
}

sub is_value {
    my( $type, $class ) = @_;
    return 0 if $type->is_pointer;
    return $type->base_type eq $class;
}

sub is_any {
    my( $type ) = @_;
    return ( grep $type->base_type eq $_, @$overload_any_types ) ? 1 : 0;
}

sub _compare_function {
    my( $ca, $cb ) = ( 0, 0 );

    # arbitrary order for functions with the same name, assuming they
    # will be guarded with different #ifdefs
    return $a <=> $b if $a->perl_name eq $b->perl_name;

    $ca += 1 foreach grep !$_->has_default, @{$a->arguments};
    $cb += 1 foreach grep !$_->has_default, @{$b->arguments};

    return $ca - $cb if $ca != $cb;

    for( my $i = 0; $i < 10000; ++$i ) {
        return -1 if $#{$a->arguments} <  $i && $#{$b->arguments} >= $i;
        return  1 if $#{$a->arguments} >= $i && $#{$b->arguments}  < $i;
        return  0 if $#{$a->arguments} <  $i && $#{$b->arguments}  < $i;
        # since optional arguments might not be specified, we can't rely on them
        # to disambiguate two calls
        return  0 if $ca <  $i && $cb < $i;

        my $ta = $a->arguments->[$i]->type;
        my $tb = $b->arguments->[$i]->type;

        my( $as, $bs ) = ( is_string( $ta ) || is_any( $ta ),
                           is_string( $tb ) || is_any( $tb ) );
        my( $ai, $bi ) = ( is_number( $ta ), is_number( $tb ) );
        my( $ab, $bb ) = ( is_bool( $ta ), is_bool( $tb ) );
        my $asimple = $as || $ai || $ab;
        my $bsimple = $bs || $bi || $bb;

        # first complex types, then integer, then boolean/string

        # this does not handle overloading on a base and a derived type,
        # it is good enough for wxPerl
        return -1 if !$asimple && !$bsimple;

        return -1 if !$asimple &&  $bsimple;
        return  1 if  $asimple && !$bsimple;

        next      if  $ai &&  $bi;
        return -1 if  $ai && !$bi;
        return  1 if !$ai &&  $bi;

        # string/bool are ambiguous
        next;
    }

    return 0;
}

sub _make_dispatch {
    my( $self, $methods, $method ) = @_;

    if( $method->cpp_name eq $method->perl_name ) {
        for( my $i = 0; $i < @$methods; ++$i ) {
            if( $method == $methods->[$i] ) {
                $method->{PERL_NAME} = $method->cpp_name . $i;
                last;
            }
        }
    }
    if( @{$method->arguments} == 0 ) {
        my $init = <<EOT;
    static wxPliPrototype void_proto( NULL, 0 );
EOT
        return [ $init, 'void_proto',
                 sprintf( '        MATCH_VOIDM_REDISP( %s )',
                          $method->perl_name ),
                 $method->condition_expression || 1 ];
    }
    if( @$methods == 2 && @{$methods->[0]->arguments} == 0 ) {
        return [ undef, 'NULL',
                 sprintf( '        MATCH_ANY_REDISP( %s )',
                          $method->perl_name ),
                 $method->condition_expression || 1 ];
    }
    my( $min, $max, @indices ) = ( 0, 0 );
    foreach my $arg ( @{$method->arguments} ) {
        ++$max;
        ++$min unless defined $arg->default;

        if( is_bool( $arg->type ) ) {
            push @indices, 'wxPliOvlbool';
            next;
        }
        if( is_string( $arg->type ) || is_any( $arg->type ) ) {
            push @indices, 'wxPliOvlstr';
            next;
        }
        if( is_number( $arg->type ) ) {
            push @indices, 'wxPliOvlnum';
            next;
        }
        # TODO 3 wxPerl-specific types
        if( is_value( $arg->type, 'wxPoint' ) ) {
            push @indices, 'wxPliOvlwpoi';
            next;
        }
        if( is_value( $arg->type, 'wxPosition' ) ) {
            push @indices, 'wxPliOvlwpos';
            next;
        }
        if( is_value( $arg->type, 'wxSize' ) ) {
            push @indices, 'wxPliOvlwsiz';
            next;
        }
        # TODO name mapping is wxPerl-specific
        die 'Unable to dispatch ', $arg->type->base_type
          unless $arg->type->base_type =~ /^[Ww]x/;
        {
            # convert typemap parsed types
            my $subtype = substr $arg->type->base_type, 2;
            $subtype =~ s/__parsed.*$//;
            push @indices, '"Wx::' . $subtype . '"';
        }
    }

    my $proto_name = sprintf '%s_proto', $method->perl_name;
    my $init = sprintf <<EOT,
    static const char *%s_types[] = { %s };
    static wxPliPrototype %s_proto( %s_types, sizeof( %s_types ) / sizeof( %s_types[0] ) );
EOT
        $method->perl_name, join( ', ', @indices ),
        $method->perl_name, $method->perl_name, $method->perl_name, $method->perl_name;

    if( $min != $max ) {
        return [ $init, $proto_name,
                 sprintf( '        MATCH_REDISP_COUNT_ALLOWMORE( %s_proto, %s, %d )',
                          $method->perl_name, $method->perl_name, $min ),
                 $method->condition_expression || 1 ];
    } else {
        return [ $init, $proto_name,
                 sprintf( '        MATCH_REDISP_COUNT( %s_proto, %s, %d )',
                          $method->perl_name, $method->perl_name, $max ),
                 $method->condition_expression || 1 ];
    }
}

sub _add_overload {
    my( $self, $class, $methods ) = @_;
    my @methods = sort _compare_function @$methods;

    for( my $i = 0; $i < $#methods; ++$i ) {
        ( $a, $b ) = ( $methods[$i], $methods[$i + 1] );
        next if _compare_function() != 0;
        die "Ambiguous overload for ", $a->perl_name, " and ", $b->perl_name;
    }

    my @dispatch = map _make_dispatch( $self, $methods, $_ ), @methods;
    my $method_name = $class->cpp_name eq $methods[0]->cpp_name ?
                          'new' : $methods[0]->cpp_name;
    my $code = sprintf <<EOT,
void
%s::%s( ... )
  PPCODE:
EOT

      $class->cpp_name, $method_name;

    my @prototypes;
    foreach my $dispatch ( @dispatch ) {
        next unless $dispatch->[0];
        chomp $dispatch->[0];
        $code .= <<EOT;
#if $dispatch->[3]
$dispatch->[0]
#endif // $dispatch->[3]
EOT
        push @prototypes, <<EOT;
#if $dispatch->[3]
        &$dispatch->[1],
#endif // $dispatch->[3]
EOT
    }

    $code .= sprintf <<EOT,
    static wxPliPrototype *wxPliOvl_all_prototypes[] = {
%s        NULL };
    BEGIN_OVERLOAD()
EOT
      join( '', @prototypes );

    foreach my $dispatch ( @dispatch ) {
        $code .= <<EOT;
#if $dispatch->[3]
$dispatch->[2]
#endif // $dispatch->[3]
EOT
    }

    $code .= sprintf <<EOT,
    END_OVERLOAD_MESSAGE( %s::%s, wxPliOvl_all_prototypes )
EOT
      $class->perl_name, $method_name;

    $class->add_methods( ExtUtils::XSpp::Node::Raw->new
                             ( rows           => [ $code ],
                               emit_condition => $class->condition_expression,
                               ) );
}

1;

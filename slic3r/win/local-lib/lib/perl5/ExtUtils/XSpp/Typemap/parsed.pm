package ExtUtils::XSpp::Typemap::parsed;

use base 'ExtUtils::XSpp::Typemap';

sub _dl { return defined( $_[0] ) && length( $_[0] ) ? $_[0] : undef }

sub init {
  my $this = shift;
  my %args = @_;

  if( my $base = $args{base} ) {
    %args = ( cpp_type => $base->{CPP_TYPE},
              call_function_code => $base->{CALL_FUNCTION_CODE},
              output_code => $base->{OUTPUT_CODE},
              cleanup_code => $base->{CLEANUP_CODE},
              precall_code => $base->{PRECALL_CODE},
              output_list => $base->{OUTPUT_LIST},
              xs_type => $base->{XS_TYPE},
              xs_input_code => $base->{XS_INPUT_CODE},
              xs_output_code => $base->{XS_OUTPUT_CODE},
              %args );
  }

  $this->{TYPE} = $args{type};
  $this->{NAME} = $args{name};
  $this->{CPP_TYPE} = $args{cpp_type} || $args{arg1};
  $this->{CALL_FUNCTION_CODE} = _dl( $args{call_function_code} || $args{arg2} );
  $this->{OUTPUT_CODE} = _dl( $args{output_code} || $args{arg3} );
  $this->{CLEANUP_CODE} = _dl( $args{cleanup_code} || $args{arg4} );
  $this->{PRECALL_CODE} = _dl( $args{precall_code} || $args{arg5} );
  $this->{OUTPUT_LIST} = _dl( $args{output_list} );
  $this->{XS_TYPE} = $args{xs_type};
  $this->{XS_INPUT_CODE} = $args{xs_input_code};
  $this->{XS_OUTPUT_CODE} = $args{xs_output_code};
}

sub cpp_type { $_[0]->{CPP_TYPE} || $_[0]->{TYPE}->print }

sub output_code {
  my( $this, $pvar, $cvar ) = @_;
  return unless defined $_[0]->{OUTPUT_CODE};
  return _replace( $_[0]->{OUTPUT_CODE}, '$PerlVar' => $pvar, '$CVar' => $cvar );
}

sub output_list {
  my( $this, $cvar ) = @_;
  return unless defined $_[0]->{OUTPUT_LIST};
  return _replace( $_[0]->{OUTPUT_LIST}, '$CVar' => $cvar );
}

sub cleanup_code {
  my( $this, $pvar, $cvar ) = @_;
  return unless defined $_[0]->{CLEANUP_CODE};
  return _replace( $_[0]->{CLEANUP_CODE}, '$PerlVar' => $pvar, '$CVar' => $cvar );
}

sub call_parameter_code { undef }

sub call_function_code {
  my( $this, $func, $var ) = @_;
  return unless defined $this->{CALL_FUNCTION_CODE};
  return _replace( $this->{CALL_FUNCTION_CODE},
                   '$CVar' => $var, '$Call' => $func,
                   # backward compatibility
                   '$1' => $func, '$$' => $var,
                   );
}

sub precall_code {
  my( $this, $pvar, $cvar ) = @_;
  return unless defined $_[0]->{PRECALL_CODE};
  return _replace( $this->{PRECALL_CODE},
                   '$PerlVar' => $pvar, '$CVar' => $cvar,
                   # backward compatibility
                   '$1' => $pvar, '$2' => $cvar,
                   );
}

sub _replace {
  my( $code ) = shift;
  while( @_ ) {
    my( $f, $t ) = ( shift, shift );
    $code =~ s/\Q$f\E/$t/g;
  }
  return $code;
}

1;

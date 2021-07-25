package ExtUtils::XSpp::Typemap::simple;

use base 'ExtUtils::XSpp::Typemap';

sub init {
  my $this = shift;
  my %args = @_;

  if( my $base = $args{base} ) {
    %args = ( xs_type => $base->{XS_TYPE},
              xs_input_code => $base->{XS_INPUT_CODE},
              xs_output_code => $base->{XS_OUTPUT_CODE},
              %args );
  }

  $this->{TYPE} = $args{type};
  $this->{NAME} = $args{name};
  $this->{XS_TYPE} = $args{xs_type};
  $this->{XS_INPUT_CODE} = $args{xs_input_code};
  $this->{XS_OUTPUT_CODE} = $args{xs_output_code};
}

sub cpp_type { $_[0]->{TYPE}->print }
sub output_code { undef } # likewise
sub call_parameter_code { undef }
sub call_function_code { undef }

1;

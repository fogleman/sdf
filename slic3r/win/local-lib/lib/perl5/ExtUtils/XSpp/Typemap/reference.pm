package ExtUtils::XSpp::Typemap::reference;

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

  $this->{XS_TYPE} = $args{xs_type};
  $this->{NAME} = $args{name};
  $this->{TYPE} = $args{type};
}

sub cpp_type {
  my $type = $_[0]->type;
  $type->base_type . $type->print_tmpl_args . ('*' x ($type->is_pointer+1))
}
sub output_code { undef }
sub call_parameter_code { "*( $_[1] )" }
sub call_function_code {
  my $type = $_[0]->type;
  $_[2] . ' = new ' . $type->base_type . $type->print_tmpl_args . '( ' . $_[1] . " )";
}

1;

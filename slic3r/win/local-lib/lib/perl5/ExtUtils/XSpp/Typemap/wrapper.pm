package ExtUtils::XSpp::Typemap::wrapper;

use base 'ExtUtils::XSpp::Typemap';

sub init {
  my $this = shift;
  my %args = @_;

  $this->{TYPEMAP} = $args{typemap};
}

sub type { shift->{TYPEMAP}->type( @_ ) }
sub cpp_type { shift->{TYPEMAP}->cpp_type( @_ ) }
sub input_code { shift->{TYPEMAP}->input_code( @_ ) }
sub precall_code { shift->{TYPEMAP}->precall_code( @_ ) }
sub output_code { shift->{TYPEMAP}->output_code( @_ ) }
sub cleanup_code { shift->{TYPEMAP}->cleanup_code( @_ ) }
sub call_parameter_code { shift->{TYPEMAP}->call_parameter_code( @_ ) }
sub call_function_code { shift->{TYPEMAP}->call_function_code( @_ ) }
sub output_list { shift->{TYPEMAP}->output_list( @_ ) }

sub typemap { $_[0]->{TYPEMAP} }

1;

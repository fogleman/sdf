package ExtUtils::XSpp::Node::Type;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node';

# TODO: Document...

# normalized names for some integral C types
my %normalize =
  ( 'unsigned'           => 'unsigned int',
    'long int'           => 'long',
    'unsigned long int'  => 'unsigned long',
    'short int'          => 'short',
    'unsigned short int' => 'unsigned short',
    );

sub init {
  my $this = shift;
  my %args = @_;

  $this->{BASE}          = $normalize{$args{base}} || $args{base};
  $this->{POINTER}       = $args{pointer} ? 1 : 0;
  $this->{REFERENCE}     = $args{reference} ? 1 : 0;
  $this->{CONST}         = $args{const} ? 1 : 0;
  $this->{TEMPLATE_ARGS} = $args{template_args} || [];
}

sub clone {
  my $this = shift;
  my $clone = bless {%$this} => ref($this);
  $clone->{TEMPLATE_ARGS} = [map $_->clone, @{$clone->template_args}];
  return $clone;
}

sub is_const { $_[0]->{CONST} }
sub is_reference { $_[0]->{REFERENCE} }
sub is_pointer { $_[0]->{POINTER} }
sub base_type { $_[0]->{BASE} }
sub template_args { $_[0]->{TEMPLATE_ARGS} }

sub equals {
  my( $f, $s ) = @_;

  return 0 if @{$f->template_args} != @{$s->template_args};

  for( my $i = 0; $i < @{$f->template_args}; ++$i ) {
      return 0
          unless $f->template_args->[$i]->equals( $s->template_args->[$i] );
  }

  return $f->is_const == $s->is_const
      && $f->is_reference == $s->is_reference
      && $f->is_pointer == $s->is_pointer
      && $f->base_type eq $s->base_type;
}

sub is_void { return $_[0]->base_type eq 'void' &&
                !$_[0]->is_pointer && !$_[0]->is_reference }

sub print_tmpl_args {
  my $this = shift;
  my $state = shift;
  my $tmpl_args = '';
  if( @{$this->template_args} ) {
      $tmpl_args =   '< '
                   . join( ', ',
                           map $_->print( $state ), @{$this->template_args} )
                   . ' >';
  }
  return $tmpl_args;
}

sub print {
  my $this = shift;
  my $state = shift;

  return join( '',
               ( $this->is_const ? 'const ' : '' ),
               $this->base_type,
               $this->print_tmpl_args,
               ( $this->is_pointer ? ( '*' x $this->is_pointer ) :
                 $this->is_reference ? '&' : '' ) );
}


1;

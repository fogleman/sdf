package ExtUtils::XSpp::Node::Class;
use strict;
use warnings;
use base 'ExtUtils::XSpp::Node::Package';

=head1 NAME

ExtUtils::XSpp::Node::Class - A class (inherits from Package).

=head1 DESCRIPTION

An L<ExtUtils::XSpp::Node::Package> sub-class representing a class
declaration such as

  %name{PerlClassName} class MyClass : public BaseClass
  {
    ...
  }

The Perl-level class name and the C++ class name attributes
are inherited from the L<ExtUtils::XSpp::Node::Package> class.

=head1 METHODS

=head2 new

Creates a new C<ExtUtils::XSpp::Node::Class> object.

Optional named parameters:
C<methods> can be a reference to an array of methods
(L<ExtUtils::XSpp::Node::Method>) of the class,
and C<base_classes>, a reference to an array of
base classes (C<ExtUtils::XSpp::Node::Class> objects).
C<catch> may be a list of exception names that all
methods in the class handle.

=cut

# internal list of all the non-empty class objects, either defined by the
# parser or created by plugins; does not include dummy base class objects
my %all_classes;

sub init {
  my $this = shift;
  my %args = @_;

  $this->SUPER::init( @_ );
  $this->{METHODS} = [];
  $this->{BASE_CLASSES} = $args{base_classes} || [];
  $this->add_methods( @{$args{methods}} ) if $args{methods};
  $this->{CATCH}     = $args{catch};
  $this->{CONDITION} = $args{condition};
  $this->{EMIT_CONDITION} = $args{emit_condition};
  $this->{GETTER_STYLE} = $this->{SETTER_STYLE} = 'underscore';

  $all_classes{$this->cpp_name} = $this unless $this->empty;

  # TODO check the Perl name of the base class?
  foreach my $base ( @{$this->base_classes} ) {
    $base = $all_classes{$base->cpp_name}
        if $all_classes{$base->cpp_name};
  }
}

=head2 add_methods

Adds new methods to the class. By default, their
scope is C<public>. Takes arbitrary number of arguments
which are processed in order.

If an argument is an L<ExtUtils::XSpp::Node::Access>,
the current method scope is changed accordingly for
all following methods.

If an argument is an L<ExtUtils::XSpp::Node::Method>
it is added to the list of methods of the class.
The method's class name is set to the current class
and its scope is set to the current method scope.

=cut

sub add_methods {
  my $this = shift;
  my $access = 'public'; # good enough for now
  foreach my $meth ( @_ ) {
      if( $meth->isa( 'ExtUtils::XSpp::Node::Function' ) ) {
          $meth->{CLASS} = $this;
          $meth->{ACCESS} = $access;
          $meth->add_exception_handlers( @{$this->{CATCH} || []} );
          $meth->resolve_typemaps;
          $meth->resolve_exceptions;
      } elsif( $meth->isa( 'ExtUtils::XSpp::Node::Member' ) ) {
          $meth->{CLASS} = $this;
          $meth->{ACCESS} = $access;
          $meth->resolve_typemaps;
      } elsif( $meth->isa( 'ExtUtils::XSpp::Node::Access' ) ) {
          $access = $meth->access;
          next;
      }
      # FIXME: Should there be else{croak}?
      push @{$this->{METHODS}}, $meth;
  }

  $all_classes{$this->cpp_name} = $this unless $this->empty;
}

sub delete_methods {
    my( $this, @methods ) = @_;
    my %methods = map { $_ => 1 } @methods;

    $this->{METHODS} = [ grep !$methods{$_}, @{$this->{METHODS}} ];
}

sub print {
  my $this = shift;
  my $state = shift;
  my $out = $this->SUPER::print( $state );

  $out .= '#if ' . $this->emit_condition . "\n" if $this->emit_condition;

  foreach my $m ( @{$this->methods} ) {
    next if $m->can( 'access' ) && $m->access ne 'public';
    $out .= $m->print( $state );
  }

  # add a BOOT block for base classes
  if( @{$this->base_classes} ) {
      my $class = $this->perl_name;

      $out .= <<EOT;
BOOT:
    {
EOT

      $out .= '#ifdef ' . $this->condition . "\n" if $this->condition;
      $out .= <<EOT;
        AV* isa = get_av( "${class}::ISA", 1 );
EOT

    foreach my $b ( @{$this->base_classes} ) {
      my $base = $b->perl_name;

      $out .= <<EOT;
        av_store( isa, 0, newSVpv( "$base", 0 ) );
EOT
    }

      # close block in BOOT
      $out .= '#endif // ' . $this->condition . "\n" if $this->condition;
      $out .= <<EOT;
    } // blank line here is important

EOT
  }

  $out .= '#endif // ' . $this->emit_condition . "\n" if $this->emit_condition;

  return $out;
}

my %getter_maker =
  ( no_prefix   => sub { $_[0] },
    underscore  => sub { 'get_' . $_[0] },
    camelcase   => sub { 'get'  . ucfirst $_[0] },
    uppercase   => sub { 'Get'  . ucfirst $_[0] },
    );

my %setter_maker =
  ( no_prefix   => sub { $_[0] },
    underscore  => sub { 'set_' . $_[0] },
    camelcase   => sub { 'set'  . ucfirst $_[0] },
    uppercase   => sub { 'Set'  . ucfirst $_[0] },
    );

sub _getter_name {
    my( $this, $base ) = @_;

    return $getter_maker{$this->{GETTER_STYLE}}->( $base );
}

sub _setter_name {
    my( $this, $base ) = @_;

    return $setter_maker{$this->{SETTER_STYLE}}->( $base );
}

sub set_getter_style {
    my( $this, $style ) = @_;

    die "Invalid accessor style '$style'" unless exists $getter_maker{$style};
    $this->{GETTER_STYLE} = $style;
}

sub set_setter_style {
    my( $this, $style ) = @_;

    die "Invalid accessor style '$style'" unless exists $setter_maker{$style};
    $this->{SETTER_STYLE} = $style;
}

=head1 ACCESSORS

=head2 methods

Returns the internal reference to the array of methods in this class.
Each of the methods is an C<ExtUtils::XSpp::Node::Method>

=head2 base_classes

Returns the internal reference to the array of base classes of
this class.

If the base classes have been defined in the same file, these are the
complete class objects including method definitions, otherwise only
the C++ and Perl name of the class are available as attributes.

=cut

sub methods { $_[0]->{METHODS} }
sub base_classes { $_[0]->{BASE_CLASSES} }
sub empty { !$_[0]->methods || !@{$_[0]->methods} }

1;

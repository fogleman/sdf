package Method::Generate::DemolishAll;

use Moo::_strictures;
use Moo::Object ();
BEGIN { our @ISA = qw(Moo::Object) }
use Sub::Quote qw(quote_sub quotify);
use Moo::_Utils qw(_getglob);
use Moo::_mro;

sub generate_method {
  my ($self, $into) = @_;
  quote_sub "${into}::DEMOLISHALL", join '',
    $self->_handle_subdemolish($into),
    qq{    my \$self = shift;\n},
    $self->demolishall_body_for($into, '$self', '@_'),
    qq{    return \$self\n};
  quote_sub "${into}::DESTROY", join '',
    q!    my $self = shift;
    my $e = do {
      local $?;
      local $@;
      require Devel::GlobalDestruction;
      eval {
        $self->DEMOLISHALL(Devel::GlobalDestruction::in_global_destruction);
      };
      $@;
    };

    # fatal warnings+die in DESTROY = bad times (perl rt#123398)
    no warnings FATAL => 'all';
    use warnings 'all';
    die $e if $e; # rethrow
  !;
}

sub demolishall_body_for {
  my ($self, $into, $me, $args) = @_;
  my @demolishers =
    grep *{_getglob($_)}{CODE},
    map "${_}::DEMOLISH",
    @{mro::get_linear_isa($into)};
  join '', map qq{    ${me}->${_}(${args});\n}, @demolishers;
}

sub _handle_subdemolish {
  my ($self, $into) = @_;
  '    if (ref($_[0]) ne '.quotify($into).') {'."\n".
  '      return shift->Moo::Object::DEMOLISHALL(@_)'.";\n".
  '    }'."\n";
}

1;

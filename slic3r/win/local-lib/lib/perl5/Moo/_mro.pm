package Moo::_mro;
use Moo::_strictures;

if ("$]" >= 5.010_000) {
  require mro;
} else {
  require MRO::Compat;
}

1;

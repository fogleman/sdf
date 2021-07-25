package ExtUtils::XSpp::Plugin::feature::default_xs_typemap;

use strict;
use warnings;

sub register_plugin {
    my( $class, $parser ) = @_;

    ExtUtils::XSpp::Typemap::_enable_default_xs_typemaps();

}

1;

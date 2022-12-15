#line 1 "parent.pm"
package parent;
use strict;
use vars qw($VERSION);
$VERSION = '0.236';

sub import {
    my $class = shift;

    my $inheritor = caller(0);

    if ( @_ and $_[0] eq '-norequire' ) {
        shift @_;
    } else {
        for ( my @filename = @_ ) {
            s{::|'}{/}g;
            require "$_.pm"; # dies if the file is not found
        }
    }

    {
        no strict 'refs';
        push @{"$inheritor\::ISA"}, @_; # dies if a loop is detected
    };
};

1;

__END__



#line 120

#line 1 "Class/Struct.pm"
package Class::Struct;

## See POD after __END__

use 5.006_001;

use strict;
use warnings::register;
our(@ISA, @EXPORT, $VERSION);

use Carp;

require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw(struct);

$VERSION = '0.65';

my $print = 0;
sub printem {
    if (@_) { $print = shift }
    else    { $print++ }
}

{
    package Class::Struct::Tie_ISA;

    sub TIEARRAY {
        my $class = shift;
        return bless [], $class;
    }

    sub STORE {
        my ($self, $index, $value) = @_;
        Class::Struct::_subclass_error();
    }

    sub FETCH {
        my ($self, $index) = @_;
        $self->[$index];
    }

    sub FETCHSIZE {
        my $self = shift;
        return scalar(@$self);
    }

    sub DESTROY { }
}

sub import {
    my $self = shift;

    if ( @_ == 0 ) {
      $self->export_to_level( 1, $self, @EXPORT );
    } elsif ( @_ == 1 ) {
	# This is admittedly a little bit silly:
	# do we ever export anything else than 'struct'...?
      $self->export_to_level( 1, $self, @_ );
    } else {
      goto &struct;
    }
}

sub struct {

    # Determine parameter list structure, one of:
    #   struct( class => [ element-list ])
    #   struct( class => { element-list })
    #   struct( element-list )
    # Latter form assumes current package name as struct name.

    my ($class, @decls);
    my $base_type = ref $_[1];
    if ( $base_type eq 'HASH' ) {
        $class = shift;
        @decls = %{shift()};
        _usage_error() if @_;
    }
    elsif ( $base_type eq 'ARRAY' ) {
        $class = shift;
        @decls = @{shift()};
        _usage_error() if @_;
    }
    else {
        $base_type = 'ARRAY';
        $class = (caller())[0];
        @decls = @_;
    }

    _usage_error() if @decls % 2 == 1;

    # Ensure we are not, and will not be, a subclass.

    my $isa = do {
        no strict 'refs';
        \@{$class . '::ISA'};
    };
    _subclass_error() if @$isa;
    tie @$isa, 'Class::Struct::Tie_ISA';

    # Create constructor.

    croak "function 'new' already defined in package $class"
        if do { no strict 'refs'; defined &{$class . "::new"} };

    my @methods = ();
    my %refs = ();
    my %arrays = ();
    my %hashes = ();
    my %classes = ();
    my $got_class = 0;
    my $out = '';

    $out = "{\n  package $class;\n  use Carp;\n  sub new {\n";
    $out .= "    my (\$class, \%init) = \@_;\n";
    $out .= "    \$class = __PACKAGE__ unless \@_;\n";

    my $cnt = 0;
    my $idx = 0;
    my( $cmt, $name, $type, $elem );

    if( $base_type eq 'HASH' ){
        $out .= "    my(\$r) = {};\n";
        $cmt = '';
    }
    elsif( $base_type eq 'ARRAY' ){
        $out .= "    my(\$r) = [];\n";
    }

    $out .= " bless \$r, \$class;\n\n";

    while( $idx < @decls ){
        $name = $decls[$idx];
        $type = $decls[$idx+1];
        push( @methods, $name );
        if( $base_type eq 'HASH' ){
            $elem = "{'${class}::$name'}";
        }
        elsif( $base_type eq 'ARRAY' ){
            $elem = "[$cnt]";
            ++$cnt;
            $cmt = " # $name";
        }
        if( $type =~ /^\*(.)/ ){
            $refs{$name}++;
            $type = $1;
        }
        my $init = "defined(\$init{'$name'}) ? \$init{'$name'} :";
        if( $type eq '@' ){
            $out .= "    croak 'Initializer for $name must be array reference'\n"; 
            $out .= "        if defined(\$init{'$name'}) && ref(\$init{'$name'}) ne 'ARRAY';\n";
            $out .= "    \$r->$name( $init [] );$cmt\n"; 
            $arrays{$name}++;
        }
        elsif( $type eq '%' ){
            $out .= "    croak 'Initializer for $name must be hash reference'\n";
            $out .= "        if defined(\$init{'$name'}) && ref(\$init{'$name'}) ne 'HASH';\n";
            $out .= "    \$r->$name( $init {} );$cmt\n";
            $hashes{$name}++;
        }
        elsif ( $type eq '$') {
            $out .= "    \$r->$name( $init undef );$cmt\n";
        }
        elsif( $type =~ /^\w+(?:::\w+)*$/ ){
            $out .= "    if (defined(\$init{'$name'})) {\n";
           $out .= "       if (ref \$init{'$name'} eq 'HASH')\n";
            $out .= "            { \$r->$name( $type->new(\%{\$init{'$name'}}) ) } $cmt\n";
           $out .= "       elsif (UNIVERSAL::isa(\$init{'$name'}, '$type'))\n";
            $out .= "            { \$r->$name( \$init{'$name'} ) } $cmt\n";
            $out .= "       else { croak 'Initializer for $name must be hash or $type reference' }\n";
            $out .= "    }\n";
            $classes{$name} = $type;
            $got_class = 1;
        }
        else{
            croak "'$type' is not a valid struct element type";
        }
        $idx += 2;
    }

    $out .= "\n \$r;\n}\n";

    # Create accessor methods.

    my( $pre, $pst, $sel );
    $cnt = 0;
    foreach $name (@methods){
        if ( do { no strict 'refs'; defined &{$class . "::$name"} } ) {
            warnings::warnif("function '$name' already defined, overrides struct accessor method");
        }
        else {
            $pre = $pst = $cmt = $sel = '';
            if( defined $refs{$name} ){
                $pre = "\\(";
                $pst = ")";
                $cmt = " # returns ref";
            }
            $out .= "  sub $name {$cmt\n    my \$r = shift;\n";
            if( $base_type eq 'ARRAY' ){
                $elem = "[$cnt]";
                ++$cnt;
            }
            elsif( $base_type eq 'HASH' ){
                $elem = "{'${class}::$name'}";
            }
            if( defined $arrays{$name} ){
                $out .= "    my \$i;\n";
                $out .= "    \@_ ? (\$i = shift) : return \$r->$elem;\n"; 
                $out .= "    if (ref(\$i) eq 'ARRAY' && !\@_) { \$r->$elem = \$i; return \$r }\n";
                $sel = "->[\$i]";
            }
            elsif( defined $hashes{$name} ){
                $out .= "    my \$i;\n";
                $out .= "    \@_ ? (\$i = shift) : return \$r->$elem;\n";
                $out .= "    if (ref(\$i) eq 'HASH' && !\@_) { \$r->$elem = \$i; return \$r }\n";
                $sel = "->{\$i}";
            }
            elsif( defined $classes{$name} ){
                $out .= "    croak '$name argument is wrong class' if \@_ && ! UNIVERSAL::isa(\$_[0], '$classes{$name}');\n";
            }
            $out .= "    croak 'Too many args to $name' if \@_ > 1;\n";
            $out .= "    \@_ ? ($pre\$r->$elem$sel = shift$pst) : $pre\$r->$elem$sel$pst;\n";
            $out .= "  }\n";
        }
    }
    $out .= "}\n1;\n";

    print $out if $print;
    my $result = eval $out;
    carp $@ if $@;
}

sub _usage_error {
    confess "struct usage error";
}

sub _subclass_error {
    croak 'struct class cannot be a subclass (@ISA not allowed)';
}

1; # for require


__END__

#line 638

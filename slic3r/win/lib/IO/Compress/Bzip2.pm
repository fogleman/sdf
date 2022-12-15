#line 1 "IO/Compress/Bzip2.pm"
package IO::Compress::Bzip2 ;

use strict ;
use warnings;
use bytes;
require Exporter ;

use IO::Compress::Base 2.074 ;

use IO::Compress::Base::Common  2.074 qw();
use IO::Compress::Adapter::Bzip2 2.074 ;



our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, $Bzip2Error);

$VERSION = '2.074';
$Bzip2Error = '';

@ISA    = qw(IO::Compress::Base Exporter);
@EXPORT_OK = qw( $Bzip2Error bzip2 ) ;
%EXPORT_TAGS = %IO::Compress::Base::EXPORT_TAGS ;
push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
Exporter::export_ok_tags('all');



sub new
{
    my $class = shift ;

    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$Bzip2Error);
    return $obj->_create(undef, @_);
}

sub bzip2
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$Bzip2Error);
    $obj->_def(@_);
}


sub mkHeader 
{
    my $self = shift ;
    return '';

}

sub getExtraParams
{
    my $self = shift ;

    use IO::Compress::Base::Common  2.074 qw(:Parse);
    
    return (  
            'blocksize100k' => [IO::Compress::Base::Common::Parse_unsigned,  1],
            'workfactor'    => [IO::Compress::Base::Common::Parse_unsigned,  0],
            'verbosity'     => [IO::Compress::Base::Common::Parse_boolean,   0],
        );
}



sub ckParams
{
    my $self = shift ;
    my $got = shift;
    
    # check that BlockSize100K is a number between 1 & 9
    if ($got->parsed('blocksize100k')) {
        my $value = $got->getValue('blocksize100k');
        return $self->saveErrorString(undef, "Parameter 'BlockSize100K' not between 1 and 9, got $value")
            unless defined $value && $value >= 1 && $value <= 9;

    }

    # check that WorkFactor between 0 & 250
    if ($got->parsed('workfactor')) {
        my $value = $got->getValue('workfactor');
        return $self->saveErrorString(undef, "Parameter 'WorkFactor' not between 0 and 250, got $value")
            unless $value >= 0 && $value <= 250;
    }

    return 1 ;
}


sub mkComp
{
    my $self = shift ;
    my $got = shift ;

    my $BlockSize100K = $got->getValue('blocksize100k');
    my $WorkFactor    = $got->getValue('workfactor');
    my $Verbosity     = $got->getValue('verbosity');

    my ($obj, $errstr, $errno) = IO::Compress::Adapter::Bzip2::mkCompObject(
                                               $BlockSize100K, $WorkFactor,
                                               $Verbosity);

    return $self->saveErrorString(undef, $errstr, $errno)
        if ! defined $obj;
    
    return $obj;
}


sub mkTrailer
{
    my $self = shift ;
    return '';
}

sub mkFinalTrailer
{
    return '';
}

#sub newHeader
#{
#    my $self = shift ;
#    return '';
#}

sub getInverseClass
{
    return ('IO::Uncompress::Bunzip2');
}

sub getFileInfo
{
    my $self = shift ;
    my $params = shift;
    my $file = shift ;
    
}

1;

__END__

#line 806

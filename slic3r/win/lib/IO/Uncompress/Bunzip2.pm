#line 1 "IO/Uncompress/Bunzip2.pm"
package IO::Uncompress::Bunzip2 ;

use strict ;
use warnings;
use bytes;

use IO::Compress::Base::Common 2.074 qw(:Status );

use IO::Uncompress::Base 2.074 ;
use IO::Uncompress::Adapter::Bunzip2 2.074 ;

require Exporter ;
our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, $Bunzip2Error);

$VERSION = '2.074';
$Bunzip2Error = '';

@ISA    = qw(IO::Uncompress::Base Exporter);
@EXPORT_OK = qw( $Bunzip2Error bunzip2 ) ;
#%EXPORT_TAGS = %IO::Uncompress::Base::EXPORT_TAGS ;
push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
#Exporter::export_ok_tags('all');


sub new
{
    my $class = shift ;
    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$Bunzip2Error);

    $obj->_create(undef, 0, @_);
}

sub bunzip2
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$Bunzip2Error);
    return $obj->_inf(@_);
}

sub getExtraParams
{
    return (
            'verbosity'     => [IO::Compress::Base::Common::Parse_boolean,   0],
            'small'         => [IO::Compress::Base::Common::Parse_boolean,   0],
        );
}


sub ckParams
{
    my $self = shift ;
    my $got = shift ;

    return 1;
}

sub mkUncomp
{
    my $self = shift ;
    my $got = shift ;

     my $magic = $self->ckMagic()
        or return 0;

    *$self->{Info} = $self->readHeader($magic)
        or return undef ;

    my $Small     = $got->getValue('small');
    my $Verbosity = $got->getValue('verbosity');

    my ($obj, $errstr, $errno) =  IO::Uncompress::Adapter::Bunzip2::mkUncompObject(
                                                    $Small, $Verbosity);

    return $self->saveErrorString(undef, $errstr, $errno)
        if ! defined $obj;
    
    *$self->{Uncomp} = $obj;

    return 1;

}


sub ckMagic
{
    my $self = shift;

    my $magic ;
    $self->smartReadExact(\$magic, 4);

    *$self->{HeaderPending} = $magic ;
    
    return $self->HeaderError("Header size is " . 
                                        4 . " bytes") 
        if length $magic != 4;

    return $self->HeaderError("Bad Magic.")
        if ! isBzip2Magic($magic) ;
                      
        
    *$self->{Type} = 'bzip2';
    return $magic;
}

sub readHeader
{
    my $self = shift;
    my $magic = shift ;

    $self->pushBack($magic);
    *$self->{HeaderPending} = '';


    return {
        'Type'              => 'bzip2',
        'FingerprintLength' => 4,
        'HeaderLength'      => 4,
        'TrailerLength'     => 0,
        'Header'            => '$magic'
        };
    
}

sub chkTrailer
{
    return STATUS_OK;
}



sub isBzip2Magic
{
    my $buffer = shift ;
    return $buffer =~ /^BZh\d$/;
}

1 ;

__END__


#line 911

#line 1 "IO/Uncompress/Inflate.pm"
package IO::Uncompress::Inflate ;
# for RFC1950

use strict ;
use warnings;
use bytes;

use IO::Compress::Base::Common  2.074 qw(:Status );
use IO::Compress::Zlib::Constants 2.074 ;

use IO::Uncompress::RawInflate  2.074 ;

require Exporter ;
our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, $InflateError);

$VERSION = '2.074';
$InflateError = '';

@ISA    = qw(IO::Uncompress::RawInflate Exporter);
@EXPORT_OK = qw( $InflateError inflate ) ;
%EXPORT_TAGS = %IO::Uncompress::RawInflate::DEFLATE_CONSTANTS ;
push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
Exporter::export_ok_tags('all');


sub new
{
    my $class = shift ;
    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$InflateError);

    $obj->_create(undef, 0, @_);
}

sub inflate
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$InflateError);
    return $obj->_inf(@_);
}

sub getExtraParams
{
    return ();
}

sub ckParams
{
    my $self = shift ;
    my $got = shift ;

    # gunzip always needs adler32
    $got->setValue('adler32' => 1);

    return 1;
}

sub ckMagic
{
    my $self = shift;

    my $magic ;
    $self->smartReadExact(\$magic, ZLIB_HEADER_SIZE);

    *$self->{HeaderPending} = $magic ;

    return $self->HeaderError("Header size is " . 
                                        ZLIB_HEADER_SIZE . " bytes") 
        if length $magic != ZLIB_HEADER_SIZE;

    #return $self->HeaderError("CRC mismatch.")
    return undef
        if ! $self->isZlibMagic($magic) ;
                      
    *$self->{Type} = 'rfc1950';
    return $magic;
}

sub readHeader
{
    my $self = shift;
    my $magic = shift ;

    return $self->_readDeflateHeader($magic) ;
}

sub chkTrailer
{
    my $self = shift;
    my $trailer = shift;

    my $ADLER32 = unpack("N", $trailer) ;
    *$self->{Info}{ADLER32} = $ADLER32;    
    return $self->TrailerError("CRC mismatch")
        if *$self->{Strict} && $ADLER32 != *$self->{Uncomp}->adler32() ;

    return STATUS_OK;
}



sub isZlibMagic
{
    my $self = shift;
    my $buffer = shift ;

    return 0 
        if length $buffer < ZLIB_HEADER_SIZE ;

    my $hdr = unpack("n", $buffer) ;
    #return 0 if $hdr % 31 != 0 ;
    return $self->HeaderError("CRC mismatch.")
        if $hdr % 31 != 0 ;

    my ($CMF, $FLG) = unpack "C C", $buffer;
    my $cm =    bits($CMF, ZLIB_CMF_CM_OFFSET,    ZLIB_CMF_CM_BITS) ;

    # Only Deflate supported
    return $self->HeaderError("Not Deflate (CM is $cm)") 
        if $cm != ZLIB_CMF_CM_DEFLATED ;

    # Max window value is 7 for Deflate.
    my $cinfo = bits($CMF, ZLIB_CMF_CINFO_OFFSET, ZLIB_CMF_CINFO_BITS) ;
    return $self->HeaderError("CINFO > " . ZLIB_CMF_CINFO_MAX . 
                              " (CINFO is $cinfo)") 
        if $cinfo > ZLIB_CMF_CINFO_MAX ;

    return 1;    
}

sub bits
{
    my $data   = shift ;
    my $offset = shift ;
    my $mask  = shift ;

    ($data >> $offset ) & $mask & 0xFF ;
}


sub _readDeflateHeader
{
    my ($self, $buffer) = @_ ;

#    if (! $buffer) {
#        $self->smartReadExact(\$buffer, ZLIB_HEADER_SIZE);
#
#        *$self->{HeaderPending} = $buffer ;
#
#        return $self->HeaderError("Header size is " . 
#                                            ZLIB_HEADER_SIZE . " bytes") 
#            if length $buffer != ZLIB_HEADER_SIZE;
#
#        return $self->HeaderError("CRC mismatch.")
#            if ! isZlibMagic($buffer) ;
#    }
                                        
    my ($CMF, $FLG) = unpack "C C", $buffer;
    my $FDICT = bits($FLG, ZLIB_FLG_FDICT_OFFSET,  ZLIB_FLG_FDICT_BITS ),

    my $cm = bits($CMF, ZLIB_CMF_CM_OFFSET, ZLIB_CMF_CM_BITS) ;
    $cm == ZLIB_CMF_CM_DEFLATED 
        or return $self->HeaderError("Not Deflate (CM is $cm)") ;

    my $DICTID;
    if ($FDICT) {
        $self->smartReadExact(\$buffer, ZLIB_FDICT_SIZE)
            or return $self->TruncatedHeader("FDICT");

        $DICTID = unpack("N", $buffer) ;
    }

    *$self->{Type} = 'rfc1950';

    return {
        'Type'          => 'rfc1950',
        'FingerprintLength'  => ZLIB_HEADER_SIZE,
        'HeaderLength'  => ZLIB_HEADER_SIZE,
        'TrailerLength' => ZLIB_TRAILER_SIZE,
        'Header'        => $buffer,

        CMF     =>      $CMF                                               ,
        CM      => bits($CMF, ZLIB_CMF_CM_OFFSET,     ZLIB_CMF_CM_BITS    ),
        CINFO   => bits($CMF, ZLIB_CMF_CINFO_OFFSET,  ZLIB_CMF_CINFO_BITS ),
        FLG     =>      $FLG                                               ,
        FCHECK  => bits($FLG, ZLIB_FLG_FCHECK_OFFSET, ZLIB_FLG_FCHECK_BITS),
        FDICT   => bits($FLG, ZLIB_FLG_FDICT_OFFSET,  ZLIB_FLG_FDICT_BITS ),
        FLEVEL  => bits($FLG, ZLIB_FLG_LEVEL_OFFSET,  ZLIB_FLG_LEVEL_BITS ),
        DICTID  =>      $DICTID                                            ,

    };
}




1 ;

__END__


#line 998

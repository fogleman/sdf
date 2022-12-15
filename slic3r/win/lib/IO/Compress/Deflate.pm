#line 1 "IO/Compress/Deflate.pm"
package IO::Compress::Deflate ;

require 5.006 ;

use strict ;
use warnings;
use bytes;

require Exporter ;

use IO::Compress::RawDeflate 2.074 ();
use IO::Compress::Adapter::Deflate 2.074 ;

use IO::Compress::Zlib::Constants 2.074 ;
use IO::Compress::Base::Common  2.074 qw();


our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, %DEFLATE_CONSTANTS, $DeflateError);

$VERSION = '2.074';
$DeflateError = '';

@ISA    = qw(IO::Compress::RawDeflate Exporter);
@EXPORT_OK = qw( $DeflateError deflate ) ;
%EXPORT_TAGS = %IO::Compress::RawDeflate::DEFLATE_CONSTANTS ;

push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
Exporter::export_ok_tags('all');


sub new
{
    my $class = shift ;

    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$DeflateError);
    return $obj->_create(undef, @_);
}

sub deflate
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$DeflateError);
    return $obj->_def(@_);
}


sub bitmask($$$$)
{
    my $into  = shift ;
    my $value  = shift ;
    my $offset = shift ;
    my $mask   = shift ;

    return $into | (($value & $mask) << $offset ) ;
}

sub mkDeflateHdr($$$;$)
{
    my $method = shift ;
    my $cinfo  = shift;
    my $level  = shift;
    my $fdict_adler = shift  ;

    my $cmf = 0;
    my $flg = 0;
    my $fdict = 0;
    $fdict = 1 if defined $fdict_adler;

    $cmf = bitmask($cmf, $method, ZLIB_CMF_CM_OFFSET,    ZLIB_CMF_CM_BITS);
    $cmf = bitmask($cmf, $cinfo,  ZLIB_CMF_CINFO_OFFSET, ZLIB_CMF_CINFO_BITS);

    $flg = bitmask($flg, $fdict,  ZLIB_FLG_FDICT_OFFSET, ZLIB_FLG_FDICT_BITS);
    $flg = bitmask($flg, $level,  ZLIB_FLG_LEVEL_OFFSET, ZLIB_FLG_LEVEL_BITS);

    my $fcheck = 31 - ($cmf * 256 + $flg) % 31 ;
    $flg = bitmask($flg, $fcheck, ZLIB_FLG_FCHECK_OFFSET, ZLIB_FLG_FCHECK_BITS);

    my $hdr =  pack("CC", $cmf, $flg) ;
    $hdr .= pack("N", $fdict_adler) if $fdict ;

    return $hdr;
}

sub mkHeader 
{
    my $self = shift ;
    my $param = shift ;

    my $level = $param->getValue('level');
    my $strategy = $param->getValue('strategy');

    my $lflag ;
    $level = 6 
        if $level == Z_DEFAULT_COMPRESSION ;

    if (ZLIB_VERNUM >= 0x1210)
    {
        if ($strategy >= Z_HUFFMAN_ONLY || $level < 2)
         {  $lflag = ZLIB_FLG_LEVEL_FASTEST }
        elsif ($level < 6)
         {  $lflag = ZLIB_FLG_LEVEL_FAST }
        elsif ($level == 6)
         {  $lflag = ZLIB_FLG_LEVEL_DEFAULT }
        else
         {  $lflag = ZLIB_FLG_LEVEL_SLOWEST }
    }
    else
    {
        $lflag = ($level - 1) >> 1 ;
        $lflag = 3 if $lflag > 3 ;
    }

     #my $wbits = (MAX_WBITS - 8) << 4 ;
    my $wbits = 7;
    mkDeflateHdr(ZLIB_CMF_CM_DEFLATED, $wbits, $lflag);
}

sub ckParams
{
    my $self = shift ;
    my $got = shift;
    
    $got->setValue('adler32' => 1);
    return 1 ;
}


sub mkTrailer
{
    my $self = shift ;
    return pack("N", *$self->{Compress}->adler32()) ;
}

sub mkFinalTrailer
{
    return '';
}

#sub newHeader
#{
#    my $self = shift ;
#    return *$self->{Header};
#}

sub getExtraParams
{
    my $self = shift ;
    return $self->getZlibParams(),
}

sub getInverseClass
{
    return ('IO::Uncompress::Inflate',
                \$IO::Uncompress::Inflate::InflateError);
}

sub getFileInfo
{
    my $self = shift ;
    my $params = shift;
    my $file = shift ;
    
}



1;

__END__

#line 940

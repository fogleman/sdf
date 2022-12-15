#line 1 "IO/Uncompress/Gunzip.pm"

package IO::Uncompress::Gunzip ;

require 5.006 ;

# for RFC1952

use strict ;
use warnings;
use bytes;

use IO::Uncompress::RawInflate 2.074 ;

use Compress::Raw::Zlib 2.074 () ;
use IO::Compress::Base::Common 2.074 qw(:Status );
use IO::Compress::Gzip::Constants 2.074 ;
use IO::Compress::Zlib::Extra 2.074 ;

require Exporter ;

our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, $GunzipError);

@ISA = qw(IO::Uncompress::RawInflate Exporter);
@EXPORT_OK = qw( $GunzipError gunzip );
%EXPORT_TAGS = %IO::Uncompress::RawInflate::DEFLATE_CONSTANTS ;
push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
Exporter::export_ok_tags('all');

$GunzipError = '';

$VERSION = '2.074';

sub new
{
    my $class = shift ;
    $GunzipError = '';
    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$GunzipError);

    $obj->_create(undef, 0, @_);
}

sub gunzip
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$GunzipError);
    return $obj->_inf(@_) ;
}

sub getExtraParams
{
    return ( 'parseextra' => [IO::Compress::Base::Common::Parse_boolean,  0] ) ;
}

sub ckParams
{
    my $self = shift ;
    my $got = shift ;

    # gunzip always needs crc32
    $got->setValue('crc32' => 1);

    return 1;
}

sub ckMagic
{
    my $self = shift;

    my $magic ;
    $self->smartReadExact(\$magic, GZIP_ID_SIZE);

    *$self->{HeaderPending} = $magic ;

    return $self->HeaderError("Minimum header size is " . 
                              GZIP_MIN_HEADER_SIZE . " bytes") 
        if length $magic != GZIP_ID_SIZE ;                                    

    return $self->HeaderError("Bad Magic")
        if ! isGzipMagic($magic) ;

    *$self->{Type} = 'rfc1952';

    return $magic ;
}

sub readHeader
{
    my $self = shift;
    my $magic = shift;

    return $self->_readGzipHeader($magic);
}

sub chkTrailer
{
    my $self = shift;
    my $trailer = shift;

    # Check CRC & ISIZE 
    my ($CRC32, $ISIZE) = unpack("V V", $trailer) ;
    *$self->{Info}{CRC32} = $CRC32;    
    *$self->{Info}{ISIZE} = $ISIZE;    

    if (*$self->{Strict}) {
        return $self->TrailerError("CRC mismatch")
            if $CRC32 != *$self->{Uncomp}->crc32() ;

        my $exp_isize = *$self->{UnCompSize}->get32bit();
        return $self->TrailerError("ISIZE mismatch. Got $ISIZE"
                                  . ", expected $exp_isize")
            if $ISIZE != $exp_isize ;
    }

    return STATUS_OK;
}

sub isGzipMagic
{
    my $buffer = shift ;
    return 0 if length $buffer < GZIP_ID_SIZE ;
    my ($id1, $id2) = unpack("C C", $buffer) ;
    return $id1 == GZIP_ID1 && $id2 == GZIP_ID2 ;
}

sub _readFullGzipHeader($)
{
    my ($self) = @_ ;
    my $magic = '' ;

    $self->smartReadExact(\$magic, GZIP_ID_SIZE);

    *$self->{HeaderPending} = $magic ;

    return $self->HeaderError("Minimum header size is " . 
                              GZIP_MIN_HEADER_SIZE . " bytes") 
        if length $magic != GZIP_ID_SIZE ;                                    


    return $self->HeaderError("Bad Magic")
        if ! isGzipMagic($magic) ;

    my $status = $self->_readGzipHeader($magic);
    delete *$self->{Transparent} if ! defined $status ;
    return $status ;
}

sub _readGzipHeader($)
{
    my ($self, $magic) = @_ ;
    my ($HeaderCRC) ;
    my ($buffer) = '' ;

    $self->smartReadExact(\$buffer, GZIP_MIN_HEADER_SIZE - GZIP_ID_SIZE)
        or return $self->HeaderError("Minimum header size is " . 
                                     GZIP_MIN_HEADER_SIZE . " bytes") ;

    my $keep = $magic . $buffer ;
    *$self->{HeaderPending} = $keep ;

    # now split out the various parts
    my ($cm, $flag, $mtime, $xfl, $os) = unpack("C C V C C", $buffer) ;

    $cm == GZIP_CM_DEFLATED 
        or return $self->HeaderError("Not Deflate (CM is $cm)") ;

    # check for use of reserved bits
    return $self->HeaderError("Use of Reserved Bits in FLG field.")
        if $flag & GZIP_FLG_RESERVED ; 

    my $EXTRA ;
    my @EXTRA = () ;
    if ($flag & GZIP_FLG_FEXTRA) {
        $EXTRA = "" ;
        $self->smartReadExact(\$buffer, GZIP_FEXTRA_HEADER_SIZE) 
            or return $self->TruncatedHeader("FEXTRA Length") ;

        my ($XLEN) = unpack("v", $buffer) ;
        $self->smartReadExact(\$EXTRA, $XLEN) 
            or return $self->TruncatedHeader("FEXTRA Body");
        $keep .= $buffer . $EXTRA ;

        if ($XLEN && *$self->{'ParseExtra'}) {
            my $bad = IO::Compress::Zlib::Extra::parseRawExtra($EXTRA,
                                                \@EXTRA, 1, 1);
            return $self->HeaderError($bad)
                if defined $bad;
        }
    }

    my $origname ;
    if ($flag & GZIP_FLG_FNAME) {
        $origname = "" ;
        while (1) {
            $self->smartReadExact(\$buffer, 1) 
                or return $self->TruncatedHeader("FNAME");
            last if $buffer eq GZIP_NULL_BYTE ;
            $origname .= $buffer 
        }
        $keep .= $origname . GZIP_NULL_BYTE ;

        return $self->HeaderError("Non ISO 8859-1 Character found in Name")
            if *$self->{Strict} && $origname =~ /$GZIP_FNAME_INVALID_CHAR_RE/o ;
    }

    my $comment ;
    if ($flag & GZIP_FLG_FCOMMENT) {
        $comment = "";
        while (1) {
            $self->smartReadExact(\$buffer, 1) 
                or return $self->TruncatedHeader("FCOMMENT");
            last if $buffer eq GZIP_NULL_BYTE ;
            $comment .= $buffer 
        }
        $keep .= $comment . GZIP_NULL_BYTE ;

        return $self->HeaderError("Non ISO 8859-1 Character found in Comment")
            if *$self->{Strict} && $comment =~ /$GZIP_FCOMMENT_INVALID_CHAR_RE/o ;
    }

    if ($flag & GZIP_FLG_FHCRC) {
        $self->smartReadExact(\$buffer, GZIP_FHCRC_SIZE) 
            or return $self->TruncatedHeader("FHCRC");

        $HeaderCRC = unpack("v", $buffer) ;
        my $crc16 = Compress::Raw::Zlib::crc32($keep) & 0xFF ;

        return $self->HeaderError("CRC16 mismatch.")
            if *$self->{Strict} && $crc16 != $HeaderCRC;

        $keep .= $buffer ;
    }

    # Assume compression method is deflated for xfl tests
    #if ($xfl) {
    #}

    *$self->{Type} = 'rfc1952';

    return {
        'Type'          => 'rfc1952',
        'FingerprintLength'  => 2,
        'HeaderLength'  => length $keep,
        'TrailerLength' => GZIP_TRAILER_SIZE,
        'Header'        => $keep,
        'isMinimalHeader' => $keep eq GZIP_MINIMUM_HEADER ? 1 : 0,

        'MethodID'      => $cm,
        'MethodName'    => $cm == GZIP_CM_DEFLATED ? "Deflated" : "Unknown" ,
        'TextFlag'      => $flag & GZIP_FLG_FTEXT ? 1 : 0,
        'HeaderCRCFlag' => $flag & GZIP_FLG_FHCRC ? 1 : 0,
        'NameFlag'      => $flag & GZIP_FLG_FNAME ? 1 : 0,
        'CommentFlag'   => $flag & GZIP_FLG_FCOMMENT ? 1 : 0,
        'ExtraFlag'     => $flag & GZIP_FLG_FEXTRA ? 1 : 0,
        'Name'          => $origname,
        'Comment'       => $comment,
        'Time'          => $mtime,
        'OsID'          => $os,
        'OsName'        => defined $GZIP_OS_Names{$os} 
                                 ? $GZIP_OS_Names{$os} : "Unknown",
        'HeaderCRC'     => $HeaderCRC,
        'Flags'         => $flag,
        'ExtraFlags'    => $xfl,
        'ExtraFieldRaw' => $EXTRA,
        'ExtraField'    => [ @EXTRA ],


        #'CompSize'=> $compsize,
        #'CRC32'=> $CRC32,
        #'OrigSize'=> $ISIZE,
      }
}


1;

__END__


#line 1126

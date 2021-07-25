#line 1 "IO/Compress/Gzip.pm"
package IO::Compress::Gzip ;

require 5.006 ;

use strict ;
use warnings;
use bytes;

require Exporter ;

use IO::Compress::RawDeflate 2.074 () ; 
use IO::Compress::Adapter::Deflate 2.074 ;

use IO::Compress::Base::Common  2.074 qw(:Status );
use IO::Compress::Gzip::Constants 2.074 ;
use IO::Compress::Zlib::Extra 2.074 ;

BEGIN
{
    if (defined &utf8::downgrade ) 
      { *noUTF8 = \&utf8::downgrade }
    else
      { *noUTF8 = sub {} }  
}

our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, %DEFLATE_CONSTANTS, $GzipError);

$VERSION = '2.074';
$GzipError = '' ;

@ISA    = qw(IO::Compress::RawDeflate Exporter);
@EXPORT_OK = qw( $GzipError gzip ) ;
%EXPORT_TAGS = %IO::Compress::RawDeflate::DEFLATE_CONSTANTS ;

push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
Exporter::export_ok_tags('all');

sub new
{
    my $class = shift ;

    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$GzipError);

    $obj->_create(undef, @_);
}


sub gzip
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$GzipError);
    return $obj->_def(@_);
}

#sub newHeader
#{
#    my $self = shift ;
#    #return GZIP_MINIMUM_HEADER ;
#    return $self->mkHeader(*$self->{Got});
#}

sub getExtraParams
{
    my $self = shift ;

    return (
            # zlib behaviour
            $self->getZlibParams(),
           
            # Gzip header fields
            'minimal'   => [IO::Compress::Base::Common::Parse_boolean,   0],
            'comment'   => [IO::Compress::Base::Common::Parse_any,       undef],
            'name'      => [IO::Compress::Base::Common::Parse_any,       undef],
            'time'      => [IO::Compress::Base::Common::Parse_any,       undef],
            'textflag'  => [IO::Compress::Base::Common::Parse_boolean,   0],
            'headercrc' => [IO::Compress::Base::Common::Parse_boolean,   0],
            'os_code'   => [IO::Compress::Base::Common::Parse_unsigned,  $Compress::Raw::Zlib::gzip_os_code],
            'extrafield'=> [IO::Compress::Base::Common::Parse_any,       undef],
            'extraflags'=> [IO::Compress::Base::Common::Parse_any,       undef],

        );
}


sub ckParams
{
    my $self = shift ;
    my $got = shift ;

    # gzip always needs crc32
    $got->setValue('crc32' => 1);

    return 1
        if $got->getValue('merge') ;

    my $strict = $got->getValue('strict') ;


    {
        if (! $got->parsed('time') ) {
            # Modification time defaults to now.
            $got->setValue(time => time) ;
        }

        # Check that the Name & Comment don't have embedded NULLs
        # Also check that they only contain ISO 8859-1 chars.
        if ($got->parsed('name') && defined $got->getValue('name')) {
            my $name = $got->getValue('name');
                
            return $self->saveErrorString(undef, "Null Character found in Name",
                                                Z_DATA_ERROR)
                if $strict && $name =~ /\x00/ ;

            return $self->saveErrorString(undef, "Non ISO 8859-1 Character found in Name",
                                                Z_DATA_ERROR)
                if $strict && $name =~ /$GZIP_FNAME_INVALID_CHAR_RE/o ;
        }

        if ($got->parsed('comment') && defined $got->getValue('comment')) {
            my $comment = $got->getValue('comment');

            return $self->saveErrorString(undef, "Null Character found in Comment",
                                                Z_DATA_ERROR)
                if $strict && $comment =~ /\x00/ ;

            return $self->saveErrorString(undef, "Non ISO 8859-1 Character found in Comment",
                                                Z_DATA_ERROR)
                if $strict && $comment =~ /$GZIP_FCOMMENT_INVALID_CHAR_RE/o;
        }

        if ($got->parsed('os_code') ) {
            my $value = $got->getValue('os_code');

            return $self->saveErrorString(undef, "OS_Code must be between 0 and 255, got '$value'")
                if $value < 0 || $value > 255 ;
            
        }

        # gzip only supports Deflate at present
        $got->setValue('method' => Z_DEFLATED) ;

        if ( ! $got->parsed('extraflags')) {
            $got->setValue('extraflags' => 2) 
                if $got->getValue('level') == Z_BEST_COMPRESSION ;
            $got->setValue('extraflags' => 4) 
                if $got->getValue('level') == Z_BEST_SPEED ;
        }

        my $data = $got->getValue('extrafield') ;
        if (defined $data) {
            my $bad = IO::Compress::Zlib::Extra::parseExtraField($data, $strict, 1) ;
            return $self->saveErrorString(undef, "Error with ExtraField Parameter: $bad", Z_DATA_ERROR)
                if $bad ;

            $got->setValue('extrafield' => $data) ;
        }
    }

    return 1;
}

sub mkTrailer
{
    my $self = shift ;
    return pack("V V", *$self->{Compress}->crc32(), 
                       *$self->{UnCompSize}->get32bit());
}

sub getInverseClass
{
    return ('IO::Uncompress::Gunzip',
                \$IO::Uncompress::Gunzip::GunzipError);
}

sub getFileInfo
{
    my $self = shift ;
    my $params = shift;
    my $filename = shift ;

    return if IO::Compress::Base::Common::isaScalar($filename);

    my $defaultTime = (stat($filename))[9] ;

    $params->setValue('name' => $filename)
        if ! $params->parsed('name') ;

    $params->setValue('time' => $defaultTime) 
        if ! $params->parsed('time') ;
}


sub mkHeader
{
    my $self = shift ;
    my $param = shift ;

    # short-circuit if a minimal header is requested.
    return GZIP_MINIMUM_HEADER if $param->getValue('minimal') ;

    # METHOD
    my $method = $param->valueOrDefault('method', GZIP_CM_DEFLATED) ;

    # FLAGS
    my $flags       = GZIP_FLG_DEFAULT ;
    $flags |= GZIP_FLG_FTEXT    if $param->getValue('textflag') ;
    $flags |= GZIP_FLG_FHCRC    if $param->getValue('headercrc') ;
    $flags |= GZIP_FLG_FEXTRA   if $param->wantValue('extrafield') ;
    $flags |= GZIP_FLG_FNAME    if $param->wantValue('name') ;
    $flags |= GZIP_FLG_FCOMMENT if $param->wantValue('comment') ;
    
    # MTIME
    my $time = $param->valueOrDefault('time', GZIP_MTIME_DEFAULT) ;

    # EXTRA FLAGS
    my $extra_flags = $param->valueOrDefault('extraflags', GZIP_XFL_DEFAULT);

    # OS CODE
    my $os_code = $param->valueOrDefault('os_code', GZIP_OS_DEFAULT) ;


    my $out = pack("C4 V C C", 
            GZIP_ID1,   # ID1
            GZIP_ID2,   # ID2
            $method,    # Compression Method
            $flags,     # Flags
            $time,      # Modification Time
            $extra_flags, # Extra Flags
            $os_code,   # Operating System Code
            ) ;

    # EXTRA
    if ($flags & GZIP_FLG_FEXTRA) {
        my $extra = $param->getValue('extrafield') ;
        $out .= pack("v", length $extra) . $extra ;
    }

    # NAME
    if ($flags & GZIP_FLG_FNAME) {
        my $name .= $param->getValue('name') ;
        $name =~ s/\x00.*$//;
        $out .= $name ;
        # Terminate the filename with NULL unless it already is
        $out .= GZIP_NULL_BYTE 
            if !length $name or
               substr($name, 1, -1) ne GZIP_NULL_BYTE ;
    }

    # COMMENT
    if ($flags & GZIP_FLG_FCOMMENT) {
        my $comment .= $param->getValue('comment') ;
        $comment =~ s/\x00.*$//;
        $out .= $comment ;
        # Terminate the comment with NULL unless it already is
        $out .= GZIP_NULL_BYTE
            if ! length $comment or
               substr($comment, 1, -1) ne GZIP_NULL_BYTE;
    }

    # HEADER CRC
    $out .= pack("v", Compress::Raw::Zlib::crc32($out) & 0x00FF ) 
        if $param->getValue('headercrc') ;

    noUTF8($out);

    return $out ;
}

sub mkFinalTrailer
{
    return '';
}

1; 

__END__

#line 1252

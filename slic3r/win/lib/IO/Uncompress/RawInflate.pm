#line 1 "IO/Uncompress/RawInflate.pm"
package IO::Uncompress::RawInflate ;
# for RFC1951

use strict ;
use warnings;
use bytes;

use Compress::Raw::Zlib  2.074 ;
use IO::Compress::Base::Common  2.074 qw(:Status );

use IO::Uncompress::Base  2.074 ;
use IO::Uncompress::Adapter::Inflate  2.074 ;

require Exporter ;
our ($VERSION, @ISA, @EXPORT_OK, %EXPORT_TAGS, %DEFLATE_CONSTANTS, $RawInflateError);

$VERSION = '2.074';
$RawInflateError = '';

@ISA    = qw(IO::Uncompress::Base Exporter);
@EXPORT_OK = qw( $RawInflateError rawinflate ) ;
%DEFLATE_CONSTANTS = ();
%EXPORT_TAGS = %IO::Uncompress::Base::EXPORT_TAGS ;
push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;
Exporter::export_ok_tags('all');

#{
#    # Execute at runtime  
#    my %bad;
#    for my $module (qw(Compress::Raw::Zlib IO::Compress::Base::Common IO::Uncompress::Base IO::Uncompress::Adapter::Inflate))
#    {
#        my $ver = ${ $module . "::VERSION"} ;
#        
#        $bad{$module} = $ver
#            if $ver ne $VERSION;
#    }
#    
#    if (keys %bad)
#    {
#        my $string = join "\n", map { "$_ $bad{$_}" } keys %bad;
#        die caller(0)[0] . "needs version $VERSION mismatch\n$string\n";
#    }
#}

sub new
{
    my $class = shift ;
    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$RawInflateError);
    $obj->_create(undef, 0, @_);
}

sub rawinflate
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$RawInflateError);
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

    return 1;
}

sub mkUncomp
{
    my $self = shift ;
    my $got = shift ;

    my ($obj, $errstr, $errno) = IO::Uncompress::Adapter::Inflate::mkUncompObject(
                                                                $got->getValue('crc32'),
                                                                $got->getValue('adler32'),
                                                                $got->getValue('scan'),
                                                            );

    return $self->saveErrorString(undef, $errstr, $errno)
        if ! defined $obj;

    *$self->{Uncomp} = $obj;

     my $magic = $self->ckMagic()
        or return 0;

    *$self->{Info} = $self->readHeader($magic)
        or return undef ;

    return 1;

}


sub ckMagic
{
    my $self = shift;

    return $self->_isRaw() ;
}

sub readHeader
{
    my $self = shift;
    my $magic = shift ;

    return {
        'Type'          => 'rfc1951',
        'FingerprintLength'  => 0,
        'HeaderLength'  => 0,
        'TrailerLength' => 0,
        'Header'        => ''
        };
}

sub chkTrailer
{
    return STATUS_OK ;
}

sub _isRaw
{
    my $self   = shift ;

    my $got = $self->_isRawx(@_);

    if ($got) {
        *$self->{Pending} = *$self->{HeaderPending} ;
    }
    else {
        $self->pushBack(*$self->{HeaderPending});
        *$self->{Uncomp}->reset();
    }
    *$self->{HeaderPending} = '';

    return $got ;
}

sub _isRawx
{
    my $self   = shift ;
    my $magic = shift ;

    $magic = '' unless defined $magic ;

    my $buffer = '';

    $self->smartRead(\$buffer, *$self->{BlockSize}) >= 0  
        or return $self->saveErrorString(undef, "No data to read");

    my $temp_buf = $magic . $buffer ;
    *$self->{HeaderPending} = $temp_buf ;    
    $buffer = '';
    my $status = *$self->{Uncomp}->uncompr(\$temp_buf, \$buffer, $self->smartEof()) ;
    
    return $self->saveErrorString(undef, *$self->{Uncomp}{Error}, STATUS_ERROR)
        if $status == STATUS_ERROR;

    $self->pushBack($temp_buf)  ;

    return $self->saveErrorString(undef, "unexpected end of file", STATUS_ERROR)
        if $self->smartEof() && $status != STATUS_ENDSTREAM;
            
    #my $buf_len = *$self->{Uncomp}->uncompressedBytes();
    my $buf_len = length $buffer;

    if ($status == STATUS_ENDSTREAM) {
        if (*$self->{MultiStream} 
                    && (length $temp_buf || ! $self->smartEof())){
            *$self->{NewStream} = 1 ;
            *$self->{EndStream} = 0 ;
        }
        else {
            *$self->{EndStream} = 1 ;
        }
    }
    *$self->{HeaderPending} = $buffer ;    
    *$self->{InflatedBytesRead} = $buf_len ;    
    *$self->{TotalInflatedBytesRead} += $buf_len ;    
    *$self->{Type} = 'rfc1951';

    $self->saveStatus(STATUS_OK);

    return {
        'Type'          => 'rfc1951',
        'HeaderLength'  => 0,
        'TrailerLength' => 0,
        'Header'        => ''
        };
}


sub inflateSync
{
    my $self = shift ;

    # inflateSync is a no-op in Plain mode
    return 1
        if *$self->{Plain} ;

    return 0 if *$self->{Closed} ;
    #return G_EOF if !length *$self->{Pending} && *$self->{EndStream} ;
    return 0 if ! length *$self->{Pending} && *$self->{EndStream} ;

    # Disable CRC check
    *$self->{Strict} = 0 ;

    my $status ;
    while (1)
    {
        my $temp_buf ;

        if (length *$self->{Pending} )
        {
            $temp_buf = *$self->{Pending} ;
            *$self->{Pending} = '';
        }
        else
        {
            $status = $self->smartRead(\$temp_buf, *$self->{BlockSize}) ;
            return $self->saveErrorString(0, "Error Reading Data")
                if $status < 0  ;

            if ($status == 0 ) {
                *$self->{EndStream} = 1 ;
                return $self->saveErrorString(0, "unexpected end of file", STATUS_ERROR);
            }
        }
        
        $status = *$self->{Uncomp}->sync($temp_buf) ;

        if ($status == STATUS_OK)
        {
            *$self->{Pending} .= $temp_buf ;
            return 1 ;
        }

        last unless $status == STATUS_ERROR ;
    }

    return 0;
}

#sub performScan
#{
#    my $self = shift ;
#
#    my $status ;
#    my $end_offset = 0;
#
#    $status = $self->scan() 
#    #or return $self->saveErrorString(undef, "Error Scanning: $$error_ref", $self->errorNo) ;
#        or return $self->saveErrorString(G_ERR, "Error Scanning: $status")
#
#    $status = $self->zap($end_offset) 
#        or return $self->saveErrorString(G_ERR, "Error Zapping: $status");
#    #or return $self->saveErrorString(undef, "Error Zapping: $$error_ref", $self->errorNo) ;
#
#    #(*$obj->{Deflate}, $status) = $inf->createDeflate();
#
##    *$obj->{Header} = *$inf->{Info}{Header};
##    *$obj->{UnCompSize_32bit} = 
##        *$obj->{BytesWritten} = *$inf->{UnCompSize_32bit} ;
##    *$obj->{CompSize_32bit} = *$inf->{CompSize_32bit} ;
#
#
##    if ( $outType eq 'buffer') 
##      { substr( ${ *$self->{Buffer} }, $end_offset) = '' }
##    elsif ($outType eq 'handle' || $outType eq 'filename') {
##        *$self->{FH} = *$inf->{FH} ;
##        delete *$inf->{FH};
##        *$obj->{FH}->flush() ;
##        *$obj->{Handle} = 1 if $outType eq 'handle';
##
##        #seek(*$obj->{FH}, $end_offset, SEEK_SET) 
##        *$obj->{FH}->seek($end_offset, SEEK_SET) 
##            or return $obj->saveErrorString(undef, $!, $!) ;
##    }
#    
#}

sub scan
{
    my $self = shift ;

    return 1 if *$self->{Closed} ;
    return 1 if !length *$self->{Pending} && *$self->{EndStream} ;

    my $buffer = '' ;
    my $len = 0;

    $len = $self->_raw_read(\$buffer, 1) 
        while ! *$self->{EndStream} && $len >= 0 ;

    #return $len if $len < 0 ? $len : 0 ;
    return $len < 0 ? 0 : 1 ;
}

sub zap
{
    my $self  = shift ;

    my $headerLength = *$self->{Info}{HeaderLength};
    my $block_offset =  $headerLength + *$self->{Uncomp}->getLastBlockOffset();
    $_[0] = $headerLength + *$self->{Uncomp}->getEndOffset();
    #printf "# End $_[0], headerlen $headerLength \n";;
    #printf "# block_offset $block_offset %x\n", $block_offset;
    my $byte ;
    ( $self->smartSeek($block_offset) &&
      $self->smartRead(\$byte, 1) ) 
        or return $self->saveErrorString(0, $!, $!); 

    #printf "#byte is %x\n", unpack('C*',$byte);
    *$self->{Uncomp}->resetLastBlockByte($byte);
    #printf "#to byte is %x\n", unpack('C*',$byte);

    ( $self->smartSeek($block_offset) && 
      $self->smartWrite($byte) )
        or return $self->saveErrorString(0, $!, $!); 

    #$self->smartSeek($end_offset, 1);

    return 1 ;
}

sub createDeflate
{
    my $self  = shift ;
    my ($def, $status) = *$self->{Uncomp}->createDeflateStream(
                                    -AppendOutput   => 1,
                                    -WindowBits => - MAX_WBITS,
                                    -CRC32      => *$self->{Params}->getValue('crc32'),
                                    -ADLER32    => *$self->{Params}->getValue('adler32'),
                                );
    
    return wantarray ? ($status, $def) : $def ;                                
}


1; 

__END__


#line 1126

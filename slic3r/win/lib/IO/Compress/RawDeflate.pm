#line 1 "IO/Compress/RawDeflate.pm"
package IO::Compress::RawDeflate ;

# create RFC1951
#
use strict ;
use warnings;
use bytes;

use IO::Compress::Base 2.074 ;
use IO::Compress::Base::Common  2.074 qw(:Status );
use IO::Compress::Adapter::Deflate 2.074 ;

require Exporter ;

our ($VERSION, @ISA, @EXPORT_OK, %DEFLATE_CONSTANTS, %EXPORT_TAGS, $RawDeflateError);

$VERSION = '2.074';
$RawDeflateError = '';

@ISA = qw(IO::Compress::Base Exporter);
@EXPORT_OK = qw( $RawDeflateError rawdeflate ) ;
push @EXPORT_OK, @IO::Compress::Adapter::Deflate::EXPORT_OK ;

%EXPORT_TAGS = %IO::Compress::Adapter::Deflate::DEFLATE_CONSTANTS;


{
    my %seen;
    foreach (keys %EXPORT_TAGS )
    {
        push @{$EXPORT_TAGS{constants}}, 
                 grep { !$seen{$_}++ } 
                 @{ $EXPORT_TAGS{$_} }
    }
    $EXPORT_TAGS{all} = $EXPORT_TAGS{constants} ;
}


%DEFLATE_CONSTANTS = %EXPORT_TAGS;

#push @{ $EXPORT_TAGS{all} }, @EXPORT_OK ;

Exporter::export_ok_tags('all');
              


sub new
{
    my $class = shift ;

    my $obj = IO::Compress::Base::Common::createSelfTiedObject($class, \$RawDeflateError);

    return $obj->_create(undef, @_);
}

sub rawdeflate
{
    my $obj = IO::Compress::Base::Common::createSelfTiedObject(undef, \$RawDeflateError);
    return $obj->_def(@_);
}

sub ckParams
{
    my $self = shift ;
    my $got = shift;

    return 1 ;
}

sub mkComp
{
    my $self = shift ;
    my $got = shift ;

    my ($obj, $errstr, $errno) = IO::Compress::Adapter::Deflate::mkCompObject(
                                                 $got->getValue('crc32'),
                                                 $got->getValue('adler32'),
                                                 $got->getValue('level'),
                                                 $got->getValue('strategy')
                                                 );

   return $self->saveErrorString(undef, $errstr, $errno)
       if ! defined $obj;

   return $obj;    
}


sub mkHeader
{
    my $self = shift ;
    return '';
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

sub getExtraParams
{
    my $self = shift ;
    return getZlibParams();
}

use IO::Compress::Base::Common  2.074 qw(:Parse);
use Compress::Raw::Zlib  2.074 qw(Z_DEFLATED Z_DEFAULT_COMPRESSION Z_DEFAULT_STRATEGY);
our %PARAMS = (
            #'method'   => [IO::Compress::Base::Common::Parse_unsigned,  Z_DEFLATED],
            'level'     => [IO::Compress::Base::Common::Parse_signed,    Z_DEFAULT_COMPRESSION],
            'strategy'  => [IO::Compress::Base::Common::Parse_signed,    Z_DEFAULT_STRATEGY],

            'crc32'     => [IO::Compress::Base::Common::Parse_boolean,   0],
            'adler32'   => [IO::Compress::Base::Common::Parse_boolean,   0],
            'merge'     => [IO::Compress::Base::Common::Parse_boolean,   0], 
        );
        
sub getZlibParams
{
    return %PARAMS;    
}

sub getInverseClass
{
    return ('IO::Uncompress::RawInflate', 
                \$IO::Uncompress::RawInflate::RawInflateError);
}

sub getFileInfo
{
    my $self = shift ;
    my $params = shift;
    my $file = shift ;
    
}

use Fcntl qw(SEEK_SET);

sub createMerge
{
    my $self = shift ;
    my $outValue = shift ;
    my $outType = shift ;

    my ($invClass, $error_ref) = $self->getInverseClass();
    eval "require $invClass" 
        or die "aaaahhhh" ;

    my $inf = $invClass->new( $outValue, 
                             Transparent => 0, 
                             #Strict     => 1,
                             AutoClose   => 0,
                             Scan        => 1)
       or return $self->saveErrorString(undef, "Cannot create InflateScan object: $$error_ref" ) ;

    my $end_offset = 0;
    $inf->scan() 
        or return $self->saveErrorString(undef, "Error Scanning: $$error_ref", $inf->errorNo) ;
    $inf->zap($end_offset) 
        or return $self->saveErrorString(undef, "Error Zapping: $$error_ref", $inf->errorNo) ;

    my $def = *$self->{Compress} = $inf->createDeflate();

    *$self->{Header} = *$inf->{Info}{Header};
    *$self->{UnCompSize} = *$inf->{UnCompSize}->clone();
    *$self->{CompSize} = *$inf->{CompSize}->clone();
    # TODO -- fix this
    #*$self->{CompSize} = new U64(0, *$self->{UnCompSize_32bit});


    if ( $outType eq 'buffer') 
      { substr( ${ *$self->{Buffer} }, $end_offset) = '' }
    elsif ($outType eq 'handle' || $outType eq 'filename') {
        *$self->{FH} = *$inf->{FH} ;
        delete *$inf->{FH};
        *$self->{FH}->flush() ;
        *$self->{Handle} = 1 if $outType eq 'handle';

        #seek(*$self->{FH}, $end_offset, SEEK_SET) 
        *$self->{FH}->seek($end_offset, SEEK_SET) 
            or return $self->saveErrorString(undef, $!, $!) ;
    }

    return $def ;
}

#### zlib specific methods

sub deflateParams 
{
    my $self = shift ;

    my $level = shift ;
    my $strategy = shift ;

    my $status = *$self->{Compress}->deflateParams(Level => $level, Strategy => $strategy) ;
    return $self->saveErrorString(0, *$self->{Compress}{Error}, *$self->{Compress}{ErrorNo})
        if $status == STATUS_ERROR;

    return 1;    
}




1;

__END__

#line 996

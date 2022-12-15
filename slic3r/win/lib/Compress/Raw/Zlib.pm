#line 1 "Compress/Raw/Zlib.pm"

package Compress::Raw::Zlib;

require 5.006 ;
require Exporter;
use Carp ;

use strict ;
use warnings ;
use bytes ;
our ($VERSION, $XS_VERSION, @ISA, @EXPORT, %EXPORT_TAGS, @EXPORT_OK, $AUTOLOAD, %DEFLATE_CONSTANTS, @DEFLATE_CONSTANTS);

$VERSION = '2.074';
$XS_VERSION = $VERSION; 
$VERSION = eval $VERSION;

@ISA = qw(Exporter);
%EXPORT_TAGS = ( flush     => [qw{  
                                    Z_NO_FLUSH
                                    Z_PARTIAL_FLUSH
                                    Z_SYNC_FLUSH
                                    Z_FULL_FLUSH
                                    Z_FINISH
                                    Z_BLOCK
                              }],
                 level     => [qw{  
                                    Z_NO_COMPRESSION
                                    Z_BEST_SPEED
                                    Z_BEST_COMPRESSION
                                    Z_DEFAULT_COMPRESSION
                              }],
                 strategy  => [qw{  
                                    Z_FILTERED
                                    Z_HUFFMAN_ONLY
                                    Z_RLE
                                    Z_FIXED
                                    Z_DEFAULT_STRATEGY
                              }],
                 status   => [qw{  
                                    Z_OK
                                    Z_STREAM_END
                                    Z_NEED_DICT
                                    Z_ERRNO
                                    Z_STREAM_ERROR
                                    Z_DATA_ERROR  
                                    Z_MEM_ERROR   
                                    Z_BUF_ERROR 
                                    Z_VERSION_ERROR 
                              }],                              
              );

%DEFLATE_CONSTANTS = %EXPORT_TAGS;

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.
@DEFLATE_CONSTANTS = 
@EXPORT = qw(
        ZLIB_VERSION
        ZLIB_VERNUM

        
        OS_CODE

        MAX_MEM_LEVEL
        MAX_WBITS

        Z_ASCII
        Z_BEST_COMPRESSION
        Z_BEST_SPEED
        Z_BINARY
        Z_BLOCK
        Z_BUF_ERROR
        Z_DATA_ERROR
        Z_DEFAULT_COMPRESSION
        Z_DEFAULT_STRATEGY
        Z_DEFLATED
        Z_ERRNO
        Z_FILTERED
        Z_FIXED
        Z_FINISH
        Z_FULL_FLUSH
        Z_HUFFMAN_ONLY
        Z_MEM_ERROR
        Z_NEED_DICT
        Z_NO_COMPRESSION
        Z_NO_FLUSH
        Z_NULL
        Z_OK
        Z_PARTIAL_FLUSH
        Z_RLE
        Z_STREAM_END
        Z_STREAM_ERROR
        Z_SYNC_FLUSH
        Z_TREES
        Z_UNKNOWN
        Z_VERSION_ERROR

        WANT_GZIP
        WANT_GZIP_OR_ZLIB
);

push @EXPORT, qw(crc32 adler32 DEF_WBITS);

use constant WANT_GZIP           => 16;
use constant WANT_GZIP_OR_ZLIB   => 32;

sub AUTOLOAD {
    my($constname);
    ($constname = $AUTOLOAD) =~ s/.*:://;
    my ($error, $val) = constant($constname);
    Carp::croak $error if $error;
    no strict 'refs';
    *{$AUTOLOAD} = sub { $val };
    goto &{$AUTOLOAD};
}

use constant FLAG_APPEND             => 1 ;
use constant FLAG_CRC                => 2 ;
use constant FLAG_ADLER              => 4 ;
use constant FLAG_CONSUME_INPUT      => 8 ;
use constant FLAG_LIMIT_OUTPUT       => 16 ;

eval {
    require XSLoader;
    XSLoader::load('Compress::Raw::Zlib', $XS_VERSION);
    1;
} 
or do {
    require DynaLoader;
    local @ISA = qw(DynaLoader);
    bootstrap Compress::Raw::Zlib $XS_VERSION ; 
};
 

use constant Parse_any      => 0x01;
use constant Parse_unsigned => 0x02;
use constant Parse_signed   => 0x04;
use constant Parse_boolean  => 0x08;
#use constant Parse_string   => 0x10;
#use constant Parse_custom   => 0x12;

#use constant Parse_store_ref => 0x100 ;

use constant OFF_PARSED     => 0 ;
use constant OFF_TYPE       => 1 ;
use constant OFF_DEFAULT    => 2 ;
use constant OFF_FIXED      => 3 ;
use constant OFF_FIRST_ONLY => 4 ;
use constant OFF_STICKY     => 5 ;



sub ParseParameters
{
    my $level = shift || 0 ; 

    my $sub = (caller($level + 1))[3] ;
    #local $Carp::CarpLevel = 1 ;
    my $p = new Compress::Raw::Zlib::Parameters() ;
    $p->parse(@_)
        or croak "$sub: $p->{Error}" ;

    return $p;
}


sub Compress::Raw::Zlib::Parameters::new
{
    my $class = shift ;

    my $obj = { Error => '',
                Got   => {},
              } ;

    #return bless $obj, ref($class) || $class || __PACKAGE__ ;
    return bless $obj, 'Compress::Raw::Zlib::Parameters' ;
}

sub Compress::Raw::Zlib::Parameters::setError
{
    my $self = shift ;
    my $error = shift ;
    my $retval = @_ ? shift : undef ;

    $self->{Error} = $error ;
    return $retval;
}
          
#sub getError
#{
#    my $self = shift ;
#    return $self->{Error} ;
#}
          
sub Compress::Raw::Zlib::Parameters::parse
{
    my $self = shift ;

    my $default = shift ;

    my $got = $self->{Got} ;
    my $firstTime = keys %{ $got } == 0 ;

    my (@Bad) ;
    my @entered = () ;

    # Allow the options to be passed as a hash reference or
    # as the complete hash.
    if (@_ == 0) {
        @entered = () ;
    }
    elsif (@_ == 1) {
        my $href = $_[0] ;    
        return $self->setError("Expected even number of parameters, got 1")
            if ! defined $href or ! ref $href or ref $href ne "HASH" ;
 
        foreach my $key (keys %$href) {
            push @entered, $key ;
            push @entered, \$href->{$key} ;
        }
    }
    else {
        my $count = @_;
        return $self->setError("Expected even number of parameters, got $count")
            if $count % 2 != 0 ;
        
        for my $i (0.. $count / 2 - 1) {
            push @entered, $_[2* $i] ;
            push @entered, \$_[2* $i+1] ;
        }
    }


    while (my ($key, $v) = each %$default)
    {
        croak "need 4 params [@$v]"
            if @$v != 4 ;

        my ($first_only, $sticky, $type, $value) = @$v ;
        my $x ;
        $self->_checkType($key, \$value, $type, 0, \$x) 
            or return undef ;

        $key = lc $key;

        if ($firstTime || ! $sticky) {
            $got->{$key} = [0, $type, $value, $x, $first_only, $sticky] ;
        }

        $got->{$key}[OFF_PARSED] = 0 ;
    }

    for my $i (0.. @entered / 2 - 1) {
        my $key = $entered[2* $i] ;
        my $value = $entered[2* $i+1] ;

        #print "Key [$key] Value [$value]" ;
        #print defined $$value ? "[$$value]\n" : "[undef]\n";

        $key =~ s/^-// ;
        my $canonkey = lc $key;
 
        if ($got->{$canonkey} && ($firstTime ||
                                  ! $got->{$canonkey}[OFF_FIRST_ONLY]  ))
        {
            my $type = $got->{$canonkey}[OFF_TYPE] ;
            my $s ;
            $self->_checkType($key, $value, $type, 1, \$s)
                or return undef ;
            #$value = $$value unless $type & Parse_store_ref ;
            $value = $$value ;
            $got->{$canonkey} = [1, $type, $value, $s] ;
        }
        else
          { push (@Bad, $key) }
    }
 
    if (@Bad) {
        my ($bad) = join(", ", @Bad) ;
        return $self->setError("unknown key value(s) @Bad") ;
    }

    return 1;
}

sub Compress::Raw::Zlib::Parameters::_checkType
{
    my $self = shift ;

    my $key   = shift ;
    my $value = shift ;
    my $type  = shift ;
    my $validate  = shift ;
    my $output  = shift;

    #local $Carp::CarpLevel = $level ;
    #print "PARSE $type $key $value $validate $sub\n" ;
#    if ( $type & Parse_store_ref)
#    {
#        #$value = $$value
#        #    if ref ${ $value } ;
#
#        $$output = $value ;
#        return 1;
#    }

    $value = $$value ;

    if ($type & Parse_any)
    {
        $$output = $value ;
        return 1;
    }
    elsif ($type & Parse_unsigned)
    {
        return $self->setError("Parameter '$key' must be an unsigned int, got 'undef'")
            if $validate && ! defined $value ;
        return $self->setError("Parameter '$key' must be an unsigned int, got '$value'")
            if $validate && $value !~ /^\d+$/;

        $$output = defined $value ? $value : 0 ;    
        return 1;
    }
    elsif ($type & Parse_signed)
    {
        return $self->setError("Parameter '$key' must be a signed int, got 'undef'")
            if $validate && ! defined $value ;
        return $self->setError("Parameter '$key' must be a signed int, got '$value'")
            if $validate && $value !~ /^-?\d+$/;

        $$output = defined $value ? $value : 0 ;    
        return 1 ;
    }
    elsif ($type & Parse_boolean)
    {
        return $self->setError("Parameter '$key' must be an int, got '$value'")
            if $validate && defined $value && $value !~ /^\d*$/;
        $$output =  defined $value ? $value != 0 : 0 ;    
        return 1;
    }
#    elsif ($type & Parse_string)
#    {
#        $$output = defined $value ? $value : "" ;    
#        return 1;
#    }

    $$output = $value ;
    return 1;
}



sub Compress::Raw::Zlib::Parameters::parsed
{
    my $self = shift ;
    my $name = shift ;

    return $self->{Got}{lc $name}[OFF_PARSED] ;
}

sub Compress::Raw::Zlib::Parameters::value
{
    my $self = shift ;
    my $name = shift ;

    if (@_)
    {
        $self->{Got}{lc $name}[OFF_PARSED]  = 1;
        $self->{Got}{lc $name}[OFF_DEFAULT] = $_[0] ;
        $self->{Got}{lc $name}[OFF_FIXED]   = $_[0] ;
    }

    return $self->{Got}{lc $name}[OFF_FIXED] ;
}

our $OPTIONS_deflate =   
    {
        'AppendOutput'  => [1, 1, Parse_boolean,  0],
        'CRC32'         => [1, 1, Parse_boolean,  0],
        'ADLER32'       => [1, 1, Parse_boolean,  0],
        'Bufsize'       => [1, 1, Parse_unsigned, 4096],

        'Level'         => [1, 1, Parse_signed,   Z_DEFAULT_COMPRESSION()],
        'Method'        => [1, 1, Parse_unsigned, Z_DEFLATED()],
        'WindowBits'    => [1, 1, Parse_signed,   MAX_WBITS()],
        'MemLevel'      => [1, 1, Parse_unsigned, MAX_MEM_LEVEL()],
        'Strategy'      => [1, 1, Parse_unsigned, Z_DEFAULT_STRATEGY()],
        'Dictionary'    => [1, 1, Parse_any,      ""],
    };

sub Compress::Raw::Zlib::Deflate::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0, $OPTIONS_deflate, @_);

    croak "Compress::Raw::Zlib::Deflate::new: Bufsize must be >= 1, you specified " . 
            $got->value('Bufsize')
        unless $got->value('Bufsize') >= 1;

    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CRC    if $got->value('CRC32') ;
    $flags |= FLAG_ADLER  if $got->value('ADLER32') ;

    my $windowBits =  $got->value('WindowBits');
    $windowBits += MAX_WBITS()
        if ($windowBits & MAX_WBITS()) == 0 ;

    _deflateInit($flags,
                $got->value('Level'), 
                $got->value('Method'), 
                $windowBits, 
                $got->value('MemLevel'), 
                $got->value('Strategy'), 
                $got->value('Bufsize'),
                $got->value('Dictionary')) ;

}

sub Compress::Raw::Zlib::deflateStream::STORABLE_freeze
{
    my $type = ref shift;
    croak "Cannot freeze $type object\n";
}

sub Compress::Raw::Zlib::deflateStream::STORABLE_thaw
{
    my $type = ref shift;
    croak "Cannot thaw $type object\n";
}


our $OPTIONS_inflate = 
    {
        'AppendOutput'  => [1, 1, Parse_boolean,  0],
        'LimitOutput'   => [1, 1, Parse_boolean,  0],
        'CRC32'         => [1, 1, Parse_boolean,  0],
        'ADLER32'       => [1, 1, Parse_boolean,  0],
        'ConsumeInput'  => [1, 1, Parse_boolean,  1],
        'Bufsize'       => [1, 1, Parse_unsigned, 4096],
 
        'WindowBits'    => [1, 1, Parse_signed,   MAX_WBITS()],
        'Dictionary'    => [1, 1, Parse_any,      ""],
    } ;

sub Compress::Raw::Zlib::Inflate::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0, $OPTIONS_inflate, @_);

    croak "Compress::Raw::Zlib::Inflate::new: Bufsize must be >= 1, you specified " . 
            $got->value('Bufsize')
        unless $got->value('Bufsize') >= 1;

    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CRC    if $got->value('CRC32') ;
    $flags |= FLAG_ADLER  if $got->value('ADLER32') ;
    $flags |= FLAG_CONSUME_INPUT if $got->value('ConsumeInput') ;
    $flags |= FLAG_LIMIT_OUTPUT if $got->value('LimitOutput') ;


    my $windowBits =  $got->value('WindowBits');
    $windowBits += MAX_WBITS()
        if ($windowBits & MAX_WBITS()) == 0 ;

    _inflateInit($flags, $windowBits, $got->value('Bufsize'), 
                 $got->value('Dictionary')) ;
}

sub Compress::Raw::Zlib::inflateStream::STORABLE_freeze
{
    my $type = ref shift;
    croak "Cannot freeze $type object\n";
}

sub Compress::Raw::Zlib::inflateStream::STORABLE_thaw
{
    my $type = ref shift;
    croak "Cannot thaw $type object\n";
}

sub Compress::Raw::Zlib::InflateScan::new
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
                    {
                        'CRC32'         => [1, 1, Parse_boolean,  0],
                        'ADLER32'       => [1, 1, Parse_boolean,  0],
                        'Bufsize'       => [1, 1, Parse_unsigned, 4096],
                 
                        'WindowBits'    => [1, 1, Parse_signed,   -MAX_WBITS()],
                        'Dictionary'    => [1, 1, Parse_any,      ""],
            }, @_) ;


    croak "Compress::Raw::Zlib::InflateScan::new: Bufsize must be >= 1, you specified " . 
            $got->value('Bufsize')
        unless $got->value('Bufsize') >= 1;

    my $flags = 0 ;
    #$flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CRC    if $got->value('CRC32') ;
    $flags |= FLAG_ADLER  if $got->value('ADLER32') ;
    #$flags |= FLAG_CONSUME_INPUT if $got->value('ConsumeInput') ;

    _inflateScanInit($flags, $got->value('WindowBits'), $got->value('Bufsize'), 
                 '') ;
}

sub Compress::Raw::Zlib::inflateScanStream::createDeflateStream
{
    my $pkg = shift ;
    my ($got) = ParseParameters(0,
            {
                'AppendOutput'  => [1, 1, Parse_boolean,  0],
                'CRC32'         => [1, 1, Parse_boolean,  0],
                'ADLER32'       => [1, 1, Parse_boolean,  0],
                'Bufsize'       => [1, 1, Parse_unsigned, 4096],
 
                'Level'         => [1, 1, Parse_signed,   Z_DEFAULT_COMPRESSION()],
                'Method'        => [1, 1, Parse_unsigned, Z_DEFLATED()],
                'WindowBits'    => [1, 1, Parse_signed,   - MAX_WBITS()],
                'MemLevel'      => [1, 1, Parse_unsigned, MAX_MEM_LEVEL()],
                'Strategy'      => [1, 1, Parse_unsigned, Z_DEFAULT_STRATEGY()],
            }, @_) ;

    croak "Compress::Raw::Zlib::InflateScan::createDeflateStream: Bufsize must be >= 1, you specified " . 
            $got->value('Bufsize')
        unless $got->value('Bufsize') >= 1;

    my $flags = 0 ;
    $flags |= FLAG_APPEND if $got->value('AppendOutput') ;
    $flags |= FLAG_CRC    if $got->value('CRC32') ;
    $flags |= FLAG_ADLER  if $got->value('ADLER32') ;

    $pkg->_createDeflateStream($flags,
                $got->value('Level'), 
                $got->value('Method'), 
                $got->value('WindowBits'), 
                $got->value('MemLevel'), 
                $got->value('Strategy'), 
                $got->value('Bufsize'),
                ) ;

}

sub Compress::Raw::Zlib::inflateScanStream::inflate
{
    my $self = shift ;
    my $buffer = $_[1];
    my $eof = $_[2];

    my $status = $self->scan(@_);

    if ($status == Z_OK() && $_[2]) {
        my $byte = ' ';
        
        $status = $self->scan(\$byte, $_[1]) ;
    }
    
    return $status ;
}

sub Compress::Raw::Zlib::deflateStream::deflateParams
{
    my $self = shift ;
    my ($got) = ParseParameters(0, {
                'Level'      => [1, 1, Parse_signed,   undef],
                'Strategy'   => [1, 1, Parse_unsigned, undef],
                'Bufsize'    => [1, 1, Parse_unsigned, undef],
                }, 
                @_) ;

    croak "Compress::Raw::Zlib::deflateParams needs Level and/or Strategy"
        unless $got->parsed('Level') + $got->parsed('Strategy') +
            $got->parsed('Bufsize');

    croak "Compress::Raw::Zlib::Inflate::deflateParams: Bufsize must be >= 1, you specified " . 
            $got->value('Bufsize')
        if $got->parsed('Bufsize') && $got->value('Bufsize') <= 1;

    my $flags = 0;
    $flags |= 1 if $got->parsed('Level') ;
    $flags |= 2 if $got->parsed('Strategy') ;
    $flags |= 4 if $got->parsed('Bufsize') ;

    $self->_deflateParams($flags, $got->value('Level'), 
                          $got->value('Strategy'), $got->value('Bufsize'));

}


1;
__END__


#line 1598

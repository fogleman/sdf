#line 1 "File/GlobMapper.pm"
package File::GlobMapper;

use strict;
use warnings;
use Carp;

our ($CSH_GLOB);

BEGIN
{
    if ($] < 5.006)
    { 
        require File::BSDGlob; import File::BSDGlob qw(:glob) ;
        $CSH_GLOB = File::BSDGlob::GLOB_CSH() ;
        *globber = \&File::BSDGlob::csh_glob;
    }  
    else
    { 
        require File::Glob; import File::Glob qw(:glob) ;
        $CSH_GLOB = File::Glob::GLOB_CSH() ;
        #*globber = \&File::Glob::bsd_glob;
        *globber = \&File::Glob::csh_glob;
    }  
}

our ($Error);

our ($VERSION, @EXPORT_OK);
$VERSION = '1.000';
@EXPORT_OK = qw( globmap );


our ($noPreBS, $metachars, $matchMetaRE, %mapping, %wildCount);
$noPreBS = '(?<!\\\)' ; # no preceding backslash
$metachars = '.*?[](){}';
$matchMetaRE = '[' . quotemeta($metachars) . ']';

%mapping = (
                '*' => '([^/]*)',
                '?' => '([^/])',
                '.' => '\.',
                '[' => '([',
                '(' => '(',
                ')' => ')',
           );

%wildCount = map { $_ => 1 } qw/ * ? . { ( [ /;           

sub globmap ($$;)
{
    my $inputGlob = shift ;
    my $outputGlob = shift ;

    my $obj = new File::GlobMapper($inputGlob, $outputGlob, @_)
        or croak "globmap: $Error" ;
    return $obj->getFileMap();
}

sub new
{
    my $class = shift ;
    my $inputGlob = shift ;
    my $outputGlob = shift ;
    # TODO -- flags needs to default to whatever File::Glob does
    my $flags = shift || $CSH_GLOB ;
    #my $flags = shift ;

    $inputGlob =~ s/^\s*\<\s*//;
    $inputGlob =~ s/\s*\>\s*$//;

    $outputGlob =~ s/^\s*\<\s*//;
    $outputGlob =~ s/\s*\>\s*$//;

    my %object =
            (   InputGlob   => $inputGlob,
                OutputGlob  => $outputGlob,
                GlobFlags   => $flags,
                Braces      => 0,
                WildCount   => 0,
                Pairs       => [],
                Sigil       => '#',
            );

    my $self = bless \%object, ref($class) || $class ;

    $self->_parseInputGlob()
        or return undef ;

    $self->_parseOutputGlob()
        or return undef ;
    
    my @inputFiles = globber($self->{InputGlob}, $flags) ;

    if (GLOB_ERROR)
    {
        $Error = $!;
        return undef ;
    }

    #if (whatever)
    {
        my $missing = grep { ! -e $_ } @inputFiles ;

        if ($missing)
        {
            $Error = "$missing input files do not exist";
            return undef ;
        }
    }

    $self->{InputFiles} = \@inputFiles ;

    $self->_getFiles()
        or return undef ;

    return $self;
}

sub _retError
{
    my $string = shift ;
    $Error = "$string in input fileglob" ;
    return undef ;
}

sub _unmatched
{
    my $delimeter = shift ;

    _retError("Unmatched $delimeter");
    return undef ;
}

sub _parseBit
{
    my $self = shift ;

    my $string = shift ;

    my $out = '';
    my $depth = 0 ;

    while ($string =~ s/(.*?)$noPreBS(,|$matchMetaRE)//)
    {
        $out .= quotemeta($1) ;
        $out .= $mapping{$2} if defined $mapping{$2};

        ++ $self->{WildCount} if $wildCount{$2} ;

        if ($2 eq ',')
        { 
            return _unmatched("(")
                if $depth ;
            
            $out .= '|';
        }
        elsif ($2 eq '(')
        { 
            ++ $depth ;
        }
        elsif ($2 eq ')')
        { 
            return _unmatched(")")
                if ! $depth ;

            -- $depth ;
        }
        elsif ($2 eq '[')
        {
            # TODO -- quotemeta & check no '/'
            # TODO -- check for \]  & other \ within the []
            $string =~ s#(.*?\])##
                or return _unmatched("[");
            $out .= "$1)" ;
        }
        elsif ($2 eq ']')
        {
            return _unmatched("]");
        }
        elsif ($2 eq '{' || $2 eq '}')
        {
            return _retError("Nested {} not allowed");
        }
    }

    $out .= quotemeta $string;

    return _unmatched("(")
        if $depth ;

    return $out ;
}

sub _parseInputGlob
{
    my $self = shift ;

    my $string = $self->{InputGlob} ;
    my $inGlob = '';

    # Multiple concatenated *'s don't make sense
    #$string =~ s#\*\*+#*# ;

    # TODO -- Allow space to delimit patterns?
    #my @strings = split /\s+/, $string ;
    #for my $str (@strings)
    my $out = '';
    my $depth = 0 ;

    while ($string =~ s/(.*?)$noPreBS($matchMetaRE)//)
    {
        $out .= quotemeta($1) ;
        $out .= $mapping{$2} if defined $mapping{$2};
        ++ $self->{WildCount} if $wildCount{$2} ;

        if ($2 eq '(')
        { 
            ++ $depth ;
        }
        elsif ($2 eq ')')
        { 
            return _unmatched(")")
                if ! $depth ;

            -- $depth ;
        }
        elsif ($2 eq '[')
        {
            # TODO -- quotemeta & check no '/' or '(' or ')'
            # TODO -- check for \]  & other \ within the []
            $string =~ s#(.*?\])##
                or return _unmatched("[");
            $out .= "$1)" ;
        }
        elsif ($2 eq ']')
        {
            return _unmatched("]");
        }
        elsif ($2 eq '}')
        {
            return _unmatched("}");
        }
        elsif ($2 eq '{')
        {
            # TODO -- check no '/' within the {}
            # TODO -- check for \}  & other \ within the {}

            my $tmp ;
            unless ( $string =~ s/(.*?)$noPreBS\}//)
            {
                return _unmatched("{");
            }
            #$string =~ s#(.*?)\}##;

            #my $alt = join '|', 
            #          map { quotemeta $_ } 
            #          split "$noPreBS,", $1 ;
            my $alt = $self->_parseBit($1);
            defined $alt or return 0 ;
            $out .= "($alt)" ;

            ++ $self->{Braces} ;
        }
    }

    return _unmatched("(")
        if $depth ;

    $out .= quotemeta $string ;


    $self->{InputGlob} =~ s/$noPreBS[\(\)]//g;
    $self->{InputPattern} = $out ;

    #print "# INPUT '$self->{InputGlob}' => '$out'\n";

    return 1 ;

}

sub _parseOutputGlob
{
    my $self = shift ;

    my $string = $self->{OutputGlob} ;
    my $maxwild = $self->{WildCount};

    if ($self->{GlobFlags} & GLOB_TILDE)
    #if (1)
    {
        $string =~ s{
              ^ ~             # find a leading tilde
              (               # save this in $1
                  [^/]        # a non-slash character
                        *     # repeated 0 or more times (0 means me)
              )
            }{
              $1
                  ? (getpwnam($1))[7]
                  : ( $ENV{HOME} || $ENV{LOGDIR} )
            }ex;

    }

    # max #1 must be == to max no of '*' in input
    while ( $string =~ m/#(\d)/g )
    {
        croak "Max wild is #$maxwild, you tried #$1"
            if $1 > $maxwild ;
    }

    my $noPreBS = '(?<!\\\)' ; # no preceding backslash
    #warn "noPreBS = '$noPreBS'\n";

    #$string =~ s/${noPreBS}\$(\d)/\${$1}/g;
    $string =~ s/${noPreBS}#(\d)/\${$1}/g;
    $string =~ s#${noPreBS}\*#\${inFile}#g;
    $string = '"' . $string . '"';

    #print "OUTPUT '$self->{OutputGlob}' => '$string'\n";
    $self->{OutputPattern} = $string ;

    return 1 ;
}

sub _getFiles
{
    my $self = shift ;

    my %outInMapping = ();
    my %inFiles = () ;

    foreach my $inFile (@{ $self->{InputFiles} })
    {
        next if $inFiles{$inFile} ++ ;

        my $outFile = $inFile ;

        if ( $inFile =~ m/$self->{InputPattern}/ )
        {
            no warnings 'uninitialized';
            eval "\$outFile = $self->{OutputPattern};" ;

            if (defined $outInMapping{$outFile})
            {
                $Error =  "multiple input files map to one output file";
                return undef ;
            }
            $outInMapping{$outFile} = $inFile;
            push @{ $self->{Pairs} }, [$inFile, $outFile];
        }
    }

    return 1 ;
}

sub getFileMap
{
    my $self = shift ;

    return $self->{Pairs} ;
}

sub getHash
{
    my $self = shift ;

    return { map { $_->[0] => $_->[1] } @{ $self->{Pairs} } } ;
}

1;

__END__

#line 680
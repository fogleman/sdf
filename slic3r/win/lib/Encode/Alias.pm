#line 1 "Encode/Alias.pm"
package Encode::Alias;
use strict;
use warnings;
no warnings 'redefine';
our $VERSION = do { my @r = ( q$Revision: 2.21 $ =~ /\d+/g ); sprintf "%d." . "%02d" x $#r, @r };
use constant DEBUG => !!$ENV{PERL_ENCODE_DEBUG};

use Exporter 'import';

# Public, encouraged API is exported by default

our @EXPORT =
  qw (
  define_alias
  find_alias
);

our @Alias;    # ordered matching list
our %Alias;    # cached known aliases

sub find_alias {
    require Encode;
    my $class = shift;
    my $find  = shift;
    unless ( exists $Alias{$find} ) {
        $Alias{$find} = undef;    # Recursion guard
        for ( my $i = 0 ; $i < @Alias ; $i += 2 ) {
            my $alias = $Alias[$i];
            my $val   = $Alias[ $i + 1 ];
            my $new;
            if ( ref($alias) eq 'Regexp' && $find =~ $alias ) {
                DEBUG and warn "eval $val";
                $new = eval $val;
                DEBUG and $@ and warn "$val, $@";
            }
            elsif ( ref($alias) eq 'CODE' ) {
                DEBUG and warn "$alias", "->", "($find)";
                $new = $alias->($find);
            }
            elsif ( lc($find) eq lc($alias) ) {
                $new = $val;
            }
            if ( defined($new) ) {
                next if $new eq $find;    # avoid (direct) recursion on bugs
                DEBUG and warn "$alias, $new";
                my $enc =
                  ( ref($new) ) ? $new : Encode::find_encoding($new);
                if ($enc) {
                    $Alias{$find} = $enc;
                    last;
                }
            }
        }

        # case insensitive search when canonical is not in all lowercase
        # RT ticket #7835
        unless ( $Alias{$find} ) {
            my $lcfind = lc($find);
            for my $name ( keys %Encode::Encoding, keys %Encode::ExtModule )
            {
                $lcfind eq lc($name) or next;
                $Alias{$find} = Encode::find_encoding($name);
                DEBUG and warn "$find => $name";
            }
        }
    }
    if (DEBUG) {
        my $name;
        if ( my $e = $Alias{$find} ) {
            $name = $e->name;
        }
        else {
            $name = "";
        }
        warn "find_alias($class, $find)->name = $name";
    }
    return $Alias{$find};
}

sub define_alias {
    while (@_) {
        my $alias = shift;
        my $name = shift;
        unshift( @Alias, $alias => $name )    # newer one has precedence
            if defined $alias;
        if ( ref($alias) ) {

            # clear %Alias cache to allow overrides
            my @a = keys %Alias;
            for my $k (@a) {
                if ( ref($alias) eq 'Regexp' && $k =~ $alias ) {
                    DEBUG and warn "delete \$Alias\{$k\}";
                    delete $Alias{$k};
                }
                elsif ( ref($alias) eq 'CODE' && $alias->($k) ) {
                    DEBUG and warn "delete \$Alias\{$k\}";
                    delete $Alias{$k};
                }
            }
        }
        elsif (defined $alias) {
            DEBUG and warn "delete \$Alias\{$alias\}";
            delete $Alias{$alias};
        }
        elsif (DEBUG) {
            require Carp;
            Carp::croak("undef \$alias");
        }
    }
}

# Allow latin-1 style names as well
# 0  1  2  3  4  5   6   7   8   9  10
our @Latin2iso = ( 0, 1, 2, 3, 4, 9, 10, 13, 14, 15, 16 );

# Allow winlatin1 style names as well
our %Winlatin2cp = (
    'latin1'     => 1252,
    'latin2'     => 1250,
    'cyrillic'   => 1251,
    'greek'      => 1253,
    'turkish'    => 1254,
    'hebrew'     => 1255,
    'arabic'     => 1256,
    'baltic'     => 1257,
    'vietnamese' => 1258,
);

init_aliases();

sub undef_aliases {
    @Alias = ();
    %Alias = ();
}

sub init_aliases {
    require Encode;
    undef_aliases();

    # Try all-lower-case version should all else fails
    define_alias( qr/^(.*)$/ => '"\L$1"' );

    # UTF/UCS stuff
    define_alias( qr/^(unicode-1-1-)?UTF-?7$/i     => '"UTF-7"' );
    define_alias( qr/^UCS-?2-?LE$/i => '"UCS-2LE"' );
    define_alias(
        qr/^UCS-?2-?(BE)?$/i    => '"UCS-2BE"',
        qr/^UCS-?4-?(BE|LE|)?$/i => 'uc("UTF-32$1")',
        qr/^iso-10646-1$/i      => '"UCS-2BE"'
    );
    define_alias(
        qr/^UTF-?(16|32)-?BE$/i => '"UTF-$1BE"',
        qr/^UTF-?(16|32)-?LE$/i => '"UTF-$1LE"',
        qr/^UTF-?(16|32)$/i     => '"UTF-$1"',
    );

    # ASCII
    define_alias( qr/^(?:US-?)ascii$/i       => '"ascii"' );
    define_alias( 'C'                        => 'ascii' );
    define_alias( qr/\b(?:ISO[-_]?)?646(?:[-_]?US)?$/i => '"ascii"' );

    # Allow variants of iso-8859-1 etc.
    define_alias( qr/\biso[-_]?(\d+)[-_](\d+)$/i => '"iso-$1-$2"' );

    # At least HP-UX has these.
    define_alias( qr/\biso8859(\d+)$/i => '"iso-8859-$1"' );

    # More HP stuff.
    define_alias(
        qr/\b(?:hp-)?(arabic|greek|hebrew|kana|roman|thai|turkish)8$/i =>
          '"${1}8"' );

    # The Official name of ASCII.
    define_alias( qr/\bANSI[-_]?X3\.4[-_]?1968$/i => '"ascii"' );

    # This is a font issue, not an encoding issue.
    # (The currency symbol of the Latin 1 upper half
    #  has been redefined as the euro symbol.)
    define_alias( qr/^(.+)\@euro$/i => '"$1"' );

    define_alias( qr/\b(?:iso[-_]?)?latin[-_]?(\d+)$/i =>
'defined $Encode::Alias::Latin2iso[$1] ? "iso-8859-$Encode::Alias::Latin2iso[$1]" : undef'
    );

    define_alias(
        qr/\bwin(latin[12]|cyrillic|baltic|greek|turkish|
             hebrew|arabic|baltic|vietnamese)$/ix =>
          '"cp" . $Encode::Alias::Winlatin2cp{lc($1)}'
    );

    # Common names for non-latin preferred MIME names
    define_alias(
        'ascii'    => 'US-ascii',
        'cyrillic' => 'iso-8859-5',
        'arabic'   => 'iso-8859-6',
        'greek'    => 'iso-8859-7',
        'hebrew'   => 'iso-8859-8',
        'thai'     => 'iso-8859-11',
    );
    # RT #20781
    define_alias(qr/\btis-?620\b/i  => '"iso-8859-11"');

    # At least AIX has IBM-NNN (surprisingly...) instead of cpNNN.
    # And Microsoft has their own naming (again, surprisingly).
    # And windows-* is registered in IANA!
    define_alias(
        qr/\b(?:cp|ibm|ms|windows)[-_ ]?(\d{2,4})$/i => '"cp$1"' );

    # Sometimes seen with a leading zero.
    # define_alias( qr/\bcp037\b/i => '"cp37"');

    # Mac Mappings
    # predefined in *.ucm; unneeded
    # define_alias( qr/\bmacIcelandic$/i => '"macIceland"');
    define_alias( qr/^(?:x[_-])?mac[_-](.*)$/i => '"mac$1"' );
    # http://rt.cpan.org/Ticket/Display.html?id=36326
    define_alias( qr/^macintosh$/i => '"MacRoman"' );
    # https://rt.cpan.org/Ticket/Display.html?id=78125
    define_alias( qr/^macce$/i => '"MacCentralEurRoman"' );
    # Ououououou. gone.  They are different!
    # define_alias( qr/\bmacRomanian$/i => '"macRumanian"');

    # Standardize on the dashed versions.
    define_alias( qr/\bkoi8[\s\-_]*([ru])$/i => '"koi8-$1"' );

    unless ($Encode::ON_EBCDIC) {

        # for Encode::CN
        define_alias( qr/\beuc.*cn$/i => '"euc-cn"' );
        define_alias( qr/\bcn.*euc$/i => '"euc-cn"' );

        # define_alias( qr/\bGB[- ]?(\d+)$/i => '"euc-cn"' )
        # CP936 doesn't have vendor-addon for GBK, so they're identical.
        define_alias( qr/^gbk$/i => '"cp936"' );

        # This fixes gb2312 vs. euc-cn confusion, practically
        define_alias( qr/\bGB[-_ ]?2312(?!-?raw)/i => '"euc-cn"' );

        # for Encode::JP
        define_alias( qr/\bjis$/i         => '"7bit-jis"' );
        define_alias( qr/\beuc.*jp$/i     => '"euc-jp"' );
        define_alias( qr/\bjp.*euc$/i     => '"euc-jp"' );
        define_alias( qr/\bujis$/i        => '"euc-jp"' );
        define_alias( qr/\bshift.*jis$/i  => '"shiftjis"' );
        define_alias( qr/\bsjis$/i        => '"shiftjis"' );
        define_alias( qr/\bwindows-31j$/i => '"cp932"' );

        # for Encode::KR
        define_alias( qr/\beuc.*kr$/i => '"euc-kr"' );
        define_alias( qr/\bkr.*euc$/i => '"euc-kr"' );

        # This fixes ksc5601 vs. euc-kr confusion, practically
        define_alias( qr/(?:x-)?uhc$/i         => '"cp949"' );
        define_alias( qr/(?:x-)?windows-949$/i => '"cp949"' );
        define_alias( qr/\bks_c_5601-1987$/i   => '"cp949"' );

        # for Encode::TW
        define_alias( qr/\bbig-?5$/i              => '"big5-eten"' );
        define_alias( qr/\bbig5-?et(?:en)?$/i     => '"big5-eten"' );
        define_alias( qr/\btca[-_]?big5$/i        => '"big5-eten"' );
        define_alias( qr/\bbig5-?hk(?:scs)?$/i    => '"big5-hkscs"' );
        define_alias( qr/\bhk(?:scs)?[-_]?big5$/i => '"big5-hkscs"' );
    }

    # https://github.com/dankogai/p5-encode/issues/37
    define_alias(qr/cp65000/i => '"UTF-7"');
    define_alias(qr/cp65001/i => '"utf-8-strict"');

    # utf8 is blessed :)
    define_alias( qr/\bUTF-8$/i => '"utf-8-strict"' );

    # At last, Map white space and _ to '-'
    define_alias( qr/^(\S+)[\s_]+(.*)$/i => '"$1-$2"' );
}

1;
__END__

# TODO: HP-UX '8' encodings arabic8 greek8 hebrew8 kana8 thai8 turkish8
# TODO: HP-UX '15' encodings japanese15 korean15 roi15
# TODO: Cyrillic encoding ISO-IR-111 (useful?)
# TODO: Armenian encoding ARMSCII-8
# TODO: Hebrew encoding ISO-8859-8-1
# TODO: Thai encoding TCVN
# TODO: Vietnamese encodings VPS
# TODO: Mac Asian+African encodings: Arabic Armenian Bengali Burmese
#       ChineseSimp ChineseTrad Devanagari Ethiopic ExtArabic
#       Farsi Georgian Gujarati Gurmukhi Hebrew Japanese
#       Kannada Khmer Korean Laotian Malayalam Mongolian
#       Oriya Sinhalese Symbol Tamil Telugu Tibetan Vietnamese

#line 395


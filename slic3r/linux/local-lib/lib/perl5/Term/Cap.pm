#line 1 "Term/Cap.pm"
package Term::Cap;

# Since the debugger uses Term::ReadLine which uses Term::Cap, we want
# to load as few modules as possible.  This includes Carp.pm.
sub carp
{
    require Carp;
    goto &Carp::carp;
}

sub croak
{
    require Carp;
    goto &Carp::croak;
}

use strict;

use vars qw($VERSION $VMS_TERMCAP);
use vars qw($termpat $state $first $entry);

$VERSION = '1.17';

# TODO:
# support Berkeley DB termcaps
# force $FH into callers package?
# keep $FH in object at Tgetent time?

#line 63

# Preload the default VMS termcap.
# If a different termcap is required then the text of one can be supplied
# in $Term::Cap::VMS_TERMCAP before Tgetent is called.

if ( $^O eq 'VMS' )
{
    chomp( my @entry = <DATA> );
    $VMS_TERMCAP = join '', @entry;
}

# Returns a list of termcap files to check.

sub termcap_path
{    ## private
    my @termcap_path;

    # $TERMCAP, if it's a filespec
    push( @termcap_path, $ENV{TERMCAP} )
      if (
        ( exists $ENV{TERMCAP} )
        && (
            ( $^O eq 'os2' || $^O eq 'MSWin32' || $^O eq 'dos' )
            ? $ENV{TERMCAP} =~ /^[a-z]:[\\\/]/is
            : $ENV{TERMCAP} =~ /^\//s
        )
      );
    if ( ( exists $ENV{TERMPATH} ) && ( $ENV{TERMPATH} ) )
    {

        # Add the users $TERMPATH
        push( @termcap_path, split( /(:|\s+)/, $ENV{TERMPATH} ) );
    }
    else
    {

        # Defaults
        push( @termcap_path,
            exists $ENV{'HOME'} ? $ENV{'HOME'} . '/.termcap' : undef,
            '/etc/termcap', '/usr/share/misc/termcap', );
    }

    # return the list of those termcaps that exist
    return grep { defined $_ && -f $_ } @termcap_path;
}

#line 164

sub Tgetent
{    ## public -- static method
    my $class = shift;
    my ($self) = @_;

    $self = {} unless defined $self;
    bless $self, $class;

    my ( $term, $cap, $search, $field, $max, $tmp_term, $TERMCAP );
    local ( $termpat, $state, $first, $entry );    # used inside eval
    local $_;

    # Compute PADDING factor from OSPEED (to be used by Tpad)
    if ( !$self->{OSPEED} )
    {
        if ($^W)
        {
            carp "OSPEED was not set, defaulting to 9600";
        }
        $self->{OSPEED} = 9600;
    }
    if ( $self->{OSPEED} < 16 )
    {

        # delays for old style speeds
        my @pad = (
            0,    200, 133.3, 90.9, 74.3, 66.7, 50, 33.3,
            16.7, 8.3, 5.5,   4.1,  2,    1,    .5, .2
        );
        $self->{PADDING} = $pad[ $self->{OSPEED} ];
    }
    else
    {
        $self->{PADDING} = 10000 / $self->{OSPEED};
    }

    unless ( $self->{TERM} )
    {
       if ( $ENV{TERM} )
       {
         $self->{TERM} =  $ENV{TERM} ;
       }
       else
       {
          if ( $^O eq 'MSWin32' )
          {
             $self->{TERM} =  'dumb';
          }
          else
          {
             croak "TERM not set";
          }
       }
    }

    $term = $self->{TERM};    # $term is the term type we are looking for

    # $tmp_term is always the next term (possibly :tc=...:) we are looking for
    $tmp_term = $self->{TERM};

    # protect any pattern metacharacters in $tmp_term
    $termpat = $tmp_term;
    $termpat =~ s/(\W)/\\$1/g;

    my $foo = ( exists $ENV{TERMCAP} ? $ENV{TERMCAP} : '' );

    # $entry is the extracted termcap entry
    if ( ( $foo !~ m:^/:s ) && ( $foo =~ m/(^|\|)${termpat}[:|]/s ) )
    {
        $entry = $foo;
    }

    my @termcap_path = termcap_path();

    if ( !@termcap_path && !$entry )
    {

        # last resort--fake up a termcap from terminfo
        local $ENV{TERM} = $term;

        if ( $^O eq 'VMS' )
        {
            $entry = $VMS_TERMCAP;
        }
        else
        {
            if ( grep { -x "$_/infocmp" } split /:/, $ENV{PATH} )
            {
                eval {
                    my $tmp = `infocmp -C 2>/dev/null`;
                    $tmp =~ s/^#.*\n//gm;    # remove comments
                    if (   ( $tmp !~ m%^/%s )
                        && ( $tmp =~ /(^|\|)${termpat}[:|]/s ) )
                    {
                        $entry = $tmp;
                    }
                };
                warn "Can't run infocmp to get a termcap entry: $@" if $@;
            }
            else
            {
               # this is getting desperate now
               if ( $self->{TERM} eq 'dumb' )
               {
                  $entry = 'dumb|80-column dumb tty::am::co#80::bl=^G:cr=^M:do=^J:sf=^J:';
               }
            }
        }
    }

    croak "Can't find a valid termcap file" unless @termcap_path || $entry;

    $state = 1;    # 0 == finished
                   # 1 == next file
                   # 2 == search again

    $first = 0;    # first entry (keeps term name)

    $max = 32;     # max :tc=...:'s

    if ($entry)
    {

        # ok, we're starting with $TERMCAP
        $first++;    # we're the first entry
                     # do we need to continue?
        if ( $entry =~ s/:tc=([^:]+):/:/ )
        {
            $tmp_term = $1;

            # protect any pattern metacharacters in $tmp_term
            $termpat = $tmp_term;
            $termpat =~ s/(\W)/\\$1/g;
        }
        else
        {
            $state = 0;    # we're already finished
        }
    }

    # This is eval'ed inside the while loop for each file
    $search = q{
	while (<TERMCAP>) {
	    next if /^\\t/ || /^#/;
	    if ($_ =~ m/(^|\\|)${termpat}[:|]/o) {
		chomp;
		s/^[^:]*:// if $first++;
		$state = 0;
		while ($_ =~ s/\\\\$//) {
		    defined(my $x = <TERMCAP>) or last;
		    $_ .= $x; chomp;
		}
		last;
	    }
	}
	defined $entry or $entry = '';
	$entry .= $_ if $_;
    };

    while ( $state != 0 )
    {
        if ( $state == 1 )
        {

            # get the next TERMCAP
            $TERMCAP = shift @termcap_path
              || croak "failed termcap lookup on $tmp_term";
        }
        else
        {

            # do the same file again
            # prevent endless recursion
            $max-- || croak "failed termcap loop at $tmp_term";
            $state = 1;    # ok, maybe do a new file next time
        }

        open( TERMCAP, "< $TERMCAP\0" ) || croak "open $TERMCAP: $!";
        eval $search;
        die $@ if $@;
        close TERMCAP;

        # If :tc=...: found then search this file again
        $entry =~ s/:tc=([^:]+):/:/ && ( $tmp_term = $1, $state = 2 );

        # protect any pattern metacharacters in $tmp_term
        $termpat = $tmp_term;
        $termpat =~ s/(\W)/\\$1/g;
    }

    croak "Can't find $term" if $entry eq '';
    $entry =~ s/:+\s*:+/:/g;    # cleanup $entry
    $entry =~ s/:+/:/g;         # cleanup $entry
    $self->{TERMCAP} = $entry;  # save it
                                # print STDERR "DEBUG: $entry = ", $entry, "\n";

    # Precompile $entry into the object
    $entry =~ s/^[^:]*://;
    foreach $field ( split( /:[\s:\\]*/, $entry ) )
    {
        if ( defined $field && $field =~ /^(\w{2,})$/ )
        {
            $self->{ '_' . $field } = 1 unless defined $self->{ '_' . $1 };

            # print STDERR "DEBUG: flag $1\n";
        }
        elsif ( defined $field && $field =~ /^(\w{2,})\@/ )
        {
            $self->{ '_' . $1 } = "";

            # print STDERR "DEBUG: unset $1\n";
        }
        elsif ( defined $field && $field =~ /^(\w{2,})#(.*)/ )
        {
            $self->{ '_' . $1 } = $2 unless defined $self->{ '_' . $1 };

            # print STDERR "DEBUG: numeric $1 = $2\n";
        }
        elsif ( defined $field && $field =~ /^(\w{2,})=(.*)/ )
        {

            # print STDERR "DEBUG: string $1 = $2\n";
            next if defined $self->{ '_' . ( $cap = $1 ) };
            $_ = $2;
            if ( ord('A') == 193 )
            {
               s/\\E/\047/g;
               s/\\(\d\d\d)/pack('c',oct($1) & 0177)/eg;
               s/\\n/\n/g;
               s/\\r/\r/g;
               s/\\t/\t/g;
               s/\\b/\b/g;
               s/\\f/\f/g;
               s/\\\^/\337/g;
               s/\^\?/\007/g;
               s/\^(.)/pack('c',ord($1) & 31)/eg;
               s/\\(.)/$1/g;
               s/\337/^/g;
            }
            else
            {
               s/\\E/\033/g;
               s/\\(\d\d\d)/pack('c',oct($1) & 0177)/eg;
               s/\\n/\n/g;
               s/\\r/\r/g;
               s/\\t/\t/g;
               s/\\b/\b/g;
               s/\\f/\f/g;
               s/\\\^/\377/g;
               s/\^\?/\177/g;
               s/\^(.)/pack('c',ord($1) & 31)/eg;
               s/\\(.)/$1/g;
               s/\377/^/g;
            }
            $self->{ '_' . $cap } = $_;
        }

        # else { carp "junk in $term ignored: $field"; }
    }
    $self->{'_pc'} = "\0" unless defined $self->{'_pc'};
    $self->{'_bc'} = "\b" unless defined $self->{'_bc'};
    $self;
}

# $terminal->Tpad($string, $cnt, $FH);

#line 459

sub Tpad
{    ## public
    my $self = shift;
    my ( $string, $cnt, $FH ) = @_;
    my ( $decr, $ms );

    if ( defined $string && $string =~ /(^[\d.]+)(\*?)(.*)$/ )
    {
        $ms = $1;
        $ms *= $cnt if $2;
        $string = $3;
        $decr   = $self->{PADDING};
        if ( $decr > .1 )
        {
            $ms += $decr / 2;
            $string .= $self->{'_pc'} x ( $ms / $decr );
        }
    }
    print $FH $string if $FH;
    $string;
}

# $terminal->Tputs($cap, $cnt, $FH);

#line 511

sub Tputs
{    ## public
    my $self = shift;
    my ( $cap, $cnt, $FH ) = @_;
    my $string;

    $cnt = 0 unless $cnt;

    if ( $cnt > 1 )
    {
        $string = Tpad( $self, $self->{ '_' . $cap }, $cnt );
    }
    else
    {

        # cache result because Tpad can be slow
        unless ( exists $self->{$cap} )
        {
            $self->{$cap} =
              exists $self->{"_$cap"}
              ? Tpad( $self, $self->{"_$cap"}, 1 )
              : undef;
        }
        $string = $self->{$cap};
    }
    print $FH $string if $FH;
    $string;
}

# $terminal->Tgoto($cap, $col, $row, $FH);

#line 593

sub Tgoto
{    ## public
    my $self = shift;
    my ( $cap, $code, $tmp, $FH ) = @_;
    my $string = $self->{ '_' . $cap };
    my $result = '';
    my $after  = '';
    my $online = 0;
    my @tmp    = ( $tmp, $code );
    my $cnt    = $code;

    while ( $string =~ /^([^%]*)%(.)(.*)/ )
    {
        $result .= $1;
        $code   = $2;
        $string = $3;
        if ( $code eq 'd' )
        {
            $result .= sprintf( "%d", shift(@tmp) );
        }
        elsif ( $code eq '.' )
        {
            $tmp = shift(@tmp);
            if ( $tmp == 0 || $tmp == 4 || $tmp == 10 )
            {
                if ($online)
                {
                    ++$tmp, $after .= $self->{'_up'} if $self->{'_up'};
                }
                else
                {
                    ++$tmp, $after .= $self->{'_bc'};
                }
            }
            $result .= sprintf( "%c", $tmp );
            $online = !$online;
        }
        elsif ( $code eq '+' )
        {
            $result .= sprintf( "%c", shift(@tmp) + ord($string) );
            $string = substr( $string, 1, 99 );
            $online = !$online;
        }
        elsif ( $code eq 'r' )
        {
            ( $code, $tmp ) = @tmp;
            @tmp = ( $tmp, $code );
            $online = !$online;
        }
        elsif ( $code eq '>' )
        {
            ( $code, $tmp, $string ) = unpack( "CCa99", $string );
            if ( $tmp[0] > $code )
            {
                $tmp[0] += $tmp;
            }
        }
        elsif ( $code eq '2' )
        {
            $result .= sprintf( "%02d", shift(@tmp) );
            $online = !$online;
        }
        elsif ( $code eq '3' )
        {
            $result .= sprintf( "%03d", shift(@tmp) );
            $online = !$online;
        }
        elsif ( $code eq 'i' )
        {
            ( $code, $tmp ) = @tmp;
            @tmp = ( $code + 1, $tmp + 1 );
        }
        else
        {
            return "OOPS";
        }
    }
    $string = Tpad( $self, $result . $string . $after, $cnt );
    print $FH $string if $FH;
    $string;
}

# $terminal->Trequire(qw/ce ku kd/);

#line 684

sub Trequire
{    ## public
    my $self = shift;
    my ( $cap, @undefined );
    foreach $cap (@_)
    {
        push( @undefined, $cap )
          unless defined $self->{ '_' . $cap } && $self->{ '_' . $cap };
    }
    croak "Terminal does not support: (@undefined)" if @undefined;
}

#line 751

# Below is a default entry for systems where there are terminals but no
# termcap
1;
__DATA__
vt220|vt200|DEC VT220 in vt100 emulation mode:
am:mi:xn:xo:
co#80:li#24:
RA=\E[?7l:SA=\E[?7h:
ac=kkllmmjjnnwwqquuttvvxx:ae=\E(B:al=\E[L:as=\E(0:
bl=^G:cd=\E[J:ce=\E[K:cl=\E[H\E[2J:cm=\E[%i%d;%dH:
cr=^M:cs=\E[%i%d;%dr:dc=\E[P:dl=\E[M:do=\E[B:
ei=\E[4l:ho=\E[H:im=\E[4h:
is=\E[1;24r\E[24;1H:
nd=\E[C:
kd=\E[B::kl=\E[D:kr=\E[C:ku=\E[A:le=^H:
mb=\E[5m:md=\E[1m:me=\E[m:mr=\E[7m:
kb=\0177:
r2=\E>\E[24;1H\E[?3l\E[?4l\E[?5l\E[?7h\E[?8h\E=:rc=\E8:
sc=\E7:se=\E[27m:sf=\ED:so=\E[7m:sr=\EM:ta=^I:
ue=\E[24m:up=\E[A:us=\E[4m:ve=\E[?25h:vi=\E[?25l:


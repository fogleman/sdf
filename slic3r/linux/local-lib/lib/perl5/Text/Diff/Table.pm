package Text::Diff::Table;

use 5.006;
use strict;
use warnings;
use Carp;
use Text::Diff::Config;

our $VERSION   = '1.44';
our @ISA       = qw( Text::Diff::Base Exporter );
our @EXPORT_OK = qw( expand_tabs );

my %escapes = map {
    my $c =
        $_ eq '"' || $_ eq '$' ? qq{'$_'}
    : $_ eq "\\"           ? qq{"\\\\"}
                           : qq{"$_"};
    ( ord eval $c => $_ )
} (
    map( chr, 32..126),
    map( sprintf( "\\x%02x", $_ ), ( 0..31, 127..255 ) ),
#    map( "\\c$_", "A".."Z"),
    "\\t", "\\n", "\\r", "\\f", "\\b", "\\a", "\\e"
    ## NOTE: "\\\\" is not here because some things are explicitly
    ## escaped before escape() is called and we don't want to
    ## double-escape "\".  Also, in most texts, leaving "\" more
    ## readable makes sense.
);

sub expand_tabs($) {
    my $s     = shift;
    my $count = 0;
    $s =~ s{(\t)(\t*)|([^\t]+)}{
         if ( $1 ) {
             my $spaces = " " x ( 8 - $count % 8  + 8 * length $2 );
             $count = 0;
             $spaces;
     }
     else {
         $count += length $3;
         $3;
    }
    }ge;

    return $s;
}

sub trim_trailing_line_ends($) {
    my $s = shift;
    $s =~ s/[\r\n]+(?!\n)$//;
    return $s;
}

sub escape($);

SCOPE: {
   ## use utf8 if available.  don't if not.
   my $escaper = <<'EOCODE';
      sub escape($) {
      use utf8;
      join "", map {
          my $c = $_;
          $_ = ord;
          exists $escapes{$_}
          ? $escapes{$_}
          : $Text::Diff::Config::Output_Unicode 
          ? $c
          : sprintf( "\\x{%04x}", $_ );
      } split //, shift;
      }

      1;
EOCODE
   unless ( eval $escaper ) {
       $escaper =~ s/ *use *utf8 *;\n// or die "Can't drop use utf8;";
       eval $escaper or die $@;
   }
}

sub new {
    my $proto = shift;
    return bless { @_ }, $proto
}

my $missing_elt = [ "", "" ];

sub hunk {
    my $self    = shift;
    my @seqs    = ( shift, shift );
    my $ops     = shift;  ## Leave sequences in @_[0,1]
    my $options = shift;

    my ( @A, @B );
    for ( @$ops ) {
        my $opcode = $_->[Text::Diff::OPCODE()];
        if ( $opcode eq " " ) {
            push @A, $missing_elt while @A < @B;
            push @B, $missing_elt while @B < @A;
        }
        push @A, [ $_->[0] + ( $options->{OFFSET_A} || 0), $seqs[0][$_->[0]] ]
            if $opcode eq " " || $opcode eq "-";
        push @B, [ $_->[1] + ( $options->{OFFSET_B} || 0), $seqs[1][$_->[1]] ]
            if $opcode eq " " || $opcode eq "+";
    }

    push @A, $missing_elt while @A < @B;
    push @B, $missing_elt while @B < @A;
    my @elts;
    for ( 0..$#A ) {
        my ( $A, $B ) = (shift @A, shift @B );
        
        ## Do minimal cleaning on identical elts so these look "normal":
        ## tabs are expanded, trailing newelts removed, etc.  For differing
        ## elts, make invisible characters visible if the invisible characters
        ## differ.
        my $elt_type =  $B == $missing_elt ? "A" :
                        $A == $missing_elt ? "B" :
                        $A->[1] eq $B->[1]  ? "="
                                            : "*";
        if ( $elt_type ne "*" ) {
        if ( $elt_type eq "=" || $A->[1] =~ /\S/ || $B->[1] =~ /\S/ ) {
        $A->[1] = escape trim_trailing_line_ends expand_tabs $A->[1];
        $B->[1] = escape trim_trailing_line_ends expand_tabs $B->[1];
        }
        else {
        $A->[1] = escape $A->[1];
        $B->[1] = escape $B->[1];
        }
        }
        else {
            ## not using \z here for backcompat reasons.
            $A->[1] =~ /^(\s*?)([^ \t].*?)?(\s*)(?![\n\r])$/s;
            my ( $l_ws_A, $body_A, $t_ws_A ) = ( $1, $2, $3 );
        $body_A = "" unless defined $body_A;
            $B->[1] =~ /^(\s*?)([^ \t].*?)?(\s*)(?![\n\r])$/s;
            my ( $l_ws_B, $body_B, $t_ws_B ) = ( $1, $2, $3 );
        $body_B = "" unless defined $body_B;

            my $added_escapes;

            if ( $l_ws_A ne $l_ws_B ) {
                ## Make leading tabs visible.  Other non-' ' chars
                ## will be dealt with in escape(), but this prevents
                ## tab expansion from hiding tabs by making them
                ## look like ' '.
                $added_escapes = 1 if $l_ws_A =~ s/\t/\\t/g;
                $added_escapes = 1 if $l_ws_B =~ s/\t/\\t/g;
            }

            if ( $t_ws_A ne $t_ws_B ) {
                ## Only trailing whitespace gets the \s treatment
                ## to make it obvious what's going on.
                $added_escapes = 1 if $t_ws_A =~ s/ /\\s/g;
                $added_escapes = 1 if $t_ws_B =~ s/ /\\s/g;
                $added_escapes = 1 if $t_ws_A =~ s/\t/\\t/g;
                $added_escapes = 1 if $t_ws_B =~ s/\t/\\t/g;
            }
            else {
                $t_ws_A = $t_ws_B = "";
            }

            my $do_tab_escape = $added_escapes || do {
                my $expanded_A = expand_tabs join( $body_A, $l_ws_A, $t_ws_A );
                my $expanded_B = expand_tabs join( $body_B, $l_ws_B, $t_ws_B );
                $expanded_A eq $expanded_B;
            };

            my $do_back_escape = $do_tab_escape || do {
                my ( $unescaped_A, $escaped_A,
                     $unescaped_B, $escaped_B
                ) =
                    map
                        join( "", /(\\.)/g ),
                        map {
                            ( $_, escape $_ )
                        }
                        expand_tabs join( $body_A, $l_ws_A, $t_ws_A ),
                        expand_tabs join( $body_B, $l_ws_B, $t_ws_B );
                $unescaped_A ne $unescaped_B && $escaped_A eq $escaped_B;
            };

            if ( $do_back_escape ) {
                $body_A =~ s/\\/\\\\/g;
                $body_B =~ s/\\/\\\\/g;
            }

            my $line_A = join $body_A, $l_ws_A, $t_ws_A;
            my $line_B = join $body_B, $l_ws_B, $t_ws_B;

            unless ( $do_tab_escape ) {
                $line_A = expand_tabs $line_A;
                $line_B = expand_tabs $line_B;
            }

            $A->[1] = escape $line_A;
            $B->[1] = escape $line_B;
        }

        push @elts, [ @$A, @$B, $elt_type ];
    }

    push @{$self->{ELTS}}, @elts, ["bar"];
    return "";
}

sub _glean_formats {
    my $self = shift;
}

sub file_footer {
    my $self = shift;
    my @seqs = (shift,shift);
    my $options = pop;

    my @heading_lines;
    
    if ( defined $options->{FILENAME_A} || defined $options->{FILENAME_B} ) {
        push @heading_lines, [ 
            map(
                {
                    ( "", escape( defined $_ ? $_ : "<undef>" ) );
                }
                ( @{$options}{qw( FILENAME_A FILENAME_B)} )
            ),
            "=",
        ];
    }

    if ( defined $options->{MTIME_A} || defined $options->{MTIME_B} ) {
        push @heading_lines, [
            map( {
                    ( "",
                        escape(
                            ( defined $_ && length $_ )
                                ? localtime $_
                                : ""
                        )
                    );
                }
                @{$options}{qw( MTIME_A MTIME_B )}
            ),
            "=",
        ];
    }

    if ( defined $options->{INDEX_LABEL} ) {
        push @heading_lines, [ "", "", "", "", "=" ] unless @heading_lines;
        $heading_lines[-1]->[0] = $heading_lines[-1]->[2] =
            $options->{INDEX_LABEL};
    }

    ## Not ushifting on to @{$self->{ELTS}} in case it's really big.  Want
    ## to avoid the overhead.

    my $four_column_mode = 0;
    for my $cols ( @heading_lines, @{$self->{ELTS}} ) {
        next if $cols->[-1] eq "bar";
        if ( $cols->[0] ne $cols->[2] ) {
            $four_column_mode = 1;
            last;
        }
    }

    unless ( $four_column_mode ) {
        for my $cols ( @heading_lines, @{$self->{ELTS}} ) {
            next if $cols->[-1] eq "bar";
            splice @$cols, 2, 1;
        }
    }

    my @w = (0,0,0,0);
    for my $cols ( @heading_lines, @{$self->{ELTS}} ) {
        next if $cols->[-1] eq "bar";
        for my $i (0..($#$cols-1)) {
            $w[$i] = length $cols->[$i]
                if defined $cols->[$i] && length $cols->[$i] > $w[$i];
        }
    }

    my %fmts = $four_column_mode
        ? (
            "=" => "| %$w[0]s|%-$w[1]s  | %$w[2]s|%-$w[3]s  |\n",
            "A" => "* %$w[0]s|%-$w[1]s  * %$w[2]s|%-$w[3]s  |\n",
            "B" => "| %$w[0]s|%-$w[1]s  * %$w[2]s|%-$w[3]s  *\n",
            "*" => "* %$w[0]s|%-$w[1]s  * %$w[2]s|%-$w[3]s  *\n",
        )
        : (
            "=" => "| %$w[0]s|%-$w[1]s  |%-$w[2]s  |\n",
            "A" => "* %$w[0]s|%-$w[1]s  |%-$w[2]s  |\n",
            "B" => "| %$w[0]s|%-$w[1]s  |%-$w[2]s  *\n",
            "*" => "* %$w[0]s|%-$w[1]s  |%-$w[2]s  *\n",
        );

    my @args = ('', '', '');
    push(@args, '') if $four_column_mode;
    $fmts{bar} = sprintf $fmts{"="}, @args;
    $fmts{bar} =~ s/\S/+/g;
    $fmts{bar} =~ s/ /-/g;

    # Sometimes the sprintf has too many arguments,
    # which results in a warning on Perl 5.021+
    # I really wanted to write:
    #   no warnings 'redundant';
    # but that causes a compilation error on older versions of perl
    # where the warnings pragma doesn't know about 'redundant'
    no warnings;

    return join( "",
        map {
            sprintf( $fmts{$_->[-1]}, @$_ );
        } (
        ["bar"],
        @heading_lines,
        @heading_lines ? ["bar"] : (),
        @{$self->{ELTS}},
        ),
    );

    @{$self->{ELTS}} = [];
}

1;

__END__

=pod

=head1 NAME

  Text::Diff::Table - Text::Diff plugin to generate "table" format output

=head1 SYNOPSIS

  use Text::Diff;
  
  diff \@a, $b, { STYLE => "Table" };

=head1 DESCRIPTION

This is a plugin output formatter for Text::Diff that generates "table" style
diffs:

  +--+----------------------------------+--+------------------------------+
  |  |../Test-Differences-0.2/MANIFEST  |  |../Test-Differences/MANIFEST  |
  |  |Thu Dec 13 15:38:49 2001          |  |Sat Dec 15 02:09:44 2001      |
  +--+----------------------------------+--+------------------------------+
  |  |                                  * 1|Changes                       *
  | 1|Differences.pm                    | 2|Differences.pm                |
  | 2|MANIFEST                          | 3|MANIFEST                      |
  |  |                                  * 4|MANIFEST.SKIP                 *
  | 3|Makefile.PL                       | 5|Makefile.PL                   |
  |  |                                  * 6|t/00escape.t                  *
  | 4|t/00flatten.t                     | 7|t/00flatten.t                 |
  | 5|t/01text_vs_data.t                | 8|t/01text_vs_data.t            |
  | 6|t/10test.t                        | 9|t/10test.t                    |
  +--+----------------------------------+--+------------------------------+

This format also goes to some pains to highlight "invisible" characters on
differing elements by selectively escaping whitespace.  Each element is split
in to three segments (leading whitespace, body, trailing whitespace).  If
whitespace differs in a segement, that segment is whitespace escaped.

Here is an example of the selective whitespace.

  +--+--------------------------+--------------------------+
  |  |demo_ws_A.txt             |demo_ws_B.txt             |
  |  |Fri Dec 21 08:36:32 2001  |Fri Dec 21 08:36:50 2001  |
  +--+--------------------------+--------------------------+
  | 1|identical                 |identical                 |
  * 2|        spaced in         |        also spaced in    *
  * 3|embedded space            |embedded        tab       *
  | 4|identical                 |identical                 |
  * 5|        spaced in         |\ttabbed in               *
  * 6|trailing spaces\s\s\n     |trailing tabs\t\t\n       *
  | 7|identical                 |identical                 |
  * 8|lf line\n                 |crlf line\r\n             *
  * 9|embedded ws               |embedded\tws              *
  +--+--------------------------+--------------------------+

Here's why the lines do or do not have whitespace escaped:

=over

=item lines 1, 4, 7 don't differ, no need.

=item lines 2, 3 differ in non-whitespace, no need.

=item lines 5, 6, 8, 9 all have subtle ws changes.

=back

Whether or not line 3 should have that tab character escaped is a judgement
call; so far I'm choosing not to.

=head1 UNICODE

To output the raw unicode chracters consult the documentation of
L<Text::Diff::Config>. You can set the C<DIFF_OUTPUT_UNICODE> environment
variable to 1 to output it from the command line. For more information,
consult this bug: L<https://rt.cpan.org/Ticket/Display.html?id=54214> .

=head1 LIMITATIONS

Table formatting requires buffering the entire diff in memory in order to
calculate column widths.  This format should only be used for smaller
diffs.

Assumes tab stops every 8 characters, as $DIETY intended.

Assumes all character codes >= 127 need to be escaped as hex codes, ie that the
user's terminal is ASCII, and not even "high bit ASCII", capable.  This can be
made an option when the need arises.

Assumes that control codes (character codes 0..31) that don't have slash-letter
escapes ("\n", "\r", etc) in Perl are best presented as hex escapes ("\x01")
instead of octal ("\001") or control-code ("\cA") escapes.

=head1 AUTHOR

Barrie Slaymaker E<lt>barries@slaysys.comE<gt>

=head1 LICENSE

Copyright 2001 Barrie Slaymaker, All Rights Reserved.

You may use this software under the terms of the GNU public license, any
version, or the Artistic license.

=cut

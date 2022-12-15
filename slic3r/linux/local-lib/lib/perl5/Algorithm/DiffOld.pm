# This is a version of Algorithm::Diff that uses only a comparison function,
# like versions <= 0.59 used to.
# $Revision: 1.3 $

package # don't index
    Algorithm::DiffOld;
use strict;
use vars qw($VERSION @EXPORT_OK @ISA @EXPORT);
use integer;		# see below in _replaceNextLargerWith() for mod to make
					# if you don't use this
require Exporter;
@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw(LCS diff traverse_sequences);
$VERSION = 1.10;	# manually tracking Algorithm::Diff

# McIlroy-Hunt diff algorithm
# Adapted from the Smalltalk code of Mario I. Wolczko, <mario@wolczko.com>
# by Ned Konz, perl@bike-nomad.com

=head1 NAME

Algorithm::DiffOld - Compute `intelligent' differences between two files / lists
but use the old (<=0.59) interface.

=head1 NOTE

This has been provided as part of the Algorithm::Diff package by Ned Konz.
This particular module is B<ONLY> for people who B<HAVE> to have the old
interface, which uses a comparison function rather than a key generating
function.

Because each of the lines in one array have to be compared with each 
of the lines in the other array, this does M*N comparisons. This can
be very slow. I clocked it at taking 18 times as long as the stock
version of Algorithm::Diff for a 4000-line file. It will get worse
quadratically as array sizes increase.

=head1 SYNOPSIS

  use Algorithm::DiffOld qw(diff LCS traverse_sequences);

  @lcs    = LCS( \@seq1, \@seq2, $comparison_function );

  $lcsref = LCS( \@seq1, \@seq2, $comparison_function );

  @diffs = diff( \@seq1, \@seq2, $comparison_function );
  
  traverse_sequences( \@seq1, \@seq2,
                     { MATCH => $callback,
                       DISCARD_A => $callback,
                       DISCARD_B => $callback,
                     },
                     $comparison_function );

=head1 COMPARISON FUNCTIONS

Each of the main routines should be passed a comparison function. If you
aren't passing one in, B<use Algorithm::Diff instead>.

These functions should return a true value when two items should compare
as equal.

For instance,

  @lcs    = LCS( \@seq1, \@seq2, sub { my ($a, $b) = @_; $a eq $b } );

but if that is all you're doing with your comparison function, just use
Algorithm::Diff and let it do this (this is its default).

Or:

  sub someFunkyComparisonFunction
  {
  	my ($a, $b) = @_;
	$a =~ m{$b};
  }

  @diffs = diff( \@lines, \@patterns, \&someFunkyComparisonFunction );

which would allow you to diff an array @lines which consists of text
lines with an array @patterns which consists of regular expressions.

This is actually the reason I wrote this version -- there is no way
to do this with a key generation function as in the stock Algorithm::Diff.

=cut

# Find the place at which aValue would normally be inserted into the array. If
# that place is already occupied by aValue, do nothing, and return undef. If
# the place does not exist (i.e., it is off the end of the array), add it to
# the end, otherwise replace the element at that point with aValue.
# It is assumed that the array's values are numeric.
# This is where the bulk (75%) of the time is spent in this module, so try to
# make it fast!

sub _replaceNextLargerWith
{
	my ( $array, $aValue, $high ) = @_;
	$high ||= $#$array;

	# off the end?
	if ( $high == -1  || $aValue > $array->[ -1 ] )
	{
		push( @$array, $aValue );
		return $high + 1;
	}

	# binary search for insertion point...
	my $low = 0;
	my $index;
	my $found;
	while ( $low <= $high )
	{
		$index = ( $high + $low ) / 2;
#		$index = int(( $high + $low ) / 2);		# without 'use integer'
		$found = $array->[ $index ];

		if ( $aValue == $found )
		{
			return undef;
		}
		elsif ( $aValue > $found )
		{
			$low = $index + 1;
		}
		else
		{
			$high = $index - 1;
		}
	}

	# now insertion point is in $low.
	$array->[ $low ] = $aValue;		# overwrite next larger
	return $low;
}

# This method computes the longest common subsequence in $a and $b.

# Result is array or ref, whose contents is such that
# 	$a->[ $i ] == $b->[ $result[ $i ] ]
# foreach $i in ( 0 .. $#result ) if $result[ $i ] is defined.

# An additional argument may be passed; this is a CODE ref to a comparison
# routine. By default, comparisons will use "eq" .
# Note that this routine will be called as many as M*N times, so make it fast!

# Additional parameters, if any, will be passed to the key generation routine.

sub _longestCommonSubsequence
{
	my $a = shift;	# array ref
	my $b = shift;	# array ref
	my $compare = shift || sub { my $a = shift; my $b = shift; $a eq $b };

	my $aStart = 0;
	my $aFinish = $#$a;
	my $bStart = 0;
	my $bFinish = $#$b;
	my $matchVector = [];

	# First we prune off any common elements at the beginning
	while ( $aStart <= $aFinish
		and $bStart <= $bFinish
		and &$compare( $a->[ $aStart ], $b->[ $bStart ], @_ ) )
	{
		$matchVector->[ $aStart++ ] = $bStart++;
	}

	# now the end
	while ( $aStart <= $aFinish
		and $bStart <= $bFinish
		and &$compare( $a->[ $aFinish ], $b->[ $bFinish ], @_ ) )
	{
		$matchVector->[ $aFinish-- ] = $bFinish--;
	}

	my $thresh = [];
	my $links = [];

	my ( $i, $ai, $j, $k );
	for ( $i = $aStart; $i <= $aFinish; $i++ )
	{
		$k = 0;
		# look for each element of @b between $bStart and $bFinish
		# that matches $a->[ $i ], in reverse order
		for ($j = $bFinish; $j >= $bStart; $j--)
		{
			next if ! &$compare( $a->[$i], $b->[$j], @_ );
			# optimization: most of the time this will be true
			if ( $k
				and $thresh->[ $k ] > $j
				and $thresh->[ $k - 1 ] < $j )
			{
				$thresh->[ $k ] = $j;
			}
			else
			{
				$k = _replaceNextLargerWith( $thresh, $j, $k );
			}

			# oddly, it's faster to always test this (CPU cache?).
			if ( defined( $k ) )
			{
				$links->[ $k ] = 
					[ ( $k ? $links->[ $k - 1 ] : undef ), $i, $j ];
			}
		}
	}

	if ( @$thresh )
	{
		for ( my $link = $links->[ $#$thresh ]; $link; $link = $link->[ 0 ] )
		{
			$matchVector->[ $link->[ 1 ] ] = $link->[ 2 ];
		}
	}

	return wantarray ? @$matchVector : $matchVector;
}

sub traverse_sequences
{
	my $a = shift;	# array ref
	my $b = shift;	# array ref
	my $callbacks = shift || { };
	my $compare = shift;
	my $matchCallback = $callbacks->{'MATCH'} || sub { };
	my $discardACallback = $callbacks->{'DISCARD_A'} || sub { };
	my $finishedACallback = $callbacks->{'A_FINISHED'};
	my $discardBCallback = $callbacks->{'DISCARD_B'} || sub { };
	my $finishedBCallback = $callbacks->{'B_FINISHED'};
	my $matchVector = _longestCommonSubsequence( $a, $b, $compare, @_ );
	# Process all the lines in match vector
	my $lastA = $#$a;
	my $lastB = $#$b;
	my $bi = 0;
	my $ai;
	for ( $ai = 0; $ai <= $#$matchVector; $ai++ )
	{
		my $bLine = $matchVector->[ $ai ];
		if ( defined( $bLine ) )	# matched
		{
			&$discardBCallback( $ai, $bi++, @_ ) while $bi < $bLine;
			&$matchCallback( $ai, $bi++, @_ );
		}
		else
		{
			&$discardACallback( $ai, $bi, @_ );
		}
	}
	# the last entry (if any) processed was a match.

	if ( defined( $finishedBCallback ) && $ai <= $lastA )
	{
		&$finishedBCallback( $bi, @_ );
	}
	else
	{
		&$discardACallback( $ai++, $bi, @_ ) while ( $ai <= $lastA );
	}

	if ( defined( $finishedACallback ) && $bi <= $lastB )
	{
		&$finishedACallback( $ai, @_ );
	}
	else
	{
		&$discardBCallback( $ai, $bi++, @_ ) while ( $bi <= $lastB );
	}
	return 1;
}

sub LCS
{
	my $a = shift;	# array ref
	my $matchVector = _longestCommonSubsequence( $a, @_ );
	my @retval;
	my $i;
	for ( $i = 0; $i <= $#$matchVector; $i++ )
	{
		if ( defined( $matchVector->[ $i ] ) )
		{
			push( @retval, $a->[ $i ] );
		}
	}
	return wantarray ? @retval : \@retval;
}

sub diff
{
	my $a = shift;	# array ref
	my $b = shift;	# array ref
	my $retval = [];
	my $hunk = [];
	my $discard = sub { push( @$hunk, [ '-', $_[ 0 ], $a->[ $_[ 0 ] ] ] ) };
	my $add = sub { push( @$hunk, [ '+', $_[ 1 ], $b->[ $_[ 1 ] ] ] ) };
	my $match = sub { push( @$retval, $hunk ) if scalar(@$hunk); $hunk = [] };
	traverse_sequences( $a, $b,
		{ MATCH => $match, DISCARD_A => $discard, DISCARD_B => $add },
		@_ );
	&$match();
	return wantarray ? @$retval : $retval;
}

1;

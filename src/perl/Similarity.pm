package Similarity;

use strict;
use warnings;

use Vector;

use Algorithm::Diff qw(
        LCS LCS_length LCSidx
        diff sdiff compact_diff
        traverse_sequences traverse_balanced );
use Function::Parameters qw/:strict/;
use List::Util qw/max/;
use Text::Trim;

sub _average_jaccard_similarity {

    my $strings = shift;

    my $average_similarity = 0;

    if ( $strings ) {
	
	my $n_strings = scalar(@$strings);
	my $count = 0;

	if ( $n_strings ) {

	    for (my $i=0; $i<$n_strings; $i++) {
		
		for (my $j=$i+1; $j<$n_strings; $j++) {

		    $count++;
		    $average_similarity += _jaccard_similarity($strings->[$i],$strings->[$j]);
		    
		}
		
	    }

	    $average_similarity /= $count;

	}

    }

    return $average_similarity;

}

# compute cosine similarity between two strings
# TODO: add support for custom tokenizer ? 
sub _compute_cosine_similarity {

    my $string1 = shift;
    my $string2 = shift;
    my $dfs = shift || {};

    my %tokens1_counts;
    my %tokens2_counts;

    if ( ( !ref($string1) && !ref($string2) ) || ( ref($string1) ne 'HASH' ) ) {

	my @tokens1;
	my @tokens2;

	if ( ! ref($string1 ) ) {

	    my $normalized_string1 = _normalize_string($string1);
	    my $normalized_string2 = _normalize_string($string2);
	    
	    @tokens1 = split /\s+/, $normalized_string1;
	    @tokens2 = split /\s+/, $normalized_string2;

	}
	else {

	    @tokens1 = @{ $string1 };
	    @tokens2 = @{ $string2 };

	}
	
	map { $tokens1_counts{$_}++; } @tokens1;
	map { $tokens2_counts{$_}++; } @tokens2;

    }
    else {

	%tokens1_counts = %{ $string1 };
	%tokens2_counts = %{ $string2 };
	
    }

    my $vector1 = new Vector( coordinates => \%tokens1_counts );
    my $vector2 = new Vector( coordinates => \%tokens2_counts );

    my $similarity = Vector::cosine( $vector1 , $vector2 , $dfs );

    return $similarity;

}

# (specific) string normalization
# TODO: move this to a normalization class
sub _normalize_string {

    my $string = shift;
    
    my $normalized_string = lc($string);
    $normalized_string = trim($normalized_string);
    $normalized_string =~ s/[[:punct:]]+/ /sg;

    return $normalized_string;

}

# compute centroid given a collection of vectors
sub compute_centroid {

    my $vectors = shift;

    my $n_vectors = scalar( @{ $vectors } );
    my $centroid = new Vector();

    if ( $n_vectors ) {

	# compute unnormalized centroid
	foreach my $vector (@{ $vectors }) {
	    $centroid->add( $vector );
	}
	
	$centroid->normalize();
		  
    }
    
    return $centroid;

}

# Note : first string is reference
method lcs_similarity ( $sequence_1 , $sequence_2 , :$normalize_by_reference_length = 1 , :$normalize_by_max_sequence_length = 0 , :$return_lcs = 0 , :$return_diff = 0 ) {

    my ( $sequence_1_length , $sequence_2_length ) = map { scalar( @{ $_ } ) } ( $sequence_1 , $sequence_2 );
    my @lcs = LCS( $sequence_1 , $sequence_2 );

    my $overlap = scalar( @lcs );

    if ( $normalize_by_max_sequence_length ) {
	$overlap /= max( $sequence_1_length , $sequence_2_length );
    }
    elsif ( $normalize_by_reference_length ) {
	$overlap /= $sequence_1_length;
    }

    my @results = ( $overlap );

    if ( $return_lcs ) {
	push @results , \@lcs;
    }

    if ( $#results > 0 ) {
	return @results;
    }

    return $results[ 0 ];

}

# TODO : does this really belong here ?
method lcs_diff ( $sequence_1 , $sequence_2 ) {
    my @diff = diff( $sequence_1 , $sequence_2 );
    return \@diff;
}

1;

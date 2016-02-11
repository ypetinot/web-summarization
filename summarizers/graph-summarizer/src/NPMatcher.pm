package NPMatcher;

# TODO: this is supposed to be a chunk (or explicit clusters thereof) oriented class
# Intended to be used as similarity function provider for higher-level hierarchical clustering frameworks

use strict;
use warnings;

use StringNormalizer;

use List::Util qw/min/;

# scores the level of match between two nodes
sub match {

    my $chunk_set_a = shift;
    my $chunk_set_b = shift;

    # 1 - if final NP matches (up to plural), then can compute match score, otherwise 0
    my $final_np_matches = _np_head_match($chunk_set_a,$chunk_set_b);
    if ( ! $final_np_matches ) {
	return 0;
    }
    else {

	# check for exact match
	my $exact_match_score = exact_match($chunk_set_a,$chunk_set_b);
	
	# check for wild-card match
	my $wild_card_match_score = wild_card_match($chunk_set_a,$chunk_set_b);
	
	# check for similarity-based match
	my $similarity_match_score = similarity_match($chunk_set_a,$chunk_set_b);
	
	my $score = $exact_match_score + $wild_card_match_score ** 2 + $similarity_match_score ** 3; 
	return $score;

    }

} 

# check whether two NPs' heads match
# plural match is optional
sub _np_head_match {

    my $np_entry_1 = shift;
    my $np_entry_2 = shift;
    my $plural_match = shift || 0;

    my $np_entry_1_head = $np_entry_1->head();
    my $np_entry_2_head = $np_entry_2->head();

    my $head_match_level = 0;

    for (my $i=0; $i<min( scalar( @{ $np_entry_1_head } ) , scalar( @{ $np_entry_2_head } ) ); $i++) {

	my $current_entry_1_head_token = $np_entry_1_head->[ scalar(@$np_entry_1_head) - 1 - $i ];
	my $current_entry_2_head_token = $np_entry_2_head->[ scalar(@$np_entry_2_head) - 1 - $i ];

	# check for exact match
	if ( StringNormalizer::_normalize($current_entry_1_head_token) eq StringNormalizer::_normalize($current_entry_2_head_token) ) {
	    $head_match_level++;
	}
	# check for plural match
	elsif ( ( $np_entry_1->is_plural() || $np_entry_2->is_plural() ) && ( StringNormalizer::_plural_normalize($current_entry_1_head_token) eq StringNormalizer::_plural_normalize($current_entry_2_head_token) ) ) {
	    $head_match_level++;
	}
	else {
	    last;
	}

    }

    return $head_match_level;

}

# check whether there is an exact match between this chunk and another one
sub exact_match {

    my $node_a = shift;
    my $node_b = shift;

    # for now compare based on the first chunk in each node
    # TODO: we need to compare the full word lattice/FSA
    my $chunk_a = $node_a->raw_data()->get_chunk( $node_a->raw_chunks()->[0] , 0 );
    my $chunk_b = $node_b->raw_data()->get_chunk( $node_b->raw_chunks()->[0] , 0 );

    if ( !$chunk_a || !$chunk_b ) {
	return 0;
    }

    my $n_terms1 = $chunk_a->get_number_of_terms();
    my $n_terms2 = $chunk_b->get_number_of_terms();

    if ( $n_terms1 != $n_terms2 ) {
	return 0;
    }
    
    for (my $i=0; $i<$n_terms1; $i++) {
	if ( $chunk_a->get_term($i) ne $chunk_b->get_term($i) ) {
	    return 0;
	}
    }

    return 1;

}

# check whether there is a wild card match between this chunk and another one
sub wild_card_match {

    my $this = shift;
    my $chunk = shift;

    # need to find ideal alignment between the two chunks
    # TODO

    return 0;

}

# check whether there is a similarity-based match between this chunk and another one
sub similarity_match {

    my $node_a = shift;
    my $node_b = shift;
    
    # for now compare based on the first chunk in each node
    # TODO: we need to compare the full word lattice/FSA
    my $chunk_a = $node_a->raw_data()->get_chunk( $node_a->raw_chunks()->[0] , 0 );
    my $chunk_b = $node_b->raw_data()->get_chunk( $node_b->raw_chunks()->[0] , 0 );

    if ( !$chunk_a || !$chunk_b ) {
	return 0;
    }

    my $terms1 = $chunk_a->get_terms();
    my $terms2 = $chunk_b->get_terms();

    my %all_terms;
    my %_terms1;
    my %_terms2;

    map { $_terms1{$_}++; $all_terms{$_}++; } @$terms1;
    map { $_terms2{$_}++; $all_terms{$_}++; } @$terms2;

    my $overlap_count = 0;
    foreach my $term (@$terms1) {
	if ( defined($_terms2{$term}) ) {
	    $overlap_count++;
	}
    }

    my $score = 0;
    if ( scalar(keys(%all_terms)) ) {
	$score = $overlap_count / scalar(keys(%all_terms));
    }

    return $score;

}

1;

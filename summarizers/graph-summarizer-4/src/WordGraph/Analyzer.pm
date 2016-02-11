package WordGraph::Analyzer;

use strict;
use warnings;

use Moose;

sub analyze {

    my $this = shift;
    my $graph = shift;
    my $instance = shift;
    my $target_sequence = shift;
    my $ngram_order = shift;

    # 1 - generate list of n-grams from target sequence
    my $target_sequence_ngrams = $target_sequence->get_ngrams( $ngram_order );
    my $target_sequence_ngrams_count = scalar( @{ $target_sequence_ngrams } );

    # 2 - for each n-gram check whether it exists in the graph
    my $has_all_ngrams = 1;
    my $has_ngrams = 0;
    my %from_2_to;
    my @missing;
    foreach my $target_sequence_ngram (@{ $target_sequence_ngrams }) {

	my $ngram_ok = 0;

	my $initial_candidates = $graph->get_node_by_surface( $target_sequence_ngram->[ 0 ]->surface() );
	foreach my $initial_candidate (@{ $initial_candidates }) {

	    my $candidate_ok = 1;

	    my $current_node = $initial_candidate;
	    my $from_node = $current_node;
	    my $to_node = $from_node;

	    for (my $i=1; $i<scalar(@{ $target_sequence_ngram }); $i++) {
		
		my $target_surface = $target_sequence_ngram->[ $i ]->surface();

		# 1 - get successors of current node
		my @successors = $graph->successors( $current_node );

		# 2 - check whether one of the successors matches the target surface
		my $found = 0;
		my $matching_successor = undef;
		my $current_successor = undef;
		for (my $i=0; $i<scalar(@successors); $i++) {

		    $current_successor = $successors[ $i ];

		    if ( lc( $current_successor->realize( $instance ) ) eq lc( $target_surface ) ) {
			$matching_successor = $current_successor;
			$found++;
		    }

		}

		if ( $found > 1 ) {
		    print STDERR ">> [__PACKAGE__] we have a problem here ...\n";
		}

		if ( $found ) {
		    $current_node = $current_successor;
		    $to_node = $current_node;
		}
		else {
		    $candidate_ok = 0;
		    last;
		}
		
	    }

	    if ( $candidate_ok ) {
		$ngram_ok = 1;
		if ( ! defined( $from_2_to{ $from_node } ) ) {
		    $from_2_to{ $from_node } = [];
		}
		push @{ $from_2_to{ $from_node } } , $to_node;
	    }
	    else {
		my $ngram_string = join( " " , map { $_->surface() } @{ $target_sequence_ngram } );
		print STDERR ">> [__PACKAGE__] ${ngram_order}-gram ( $ngram_string ) is not supported by word-graph  ...\n";
	    }

	}

	# we can stop here if this ngram is not supported by the word-graph
	if ( ! $ngram_ok ) {
	    $has_all_ngrams = 0;
	    push @missing, $target_sequence_ngram;
	}
	else {
	    $has_ngrams++;
	}

	    }

=pod
    # 3 - finally check whether (a) path is possible in the graph (i.e. are all the 2-grams present and can they be connected ? / what about extra edges --> shortest connection ?)
    my %threads;
    while ( scalar( keys( %from_2_to ) ) ) {
	
	my $from = ( keys( %from_2_to ) )[ 0 ];
	my $to = $from_2_to{ $from };

	delete( $from_2_to{ $from } );

	my $thread = [ $from , $to ];
	

    }
=cut

    return ( $has_all_ngrams , $has_ngrams / $target_sequence_ngrams_count , \@missing );

}

sub _path_overlap {

}

no Moose;

1;

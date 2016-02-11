package WordGraph::ReferenceRanker::WeightedSummaryRelevance;

use Moose;

extends 'WordGraph::ReferenceRanker::SummaryRelevance';

has '_reference_entry_frequency_cache' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

our $REFERENCE_RANKING_MODE_WEIGHTED_SUMMARY_RELEVANCE = "weighted-relevance-summary";
sub _id {
    return $REFERENCE_RANKING_MODE_WEIGHTED_SUMMARY_RELEVANCE;
}

sub get_reference_entries_frequency {

    my $this = shift;
    my $string = shift;

    my $normalized_string = lc( $string );

    if ( ! defined( $this->_reference_entry_frequency_cache()->{ $normalized_string } ) ) {

	my $frequency = 0;
	foreach my $reference_entry (@{ $this->reference_entries_unsorted() }) {
	    
	    my $reference_entry_summary = $reference_entry->get_field('summary');
	    if ( $reference_entry_summary =~ m/\Q$normalized_string\E/sgi ) {
		$frequency++;
	    }

	}

	# set cache
	$this->_reference_entry_frequency_cache()->{ $normalized_string } = $frequency;

    }

    return $this->_reference_entry_frequency_cache()->{ $normalized_string };

}

sub compute_unnormalized_relevance {

    my $this = shift;
    my $reference_entry_summary = shift;
	    
    my $reference_entry_score = 0;

    my $target_elements = $this->_target_data_elements();

    # 2 - evaluate relevance of the reference summary given set of descriptive elements for the target object
    foreach my $target_element (keys( %{ $target_elements } )) {
				
	my $target_element_weight = scalar( keys( %{ $target_elements->{ $target_element } } ) );
	
	my $reference_summary_count = 0;
	while ( $reference_entry_summary =~ m/\Q$target_element\E/sgi ) {
	    # Note : should we multiply instead ?
	    $reference_summary_count++;
	}

	if ( $reference_summary_count ) {
	    my $reference_set_count = $this->get_reference_entries_frequency( $target_element );
	    $reference_entry_score += $target_element_weight * $reference_summary_count / $reference_set_count;
	}
	
    }

    return $reference_entry_score;

}

no Moose;

1;

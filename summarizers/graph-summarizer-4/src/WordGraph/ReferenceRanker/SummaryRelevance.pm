package WordGraph::ReferenceRanker::SummaryRelevance;

# CURRENT : when writing code, always proceed bottom up, maximizing code reuse ==> make a note of this

use strict;
use warnings;

use ObjectSummaryEnergyModel;

use Moose;
use namespace::autoclean;

# CURRENT : how to abstract the featurized/vector space representation for the object(s) / summary(ies) / and their combinations ? 

our $REFERENCE_RANKING_MODE_RELEVANCE_SUMMARY = "relevance-summary";
sub _id {
    return $REFERENCE_RANKING_MODE_RELEVANCE_SUMMARY;
}



=pod
sub _asymmetric_featurized_similarity_function_builder {
    my $this = shift;
    my $asymmetric_featurized_similarity_function = sub {
	
	my $target_object = shift;
	my $reference_sentence_object = shift;

	my $summary_length = $reference_sentence_object->length;

	# CURRENT : similarity between target object and reference summary evaluated in a common space
	my $target_object_featurized = $target_object->featurize( $this->target_featurizer );
	my $reference_sentence_object_featurized = $reference_sentence_object->featurize( $this->reference_featurize );
	
	return Vector::cosine( $target_object_featurized , $reference_sentence_object_featurized );	
	#return ( $target_object_reference_summary_energy / $summary_length );
	
    };
    
    return $asymmetric_featurized_similarity_function;

}
=cut

extends( 'WordGraph::ReferenceRanker::FieldBasedRanker' );

__PACKAGE__->meta->make_immutable;

1;

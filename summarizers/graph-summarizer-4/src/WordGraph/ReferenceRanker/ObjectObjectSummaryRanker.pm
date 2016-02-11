package WordGraph::ReferenceRanker::ObjectObjectSummaryRanker;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceRanker::FieldBasedRanker' );
#extends( 'WordGraph::ReferenceRanker' );

sub _symmetric_builder {
    return 1;
}

sub _run_implementation {

    my $this = shift;
    my $target_object = shift;
    my $reference_sentences = shift;
    my $full_serialization_path = shift;

    # CURRENT : what do we use as our target summary ? => each individual reference sentence

    my $n_reference_sentences = scalar( @{ $reference_sentences } );

    my @target_object_similarities;
    my @reference_summary_similarities;
    for ( my $i=0; $i<$n_reference_sentences; $i++ ) {
  	##$target_object_similarities[ $i ] = $this->_object_object_similarity_function->( $target_object , $reference_sentences->[ $i ]->object );
  	$target_object_similarities[ $i ] = $this->object_similarity( $target_object , $reference_sentences->[ $i ] );
	for ( my $j=$i+1; $j<$n_reference_sentences; $j++ ) {
	    $reference_summary_similarities[ $i ][ $j ] =
		$reference_summary_similarities[ $j ][ $i ] =
		#$this->_summary_summary_similarity_function->( $reference_sentences->[ $i ] , $reference_sentences->[ $j ] );
		$this->summary_lcs_similarity( $reference_sentences->[ $i ] , $reference_sentences->[ $j ] );
	}
    }

    # we look at all available references
    my @reference_entries_scored;
    for ( my $i=0; $i<$n_reference_sentences; $i++ ) {

	# Note : this is the reference sentence for which we want to generate a score
	my $reference_sentence = $reference_sentences->[ $i ];
	
	my $reference_score = 0;
	
	# Note : kernel-based / kernel-like model (?)
	for ( my $j=0; $j<$n_reference_sentences; $j++ ) {
	    
	    # Note : we cannot use the current reference sentence to compute its score
	    if ( $i == $j ) {
		next;
	    }
	    
	    # a - compute how close reference_sentence_j (object) is to the target object
	    # ==> we use this as a weighting factor
	    # Note : this should be the similarity between the target object and reference object j => ok
	    my $object_similarity_j = $target_object_similarities[ $j ]; 

	    # b - compute how close reference_sentence_i (summary) is to reference_sentence_j (summary)
	    # Note : this should be the similarity between the candidate summary for the target object (i) and the summary of reference object j
	    my $summary_similarity_ij = $reference_summary_similarities[ $i ][ $j ];

	    # c - update reference score
	    # Note : this allows to encode required summary similarity, without requiring similarity between the object and the summary
	    $reference_score += $object_similarity_j * $summary_similarity_ij;

	    # ********************************** compute vector representations *******************************
	    
	    # CURRENT : are kernels appropriate to describe relationship in object space and summary space respectively ?
	    # Kernel method require only a user-specified kernel, i.e. a similarity function over raw objects ==> good for me
	    # Instead of computing coordinates in feature space, compute inner product of all pairs of objects
	    
	    # Model direct dependencies between the object and summary ==> focus intuitively should be on matching salient elements ==> not instance based
	    # Note : this is is basically TargetSimilarity
	    # The cross-correlation and the direct model are (thus) expected to be orthogonal ==> joint optimization possible ?
	    	    
	}

	push @reference_entries_scored , [ $reference_sentence , $reference_score ];

    }

    return \@reference_entries_scored;

}

# summary featurizer
has '_summary_featurizer' => ( is => 'ro' , does => 'Featurizer' , init_arg => undef , lazy => 1 , builder => '_summary_featurizer_builder' );

=pod
# Note : for now we restrict ourselves to the cosine similarity
has '_object_object_similarity_function' => ( is => 'ro' , isa => 'CodeRef' ,
					      init_arg => undef , lazy => 1 , builder => '_object_object_similarity_function_builder' );
sub _object_object_similarity_function_builder {
    my $this = shift;
    return $this->_symmetric_similarity_function_builder( $this->_object_featurizer );
}

# TODO : can we avoid code duplication with _object_object_similarity_function_builder ?
has '_summary_summary_similarity_function' => ( is => 'ro' , isa => 'CodeRef' ,
						init_arg => undef , lazy => 1 , builder => '_summary_summary_similarity_function_builder' );
sub _summary_summary_similarity_function_builder {
    my $this = shift;
    return $this->_symmetric_similarity_function_builder( $this->_summary_featurizer );
}

# CURRENT : replace with similarity function from FieldBasedRanker ?
sub _symmetric_similarity_function_builder {
    my $this = shift;
    my $featurizer = shift;
    my $symmetric_similarity_function = sub {
	my $object_1 = shift;
	my $object_2 = shift;
	my @objects_featurized = map { $_->featurize( $featurizer ); } ( $object_1 , $object_2 );
	return $this->_featurized_symmetric_similarity_function->( @objects_featurized );
    };
    return $symmetric_similarity_function;
}
=cut

sub _summary_featurizer_builder {
    my $this = shift;
    return new Web::Summarizer::Sequence::Featurizer( coordinate_weighter => $this->_summary_idf_weighter );
}

__PACKAGE__->meta->make_immutable;

1;

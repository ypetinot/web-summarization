package ReferenceTargetPairwiseDecoder;

use strict;
use warnings;

use Moose::Role;
###use namespace::autoclean;

# find optimal path for the current set of weights
# CURRENT : this is supposed to give me back a representation of the instance in the feature space ?
# CURRENT : decoding is tightly coupled with the topology ==> the topology might in fact provide the search/decoding function but relies on the model to score its objects
sub decode {

    my $this = shift;
    my $instance = shift;

    my $instance_input_target_object = $instance->[ 0 ]->[ 0 ];

=pod
    # 1 - instance is expected to provide a list of n-references
    my $instance_input_references = $instance->[ 0 ]->[ 1 ];

    # for each input reference , we run a low level decoder
    my $best_decoded_candidate;
    my $best_decoded_candidate_score = 0;
    foreach my $input_reference (@{ $instance_input_references }) {

	my $input_reference_object = $input_reference->[ 0 ];
	my $input_reference_sentence = $input_reference->[ 1 ];
	
	my $local_instance = new ReferenceTargetPairwiseFactorGraph( target_object => $instance_input_target_object ,
								     reference => $input_reference_sentence );
	my $decoded_candidate = $decoder->decode( $local_instance );
	my $decoded_candidate_score = -1;

	if ( ! $best_decoded_candidate || $decoded_candidate_score > $best_decoded_candidate_score ) {
	    $best_decoded_candidate = $decoded_candidate;
	    $best_decoded_candidate_score = $decoded_candidate_score;
	}

    }

    return $best_decoded_candidate;
=cut

}

with('WordGraph::Decoder');

1;

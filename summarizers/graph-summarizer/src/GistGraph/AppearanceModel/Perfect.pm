package GistGraph::AppearanceModel::Perfect;

# (Almost, up to quality of the matching/clustering process) Ground Truth Appearance Model - Appearance data is obtained directly from the raw testing data

use strict;
use warnings;

use Moose;

use GistGraph::AppearanceModel;
extends 'GistGraph::AppearanceModel';

# keep track of known nodes
has 'known' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# run inference
sub _run_inference {

    my $this = shift;
    my $url_data = shift;

    # Note: cluster assignment is not readily available for held out data

    # Retrieve Ground Truth data for the current URL
    my $ground_truth = $this->gist_graph()->raw_data()->category_data()->summaries()->[ $url_data->index() ];

    foreach my $chunk_id (@{ $ground_truth }) {

	my $chunk = $this->gist_graph()->raw_data()->get_chunk( $chunk_id , 0 );
	my $chunk_node = undef;
	my $chunk_known = -1;

	if ( defined( $chunk ) ) {

	    # we are only interested in NPs
	    if ( ! $chunk->is_np() ) {
		next;
	    }

	    # this is a known chunk and an NP => we can find its corresponding node
	    $chunk_node = $this->gist_graph()->get_node_for_chunk( $chunk_id );
	    if ( defined( $chunk_node ) ) {
		$chunk_known = $chunk_node->id();
	    }

	}
	else {

	    # this is not a known chunk

	    # 1 - verify using complete data whether this is an NP
	    my $original_chunk = $this->gist_graph()->raw_data()->category_data()->get_chunk( $chunk_id );
	    if ( ! $original_chunk->is_np() ) {
		next;
	    }

	    # map chunk to a GistGraph::Node instance
	    # TODO: can we add a method to the GistGraph class to instantiate nodes (even if they are not included in the model) ?
	    my $temp_node = new GistGraph::Node( raw_data => $this->gist_graph()->raw_data()->category_data() );
	    $temp_node->add( $chunk_id );

	    # Run immutable clustering for this chunk
	    # given existing set of nodes (clusters), what is the closest match
	    # TODO: move this to a method in GistGraph class ?
	    my $best_matching_score = 0;
	    my $best_matching_specific_node = undef;
	    my $best_matching_specific_score = 0;
	    foreach my $node ( @{ $this->gist_graph()->get_nodes() } ) {
		    
		if ( $node->has_flag( $GistGraph::FLAG_GENERIC ) ) {
		    
		    my $score = NPMatcher::match( $temp_node , $node );
		    
		    if ( $score > $best_matching_score ) {
			$chunk_node = $node;
			$chunk_known = $node->id();
		    }
		    
		}
		else {
		    
		    # Not supported ? Requires full alignment of gist onto Gist Graph 
		    # This is ok as far as the evaluation of the appearance model goes since we only focus on generic nodes for now 
		    next;

=pod
		    # not very meaningful since this type of clustering requires knowing the complete output, not just what NPs appear (?) 
		    my $node_context = $node->context();
		    my $chunk_context = $temp_node->context();
		    my $score = GistGraph::Node::Context::similarity( $chunk_context , $node_context );
		    
		    if ( $score > $best_matching_specific_score ) {
			$best_matching_specific_node = $node;
			$chunk_known = -2;
		    }
=cut
		    
		}
		
	    }

	    if ( ! defined( $chunk_node ) ) {
		$chunk_node = $best_matching_specific_node;
	    }

	}
	
	# TODO: instead, can we align this gist to the gist graph (more interesting, but not necessary to evalue the appearance model itself ?)
	
	if ( defined( $chunk_node ) ) {

	    # Update appearance status for the target node
	    $this->appearance()->{ $chunk_known } = 1;
	    $this->known()->{ $chunk_node->id() } = $chunk_known;

	}
	
    }
    
}

# should this model be serialized ?
sub serializable {

    my $that = shift;

    # This is not a trainable model ...
    return 0;

}

# is a given node known ?
sub is_known {

    my $this = shift;
    my $node_id = shift;
    
    return $this->known()->{ $node_id } || 0;

}

no Moose;

1;

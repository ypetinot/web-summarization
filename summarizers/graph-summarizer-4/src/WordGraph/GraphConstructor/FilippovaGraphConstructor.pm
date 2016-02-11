package WordGraph::GraphConstructor::FilippovaGraphConstructor;

use strict;
use warnings;

use JSON;

use Moose;
use namespace::autoclean;

# TODO
extends 'WordGraph::GraphConstructor';

my $DEBUG = 0;

my $ANNOTATION_KEY_AMBIGUITY = 'ambiguity';
my $ANNOTATION_KEY_INDEX = 'index';
my $ANNOTATION_KEY_KEY = 'key';
my $ANNOTATION_KEY_PATH_LABEL = 'path_label';
my $ANNOTATION_KEY_IS_SLOT = 'is_slot';

sub construct_core {
    
    my $this = shift;
    my $graph = shift;
    my $token_sequences = shift;
    
    # element key 2 node mapping
    my %_key_2_nodes;

    # node 2 element key mapping
    my %_node_2_key;

    # node 2 weight (instead of using the graph object)
    my %_node_2_weight;

    my %graph_sequences;

    # 2 - iteratively add reference paths to graph
    foreach my $reference_url ( keys( %{ $token_sequences } ) ) {
	
	my $reference_gist_sequence = $this->map_to_wordgraph_node_sequence( $graph , $token_sequences->{ $reference_url } );
	
	# update path with final sequence of nodes !
	my $updated_reference_gist_sequence = $this->_insert_path( \%_key_2_nodes , \%_node_2_key , \%_node_2_weight , $graph , $reference_url , $reference_gist_sequence );

	$graph_sequences{ $reference_url } = $updated_reference_gist_sequence;

    }

    return \%graph_sequences;

}

# Insert complete path into a word graph
sub _insert_path {

    my $this = shift;
    my $_key_2_nodes = shift;
    my $_node_2_key = shift;
    my $_node_2_weight = shift;
    my $graph = shift;
    my $path_label = shift;
    my $path_sequence = shift;

    # Just as \cite{Filippova} we allow for cycles --> linear similarity not sufficient w/in category
    # 1 - align unambiguous terms (single occurrence in graph and path)

    my @filtered_path_sequence = @{ $path_sequence };

    # 2 - map nodes to their alignment key (also include context ?)
    my @annotated_path_sequence;
    my %frequencies;
    for (my $i=0; $i<scalar(@filtered_path_sequence); $i++) { 

	my $path_element = $filtered_path_sequence[ $i ];

	my %annotations;
	$annotations{ $ANNOTATION_KEY_INDEX } = $i;
	$annotations{ $ANNOTATION_KEY_PATH_LABEL } = $path_label;

	# Use POS-lc(SURFACE) as node key ?
	my $path_element_key = $path_element->shared_key();
	$annotations{ $ANNOTATION_KEY_KEY } = $path_element_key;

	# Is this element associated with a slot location ?
	$annotations{ $ANNOTATION_KEY_IS_SLOT } = ( $path_element->abstract_type() =~ m/^SLOT_/ ) ? 1 : 0;
	
	# update frequency data (will be used towards the "soft" identification of stopwords)
	$frequencies{ $path_element_key }++;

	push @annotated_path_sequence , [ \%annotations , $path_element ];

    }

    # 3 - compute ambiguity levels
    map { $_->[0]->{ $ANNOTATION_KEY_AMBIGUITY } = $this->_ambiguity_level( $_key_2_nodes , $_node_2_key , $_node_2_weight , \%frequencies , $_ ); } @annotated_path_sequence;

    # 4 - sort elements by increasing level of ambiguity
    my @sorted_path_sequence = sort { $a->[0]->{ $ANNOTATION_KEY_AMBIGUITY } <=> $b->[0]->{ $ANNOTATION_KEY_AMBIGUITY } } @annotated_path_sequence;

    # 4 - align nodes
    my %path_status;
    my @node_sequence = map { $_->[ 1 ]; } sort { $a->[0]->{ $ANNOTATION_KEY_INDEX } <=> $b->[ 0 ]->{ $ANNOTATION_KEY_INDEX } } map { $this->_insert_node( $_key_2_nodes , $_node_2_key , $_node_2_weight , $graph , $path_sequence , $_ , \%path_status ); } @sorted_path_sequence;

    # TODO: this could be moved to the parent class
    $this->_create_path( $graph , $path_label , \@node_sequence );

    return \@node_sequence;

}

# 1 - non-stopwords (~600 ?) for which no candidate exists in the graph or for which an unambiguous mapping is possible
# 2 - non-stopwords for which there are either several possible candidates in the graph or which occur more than once in the sentence
# 3 - stopwords

# An equivalent implementation is to sort path elements according to their ambiguity level given the current status of the graph being constructed
# stopwords --> get frequency count from reference cluster

sub _ambiguity_level {

    my $this = shift;
    my $_key_2_nodes = shift;
    my $_node_2_key = shift;
    my $_node_2_weight = shift; 
    my $frequencies = shift;
    my $source_element = shift;
    
    my $source_element_key = $source_element->[ 0 ]->{ ${ANNOTATION_KEY_KEY} };
    my $base_ambiguity = $frequencies->{ $source_element_key };

    # means we must maintain a key --> [ nodes ] index
    my $vertices = $_key_2_nodes->{ $source_element_key } || [];
    my $vertex_count = scalar( @{ $vertices } );

    my $ambiguity = $base_ambiguity * ( 1 + $vertex_count );

    return $ambiguity;
    
}

# map nodes according to greater context overlap (preceding and succeeding words), or if same overlap, frequency of the node (i.e. number of paths in which it has been included so far)
sub _insert_node {

    my $this = shift;
    my $_key_2_nodes = shift;
    my $_node_2_key = shift;
    my $_node_2_weight = shift;
    my $graph = shift;
    my $path_sequence = shift;
    my $annotated_element = shift;
    my $path_status = shift;

    my $annotations = $annotated_element->[ 0 ];
    my $source_element = $annotated_element->[ 1 ];

    my $path_label = $annotations->{ $ANNOTATION_KEY_PATH_LABEL };

    # 1 - determine node key
    my $source_element_key = $source_element->shared_key();

    # 2 - retrieve matching graph nodes
    my $candidate_vertices = $_key_2_nodes->{ $source_element_key } || [];

    # 3 - determine whether a new node should be created
    my $ambiguity_level = $annotations->{ $ANNOTATION_KEY_AMBIGUITY };
    
    my $create_new = 1;
    my $node = undef;

    if ( scalar( @{ $candidate_vertices } ) && $ambiguity_level ) {
	
	# find best potential candidate
	# need to decide if one of the existing nodes can be used as a host
	
	my $best_candidate = undef;
	my $best_candidate_score = -1;
	my $best_candidate_frequency = 0;

	foreach my $candidate_node ( grep { ! $path_status->{ $_ } } @{ $candidate_vertices } ) {
	    
	    if ( defined( $path_status->{ $candidate_node } ) ) {
		# This node already appears in the current path
		next;
	    }
	    
	    # Default so that a candidate is found only if there is some level of filter match overall
	    # TO CHECK !
	    my $candidate_score = 0;
	    my $candidate_frequency = $_node_2_weight->{ $candidate_node };
	  
	    my $current_index = $annotations->{ $ANNOTATION_KEY_INDEX };

	    # 1 - predecessors data
	    my $path_predecessor = _get_path_element( $path_sequence , $current_index - 1 );
	    my @candidate_predecessors = $graph->predecessors( $candidate_node );
	    
	    # 2 - successors data
	    my $path_successor = _get_path_element( $path_sequence , $current_index + 1 );
	    my @candidate_successors = $graph->successors( $candidate_node );

	    # 3 - compute overlap match for candidate node
	    my $match_count = 0;
	    foreach my $entry ( ( [ $path_predecessor , \@candidate_predecessors ] , [ $path_successor , \@candidate_successors ] ) ) {

		my $path_neighbor = $entry->[ 0 ];
		my $graph_neighbors = $entry->[ 1 ];
		
		if ( $path_neighbor ) {
		    
		    my $path_neighbor_key = $path_neighbor->shared_key();
		    
		    foreach my $candidate_neighbor (@{ $graph_neighbors }) {
			# HERE: candidate_neighbor is not an "element"
			# --> mapping from node to elements ? --> pos and surface match (ok), what else ?
			if ( $_node_2_key->{ $candidate_neighbor } eq $path_neighbor_key ) {
			    $match_count++;
			    last;
			}
		    }

		}

	    }
  	    
	    if ( $candidate_score >= $best_candidate_score ) {
		
		if (
		    ( $candidate_score > $best_candidate_score ) ||
		    ( $candidate_frequency > $best_candidate_frequency )
		    ) {
		    $best_candidate = $candidate_node;
		    $best_candidate_score = $candidate_score;
		    $best_candidate_frequency = $candidate_frequency;
		}
	    
	    }

	}
	
	if ( defined( $best_candidate ) ) {
	    $node = $best_candidate;
	    $create_new = 0;
	}
	
    }

    # Create a new vertex
    if ( $create_new ) {

	# get new node instance
	# CURRENT : would anything break if we were to add more than one node through this call ?
	$node = $graph->add_vertex( $source_element , scalar(@{ $candidate_vertices }) );
	
	# update candidate map
	push @{ $candidate_vertices } , $node;
	if ( ! scalar( @{ $candidate_vertices } ) ) {
	    $_key_2_nodes->{ $source_element_key } = [];
	}
	push @{ $_key_2_nodes->{ $source_element_key } } , $node;

	# update node 2 key mapping
	$_node_2_key->{ $node } = $source_element_key;

    }
    
    # Keep track of current vertex weight locally (will be updated at the graph level once we add the paths)
    $_node_2_weight->{ $node } = ( $_node_2_weight->{ $node } || 0 ) + 1;

    # TODO : this needs to be removed
    # If the current chunk is of a slot type, we populate the data associated with this node
    if ( $annotations->{ $ANNOTATION_KEY_IS_SLOT } ) {
	$node->set_slot_filler( $path_label , $source_element->surface() );
    }
    else {
	$graph->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT , 0 );
    }
    
    # Register this node for the current gist
    if ( defined( $path_status->{ $node } ) ) {
	die "This should never happen - we have selected a node that is already part of the current path - $node";
    }
    $path_status->{ $node } = 1;

    # return the selected/created node
    return [ $annotations , $node ];

}

# get path element
sub _get_path_element {

    my $path_sequence = shift;
    my $index = shift;
    
    # 1 - make sure we are dealing with a valid index
    # 
    if ( $index < 0 || $index >= scalar(@{ $path_sequence }) ) {
	return undef; 
    }

    return $path_sequence->[ $index ];

}

__PACKAGE__->meta->make_immutable;

1;

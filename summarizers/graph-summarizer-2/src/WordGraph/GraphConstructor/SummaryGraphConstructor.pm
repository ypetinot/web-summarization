package WordGraph::GraphConstructor::SummaryGraphConstructor;

use strict;
use warnings;

use JSON;

use Moose;

# TODO
extends 'WordGraph::GraphConstructor';

my $DEBUG = 0;

sub construct_core {

    my $this = shift;
    
    my @updated_paths;

    # 2 - iteratively add reference paths to graph
    foreach my $reference_url ( keys( %{ $this->_paths_raw() } ) ) {
	
	my $reference_gist_sequence = $this->_paths_raw()->{ $reference_url };
	
	# update path with final sequence of nodes !
	my $updated_reference_gist_sequence = $this->_insert_path( $reference_url , $reference_gist_sequence );
	
	if ( $DEBUG ) {
	    $this->_check_path( $updated_reference_gist_sequence , $reference_url );
	}
	
	push @updated_paths, $updated_reference_gist_sequence;

    }

    return \@updated_paths;

}

sub _insert_path {

    my $this = shift;
    my $url = shift;
    my $sequence = shift;

    my %path_status;

    # Just as \cite{Filippova} we allow for cycles --> linear similarity not sufficient w/in category
    # 1 - align unambiguous terms (single occurrence in graph and path)
    my @mapped_sequence = map { $this->_insert_node( $_ , $url , \%path_status , [] ); } grep { defined( $_ ); } @{ $sequence };

    # 3 - stop words mapped only if overlap in neighbors --> convert to a top 50% word rule ? might make sense w/in categories
    # TODO ?
    
    # TODO: this could be moved to the parent class
    $this->_create_path( $url , \@mapped_sequence );

    return \@mapped_sequence;
    
}

sub _check_path {

    my $this = shift;
    my $sequence = shift;
    my $url = shift;

    # Confirm that the nodes in the generated path are effectively tied to the current path
    foreach my $node (@{ $sequence }) {
	
	if ( $this->_graph()->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {
	    
	    my $node_data = decode_json( $this->_graph()->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA ) );
	    if ( ! defined( $node_data->{ $url } ) ) {
		die "We have a problem - no target data associated with node $node for URL $url ...";
	    }
	    
	}
	
    }

    return 1;

}

#TODO: get rid of node_map
sub _insert_node {

    my $this = shift;
    
    # Surface form of the node to add
    my $token = shift;
    my $surface = WordGraph::_normalized($token->[0]);
    my $data = $token->[3];

    # Id for the current gist
    my $label = shift;

    # Nodes that already appear in the current gist (should we maintain this as a sequence ?)
    my $nodes_status = shift;

    # The only things that prevents use from reusing an existing node is its expected context
    # TODO: select existing node with the most compatible context
    my $filter = shift;
    
    my $create_new = 1;
    my $node = $surface;
    
    my $node_map = {};
    my $node_map_json = $this->_graph()->get_graph_attribute( 'node_map' );
    if ( defined( $node_map_json ) ) {
	$node_map = decode_json( $this->_graph()->get_graph_attribute( 'node_map' ) );
    }
    
    # If no node exist for this surface form, we can create it
    if ( ! defined( $node_map->{ $surface } ) ) {
	$node_map->{ $surface } = [];
	$create_new = 1;
    }
    else {
	
	# need to decide if one of the existing nodes can be used as a host
	
	my $best_candidate = undef;
	my $best_candidate_score = -1;
	
	foreach my $candidate_node (@{ $node_map->{ $surface } }) {
	    
	    if ( defined( $nodes_status->{ $candidate_node } ) ) {
		# This node already appears in the current path
		next;
	    }
	    
	    # Default so that a candidate is found only if there is some level of filter match overall
	    # TO CHECK !
	    my $candidate_score = 0;
	    
	    my @candidate_neighbors = $this->_graph()->neighbors( $candidate_node );
	    foreach my $candidate_neighbor (@candidate_neighbors) {
		
		foreach my $filter_node (@{ $filter }) {
		    
		    if ( $candidate_neighbor->get_vertex_attribute( $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_VERBALIZATION ) eq $filter_node ) {
			$candidate_score++;
		    }
		    
		}
		
	    }
	    
	    if ( $candidate_score > $best_candidate_score ) {
		$best_candidate = $candidate_node;
		$best_candidate_score = $candidate_score;
	    }
	    
	}
	
	if ( defined( $best_candidate ) ) {
	    $node = $best_candidate;
	    $create_new = 0;
	}
	
    }
    
    # Create a new node if required
    if ( $create_new ) {
	my $current_count = scalar( @{ $node_map->{ $surface } } );
	if ( $current_count ) {
	    $node = join( "/" , $surface , $current_count );
	}
	push @{ $node_map->{ $surface } } , $node;
    }
    
    # Actually create underlying vertex
    if ( ! $this->_graph()->has_vertex( $node ) ) {
	
	$this->_graph()->add_vertex( $node );
	
	# set vertex verbalization (label)
	$this->_graph()->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_VERBALIZATION , $surface );	
	$this->_graph()->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA, encode_json( {} ) );
	
    }
    
    # TODO: this is a good place to update the vertex importance ?
    $this->_graph()->set_vertex_weight( $node , ( $this->_graph()->get_vertex_weight( $node ) || 0 ) + 1 );
    
    if ( defined ( $data ) ) {
	$this->_graph()->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT , 1 );
	my $current_data = decode_json( $this->_graph()->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA ) );
	$current_data->{ $data->[ 0 ] } = $data;
	$this->_graph()->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA , encode_json( $current_data ) );
    }
    else {
	$this->_graph()->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT , 0 );
    }
    
    # Register this node for the current gist
    $nodes_status->{ $node } = 1;
    
    # Update node map
    $this->_graph()->set_graph_attribute( 'node_map' , encode_json( $node_map ) );
    
    return $node;
    
}


no Moose;

1;

package GistGraph::InferenceModel::Flow;

# Performs gist inference using a (maximum ?) flow approach

use strict;
use warnings;

use Moose;

use GistGraph::Gist;
use GistGraph::InferenceModel::Template; # Should we derive from this class instead ?
use Similarity;

use Graph;
use Graph::Directed;
use Graph::Undirected;

extends 'GistGraph::InferenceModel';

# run inference given a GistModel and a UrlData instance
sub run_inference {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;

    # 1 - select base gist ( still required for now )
    #my $base_gist_id = $this->_select_base_gist( $mode, $gist_model , $url_data );
    my $base_gist_id = undef;

    # 2 - build flow network ( should this be the result of a training step ? )
    my $flow_network = $this->_build_flow_network( $gist_model , $url_data , $base_gist_id );

    # 3 - run generation following the template defined by the base gist
    my $gist = $this->_max_flow( $gist_model , $url_data , $flow_network );

    return $gist;

}

# build flow network
sub _build_flow_network {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;
    my $base_gist_id = shift;

    # edge capacity: ratio of training gists (overall) that possess this particular transition (irrespective of the actual edge verbalization for now, we'll just pick the most likely one)
    # if two nodes cooccur but are no neighbor, just enforce a capacity of 0 (or a tiny value) ==> edge capacity = ratio of gists where the connected nodes appear as neighbors
    # The graph is connected by definition: every gist is a path from the bog node to the eog node
    
    # 1 - particle starts at the source with a given amount of energy, with which it needs to reach the sink of the graph --> implicitly constrains the length of gists that can be generated
    # The more nodes the particle visits, the more it loses energy (ideally we would like to reach the particle with the least energy possible ? Maybe rank options bases on how much energy remains at the end)
    # Starting energy: lowest gist energy observed / mean gist energy observed / highest gist energy observed / distribution/prior over energies ?

    # 2 - visiting rare/unlikely nodes has a large energy cost on the particle (like crossing an energy barrier ?)
    # Conversely visiting a frequent node / traversing a frequent edge has a low energy cost

    # Cost of traversing an edge between two nodes: proportional to how frequently these two nodes are connected by an edge (so 0 if the nodes are always connected by it, inf if the nodes are never connected by it), further parameterized by the cooccurence likelihood, typical distance (i.e. are they neighbors or always remote), the choice of edge verbalization, the directionality of the connection, etc. Make its improbable, although not impossible, to jump between nodes that cooccur, but usually not/never as neighbors.
    # Cost of visting a node: proportional to its appearance likelihood, and, if it is an abstracted node, to the confidence in the extracted value. Note that the appearance likelihood directly reflects how relevant a node is given the input content.

    # 3 - inference is search in the graph (e.g. breadth first search) for the lowest (remaining) energy path in the graph
    # Moving the weight of nodes onto edges, this can probably be approximated/implemented as a lowest cost path search between the source and the sink.

    # Should there be a way to gain energy ?

    # TODO:
    # Learn how to create random jumps within the graph
    # Any interest in causing the energy to increase at certain location of the graph ? --> problem is that this could lead to the creation of longer gists / infinite gists if there are loops in the graph
    # Given the training gists, how do you parameterize the graph so that the total energy of gists is minimized ? --> Energy-based Summarization Model

    # Create a directed graph.
    my $flow_network = Graph::Undirected->new;
    
    # Iterate over gist graph nodes
    my @gg_nodes = values( %{ $gist_model->gist_graph()->nodes() } );
    foreach my $gg_node (@gg_nodes) {
	$flow_network->add_vertex( $gg_node->id() );
    }

    my $tiny = 0.00000001;

    # Iterate over gist graph edges
    my @gg_edges = values( %{ $gist_model->gist_graph()->edges() } );
    foreach my $gg_edge (@gg_edges) {

	

	# to/from node weights
	my $from_weight = 1 / ( $tiny + $gist_model->np_appearance_model()->get_probability( $gg_edge->from() ) );
	my $to_weight = 1 / ( $tiny + $gist_model->np_appearance_model()->get_probability( $gg_edge->to() ) );

	# edge intrisic weight
	my $edge_compatibility_weight = 1 / ( $tiny + $gg_edge->get_compatibility() );
	my $edge_proximity_weight = 1 / ( $tiny + $gg_edge->get_proximity() );
	my $edge_directionality_weight = 1;
	my $edge_weight = $edge_compatibility_weight * $edge_proximity_weight * $edge_directionality_weight;

	my $weight = $from_weight * $edge_weight * $to_weight;

	$flow_network->add_weighted_edge( $gg_edge->from() , $gg_edge->to() , $weight );
    }

    # if a base gist is provided, we adjust the flow network accordingly
    if ( defined( $base_gist_id ) ) {
	
	# fetch gist object for base gist
	my $base_gist = $gist_model->gist_graph()->get_gist( $base_gist_id );
	
	# TODO
	
    }

    return $flow_network;

}

# max flow generation
sub _max_flow {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;
    my $flow_network = shift;

    my $source_node = $gist_model->gist_graph()->get_bog_node();
    my $sink_node = $gist_model->gist_graph()->get_eog_node();

    # extract shortest path between the source and sink nodes
    # TODO: in future version the shortest path should also include the best possible edge verbalization
    my @path = $flow_network->SP_Dijkstra( $source_node->id() , $sink_node->id() );


    if ( 1 ) {

	my @path2;
	
	my $sptg = $flow_network->SPT_Dijkstra($source_node);
	my $current_vertice = $sink_node->id();
	my $valid = 1;
	while ( $current_vertice ne $source_node->id() ) {
	    
	    my $u = $sptg->get_vertex_attribute($current_vertice, 'p');
	    my $w = $sptg->get_vertex_attribute($current_vertice, 'weight');
	    
	    if ( ! defined( $u ) || $current_vertice eq $u ) {
		# print STDERR "We just hit a snag ...\n";
		last;
	    }
	    
	    print STDERR "Weight for $current_vertice: $w\n";
	    
	    unshift @path2, $current_vertice;
	    $current_vertice = $u;
	    
	}
	unshift @path2, $source_node->id();

    }

    # turn shortest path into gist object
    my $gist = $gist_model->gist_graph()->get_blank_gist( $url_data->get_data()->{'url'} );

    foreach my $vertice (@path) {
	my $gg_node = $gist_model->gist_graph()->nodes()->{ $vertice };	
	if ( defined( $gg_node ) ) {
	    $gist->push_node( $gg_node );
	}
	else {
	    print STDERR "Invalid node id returned: $vertice\n";
	}
    }

    return $gist;

}

no Moose;

1;

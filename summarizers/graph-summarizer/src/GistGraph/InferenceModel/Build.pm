package GistGraph::InferenceModel::Build;

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
use Graph::Writer;
use List::MoreUtils qw/uniq/;

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
    my $gist = $this->_build( $gist_model , $url_data , $flow_network );

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
    my $flow_network = Graph::Directed->new;
    
    # Iterate over gist graph nodes
    my @gg_nodes = values( %{ $gist_model->gist_graph()->nodes() } );
    foreach my $gg_node (@gg_nodes) {
	# print STDERR "adding node: " . $gg_node->id() . "\n";
	$flow_network->add_vertex( $gg_node->id() );
    }

    my $tiny = 0.00000001;

    # Iterate over gist graph edges
    my @gg_edges = values( %{ $gist_model->gist_graph()->verbalization_edges() } );
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

	# print STDERR "adding edge: " . $gg_edge->from() . " --> " . $gg_edge->to() . "\n";
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

# build generation
sub _build {

    my $this = shift;
    my $gist_model = shift;
    my $url_data = shift;
    my $flow_network = shift;

    # 1 - determine set of nodes that must/should appear according to the appearance model
    my %must_appear;
    my @sorted_nodes = sort { $must_appear{ $a } <=> $must_appear{ $b } } map {
	$_->id();
    } 
    grep {
	
	my $appearance_probability = $gist_model->np_appearance_model()->get_probability( $_->id() );
	if ( $appearance_probability > 0.5 ) {
	    # TODO: topological sort
	    $must_appear{ $_->id() } = $_->position();
	    #$must_appear{ $_->id() } = $appearance_probability;
	    1;
	}
	else {
	    0;
	}

    }
    values( %{ $gist_model->gist_graph()->nodes() } );
    
    # 2 - iteratively build path
    my %seen;
    my @path;
    while ( scalar( @sorted_nodes ) >= 2 ) {
	
	# start with the first two nodes
	my $node1 = shift @sorted_nodes;
	my $node2 = shift @sorted_nodes;

	# find shortest path between these two nodes
	my @local_path = $flow_network->SP_Dijkstra( $node1 , $node2 );
	
	# just in case
	if ( ! scalar(@local_path) ) {
	    print STDERR "Unable to find a path between $node1 and $node2 ... will remove $node2\n";
	    unshift @sorted_nodes, $node1;
	    next;
	}

	# update complete path
	# print STDERR "appending path: " . join(" ", @local_path) . "\n";
	push @path, @local_path;

	# now remove path from the flow network
	$flow_network = $flow_network->delete_path( @local_path );
	
	# remove all the nodes on this path, except for the last one
	for (my $i=0; $i<scalar(@local_path)-1; $i++) {
	    $flow_network = $flow_network->delete_vertex( $local_path[$i] );
	    if ( defined( $seen{ $local_path[$i] } ) ) {
		print STDERR "Local path contains a previously seen node ...\n";
	    }
	    $seen{ $local_path[$i] } = 1;
	}

	# prepend node2 to the list of nodes to process
	unshift @sorted_nodes, $node2;

	# update sorted nodes
	@sorted_nodes = grep { !defined( $seen{ $_ } ); } @sorted_nodes;
	
    }

    @path = uniq @path;

    # turn shortest path into gist object
    my $gist = $gist_model->gist_graph()->get_blank_gist( $url_data->get_data()->{'url'} );

    my $gg_previous_node = undef;
    for (my $i=0; $i<scalar(@path); $i++) {

	my $current_vertice = $path[ $i ];

	my $gg_node = $gist_model->gist_graph()->nodes()->{ $current_vertice };	

	if ( defined( $gg_previous_node ) ) {
	    my $gg_edge = $gist_model->gist_graph()->get_verbalization_edge( $gg_previous_node , $gg_node );
	    if ( ! defined $gg_edge ) {
		print STDERR "Unable to retrieve edge: " . $gg_previous_node->id() . " --> " . $gg_node->id() . "\n";
	    }
	    my $most_likely_edge_verbalization_index = $gg_edge->mle_verbalization();
	    $gist->push_edge( $gg_edge , $most_likely_edge_verbalization_index );
	}
	
	if ( defined( $gg_node ) ) {
	    my $most_likely_node_verbalization_index = $gg_node->mle_verbalization();
	    # need class/metho that directly picks MLE node+edge verbalizations as nodes are being pushed to the gist object
	    $gist->push_node( $gg_node , $most_likely_node_verbalization_index );
	}
	else {
	    print STDERR "Invalid node id returned: $current_vertice\n";
	}

	# update previous vertice
	$gg_previous_node = $gg_node;

    }

    return $gist;

}

no Moose;

1;

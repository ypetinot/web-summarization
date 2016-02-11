package Graph::MinCut;

use Moose;
use POSIX;

our $DEBUG=1;

# compute min-cut for the provided graph and source/sink nodes
sub analyze {

    my $that = shift;
    my $network = shift;
    my $source_node = shift;
    my $sink_node = shift;

    # create residual network
    # TODO: is the deep copy necessary to copy weights ?
    my $residual_network = $network->deep_copy();
    
    # for convenience, we keep track of saturated edges in the residual network
    my @saturated_edges;

    while ( my @path = $residual_network->SP_Dijkstra($source_node,$sink_node) ) {

	# 1 - determine bottleneck capacity for the current (augmenting) path
	my $bottleneck_capacity = LONG_MAX;
	for (my $i=1; $i<scalar(@path); $i++) {
	    my $current_capacity = $residual_network->get_edge_weight( $path[$i-1] , $path[$i] );
	    if ( $current_capacity < $bottleneck_capacity ) {
		$bottleneck_capacity = $current_capacity;
	    }
	}

	# 2 - update residual network
	for (my $i=1; $i<scalar(@path); $i++) {

	    my $edge_from = $path[$i-1];
	    my $edge_to = $path[$i];

	    my $current_edge_capacity = $residual_network->get_edge_weight( $edge_from , $edge_to ) || 0;
	    my $new_edge_capacity = $current_edge_capacity - $bottleneck_capacity;

	    my $current_reverse_edge_capacity = $residual_network->get_edge_weight( $edge_to , $edge_from ) || 0;
	    my $new_reverse_edge_capacity = $current_reverse_edge_capacity + $bottleneck_capacity;

	    $residual_network->set_edge_weight( $edge_from , $edge_to , $new_edge_capacity );
	    $residual_network->set_edge_weight( $edge_to , $edge_from , $new_reverse_edge_capacity );

	    if ( ! $new_edge_capacity ) {
		$residual_network->delete_edge( $edge_from , $edge_to );
		push @saturated_edges, [ $edge_from , $edge_to ];
	    }

	}

    }

    # create copy of network and remove saturated edges
    my $network_copy = $network->copy_graph();
    foreach my $saturated_edge (@saturated_edges) {

	my ($edge_from, $edge_to) = @{ $saturated_edge };

	$network_copy->delete_edge( $edge_from , $edge_to );
	$network_copy->delete_edge( $edge_to , $edge_from );

    }
    
    # Sanity check: verify there is no path between the source and the sink node
    if ( $DEBUG ) {

	my @path = $network_copy->SP_Dijkstra($source_node,$sink_node);
	if ( scalar(@path) ) {
	    print __PACKAGE__ . " - error - Min-cut operation failed ...";
	}

    }


    # Label nodes
    my %labels;
    _label_nodes( \%labels , $network_copy, $source_node );
    _label_nodes( \%labels , $network_copy, $sink_node);   

    # return node-to-label mapping
    return \%labels;
    
}

no Moose;

# determine node labels through graph traversal
sub _label_nodes {

    my $labels = shift;
    my $network = shift;
    my $root_node = shift;

    my %node2seen;
    my @queue = ( $root_node );

    while ( scalar(@queue) ) {

	my $current_node = shift @queue;
	$node2seen{ $current_node } = 1;

	if ( $current_node ne $root_node ) {
	    $labels->{ $current_node } = $root_node;
	}

	my @neighbors = $network->neighbors( $current_node );
	foreach my $neighbor (@neighbors) {
	    if ( $node2seen{ $neighbor } ) {
		next;
	    }
	    push @queue, $neighbor;
	}

    }

}

1;

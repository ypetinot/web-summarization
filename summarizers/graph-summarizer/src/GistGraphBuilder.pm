package GistGraphBuilder;

# Builds a gist graph given raw category data

use strict;
use warnings;

use Moose;

use GistGraph;

our $DEBUG = 1;
our $PLOT = 1;

# build gist graph
sub build {

    my $that = shift;
    my @params = @_;

    my %construction_params;
    while ( scalar(@params) ) {
	my $key = shift @params;
	my $value = shift @params;
	$construction_params{ $key } = $value;
    }

    # This should work ?
    my $gist_graph = new GistGraph( %construction_params );
    #my $gist_graph = new GistGraph( category_data => $construction_params{ 'category_data' } , model_directory => $construction_params{ 'model_directory' } );

    # 1 - map all chunks to nodes
    $that->_init_nodes( $gist_graph );
   
    # 2 - create edges
    $that->_init_edges( $gist_graph );

    # 3 - analyze/log raw graph
    $that->analyze($gist_graph,"raw",$PLOT,$DEBUG);

    # 4 - run specific processing, if any
    $that->process($gist_graph);

    # 5 - analyze processed graph
    $that->analyze($gist_graph,"post",$PLOT,$DEBUG);

    return $gist_graph;

}

# init nodes
sub _init_nodes {

    my $that = shift;
    my $gist_graph = shift;

    # create BOG node
    my $bog_node = new GistGraph::Node( raw_data => $gist_graph->raw_data() , name => $GistGraph::BOG_NODE_NAME );
    $gist_graph->nodes()->{ $bog_node->id() } = $bog_node;

    # create EOG node
    my $eog_node = new GistGraph::Node( raw_data => $gist_graph->raw_data() , name => $GistGraph::EOG_NODE_NAME );
    $gist_graph->nodes()->{ $eog_node->id() } = $eog_node;

    # create one node for every chunk in the underlying raw data
    my @chunks = @{ $gist_graph->raw_data()->chunks() };
    my $n_added = 0;
    foreach my $chunk (@chunks) {

	# we are only interested in Noun Phrases
	if ( ! $chunk->is_np() ) {
	    next;
	}

	# instantiate node, with link back to gist graph
	my $gist_graph_node = new GistGraph::Node( raw_data => $gist_graph->raw_data() , pos => $chunk->type() );
	
	# add underlying chunk
	# TODO: should this be part of the constructor ?
	$gist_graph_node->add( $chunk->id() );
	$n_added++;

	# add node to list of nodes
	$gist_graph->nodes()->{ $gist_graph_node->id() } = $gist_graph_node;

	# update chunk-2-node mapping
	$gist_graph->chunk2node()->{ $chunk->id() } = $gist_graph_node->id();

	if ( $DEBUG ) {
	    print STDERR "Added gist graph node for: " . $chunk->surface() . "\n";
	}

    }

    return $gist_graph;

}

# init edges
sub _init_edges {

    my $that = shift;
    my $gist_graph = shift;

    # scan raw summaries and create/update edges for every pair of adjacent NPs
    my @summaries = @{ $gist_graph->raw_data()->summaries() };
    for (my $i=0; $i<scalar(@summaries); $i++) {

	my $summary = $summaries[ $i ];

	my @np_buffer;
	my @structural_buffer;

	# push the BOG node in the np buffer
	push @np_buffer, $gist_graph->nodes()->{ $GistGraph::BOG_NODE_NAME };
	$gist_graph->nodes()->{ $GistGraph::BOG_NODE_NAME }->add_gist_occurrence( $i , 0 );

	for (my $j=0; $j<scalar(@{ $summary }); $j++) {
	    
	    my $chunk_id = $summary->[$j];
	    my $chunk = $gist_graph->raw_data()->get_chunk( $chunk_id );

	    if ( $chunk->is_np() ) {

		my $current_node = $gist_graph->nodes()->{ $gist_graph->chunk2node()->{ $chunk->id() } };
		push @np_buffer, $current_node;

		# create edge for current pair
		$gist_graph->create_or_update_edge( @np_buffer , $i, \@structural_buffer );
		$current_node->add_gist_occurrence( $i , ( $j + 1 ) / ( scalar( @{ $summary } ) + 2 ) );

		# also add "co-occurence edges"
		my $current_pos = scalar(@np_buffer);
		if ( $current_pos > 2 ) {
		    for (my $k=1; $j<$current_pos-2; $k++) {
			$gist_graph->create_or_update_edge( $current_node, $np_buffer[$k], $i , [] ,  $current_pos - 2 - $k);
		    }
		}

		shift @np_buffer;
		@structural_buffer = ();
	
	    }
	    else {

		push @structural_buffer, $chunk->id();

	    }

	}

	# push the EOG node in the np buffer
	push @np_buffer, $gist_graph->nodes()->{ $GistGraph::EOG_NODE_NAME };
	$gist_graph->create_or_update_edge( @np_buffer , $i, \@structural_buffer );
	$gist_graph->nodes()->{ $GistGraph::EOG_NODE_NAME }->add_gist_occurrence( $i , 1 );

    }

    return $gist_graph;

}

# process
sub process {

    my $that = shift;

    # Nothing by default

}

# analyze gist graph
sub analyze {

    my $that = shift;
    my $gist_graph = shift;
    my $label = shift;
    my $plot = shift || 0;
    my $check_integrity = shift || 0;

    # activate plotting if requested
    # TODO: should plot be a parameter of init ?
    if ( $plot ) {

	$gist_graph->do_plotting(1);
	$gist_graph->plot( $label );

    }

    # test integrity of gist graph
    if ( $DEBUG ) {
	if ( ! $gist_graph->check_integrity() ) {
	    die "Failed to produce a valid gist graph ...";
	}
    }

}

no Moose;

1;

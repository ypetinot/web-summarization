package WordGraph;

use strict;
use warnings;

#use WordGraph::DataExtractor;
use WordGraph::EdgeFeature::NodeDegree;
use WordGraph::EdgeFeature::NodeFrequency;
use WordGraph::EdgeFeature::NodePrior;
use WordGraph::EdgeFeature::NodeSemantics;
use WordGraph::EdgeFeature::NodeType;
use WordGraph::EdgeFeature::NodeNeighborhoodFrequency;
use WordGraph::Node;
use WordGraph::Node::Slot;
use WordGraph::Path;
use Web::Summarizer::Graph2::Definitions;
use Web::Summarizer::Token;

use Graph::Directed;
use Graph::Undirected;
use Graph::Reader::Dot;
use Graph::Reader::XML;
use JSON;
use List::Util qw(min);
use Scalar::Util qw/refaddr/;

use Moose;
use MooseX::NonMoose::InsideOut;
use namespace::autoclean;

extends 'Graph::Directed';
with('Space','WordGraph::ClassLoader');

# TODO: what we really need to do is make sure the reference data is clean UTF-8
use bytes;

my $DEBUG = 1;

sub FOREIGNBUILDARGS {

    my $class = shift;

    # The arguments are now in @_
    # http://blogs.perl.org/users/mark_a_stratman/2011/03/subclassing-tricky-non-moose-classes-constructor-problems.html
    
    my @new_args;

    return @new_args ;

}

# bog node
has 'bog_node' => ( is => 'ro' , isa => 'WordGraph::Node' , init_arg => undef , lazy => 1 , builder => '_bog_node_builder' );
sub _bog_node_builder {
    my $this = shift;
    return $this->_special_node_builder( $Web::Summarizer::Graph2::Definitions::NODE_BOG );
}

# eog node
has 'eog_node' => ( is => 'ro' , isa => 'WordGraph::Node' , init_arg => undef , lazy => 1 , builder => '_eog_node_builder' );
sub _eog_node_builder {
    my $this = shift;
    return $this->_special_node_builder( $Web::Summarizer::Graph2::Definitions::NODE_EOG );
}

sub _special_node_builder {
    my $this = shift;
    my $node_marker = shift;

    # TODO : could we have WordGraph::Node handle this (i.e. coerce a string into a Web::Summarizer::Token) ?
    my $special_token = new Web::Summarizer::Token( surface => $node_marker );
    return new WordGraph::Node( graph => $this , token => $special_token );

}

=pod
# data extractor
has 'data_extractor' => ( is => 'ro' , isa => 'WordGraph::DataExtractor' , init_arg => undef , lazy => 1 , builder => '_data_extractor_builder' );
sub _data_extractor_builder {

    my $this = shift;
    
    # Instantiate data extractor
    my $data_extractor = new WordGraph::DataExtractor();

    return $data_extractor;

}
=cut

# paths
has 'paths' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# paths2energy
has 'paths2energy' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# key 2 node mapping
has 'key2node' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# word 2 node mapping
has 'word2node' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# source node
has 'source_node' => ( is => 'rw' , isa => 'WordGraph::Node' , builder => '_get_source_node' , lazy => 1 );

# sink node
has 'sink_node' => ( is => 'rw' , isa => 'WordGraph::Node' , builder => '_get_sink_node' , lazy => 1 );

# successors cache
has '_successors_cache' => ( is => 'rw' , isa => 'HashRef[Str]' , default => sub { {} } );

=pod
# edge cost class
has 'edge_cost_class' => ( is => 'ro' , isa => 'Str' , required => 1 );

# (local) edge cost
# Note: also (should) act as a normalizer 
has 'edge_cost' => ( is => 'ro' , isa => 'WordGraph::EdgeCost' , builder => '_edge_cost_builder' , lazy => 1 );
sub _edge_cost_builder {
    my $this = shift;
    $this->load_class( $this->edge_cost_class() )->new( graph => $this );
}
=cut

# is empty ?
sub is_empty {
    my $this = shift;
    return ( ! scalar( keys( %{ $this->paths() } ) ) );
}

# Load graph
sub load {

    my $this = shift;
    my $serialization_directory = shift;

    my $input_graph = join( "/" , $serialization_directory , "graph.raw" );
    my $graph_reader = Graph::Reader::XML->new();
    my $graph = $graph_reader->read_graph( $input_graph );
    
    return $graph;

}

# Serialize graph
sub serialize {

    my $this = shift;
    my $output_directory = shift;
 
    # TODO : add model id
   
    my $output_graph_file = join( "/" , $output_directory , "graph" );
    my $output_graph_file_dot = join("/", $output_directory, "graph.dot");

    # 1 - Write graph to file (note that the graph remains unchanged for now)
    print STDERR "\tWriting out gist graph ...\n";
    my $writer = Graph::Writer::XML->new();
    my $writer_dot = Graph::Writer::Dot->new();
    $writer->write_graph( $this , $output_graph_file );
    $writer_dot->write_graph( $this , $output_graph_file_dot);
    
    # 2 - Write out final edge weights
    my $weights_json = encode_json( $this->feature_weights() );
    my $weights_file = join("/", $output_directory, "weights");
    open WEIGHTS_FILE, ">$weights_file" or die "Unable to create weights file ($weights_file): $!";
    print WEIGHTS_FILE $weights_json;
    close WEIGHTS_FILE;

}

# simple normalization function
sub _normalized {

    my $string = shift;

    my $normalized_string = lc( $string );
    return $normalized_string;

}

sub register_path {
    
    my $this = shift;
    my $label = shift;
    my $path = shift;
    my $instance = shift;
    my $energy = shift;

    # update vertex weights
    map {
	my $current_vertex = $_;
	my $current_vertex_weight = $this->get_vertex_weight( $current_vertex ) || 0;
	$this->set_vertex_weight( $current_vertex , $current_vertex_weight + 1 );
    } @{ $path };
    
    # TODO: update edge weights ?

    # TODO: is there any need to copy the path, just in case ?
    my @path_copy = @{ $path };
    my $path_object = new WordGraph::Path( graph => $this , node_sequence => \@path_copy , object => $instance , source_id => 'wordgraph' );
    $this->paths()->{ $label } = $path_object;
    $this->paths2energy()->{ $label } = $energy;

    return $path_object;

}

# overloading vertex creation
sub add_vertex {

    my $this = shift;
    my $token = shift;
    my $copy_index = shift;

    # Instantiate node object
    my $node = ( ! $token->is_slot_location ) ? new WordGraph::Node( graph => $this , token => $token , index => $copy_index ) :
	new WordGraph::Node::Slot( graph => $this , token => $token , index => $copy_index );

    # 1 - make sure the node id does not already exist (should we handle this here ?)
    if ( $this->has_vertex( $node ) ) {
	die "Cannot add vertex with overlapping keys ! --> $node";
    }

    # call original method
    $this->SUPER::add_vertex( $node );

    # register node
    $this->key2node()->{ $node } = $node;

    my $token_surface_normalized = _normalized( $token->surface() );
    if ( ! defined( $this->word2node()->{ $token_surface_normalized } ) ) {
	$this->word2node()->{ $token_surface_normalized } = [];
    }
    push @{ $this->word2node()->{ $token_surface_normalized } } , $node;

    return $node;

}

sub get_nodes_by_surface {

    my $this = shift;
    my $surface = shift;

    my $missing_node = 0;
    my @individual_nodes = map {
	if ( scalar( @{ $_ } ) ) { $_; } else { $missing_node = 1; }
    } map { $this->get_node_by_surface( $_ ); } split /\s+/, $surface;

    if ( $missing_node ) {
	return [];
    }		 

=pod
    # at each level, we must have one edge between 
    for (my $i=0; $i<scalar(@individual_nodes); $i++) {
	if ( ! scalar( @{ $individual_nodes[ $i ] } ) ) {
	    return [];
	}
    }
=cut

    my @matches;

    my @status = map { [ 0 , scalar( @{ $_ } ) - 1 ]; } @individual_nodes;
    while ( 1 ) {

	my $cursor = scalar( @status ) - 1;

	# check whether current configuration is a match
	my @configuration;
	for (my $i = 0; $i < scalar(@status); $i++) {
	    push @configuration, $individual_nodes[ $i ]->[ $status[ $i ]->[ 0 ] ];
	}
	my $is_match = 1;
	for (my $i = 1; $i < scalar(@configuration); $i++) {
	    if ( ! $this->has_edge( $configuration[ $i - 1 ] , $configuration[ $i ] ) ) {
		$is_match = 0;
		last;
	    }
	}
	
	if ( $is_match ) {
	    push @matches, \@configuration;
	}
	
	# stop condition
	my $do_stop = 1;
	map { $do_stop = $do_stop && ( $_->[ 0 ] == $_->[ 1 ] ) } @status;
	if ( $do_stop ) {
	    last;
	}

	# move to next configuration
	cursor_update: while ( 1 ) {
	    $status[ $cursor ]->[ 0 ] = ( $status[ $cursor ]->[ 0 ] + 1 ) % ( $status[ $cursor ]->[ 1 ] + 1 );
	    if ( ! $status[ $cursor ]->[ 0 ] ) {
		$cursor = ( $cursor - 1 ) % scalar(@status)
	    }
	    else {
		last cursor_update;
	    }
	}

    }

    return \@matches;

}

sub get_node_by_surface {

    my $this = shift;
    my $surface = shift;

    return $this->word2node()->{ _normalized( $surface ) } || [];

}

# get source node
sub _get_source_node {

    my $this = shift;

    my $random_path = $this->get_random_path();

    return $random_path->node_sequence()->[ 0 ];

}

# get sink node
sub _get_sink_node {

    my $this = shift;

    my $random_path = $this->get_random_path();
    
    return $random_path->get_element( $random_path->length() - 1 );

}

# get path energy
sub get_path_energy {

    my $this = shift;
    my $label = shift;

    return $this->paths2energy()->{ $label };

}

# get random path
sub get_random_path {

    my $this = shift;

    my @path_keys = keys(%{ $this->paths() });
    my $n_paths = scalar(@path_keys);

    if ( ! $n_paths ) {
	die "Trying to get random path but no path has been added yet ...";
    }

    my $random_path = $this->paths()->{ $path_keys[ int( rand( $n_paths ) ) ] };

    return $random_path;

}

# number of (reference) paths registered with the graph
sub path_count {

    my $this = shift;

    return scalar( keys( %{ $this->paths() } ) );

}

# get successors for a given node
sub successors {
   
    my $this = shift;
    my $node = shift;
    my $instance = shift;
    my $activate_slots = shift || 0;

    # 1 - get list of raw successors from parent class
    my @raw_successors = $this->SUPER::successors( $node );

    my @successors;

    # 2 - replicate slot-node successors
    foreach my $raw_successor (@raw_successors) {

	if ( $DEBUG && ! $this->get_edge_attribute( $node , $raw_successor , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) ) {
	    die "Structural problem: edge ( $node --> $raw_successor ) does not exist !";
	}
	
	if ( $activate_slots && ref( $raw_successor ) eq 'WordGraph::Node::Slot' ) {

	    my $instance_url = $instance->url();

	    # Note: make sure we have the true slot filler covered for the training instances ...
	    if ( ! defined( $this->_successors_cache()->{ $instance_url } ) ||
		 ! defined( $this->_successors_cache()->{ $instance_url }->{ $raw_successor } ) ) {
		
		# create forked nodes for the target instance
		my $forked_nodes = $raw_successor->fork( $instance );

		my @_successors = @{ $forked_nodes };

		if ( $DEBUG ) {
		    foreach my $_successor (@_successors) {
			if ( ! $this->get_edge_attribute( $node , $_successor , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) ) {
			    die "Structural problem: edge ( $node --> $_successor ) does not exist !";
			}
		    }
		}

		if ( ! defined( $this->_successors_cache()->{ $instance_url } ) ) {
		    $this->_successors_cache()->{ $instance_url } = {};
		}
		$this->_successors_cache()->{ $instance_url }->{ $raw_successor } = \@_successors;

	    }

	    push @successors , @{ $this->_successors_cache()->{ $instance_url }->{ $raw_successor } };
	    
	    if ( $DEBUG ) {
		foreach my $_successor (@successors) {
		    my $val = $this->get_edge_attribute( $node , $_successor , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH );
		    if ( ! $val ) {
			die "Structural problem: edge ( $node --> $_successor ) does not exist !";
		    }
		    else {
			print STDERR join( "\t" , $node , $_successor , refaddr($_successor) , refaddr($_successor->clone_of()) || '' , $_successor->realize( $this->instance() ) , $val ) . "\n";
		    }
		}
	    }

	}
	else {

	    push @successors , $raw_successor;

	}

    }
    
    return @successors;

}

# make sure the graph is structured as it should
sub consistency {

    my $this = shift;

    my @edges = $this->edges();
    foreach my $edge (@edges) {

	# self edges cannot exist
#	if( $this->get_edge_attribute( $edge->[ 0 ] , $edge->[ 0 ] , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) ||
#	    $this->get_edge_attribute( $edge->[ 1 ] , $edge->[ 1 ] , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) ) {
#	    return 0;
#	}
	if ( $edge->[ 0 ] eq $edge->[ 1 ] ) {
	    return 0;
	}

=pod # not relevant anymore (especially when we create alternated paths in the word-graph) ?
	# each edge must have a width that is at least 1
	if( ! $this->get_edge_attribute( $edge->[ 0 ] , $edge->[ 1 ] , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) ) {
	    return 0;
	}
=cut

    }

    return 1;

}

# replicate graph according to a fixed edge weighting scheme
sub replicate {

    my $this = shift;
    my $edge_cost = shift;
    my $instance = shift;

    my $temp_graph = new Graph::Directed;

    # 1 - compute weight for all edges
    my @edges = $this->edges();
    foreach my $edge (@edges) {

	# Note : could just as well be a call to cost ?
	my $edge_cost = $edge_cost->compute( $this , $edge , $instance );

	$temp_graph->add_edge( @{ $edge } );
	$temp_graph->set_edge_weight( (@{ $edge } ) , $edge_cost );

    }
    
    return $temp_graph;

}

# top-K shortest paths
# http://en.wikipedia.org/wiki/Yen's_algorithm
# TODO: submit as contribution to the Graph package ? (is there any way to submit it without asking for "permission" ?)
sub top_k_shortest_paths {

    my $this = shift;
    my $edge_model = shift;
    my $k = shift;
    my $instance = shift;
    my $filter_op = shift || sub { return 1; };

    my @a;
    
    # 0 - replicate graph
    my $replicated_graph = $this->replicate( $edge_model , $instance );
    
    # 1 - determine A1 , the first shortest path
    my @a1 = $replicated_graph->SP_Dijkstra( $this->source_node() , $this->sink_node() );
    push @a, [ new WordGraph::Path( graph => $this , node_sequence => \@a1 , object => $instance->[ 0 ] ) , _path_cost( $replicated_graph , \@a1 ) ];
    
    # Heap to store the potential kth shortest path.
    my @b;

    # 2 - determine Ai, i \in 2 - K
    for ( my $i = 1; $i <= $k; $i++ ) {

	if ( $i > scalar( @a ) ) {
	    if ( $DEBUG ) {
		print STDERR ">> running out of shortest paths, must stop ...\n";
	    }
	    last;
	}

	if ( $DEBUG ) {
	    print STDERR ">> $i ...\n";
	}

	# TODO: if this is too slow, implement edge deletion/addition instead
	my $working_graph = $replicated_graph->deep_copy();

	# The spur node ranges from the first node to the next to last node in the shortest path
	for ( my $j = 0 ; $j < ( $a[ $i - 1 ]->[ 0 ]->length() - 1 ) ; $j++ ) {
	    
	    # Spur node is retrieved from the previous i-shortest path, i − 1.
	    my $spur_node = $a[ $i-1 ]->[0]->get_element( $j );

	    # The sequence of nodes from the source to the spur node of the previous i-shortest path.
	    my $root_path = _extract_sub_path( $a[ $i - 1 ]->[ 0 ] , 0, $j );

	    foreach my $p ( map { $_->[ 0 ]; } @a ) {

		if ( _path_equal( $root_path , _extract_sub_path( $p , 0 , $j ) ) ) {
		    # Remove the links that are part of the previous shortest paths which share the same root path.
		    $working_graph->delete_edge( $p->get_element( $j ) , $p->get_element( $j + 1 ) );
		}

	    }

	    # Calculate the spur path from the spur node to the sink.
	    my @spur_path = $working_graph->SP_Dijkstra( $spur_node , $this->sink_node() );
	    
	    if ( scalar( @spur_path ) ) {
		
		# Entire path is made up of the root path and spur path.
		my @total_path = ( @{ $root_path } , ( splice @spur_path , 1 ) );
		
		# Add the potential i-shortest path to the heap.
		# Note: we use the original (replicated graph) for cost computation since the working graph does not contain the root path anymore ...
		#push @b , [ \@total_path , _path_cost( $working_graph , \@total_path ) ];
		
		my $k_shortest_path_entry = [ new WordGraph::Path( graph => $this , node_sequence => \@total_path , object => $instance->[ 0 ] ) ,
					      _path_cost( $replicated_graph , \@total_path ) ];

		# TODO: make sure filtering at this stage does not incur any error
		if ( $filter_op->( $this , $instance , $k_shortest_path_entry ) ) {
		    push @b , $k_shortest_path_entry;
		}
		
	    }
	    else {
		
		# Technically we could just return if no shortest path exists ...
		if ( $DEBUG ) {
		    print STDERR "No shortest path found in the current sub-graph ...\n";
		}
		
	    }

	}
	
	# Sort the potential k-shortest paths by cost
	my @b_sorted = sort { $a->[ 1 ] <=> $b->[ 1 ] } @b;
	@b = @b_sorted;

	if ( scalar( @b ) ) {

	    # Add the lowest cost path becomes the k-shortest path
	    push @a , shift( @b );

	    # Keep the size of b to a minimum
	    # TODO: next optimization is to store the results of the ranker calls
	    my $b_max_size = $k - $i + 1;
	    if ( scalar( @b ) > $b_max_size ) {
		splice @b , $b_max_size;
	    }

	}
	    
    }
    
    return \@a;
    
}

# compute path cost
sub _path_cost {

    my $graph = shift;
    my $path = shift;

    my $path_cost = 0;

    for ( my $i = 0 ; $i < scalar( @{ $path } ) - 1 ; $i++ ) {
	my $edge_cost = $graph->get_edge_weight( $path->[ $i ] , $path->[ $i + 1 ] );
	if ( ! defined( $edge_cost ) ) {
	    die "Edge cannot have an undefined weight ...";
	}
	$path_cost += $edge_cost;
    }

    return $path_cost;
    
}

# extract sub-path
sub _extract_sub_path {

    my $path = shift;
    my $from = shift;
    my $to = shift;

    # This is allowed ...
    $to = min( $to , $path->length() - 1 );

    if ( $DEBUG && ( $from < 0 || ( $to > $path->length() - 1 ) ) ) {
	die "Path length does not match arguments ...";
    }

    my @subpath;
    for ( my $i = $from ; $i <= $to ; $i++ ) {
	push @subpath, $path->get_element( $i );
	if ( $DEBUG && ! defined( $subpath[ $i - $from ] ) ) {
	    die "We have a problem ...";
	}
    }

    return \@subpath;

}

# compare two paths
sub _path_equal {

    my $path_1 = shift;
    my $path_2 = shift;

    my $length_1 = scalar( @{ $path_1 } );
    my $length_2 = scalar( @{ $path_2 } );

    if ( $length_1 != $length_2 ) {
	# This is allowed ...
	#die "Comparing paths of different length ( $length_1 / $length_2 ) - should not happen in this context ...";
	return 0;
    }

    my $path_1_as_string = join( ":::" , @{ $path_1 } );
    my $path_2_as_string = join( ":::" , @{ $path_2 } );

    return ( $path_1_as_string eq $path_2_as_string );

=pod    
    for ( my $i = 0 ; $i < $length_1 ; $i++ ) {
	if ( $path_1->[ $i ] ne $path_2->[ $i ] ) {
	    return 0;
	}
    }

    return 1;
=cut

}

# overide get_edge_weight to use EdgeCost instance
# Note: set_edge_weight still has direct access to parent class
sub get_edge_weight {

    my $this = shift;
    my $from_node = shift;
    my $to_node = shift;
    my $instance = shift;

    if ( defined( $instance ) && $this->has_edge_cost() ) {
	return $this->edge_cost()->compute( $instance , [ $from_node , $to_node ] );
    }
    
    # TODO: make sure this is compatible with the way the Decoder class works currently
    return $this->SUPER::get_edge_weight( $from_node , $to_node ) || 0;

}

# override set_edge_weight to use EdgeCost instance
sub set_edge_weight {

    my $this = shift;
    my $from_node = shift;
    my $to_node = shift;
    my $weight = shift;
    my $instance = shift;

    if ( defined( $instance ) && $this->has_edge_cost() ) {
	# nothing - EdgeCost does not handle setting an edge weight directly
    }
    else {
	$this->SUPER::set_edge_weight( $from_node , $to_node , $weight );
    }

}

__PACKAGE__->meta->make_immutable;

1;

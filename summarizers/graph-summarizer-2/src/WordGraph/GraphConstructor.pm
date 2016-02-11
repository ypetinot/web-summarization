package WordGraph::GraphConstructor;

use strict;
use warnings;

#use Graph;
#use Graph::Directed;
#use Graph::Undirected;

use Moose;

# graph type (class)
has 'graph_type' => ( is => 'ro' , isa => 'Str' , required => 1 );
#trigger => \&_load_graph_type ,

# paths raw
has '_paths_raw' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# graph that is being built
has '_graph' => ( is => 'rw' , isa => 'Ref' , lazy => 1 , builder => '_initialize_graph' , reader => 'get_graph' );

my $DEBUG = 0;

sub _load_graph_type {

    my $this = shift;
    my $graph_type = shift;

    eval "use $graph_type;";

}

# graph builder
sub _initialize_graph {

    my $this = shift;
    
    # 1 - make sure the graph type is loaded
    $this->_load_graph_type( $this->graph_type() );

    # 2 - create new instance of graph type
    my $graph = $this->graph_type()->new;

    return $graph;

}

sub construct {

    my $this = shift;
    my $reference_paths = shift;

    # 1 - populate raw paths
    foreach my $reference_path (@{ $reference_paths }) {

	my $reference_url = $reference_path->[ 0 ];
	my $reference_gist_sequence = $reference_path->[ 1 ];

	$this->_paths_raw()->{ $reference_url } = $reference_gist_sequence;

    }

    # 2 - call actual construction method
    return $this->construct_core();

}

# Create path given sequence of "aligned" nodes (i.e. graph node ids)
sub _create_path {

    my $this = shift;
    my $path_label = shift;
    my $mapped_sequence = shift;

    # Once all the nodes have been aligned/inserted, we add/update edges (see \cite{Filippova2010}
    {
	my $previous_node = undef;
	foreach my $aligned_node (@{ $mapped_sequence }) {
	    
	    if ( defined( $previous_node ) ) { 
		$this->_insert_edge( $path_label , $previous_node , $aligned_node );
	    }

	    $previous_node = $aligned_node;

	}
    }
    
    # update global stats
    $this->_graph()->set_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT , ( $this->_graph()->get_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT ) || 0 ) + 1 );

}

sub _insert_edge {

    my $this = shift;
    my $url = shift;
    my $from_node = shift;
    my $to_node = shift;

    if ( ! defined( $from_node ) || ! defined( $to_node ) ) {
	die "We have a problem, invalid from/to node ...";
    }
    
    if ( ! $this->_graph()->has_edge( $from_node , $to_node ) ) {
	$this->_graph()->add_edge( $from_node , $to_node );
	$this->_graph()->set_edge_weight( $from_node , $to_node , 1 );
	$this->_graph()->set_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH , 1 );
    }
    else {
	$this->_graph()->set_edge_weight( $from_node , $to_node , $this->_graph()->get_edge_weight( $from_node , $to_node ) + 1 );
	$this->_graph()->set_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH , $this->_graph()->get_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) + 1 );
    }
    
}

no Moose;

1;

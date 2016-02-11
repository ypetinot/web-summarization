package WordGraph::GraphConstructor;

# Base class for all graph constructors
# Note : graph-constructors must be stateless

use strict;
use warnings;

use Web::Summarizer::Sentence;
use WordGraph;

use List::Util qw/min/;

use Moose;
use namespace::autoclean;
with('WordGraph::ClassLoader');

my $DEBUG = 0;

# TODO : does this belong in this class ? seems right in terms of encapsulation
# transformations
has 'transformations' => ( is => 'ro' , isa => 'ArrayRef' , predicate => 'has_transformations' );

# TODO : apply directly via role configuration
has 'transformations_sentences' => ( is => 'ro' , isa => 'ArrayRef' , predicate => 'has_transformations_sentences' );

sub construct {

    my $this = shift;
    my $entries = shift;
    my $target = shift;
    my $entries_ref = shift;

    # 1 - create new WordGraph instance
    # TODO: remove data extractor dependency, the data extractor is tied with the sentence objects
    my $graph = new WordGraph( graph_constructor => $this );

    # 2 - generate raw token sequences
    # TODO : do we want a class to abstract this process (i.e. ReferenceFusion)
    my %sentences;
    my %sentences2energy;
    # TODO : do we need this loop ?
    for (my $i=0; $i<scalar(@{ $entries }); $i++) {

	my $entry = $entries->[ $i ];

	# TODO : should the reference object even be referred to in this context ?
	my $reference_object = $entry->[ 0 ];
	my $reference_sentence = $entry->[ 1 ];
	my $reference_energy = $entry->[ 2 ];
	
	my $reference_sentence_key = $this->get_path_key( $reference_object , $i );

	# TODO : still needed ? if it is it should be moved to the adaptation stage
	# TODO : avoid attempting to load the transformation class twice
	if ( $this->has_transformations ) {
	    foreach my $transformation (@{ $this->transformations }) {
		$reference_sentence = $this->load_class( $transformation )->transform_sentence( $reference_sentence , $target , $entries_ref );
	    }
	}

	$sentences{ $reference_sentence_key } = $reference_sentence;
	$sentences2energy{ $reference_sentence_key } = $reference_energy;

    }

    # 2 - call actual construction method
    my $graph_paths = $this->construct_core( $graph , \%sentences );

    # 3 - register paths
    foreach my $reference_url (keys( %{ $graph_paths })) {
	$graph->register_path( $reference_url , $graph_paths->{ $reference_url } , $sentences{ $reference_url }->object ,
			       $sentences2energy{ $reference_url } );
    }

=pod # not relevant anymore
    # 3 - run transformation
    # TODO : having this here means the transformation (or the word-graph) is now responsible for updating the registered paths is they are affected by the transformation
    if ( $this->has_transformations ) {
	foreach my $transformation ( @{ $this->transformations } ) {
	    $graph = $this->load_class( $transformation )->transform( $graph , $target , $entries_ref );
	}
    }
=cut
    
    return $graph;

}

sub get_path_key {
    my $this = shift;
    my $reference_object = shift;
    my $index = shift;
    return join( "::" , $reference_object->url() , $index );
}

# Create path given sequence of "aligned" nodes (i.e. graph node ids)
# TODO: update the node/edge weights here and move that part of the code out of FilippovaGraphBuilder ?
sub _create_path {

    my $this = shift;
    my $graph = shift;
    my $path_label = shift;
    my $mapped_sequence = shift;

    # Once all the nodes have been aligned/inserted, we add/update edges (see \cite{Filippova2010})
    {
	my $previous_node = undef;
	foreach my $aligned_node (@{ $mapped_sequence }) {
	    
	    if ( defined( $previous_node ) ) { 
		$this->_insert_edge( $graph , $path_label , $previous_node , $aligned_node );
	    }

	    $previous_node = $aligned_node;

	}
    }
    
    # update global stats
    $graph->set_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT , ( $graph->get_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT ) || 0 ) + 1 );

}

sub _insert_edge {

    my $this = shift;
    my $graph = shift;
    my $url = shift;
    my $from_node = shift;
    my $to_node = shift;

    if ( ! defined( $from_node ) || ! defined( $to_node ) ) {
	die "We have a problem, invalid from/to node ...";
    }

    # TODO: should this be moved somewhere else ?
    if ( ! $graph->has_edge( $from_node , $to_node ) ) {
	$graph->set_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH , 1 );
    }
    else {
	$graph->set_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH , $graph->get_edge_attribute( $from_node , $to_node , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) + 1 );
    }
    
}

# generate gist path, i.e. sequence of tokens
# assumes chunked data
sub _generate_gist_path {

    my $this = shift;
    my $data = shift;

    my $gist = $data->get_field( 'summary.chunked.refined' );

    # 1 - create sentence object for this gist
    my $gist_sentence = new Web::Summarizer::Sentence( object => $data , string => $gist );

    return $gist_sentence;

}

sub map_to_wordgraph_node_sequence {

    my $this = shift;
    my $graph = shift;
    my $sentence = shift;

    # add BOG/EOG nodes to sequence
    my @wordgraph_token_sequence = ( $graph->bog_node->token, @{ $sentence->object_sequence }, $graph->eog_node->token );
    
    return \@wordgraph_token_sequence;

}

__PACKAGE__->meta->make_immutable;

1;

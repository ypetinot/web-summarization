package GistGraph::AppearanceModel;

# Base class for all Appearance Models
# Appearance models define a collection of distribution over individual nps/concepts

use strict;
use warnings;

use Moose;
use MooseX::Storage;
use namespace::autoclean;

use GistGraph;
use GistGraph::Model;
use Graph::MinCut;

use Digest::MD5 qw(md5 md5_hex md5_base64);
use File::Path;
use Graph::Directed;
use Graph::Writer::Dot;
use JSON;

extends('GistGraph::Model');
with Storage('format' => 'JSON', 'io' => 'File');

# Fields

# underlying gist graph
has 'gist_graph' => (is => 'rw', isa => 'GistGraph', required => 0, traits => [ 'DoNotSerialize' ]);

# local nodes representation
has 'nodes' => (is => 'rw', isa => 'ArrayRef', lazy => 1, default => sub { [] });

# local edges representation
has 'edges' => (is => 'rw', isa => 'ArrayRef', lazy => 1, default => sub { [] });

# ground truth (used for training)
has 'ground_truth' => (is => 'rw', isa => 'ArrayRef', init_arg => undef, lazy => 1, builder => '_build_shared_data', traits => [ 'DoNotSerialize' ]);

# appearance model
has 'appearance' => (is => 'rw', isa => 'HashRef');

# parameters of the model
has 'parameters' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# constructor
sub BUILD {

    my $this = shift;

    # init instance
    $this->reset();

}

# build shared data
sub _build_shared_data {

    my $this = shift;

    # for each input summary, determine ground truth (i.e. what are the activated noun-phrases)
    my @gists = @{ $this->gist_graph()->gists() };
    my @nodes = values %{ $this->gist_graph()->nodes() };
    my @ground_truths;
    foreach my $gist (@gists) {
	my @ground_truth = map { $_->id(); } @{ $gist->nodes() };
	push @ground_truths, \@ground_truth;
    }

    # TODO: move this somewhere else ?
    # generate nodes/edges for underlying CRF
    my $i = 0;
    my %node2numericalID;
    map { $node2numericalID{ $_->id() } = $i++; } @nodes;
    
    my @crf_nodes = map { [ $_->id() , $node2numericalID{ $_->id() } ]; } @nodes;
    my @crf_edges = map { [ $node2numericalID{ $_->from() } , $node2numericalID{ $_->to() } ] } values( %{ $this->gist_graph()->edges() } );
    
    $this->nodes( \@crf_nodes );
    $this->edges( \@crf_edges );

    return \@ground_truths;

}

# reset model
sub reset {

    my $this = shift;

    # reset appearance
    $this->appearance(
	{
	
	    # The BOG node always appears
	    $GistGraph::BOG_NODE_NAME => 1,
	    
	    # The EOG node always appears
	    $GistGraph::EOG_NODE_NAME => 1
		
	}
	);
    
    # Anything else ?
    # Looks good for now ...

}

# restore appearance model from a file
# TODO: should we restore all models so we don't need to pass the parameters params ?
sub restore {

    my $that = shift;
    my $filename_base = shift;
    # TODO: the gist graph is probably not needed here as the appearance model is part of a larger model (GistModel)
    my $gist_graph = shift;
    my $parameters = shift;

    if ( $that->serializable() ) {

	my $serialization_filename = $that->serialization_file( $filename_base , $parameters );
	
	if ( -f $serialization_filename ) {
	    my $appearance_model = $that->load( $serialization_filename );
	    $appearance_model->gist_graph( $gist_graph );
	    return $appearance_model;
	}

	return undef;

    }

    return $that->new( 'gist_graph' => $gist_graph );

}

# serialization file
sub serialization_file {

    my $that = shift;
    my $filename_base = shift;
    my $parameters = shift;

    if ( ref($that) && !$filename_base ) {
	$filename_base = $that->gist_graph()->model_directory();
    }
    
    my $model_type = lc( ref( $that ) || $that );
    $model_type =~ s/::/_/g;

    my $target_directory = join("/", $filename_base, "appearance-models", $that->key( $parameters ));
    
    # create target directory if needed
    if ( ! -d $target_directory ) {
	mkpath $target_directory;
    }

    return join( "/", $target_directory , join(".",$model_type) );

}

# write out appearance model
sub write_out {

    my $this = shift;
    my $filename_base = shift;

    my $serialization_filename = $this->serialization_file( $filename_base );
    $this->store( $serialization_filename );

}

# support directory
sub get_support_directory {

    my $this = shift;
    my $serialization_file = shift;

    if ( ! defined( $serialization_file ) ) {
	$serialization_file = $this->serialization_file();
    }

    my $support_directory = join(".", $serialization_file, "support");
    if ( ! -f $support_directory ) {
	mkpath $support_directory;
    }

    return $support_directory;

}

# train model
sub train {

    my $this = shift;

    # load required modules
    $this->_load_model_module( $this->parameters()->{ 'learner' } );

    # featurize data
    my $training_instances = $this->gist_graph()->raw_data()->url_data();
    map{ $_->featurize( $this->get_feature_set_definition() ); } @{ $training_instances };
    
    # call actual training code
    return $this->_train( $training_instances , $this->ground_truth() );
    
}

# _train model (default)
sub _train {

    my $this = shift;
    my $instances = shift;
    my $ground_truth = shift;

    # nothing here - can be overridden by sub-class

}

# run inference
sub run_inference {

    my $this = shift;
    my $url_data = shift;

    # reset model
    $this->reset();

    # featurize data
    $url_data->featurize( $this->get_feature_set_definition() );

    # call actual inference code
    $this->_run_inference( $url_data );

    # run post processing if requested
    if ( $this->parameters()->{'post-process'} ) {
	$this->post_process();
    }

}

# underlying run inference (default)
sub _run_inference {

    my $this = shift;
    my $instance = shift;

    # nothing here - can be overridden by sub-class

}

# get appearance probability for a given node
sub get_probability {

    my $this = shift;
    my $node = shift;

    my $node_id = $node;
    if ( ref( $node ) ) {
	$node_id = $node->id();
    }

    return $this->appearance()->{ $node_id } || 0;

}

# model state
sub get_state {

    my $this = shift;

    # just make sure the shared data has been built at least once
    # TODO: could this go somewhere else ?
    $this->ground_truth();

    my %state;

    $state{'appearance-model-type'} = ref( $this );
    $state{'nodes-status'} = {};

    my @nodes = @{ $this->nodes() };
    foreach my $node (@nodes) {
	$state{'nodes-status'}{ $node->[0] } = $this->get_probability( $node->[0] );
    }

    return \%state;

}

# should this model be serialized ?
sub serializable {

    my $that = shift;

    # By default should be serialized ...
    return 1;

}

# get key for this model
sub key {
    
    my $that = shift;
    my $parameters = shift;

    my $model_name = ref($that) || $that ;
    my $model_parameters = $parameters;

    if ( ref( $that ) ) {
	$model_parameters = $that->parameters();
    }

    return join( "-" , $model_name , md5_hex( encode_json( $model_parameters ) ) );

}

# get feature set definition
sub get_feature_set_definition {

    my $this = shift;

    return $this->parameters()->{ 'features' } || {};

}

# evaluate against expected output
sub evaluate {

    my $this = shift;
    my $expected_output = shift;
    
    my %local_appearance;
    my %expected_appearance;

    map { $local_appearance{ $_->head_string() } = $this->get_probability( $_->get_id() ); } @{ $this->nodes() };

    my @expected_chunks = map { $this->gist_graph()->raw_data()->category_data()->get_chunk( $_ ); } split /\s+/, $expected_output;
    map { $expected_appearance{ $_->get_surface_string() } = 1; } @expected_chunks;

    # compute similarity with current state
    my $similarity = Similarity::_compute_cosine_similarity( \%local_appearance , \%expected_appearance );

    return $similarity;

}

# content distribution
sub get_content_vector {

    my $this = shift;
    
    my %content_vector;

    my @nodes = @{ $this->nodes() };
    foreach my $node (@nodes) {
	my $node_head = join( " " , $node->head() );
	$content_vector{ $node_head } = $this->get_probability( $node->id() );
    }

    return \%content_vector;

}

# post process output of appearance model
# TODO: should we come up with a better name ?
sub post_process {

    my $this = shift;

    # source / i.e. appears
    my $source_node = "s";

    # sink / i.e. does not appear
    my $sink_node = "t";

    # 1 - generate min-cut graph (different from gist graph ?)
    my $post_processing_graph = Graph::Directed->new;

    # add source/sink nodes
    $post_processing_graph->add_vertex($source_node);
    $post_processing_graph->add_vertex($sink_node);

    # create individual nodes and edges connecting them to the source/sink nodes
    # TODO: should we remove the bog/eog nodes (maybe not if they are always preserved)
    my $node_ids = $this->gist_graph()->sorted_nodes(1);
    foreach my $node_id (@{ $node_ids }) {

	if ( ! $this->gist_graph()->is_regular_node( $node_id ) ) {
	    next;
	}

	$post_processing_graph->add_vertex($node_id);
	$post_processing_graph->set_vertex_attribute($node_id,"label",$this->gist_graph()->nodes()->{ $node_id }->surface_string());

	my $appearance_probability = $this->get_probability($node_id) || 0.01;
	my $appearance_probability_log = -1 * log( $appearance_probability );

	my $appearance_probability_complement = ( 1 - $appearance_probability ) || 0.01;
	my $appearance_probability_complement_log = -1 * log( $appearance_probability_complement );

	print STDERR "[post-process] adding source edge: $source_node --> $node_id ($appearance_probability)\n";
	$post_processing_graph->add_weighted_edge($source_node,$node_id,_weight_adjuster($appearance_probability));

	print STDERR "[post-process] adding sink edge: $node_id --> $sink_node ($appearance_probability_complement)\n";
	$post_processing_graph->add_weighted_edge($node_id,$sink_node,_weight_adjuster($appearance_probability_complement));
	#$post_processing_graph->add_weighted_edge($node_id,$sink_node,$appearance_probability_complement);

    }

    # create association edges
    my @edges = values( %{ $this->gist_graph()->edges() } );
    foreach my $edge (@edges) {
	
	my $from = $edge->from();
	my $to = $edge->to();
	
	if ( ! $this->gist_graph()->is_regular_node( $from ) || ! $this->gist_graph()->is_regular_node( $to ) ) {
	    next;
	}
	
	# TODO: should proximity be taken into account as well ?
	my $weight = $edge->get_compatibility() * ( 1 / ( $edge->get_proximity() + 1 ) );
	my $weight_log = -1 * log( $weight || 0.01);

	# Since our graph is fundamentally undirected, we map every edge to two directed edges of equal capacity
	print STDERR "[post-process] adding compatibility edge: $from --> $to ($weight)\n";
	$post_processing_graph->add_weighted_edge($from,$to,_weight_adjuster($weight));

	print STDERR "[post-process] adding compatibility edge: $to --> $from ($weight)\n";
	$post_processing_graph->add_weighted_edge($to,$from,_weight_adjuster($weight));
	
    }

    # write out graph for debugging/monitoring purposes
    my $writer = Graph::Writer::Dot->new();
    my $post_processing_graph_file = join("/",$this->get_support_directory(), "post_process.graph");
    $writer->write_graph($post_processing_graph,$post_processing_graph_file);

    # 2 - determine min-cut
    # --> mincut corresponds to satured edges with no residual flow
    # TODO: can we make this into an integrated graph library ?
    my $node_labels = Graph::MinCut->analyze( $post_processing_graph , $source_node , $sink_node );

    # 3 - update appearance status
    foreach my $node_id (keys( %{ $node_labels })) {
	
	my $node_label = $node_labels->{ $node_id };

	my $new_appearance = ( $node_label eq $source_node ) ? 1 : 0;
	my $current_appearance = $this->appearance()->{ $node_id } || 0;

	if ( $new_appearance != $current_appearance ) {
	    print STDERR "Correcting appearance for node $node_id: $current_appearance --> $new_appearance ...\n";
	    $this->appearance()->{ $node_id } = $new_appearance;
	}	
	
    }

}

sub _weight_adjuster {

    my $float_value = shift;

    return int( ( 1000 * $float_value ) );

}

__PACKAGE__->meta->make_immutable;

1;

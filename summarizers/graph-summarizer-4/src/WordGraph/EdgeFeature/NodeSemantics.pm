package WordGraph::EdgeFeature::NodeSemantics;

use Moose;

use strict;
use warnings;

use Similarity;
use Vocabulary;

use JSON;
use Net::Dict;

###my $DICTD_SERVER = "coral12.cs.columbia.edu";
###my $dict = Net::Dict->new( $DICTD_SERVER );

use Moose;
use namespace::autoclean;

with 'Feature::ServicedFeature';
extends 'WordGraph::EdgeFeature::MultiModalityFeature';

# ODP/DMOZ vocabulary
# Used only if specified at construction-time
has 'vocabulary' => ( is => 'ro' , isa => 'Vocabulary' , builder => '_build_node_vocabulary' , lazy => 1 );

sub _build_node_vocabulary {

    my $this = shift;

    my $vocabulary = Vocabulary->load( $this->params->{ 'vocabulary_file' } );

    return $vocabulary;

}

my $COMMON_SEMANTIC_REPRESENTATION_SOURCE_SINK = 'semantic-representation-source-sink';
my $COMMON_SEMANTIC_REPRESENTATION_INSTANCE_MODALITY = 'semantic-representation-instance';

sub _get_resources {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;

    my %common_resources;

    foreach my $modality (@{ $this->modalities }) {

	# instance semantic representation
	$common_resources{ $modality }{ $COMMON_SEMANTIC_REPRESENTATION_INSTANCE_MODALITY } = $instance->semantic_representation( $modality );

	# source/sink semantic representations (will be populated next)
	$common_resources{ $modality }{ $COMMON_SEMANTIC_REPRESENTATION_SOURCE_SINK } = [];

    }

    return \%common_resources;

}

sub _value_node {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $node_index = shift;
    my $modality = shift;
    
    my $node = $edge->[ $node_index ];
    
    # --> static vector (i.e. concepts appearing)
    # --> top K semantics appearings in modality

    # 1 - get semantic representation for target node
    my $node_semantic_representation = $this->_node_semantic_representation( $node );
    push @{ $common_resources->{ $COMMON_SEMANTIC_REPRESENTATION_SOURCE_SINK } } , $node_semantic_representation;

    # 2 - get semantic representation for target modality
    my $modality_semantic_representation = $common_resources->{ $COMMON_SEMANTIC_REPRESENTATION_INSTANCE_MODALITY };
    
    # 3 - compute distance between semantic representations
    my $semantic_distance = $this->_compute_semantic_distance( $node_semantic_representation , $modality_semantic_representation );

    # print STDERR join( "\t" , "SEMANTICS" , $instance->url() , $node_surface , $semantic_distance ) . "\n";

    return $semantic_distance;

}

=pod
sub _node_semantic_representation {

    my $this = shift;
    my $edge = shift;
    my $index = shift;

    my $node_surface = lc( $edge->[ $index ]->surface );
    my $node_semantic_representation = $this->vocabulary()->semantic_representation( $node_surface );    
    
    return $node_semantic_representation;

}
=cut

sub _node_semantic_representation {
    
    my $this = shift;
    my $node = shift;
    
    my $node_surface = lc( $node->surface() );

    my $feature_request_data = $this->feature_request( 'get_word_semantics' , $node_surface );

    my $node_semantic_representation = undef;
    if ( $feature_request_data ) {
	$node_semantic_representation = new Vector( coordinates => $feature_request_data );
    }

    return $node_semantic_representation;

}

sub _compute_semantic_distance {

    my $this = shift;
    my $semantic_object_1 = shift;
    my $semantic_object_2 = shift;
    
    my $similarity = 0;

    if ( $semantic_object_1 && $semantic_object_2 ) {
	    
	# cosine similarity using TFIDF weights ?
	$similarity = Vector::cosine( $semantic_object_1 , $semantic_object_2 );
    
    }

    return $similarity;

}

sub _value_edge {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $source_features = shift;
    my $sink_features = shift;
    my $modality = shift;

    # 1 - get semantic representation for source
    my $source_semantic_representation = $common_resources->{ $COMMON_SEMANTIC_REPRESENTATION_SOURCE_SINK }->[ 0 ];

    # 2 - get semantic representation for target
    my $target_semantic_representation = $common_resources->{ $COMMON_SEMANTIC_REPRESENTATION_SOURCE_SINK }->[ 1 ];

    # 3 - projected semantic representation (source onto target)
    my $projected_semantic_representation_target = defined( $source_semantic_representation ) ? $source_semantic_representation->project( $target_semantic_representation ) : 0;
    my $projected_semantic_representation_source = defined( $target_semantic_representation ) ? $target_semantic_representation->project( $source_semantic_representation ) : 0;

    # 4 - get semantic representation for target modality
    my $modality_semantic_representation = $common_resources->{ $COMMON_SEMANTIC_REPRESENTATION_INSTANCE_MODALITY };

    # 5 - semantic distance between #3 and #4
    my $semantic_distances = {
	'target_projection' => $this->_compute_semantic_distance( $projected_semantic_representation_target , $modality_semantic_representation ),
	'source_projection' => $this->_compute_semantic_distance( $projected_semantic_representation_source , $modality_semantic_representation ),
    };

    return $semantic_distances;

}

__PACKAGE__->meta->make_immutable;

1;

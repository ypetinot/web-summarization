package WordGraph::EdgeFeature::NodeNeighborhoodFrequency;

use strict;
use warnings;

use Moose;

extends 'WordGraph::EdgeFeature::NodeFrequency';

sub _get_removed_neighbors {

    my $this = shift;
    my $graph = shift;
    my $node = shift;
    my $distance = shift;

    my %nodes2seens;
    
    # ...

}

sub _value_node {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $node_index = shift;
    my $modality = shift;

    my @neighbors = $node_index ? $graph->successors( $edge->[ $node_index ] ) : $graph->predecessors( $edge->[ $node_index ] );
    $common_resources->{ 0 } = scalar( @neighbors );

    my $neighborhood_size = scalar( @neighbors );
    my $neighborhood_appearance_count = 0;

    # check for presence of each predecessor in instance's modality
    foreach my $neighbor (@neighbors) {

	# predecessor frequency
	# TODO: we should be able to directly use the node frequence feature(s)
	my $frequency = $this->_node_frequency( $graph , $neighbor , $instance , $modality );
	if ( $frequency ) {
	    $neighborhood_appearance_count++;
	}

    }
    
    return ( $neighborhood_size ? ( $neighborhood_appearance_count / $neighborhood_size ) : $neighborhood_size );

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

    # TODO: is this good enough ?
    my $feature_value = $source_features->{ $modality } * $sink_features->{ $modality };
    
    return $feature_value;

}

no Moose;

1;

package WordGraph::EdgeModel::ReferenceTargetModel;

use Moose;
use namespace::autoclean;

extends('ReferenceTargetPairwiseModel');
with('WordGraph::EdgeModel');

has 'rtm' => ( is => 'ro' , isa => 'ReferenceTargetModel' , init_arg => undef , lazy => 1 , builder => '_rtm_builder' );
sub _rtm_builder {
    my $this = shift;
    return new ReferenceTargetPairwiseModel();
}

# "dynamically" determine cost of an edge in the gist graph
# Used to be compute_edge_cost
sub _compute {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $edge_features = shift; # needed ?
    my $instance = shift;

    # TODO : remove code duplication
    
    # 1 - turn edge into a sequence
    my $edge_as_path = new WordGraph::Path( graph => $graph , node_sequence => $edge , object => $instance->[ 0 ] );

    # 2 - create rtm instance for the current configuration
    my $rtm_instance = $this->rtm->create_instance( [ $instance->[ 0 ] , $edge_as_path ] , [ [ $instance->[ 1 ]->[ 0 ]->[ 0 ] , $instance->[ 1 ]->[ 0 ]->[ 1 ] ] ] );

    return 1 / ( 0.00000001 + $rtm_instance->compute_unnormalized_probability );

}

=pod
# ****************************************************************************************************************************
# 1 - edge features (features are an integral part of the graph)
# ****************************************************************************************************************************

# TODO : move this to WordGraph's construction method
sub list_features {
    
    my $this = shift;

    my %edge_features;
    my @_edge_features;
    
    $this->rtm->
    
    return \%edge_features;

}

# *****************************************************************************************************************************
=cut

sub _sigmoid {

    my $raw_cost = shift;
    my $sigmoid_cost = 1 / ( 1 + exp( -1 * $raw_cost ) );

    return $sigmoid_cost;

}

=pod
# Compute cost of an edge given a set of features and associated weights
sub _compute_edge_cost {
    
    my $this = shift;
    my $weights = shift;
    my $edge = shift;

    my $use_shortest_path = $this->params()->{ 'use_shortest_path' };

    my $edge_cost = 0;

    my $edge_features = $this->_compute_edge_features( $edge );

    my $has_non_zero_feature = 0;
    foreach my $feature_id (keys %{ $edge_features }) {

	my $weight = _feature_weight( $weights , $feature_id );
	my $feature_value = $edge_features->{ $feature_id };

	if ( $feature_value ) {
	    $has_non_zero_feature++;
	}

	my $cost_update = $weight * $feature_value;
	if ( $cost_update ) {
	    # Multiplicative costs seem to prevent the occurrence of negative cycles ?
	    # TODO: try multiplicative costs also ?
	    $edge_cost += $cost_update;
	}
	
    }
    
    if ( ($DEBUG > 2) && $has_non_zero_feature ) {
	print STDERR "\tEdge " . join("::", @{ $edge }) . " has active feature ...\n";
    }

    my $edge_weight;
    my $TINY = 0.00000000001;
    
    if ( $use_shortest_path ) {
	#$edge_weight = -log( $TINY + $edge_cost );
	$edge_weight = $edge_cost;
    }
    else {
	$edge_weight = $edge_cost;
    }

    # TODO: include study of the best cost function ?
    return $edge_weight;
    #return sigmoid( $edge_weight );
    #return $edge_cost;
    #return exp( $edge_cost );

}
=cut

# (overridden) compute feature vector for a given edge
# CURRENT : no need for list features ? simply compute features, here via factors
sub compute_edge_features {

    my $this = shift;
    my $instance = shift;
    my $edge = shift;
    my $graph = shift;

    ### print STDERR "Computing edge features ...\n";

    # 1 - turn edge into a sequence
    my $edge_as_path = new WordGraph::Path( graph => $graph , node_sequence => $edge , object => $instance->[ 0 ] );

    # 2 - create rtm instance for the current configuration
    my $rtm_instance = $this->rtm->create_instance( [ $instance->[ 0 ] , $edge_as_path ] , $instance->[ 1 ] );
    my $rtm_instance_features = $rtm_instance->featurize;

=pod

    # Iterate over edge feature definitions
    foreach my $feature_id ( keys %{ $this->features } ) {
	my $feature_definition = $this->features->{ $feature_id };
	my $feature_values = $feature_definition->compute_cached( $instance , $edge_as_path );
    }
=cut

    return $rtm_instance_features;

}

__PACKAGE__->meta->make_immutable;

1;

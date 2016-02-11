package WordGraph::EdgeModel::LinearModel;

use Moose;
use namespace::autoclean;

with('WordGraph::EdgeModel');

has 'use_sigmoid' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# "dynamically" determine cost of an edge in the gist graph
# Used to be compute_edge_cost
sub _compute {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $edge_features = shift; # needed ?
    my $instance = shift;

    # compute linear edge cost
    my $linear_edge_cost = 0;
    map { $linear_edge_cost += $edge_features->{ $_ } * $this->feature_weights->{ $_ } } grep { $this->feature_weights->{ $_ } } keys( %{ $edge_features } );

    if ( $this->use_sigmoid ) {
	return _sigmoid( $linear_edge_cost );
    }

    return $linear_edge_cost;

}

=pod
# TODO : move this to WordGraph's construction method
sub list_features {
    
    my $this = shift;

    my %edge_features;
    my @_edge_features;
    
    # TODO : get rid of this
    map { $edge_features{ $_->id } = $_; } @_edge_features;

    return \%edge_features;

}
=cut

# ****************************************************************************************************************************
# 1 - edge features (features are an integral part of the graph)
# ****************************************************************************************************************************

# TODO : move this to WordGraph's construction method
sub list_features {
    
    my $this = shift;

    my %edge_features;
    my @_edge_features;
    
    # (Native) Source/Sink/Edge prior
    push @_edge_features, new WordGraph::EdgeFeature::NodePrior( id => $Web::Summarizer::Graph2::Definitions::FEATURE_PRIOR );
    
    # Source/Sink/Edge types
    push @_edge_features, new WordGraph::EdgeFeature::NodeType( id => $Web::Summarizer::Graph2::Definitions::FEATURE_TYPE );

    # (Native) Source/Sink/Edge degrees
    # --> featurization of graph topology
    push @_edge_features, new WordGraph::EdgeFeature::NodeDegree( id => $Web::Summarizer::Graph2::Definitions::FEATURE_DEGREE );
    
# TODO : attempt to reenable once the energy model is in place ?
# Note : this does not seem to be a (graph) native feature ?
=pod 
    # (Native) Neighborhood appearance
    push @edge_features, new WordGraph::EdgeFeature::NodeNeighborhoodFrequency( id => $Web::Summarizer::Graph2::Definitions::FEATURE_NEIGHBORHOOD_FREQUENCY , modalities => $this->modalities_fluent );
=cut
	
=pod
    # Edge source/sink/joint conditioning
    push @_edge_features, new WordGraph::EdgeFeature::NodeConditioning( id => $Web::Summarizer::Graph2::Definitions::FEATURE_CONDITIONING,
									modalities => $this->object_modalities );
=cut

# TODO : bring this back in when we're ready, this time with a decent handling of modalities
=pod    
    # Source/Sink/Edge semantics
    # (projection in both directions for edge)
    # TODO : add functionality to select subset of features / focus on specific modalities
    push @_edge_features, new WordGraph::EdgeFeature::NodeSemantics( id => $Web::Summarizer::Graph2::Definitions::FEATURE_SEMANTICS );
=cut

    # TODO : add modality-based features
    # ...

    # TODO : get rid of this
    map { $edge_features{ $_->id } = $_; } @_edge_features;

    return \%edge_features;

}

# *****************************************************************************************************************************

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

__PACKAGE__->meta->make_immutable;

1;

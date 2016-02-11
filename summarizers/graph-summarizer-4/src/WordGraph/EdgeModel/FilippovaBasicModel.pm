package WordGraph::EdgeModel::FilippovaBasicModel;

use Moose;
use namespace::autoclean;

# TODO : should create a separate base class
extends('WordGraph::EdgeModel::LinearModel');

# Based on basic edge cost scheme in (Filippova et al. 2010)
# Edge costs correspond to inverted link frequencies (2.2)
sub _compute {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $edge_features = shift; # needed ?
    my $instance = shift;

    # compute basic edge cost
    my $edge_prior = $edge_features->{ WordGraph::EdgeFeature::feature_key( "edge" , $Web::Summarizer::Graph2::Definitions::FEATURE_PRIOR ) };
    if ( ! $edge_prior ) {
	die "Edge prior cannot be 0 ...";
    }

    # Note that, compared to Filippova, the cost is scaled by a constant factor
    my $basic_edge_cost = 1 / $edge_prior;

    return $basic_edge_cost;

}

__PACKAGE__->meta->make_immutable;

1;

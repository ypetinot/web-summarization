package WordGraph::EdgeFeature::NodeDegree;

use strict;
use warnings;

use List::Util qw/max min/;

use Moose;

extends 'WordGraph::EdgeFeature';

sub value_node {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $node_index = shift;

    my $node = $edge->[ $node_index ];

    my %features;

    # TODO : node centrality (separate class)

    # node in-degree
    my $in_degree = $graph->in_degree( $node );
    $features{ 'in-degree' } = $in_degree;

    # node out-degree
    my $out_degree = $graph->out_degree( $node );
    $features{ 'out-degree' } = $out_degree;

    return \%features;

}

sub value_edge {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $source_features = shift;
    my $sink_features = shift;

    my %features;

    # compute all combinations of in/out degrees
    foreach my $source_key ( keys( %{ $source_features } ) ) {
	
	foreach my $sink_key ( keys( %{ $sink_features } ) ) {

	    my $source_value = $source_features->{ $source_key };
	    my $sink_value = $sink_features->{ $sink_key };

	    my $average = ( $source_value + $sink_value );
	    $features{ 'average' } = $average;

	    my $product = ( $source_value * $sink_value );
	    $features{ 'product' } = $product;

	    my $min = min( $source_value , $sink_value );
	    $features{ 'min' } = $min;

	    my $max = max( $source_value , $sink_value );
	    $features{ 'max' } = $max;

	}

    }

    return \%features;

}

no Moose;

1;

package WordGraph::EdgeFeature::NodeType;;

use strict;
use warnings;

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

    # indicator feature for POS
    $features{ join( "-" , 'pos' , lc( $node->token->pos() ) ) } = 1;
    
    # indicator feature for abstract type
    $features{ join( "-" , 'abstract-type' , lc( $node->token->abstract_type() ) ) } = 1;

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

    foreach my $source_key ( keys( %{ $source_features } ) ) {

	foreach my $sink_key ( keys( %{ $sink_features } ) ) {

	    $features{ join( "-" , $source_key , $sink_key ) } = 1;

	}

    }

    return \%features;

}

no Moose;

1;

package WordGraph::EdgeFeature::NodePrior;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'WordGraph::EdgeFeature';

sub value_node {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $node_index = shift;

    my $node = $edge->[ $node_index ];

    # node prior
    my $unnormalized_feature_value = $graph->get_vertex_weight( $node );
    my $normalizer = $graph->get_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT ) || 1;
    my $feature_value = $unnormalized_feature_value / $normalizer;

    return $feature_value;

}

sub value_edge {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $source_features = shift;
    my $sink_features = shift;

    my $feature_value = $graph->get_edge_attribute( $edge->[ 0 ] , $edge->[ 1 ] , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) / ( $graph->get_graph_attribute( $Web::Summarizer::Graph2::Definitions::GRAPH_PROPERTY_PATH_COUNT ) || 1 );

    return $feature_value;

}

=pod
# Collect additional stats that will be required for node/edge feature generation
print STDERR "Computing more stats ...\n";
my $field_content_phrases = 'content.phrases';
my %node2appearances;
foreach my $training_entry (@{ $training_entries }) {

    field_loop: foreach my $field ( $field_content_phrases ) {

	my $data = $training_entry->get_field( $field );
	foreach my $node ($reference_graph->vertices()) {

	    if ( ! defined( $node2appearances{ $node } ) ) {
		$node2appearances{ $node } = {};
	    }
	    
	    # If this node is a slot, we are looking for the value of its filler for the target entry
	    my $node_verbalization = $node;
	    if ( ref( $node ) ) {
		$node_verbalization = join( " " , @{ $node->[ 3 ]->{ $training_entry->url() } } );
	    }

	    # Look for occurrences of $node in $field
	    if ( $data =~ m/\Q${node_verbalization}\E/sgi ) {
		$node2appearances{ $node }{ $field }++;
		next field_loop;
	    }

	    foreach my $successor ($reference_graph->successors( $node )) {

		my $outgoing_edge = [ $node , $successor ];

	    }

	}

    }

}
=cut

=pod
sub _appears {

    my $entry = shift;
    my $token = shift;

    my $entry_content = $entry->get_field( 'content.phrases' ) || '';
    if ( $entry_content =~ m/$token/sgi ) {
	return 1;
    }

    my $entry_anchortext = $entry->get_field( 'anchortext.sentence' ) || '';
    if ( $entry_anchortext =~ m/$token/sgi ) {
	return 1;
    }

    return 0;

}
=cut

__PACKAGE__->meta->make_immutable;

1;

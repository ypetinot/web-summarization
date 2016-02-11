package WordGraph::EdgeFeature::NodeFrequency;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

extends 'WordGraph::EdgeFeature::MultiModalityFeature';

sub _value_node {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $instance = shift;
    my $common_resources = shift;
    my $node_index = shift;
    my $modality = shift;

    my $node = $edge->[ $node_index ];

    #my $node_prior = $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_PRIOR );
    #my $node_frequency_in_target = $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_TARGET_FREQUENCY );
    #my $node_frequency_expected = $graph->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_EXPECTED_FREQUENCY );
    #$feature_value = _adjusted_feature_value( $node_prior , $node_frequency_in_target , $node_frequency_expected );

    # node frequency
    my $feature_value = $this->_node_frequency( $graph , $node , $instance , $modality );
    
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

sub _node_frequency {

    my $this = shift;
    my $graph = shift;
    my $node = shift;
    my $instance = shift;
    my $modality = shift;

    # If slot node --> get slot filler (candidate ?)
    my $target_string = $node->realize( $instance );

    my $count = 0;
    
    my $content = $instance->get_field( $modality );
    while ( $content =~ m/\Q$target_string\E/sgi ) {
	$count++;
    } 

    return $count;

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
    
    # source frequency
    my $source_count = $source_features->{ $modality } || 0;

    # target frequency
    my $target_count = $sink_features->{ $modality } || 0;
    
    # we consider all combinations as an instance of the edge (should we require adjacency instead ?)
    my $feature_value = $source_count * $target_count;

    return $feature_value;

}

__PACKAGE__->meta->make_immutable;

1;

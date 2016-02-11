package GistGraph::AppearanceModel::ContentVote;

# Baseline Appearance Model - Content Vote
# Every (training) entry in the category votes as to the appearance of individual nodes: votes 1 if this node appears in the content, 0 otherwise
# The final decision is based on the majority vote

use strict;
use warnings;

use Moose;

extends 'GistGraph::AppearanceModel::MajorityVote';

# train model
sub train {

    my $this = shift;

    my %vote_data;

    my @training_content_appearances = map{ $_->get_data()->{'content::appearance'}; } @{ $this->gist_graph()->raw_data()->url_data() };

    foreach my $training_content_appearance ( @training_content_appearances ) {
	
	foreach my $node_appearance ( keys( %{ $training_content_appearance } ) ) {
	    
	    my $node = $this->gist_graph()->get_node_for_chunk( $node_appearance );
	    if ( ! defined( $node ) ) {
		next;
	    }
	    
	    $vote_data{ $node->id() }++;
	    
	}

    }

    my $n_entries = scalar( @training_content_appearances );
    map { $this->appearance()->{ $_ } = ( $vote_data{ $_ } / $n_entries ) } keys( %vote_data );

}

no Moose;

1;

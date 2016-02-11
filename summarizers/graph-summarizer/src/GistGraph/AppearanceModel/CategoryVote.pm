package GistGraph::AppearanceModel::CategoryVote;

# Baseline Appearance Model - Category Vote
# Every (training) entry in the category votes as to the appearance of individual nodes: votes 1 if this node appears in the gist, 0 otherwise
# The final decision is based on the majority vote

use strict;
use warnings;

use Moose;

use GistGraph::AppearanceModel;

extends 'GistGraph::AppearanceModel::MajorityVote';

# train model
sub train {

    my $this = shift;

    my %vote_data;

    my $ground_truths = $this->ground_truth();
    foreach my $ground_truth ( @{ $ground_truths } ) {
	map { $vote_data{ $_ }++; } @{ $ground_truth };
    }

    my $n_entries = scalar( @{ $ground_truths } );
    map { $this->appearance()->{ $_ } = $vote_data{ $_ } / $n_entries; } keys( %vote_data );

}

no Moose;

1;

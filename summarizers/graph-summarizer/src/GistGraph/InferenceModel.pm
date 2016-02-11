package GistGraph::InferenceModel;

# Base class for all Inference Models

use strict;
use warnings;

use GistGraph;
use GistGraph::Model;

use Moose;

extends 'GistGraph::Model';

use JSON;

# fields

# mode
has 'mode' => (is => 'ro', isa => 'Str', required => 0, default => '');

# constructor
sub BUILD {

    my $this = shift;

    # Nothing for now

}

# reset model
sub reset {

    my $this = shift;

    # Anything else ?
    # Looks good for now ...

}

# search for maximum likelihood path between two nodes
# TODO: should this be moved somewhere else ?
sub maximum_likelihood_path {

    my $this = shift;
    my $gist_model = shift;
    my $from_node = shift;
    my $to_node = shift;

    # Dijkstra algorithm to find shortest/longest path between two nodes ?

    # Beam-search
    return $this->beam_search( $gist_model , $from_node , $to_node , 10 );

}

# Beam search
# TODO: should this be moved to somewhere else ?
sub beam_search {

    my $this = shift;
    my $gist_model = shift;
    my $from_node = shift;
    my $to_node = shift;
    my $beam_size = shift;

    my @beams;

    # create initial beam
    # format: [ score , beam_path , beam_coverage ]
    push @beams, [ 1 , [ $from_node ] , { $from_node->id() => 1 } ];

    # expand beams until the target node is reached
    while ( scalar(@beams) ) {

	# process the best current beam
	my $beam = shift @beams;

	# 1 - consider all (only outgoing ?) neighbors for the current node
	my ( $current_score , $current_path , $current_coverage ) = @{ $beam };
	my $neighbors = $gist_model->gist_graph()->get_neighbors_outgoing( $current_path->[ scalar( @{$current_path} ) - 1 ] );
	foreach my $neighbor (@{ $neighbors }) {

	    # we avoid loops ...
	    if ( defined( $current_coverage->{ $neighbor->id() } ) ) {
		next;
	    }

	    # create new beam for this option (including the best possible edge verbalization ?)
	    # It probably isn't necessary to include the edge verbalization in the search process for now (?)
	    my $new_beam_score = $current_score * $gist_model->np_appearance_model()->get_probability( $neighbor );
	    my $new_current_path = [ @{ $current_path } , $neighbor ];
	    my %new_current_coverage = %{ $current_coverage };
	    $new_current_coverage{ $neighbor->id() } = 1;

	    # have we reached the to node ?
	    if ( $neighbor->id() eq $to_node->id() ) {
		return $new_current_path;
	    }

	    push @beams, [ $new_beam_score , $new_current_path , \%new_current_coverage ];

	}
	
	# rearrange beams by decreasing score
	@beams = sort { $b->[0] <=> $a->[0] } @beams;

	# splice at max beam size
	if ( scalar(@beams) > $beam_size ) {
	    splice @beams, $beam_size;
	}

    }

    # return an empty path by default 
    return [];

}

no Moose;

1;

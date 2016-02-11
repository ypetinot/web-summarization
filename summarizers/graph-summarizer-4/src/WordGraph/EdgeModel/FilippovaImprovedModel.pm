package WordGraph::EdgeModel::FilippovaImprovedModel;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

use POSIX;

# TODO : should create a separate base class
extends('WordGraph::EdgeModel::LinearModel');

# path position cache
has '_path_position_cache' => ( is => 'ro' , isa => 'HashRef' , default => sub { {} } );

# Based on improved edge cost scheme in (Filippova et al. 2010)
# (2.3)
sub _compute {

    my $this = shift;
    my $graph = shift;
    my $edge = shift;
    my $edge_features = shift; # needed ?
    my $instance = shift;

    # TODO: can we request non-normalized feature values ?
    my $graph_path_count = $graph->path_count();

    # 1 - edge frequency
    # TODO: is there a better way to get this than to denormalize ?
    my $edge_frequency = $edge_features->{ WordGraph::EdgeFeature::feature_key( "edge" , $Web::Summarizer::Graph2::Definitions::FEATURE_PRIOR ) } * $graph_path_count;
    if ( ! $edge_frequency ) {
	die "Edge frequency cannot be 0 ...";
    }

    # 2 - adjusted edge cost 
    #my $node_frequency_from = $edge_features->{ $Web::Summarizer::Graph2::Definitions::FEATURE_EDGE_SOURCE_PRIOR } * $graph_path_count;
    my $node_frequency_from = $edge_features->{ WordGraph::EdgeFeature::feature_key( "source" , $Web::Summarizer::Graph2::Definitions::FEATURE_PRIOR ) } * $graph_path_count;
    #my $node_frequency_to = $edge_features->{ $Web::Summarizer::Graph2::Definitions::FEATURE_EDGE_SINK_PRIOR } * $graph_path_count;
    my $node_frequency_to = $edge_features->{ WordGraph::EdgeFeature::feature_key( "sink" , $Web::Summarizer::Graph2::Definitions::FEATURE_PRIOR )  } * $graph_path_count;
    my $edge_cost_adjusted = ( $node_frequency_from + $node_frequency_to ) / $edge_frequency;

    # 3 - adjusted edge cost (2)
    my $edge_frequency_adjusted_2 = 0;
    my $edge_damped = 0;
    foreach my $path_key (keys( %{ $graph->paths() } )) {
	my $path = $graph->paths()->{ $path_key };
	my $path_diff = $this->diff( $path , $path_key , $edge->[ 0 ] , $edge->[ 1 ] );
	if ( $path_diff > 0 ) {
	    $edge_frequency_adjusted_2 += 1 / $path_diff;
	}
	## CHECK
	elsif( $path_diff == 0 ) {
	    $edge_damped = 1;
	    last;
	}
    }
    my $edge_cost_adjusted_2 = $edge_damped ? ULONG_MAX : ( ( $node_frequency_from + $node_frequency_to ) / $edge_frequency_adjusted_2 );

    # 4 - adjusted edge cost (3)
    my $edge_cost_adjusted_3 = $edge_cost_adjusted_2 / ( $node_frequency_from * $node_frequency_to );

    return $edge_cost_adjusted_3;

}

# Distance between words withing a given path
sub diff {

    my $this = shift;
    my $path = shift;
    my $path_key = shift;
    my $node_1 = shift;
    my $node_2 = shift;

    my $cache_key = join("::", $path_key, $node_1, $node_2);

    # 1 - check cache
    if ( ! defined( $this->_path_position_cache()->{ $cache_key } ) ) {

	my $index_1 = _position( $path , $node_1 );
	my $index_2 = _position( $path , $node_2 );

	my $diff_value;

	if ( ( $index_1 < 0 ) || ( $index_2 < 0 ) ) {
	    $diff_value = -1;
	}
	else {
	    $diff_value = ( $index_1 < $index_2 ) ? ( $index_2 - $index_1 ) : 0;
	}

	# set cache
	$this->_path_position_cache()->{ $cache_key } = $diff_value;

    }
    
    return $this->_path_position_cache()->{ $cache_key };

}

# position of node in sequence
sub _position {

    my $path = shift;
    my $node = shift;

    my $path_length = $path->length();
    for ( my $i = 0; $i < $path_length; $i++ ) {
	if ( $path->get_element( $i ) eq $node ) {
	    return $i;
	}
    }

    return -1;

}

__PACKAGE__->meta->make_immutable;

1;

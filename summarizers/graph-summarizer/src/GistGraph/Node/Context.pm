package GistGraph::Node::Context;

use strict;
use warnings;

use Similarity;

use Moose;
use MooseX::Storage;

with Storage('format' => 'JSON', 'io' => 'File');

# fields
has 'count' => (is => 'rw', isa => 'Int', default => 1);
has 'incoming_node_distribution' => (is => 'rw', isa => 'HashRef', required => 1);
has 'outgoing_node_distribution' => (is => 'rw', isa => 'HashRef', required => 1);
has 'incoming_edge_verbalization_distribution' => (is => 'rw', isa => 'HashRef', required => 1);
has 'outgoing_edge_verbalization_distribution' => (is => 'rw', isa => 'HashRef', required => 1);

# constructor
sub BUILD {

    my $this = shift;
    my $args = shift;

}

# merge two contexts
sub merge {

    my $this = shift;
    my $context = shift;
    
    $this->incoming_node_distribution( _sum_and_renormalize_hashes( $this->incoming_node_distribution() , $this->count() , $context->incoming_node_distribution() , $context->count() ) );
    $this->outgoing_node_distribution( _sum_and_renormalize_hashes( $this->outgoing_node_distribution() , $this->count() , $context->outgoing_node_distribution() , $context->count() ) );

    $this->incoming_edge_verbalization_distribution( _sum_and_renormalize_hashes( $this->incoming_edge_verbalization_distribution() , $this->count() , $context->incoming_edge_verbalization_distribution() , $context->count() ) );
    $this->outgoing_edge_verbalization_distribution( _sum_and_renormalize_hashes( $this->outgoing_edge_verbalization_distribution() , $this->count() , $context->outgoing_edge_verbalization_distribution() , $context->count() ) );

    # Update count information
    $this->count( $this->count() + $context->count() );

}

# sum and renormalization of two hashes
sub _sum_and_renormalize_hashes {

    my $hash_1 = shift;
    my $count_1 = shift;
    my $hash_2 = shift;
    my $count_2 = shift;

    my %result;
    map { $result{$_} = ( $hash_1->{$_} * $count_1 + $hash_2->{$_} * $count_2 ) / ( $count_1 + $count_2 ); } ( keys( %{ $hash_1 } ) , keys( %{ $hash_2 } ) );

    return \%result;

}

# compute (cosine) similarity between two hashes
sub _hash_similarity {

    my $hash_1 = shift;
    my $hash_2 = shift;

    return Similarity::_compute_cosine_similarity( $hash_1 , $hash_2 );

}

no Moose;

# compute similarity between two contexts
sub similarity {

    my $context1 = shift;
    my $context2 = shift;

    my $similarity_score = (
	_hash_similarity( $context1->incoming_node_distribution() , $context2->incoming_node_distribution() ) +
	_hash_similarity( $context1->outgoing_node_distribution() , $context2->outgoing_node_distribution() ) +
	_hash_similarity( $context1->incoming_edge_verbalization_distribution() , $context2->incoming_edge_verbalization_distribution() ) +
	_hash_similarity( $context1->outgoing_edge_verbalization_distribution() , $context2->outgoing_edge_verbalization_distribution() )
	) / 4;

    return $similarity_score;

}

1;

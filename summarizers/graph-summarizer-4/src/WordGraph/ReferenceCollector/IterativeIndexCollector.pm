package WordGraph::ReferenceCollector::IterativeIndexCollector;

use strict;
use warnings;

use Similarity;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceCollector::IndexCollector' );

sub _query_terms {

    my $this = shift;
    my $target_object = shift;

    my $modalities_unigrams = $target_object->get_all_modalities_unigrams;
    my @_terms = keys( %{ $modalities_unigrams } );

    # rank terms by decreasing genericity
    my @_terms_sorted = sort { ( $this->global_data->global_count( 'summary' , 1 , $b ) || 0 ) <=> ( $this->global_data->global_count( 'summary' , 1 , $a ) ) } grep { $this->global_data->global_count( 'summary' , 1 , $_ ) >= 2 } map { lc( $_ ) } @_terms;

    return \@_terms_sorted;

}

sub _run {

    my $this = shift;
    my $target_object = shift;
    my $reference_object_data = shift;
    my $reference_object_id = shift;

    # 1 - get full list of query terms
    my @sorted_terms = @{ $this->_query_terms( $target_object ) };

    # 2 - iteratively remove most specific term and query index
    my $best_reference_cluster_score = -1;
    my $best_reference_cluster = [];
    while( scalar( @sorted_terms ) ) {

	# query using current list of terms
	my $reference_objects = $this->_query_index( \@sorted_terms );

	# compute cluster density
	my $reference_cluster_density = $this->_cluster_density( $reference_objects );

	# compute lowest reference-target similarity
	my ( $average_target_similarity , $lowest_reference_target_similarity ) = $this->_cluster_lowest_target_similarity( $reference_objects );

	# compute reference cluster score
#	my $reference_cluster_score = $reference_cluster_density * $lowest_reference_target_similarity;
	my $reference_cluster_score = $average_target_similarity;

	if ( $reference_cluster_score >= $best_reference_cluster_score ) {
	    $best_reference_cluster_score = $reference_cluster_score;
	    $best_reference_cluster = $reference_objects;
	}
	else {
	    # TODO : should we stop here ?
	}

	$this->log_cluster( $reference_objects , \@sorted_terms , $reference_cluster_score , $reference_cluster_density , $lowest_reference_target_similarity );

	# remove most specific term
	pop @sorted_terms;

    }

    $this->log_cluster( $best_reference_cluster , [] , $best_reference_cluster_score , -1 , -1 );

    return $best_reference_cluster;

}

# log cluster
sub log_cluster {

    my $this = shift;
    my $reference_objects = shift;
    my $sorted_terms = shift;
    my $reference_cluster_score = shift;
    my $reference_cluster_density = shift;
    my $lowest_reference_target_similarity = shift;

    ### ****************************************************************************************************************
    print STDERR "keywords: " . join( " // " , @{ $sorted_terms } ) . "\n";
    print STDERR "scores: " . join( "\t" , $reference_cluster_score , $reference_cluster_density , $lowest_reference_target_similarity ) . "\n";
    foreach my $reference_object (@{ $reference_objects }) {
	print STDERR join("\t" , $reference_object->url , $reference_object->get_field( 'summary' ) ) . "\n";
    }
    print STDERR "\n\n";
    ### ****************************************************************************************************************

}

# cluster density
sub _cluster_density {
    
    my $this = shift;
    my $object_cluster = shift;

    my $density = 0;

    my $cluster_size = scalar( @{ $object_cluster } );
    for ( my $i=0; $i<$cluster_size; $i++ ) {
	for ( my $j=0; $j<$i; $j++ ) {
	    my $object_i_summary = $object_cluster->[ $i ]->get_field( 'summary' );
	    my $object_j_summary = $object_cluster->[ $j ]->get_field( 'summary' );
	    my $similarity_ij = Similarity::_compute_cosine_similarity( $object_i_summary , $object_j_summary , $this->global_data->global_distribution( 'summary' , 1 ) );
	    $density += $similarity_ij;
	}
    }

    if ( $cluster_size ) {
	$density /= $cluster_size;
    }

    return $density;

}

sub _cluster_lowest_target_similarity {

    my $this = shift;
    my $object_cluster = shift;

    my $target_content = join( " " , @{ $this->target_object->get_field( 'content.rendered' ) } );

    my $lowest_target_similarity = undef;
    my $average_target_similarity = 0;
    my $cluster_size = scalar( @{ $object_cluster } );
    for ( my $i=0; $i<$cluster_size; $i++ ) {    

	my $object_i_summary = $object_cluster->[ $i ]->get_field( 'summary' );
	# TODO : use TargetSimilarity class instead
	my $target_similarity = Similarity::_compute_cosine_similarity( $target_content , $object_i_summary , $this->global_data->global_distribution( 'summary' , 1 ) );

	if ( ! defined( $lowest_target_similarity ) || $target_similarity < $lowest_target_similarity ) {
	    $lowest_target_similarity = $target_similarity;
	}

	$average_target_similarity += $target_similarity;

    }

    # TODO : use statistical package instead ?
    if ( $cluster_size ) {
	$average_target_similarity /= $cluster_size;
    }

    return ( $average_target_similarity , $lowest_target_similarity );

}

__PACKAGE__->meta->make_immutable;

1;

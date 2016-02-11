package Clusterer::Hierarchical;

use strict;
use warnings;

use List::Util qw/max min/;
use Statistics::Descriptive;

use Moose;
use namespace::autoclean;

extends 'Clusterer';

has 'mode' => (is => 'ro', isa => 'Str', required => 1);
has 'centroid_builder' => (is => 'ro', isa => 'CodeRef', required => 0);
has 'similarity_threshold' => (is => 'ro', isa => 'Num', default => 0);
has 'similarity_measure' => (is => 'ro', isa => 'CodeRef', required => 1);
has 'similarity_cache' => (is => 'rw', isa => 'HashRef', default => sub { {} } );

our $MODE_AVERAGE_LINK = 'average-link';

# cluster
sub cluster {

    my $this = shift;
    my $clusters = shift;

    my @_clusters = map { [ $_ ]; } @$clusters;
    my @_clusters_history_stats;

    my $was_modified;
    do {

	$was_modified = 0;

	my $best_candidate_pair = undef;
	my $best_candidate_pair_score = 0;
	
	for (my $i=0; $i<scalar(@_clusters); $i++) {
	    
	    my $cluster_i = $_clusters[$i];
   
	    for (my $j=$i+1; $j<scalar(@_clusters); $j++) {
		
		my $cluster_j = $_clusters[$j];

		# compute similarity between the two clusters
		my ($pair_is_clusterable,$pair_similarity) = $this->check_clusterable($cluster_i,$cluster_j);
		if ( $pair_is_clusterable ) {
		    if ( $pair_similarity > $best_candidate_pair_score ) {
			$best_candidate_pair = [ $i , $j ];
			$best_candidate_pair_score = $pair_similarity;
		    }
		}
		
	    }
   
	}
	
	# cluster pair if a viable candidate was found
	if ( defined( $best_candidate_pair ) ) {
	    
	    # 1 - splice out the cluster indexed by the second pair element
	    my $spliced_out_cluster = splice @_clusters, $best_candidate_pair->[1], 1;
	    
	    # 2 - merge the spliced out cluster into the cluster indexed by the first pair element
	    if ( $this->mode() eq 'centroid' ) {
		die "Not yet supported ...";
		$this->centroid_builder()->( $best_candidate_pair->[0] , $best_candidate_pair->[1] );
	    }
	    else {
		push @{ $_clusters[ $best_candidate_pair->[0] ] } , @{ $spliced_out_cluster };
	    }

	    # 3 - keep track of stats (# of clusters at current similarity level, etc)
	    push @_clusters_history_stats, [ scalar( @_clusters ), $best_candidate_pair_score ]; 
	
	    # we're good for another round
	    $was_modified = 1;
    
	}

	# print STDERR "here ... " . scalar(@_clusters) . "\n";

    }
    while ( $was_modified );

    return ( \@_clusters , \@_clusters_history_stats );

}

# check whether two clusters can be clustered and compute their similarity
sub check_clusterable {

    my $this = shift;
    my $cluster_1 = shift;
    my $cluster_2 = shift;

    my $is_clusterable = 0;
    my $similarity = 0;

    # compute similarity between all element pairs
    # Note: could we add an optimization for the single-link case ?
    my @all_similarities;
    foreach my $element_1 (@$cluster_1) {

	foreach my $element_2 (@$cluster_2) {

	    my $pair_similarity;

	    my $cache_key = join( "::", sort { $a cmp $b } ( $element_1 , $element_2 ) );
	    if ( defined( $this->similarity_cache()->{ $cache_key } ) ) {
		$pair_similarity = $this->similarity_cache->{ $cache_key };
	    }
	    else {
		$pair_similarity = $this->similarity_measure->($element_1,$element_2);
		$this->similarity_cache->{ $cache_key } = $pair_similarity;
	    }

	    if ( $pair_similarity > 0 ) {
		push @all_similarities, $pair_similarity;
	    }

	}

    }

    if ( scalar(@all_similarities) ) {

	if ( $this->mode() eq 'single-link' ) {
	    
	    $similarity = max(@all_similarities);
	    if ( $similarity >= $this->similarity_threshold() ) {
		$is_clusterable = 1;
	    }
	    
	}
	elsif ( $this->mode eq $MODE_AVERAGE_LINK ) {
	    
	    my $stat = Statistics::Descriptive::Full->new;
	    $stat->add_data(@all_similarities);
	    $similarity = $stat->mean();
	    if ( $similarity >= $this->similarity_threshold ) {
		$is_clusterable = 1;
	    } 
	    
	}
	elsif ( $this->mode() eq 'all-links' ) {
	    
	    $similarity = min(@all_similarities);
	    if ( $similarity >= $this->similarity_threshold ) {
		$is_clusterable = 1;
	    }
	 
	}
	elsif ( $this->mode() eq 'centroid' ) {

	    # here we dynamically merge elements
	    die "Hierarchical clustering mode not yet supported ...";

	}
	else {
	    die "Hierarchical clustering mode is not supported ...";
	}

    }

    return ($is_clusterable,$similarity);

}

__PACKAGE__->meta->make_immutable;

1;

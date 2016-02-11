package GistGraph::ClusterableGistGraph;

# Clusterable Gist Graph
# Gist Graph where nodes can be clustered according to a text-based similarity function

use strict;
use warnings;

use Moose;

use GistGraph;
extends 'GistGraph';

# build gist graph
sub _build {

    my $that = shift;
    my %params = @_;

    # build raw graph
    # TODO: is "init" the proper method name ?
    $gist_graph->init();

    # cluster graph
    print STDERR ">> Clustering Gist-Graph\n";
    $gist_graph->cluster( 1 );
    print STDERR "\n";

}

# run cluster transformation
# (for now we modify the current graph, should we make graph objects inalterable ?)
sub cluster {

    my $this = shift;
    my $check_integrity = shift;

    if ( $check_integrity && ! $this->check_integrity() ) {
	die "Gist graph is invalid before basic clustering ...";
    } 

    my @regular_clusters = @{ $this->get_regular_nodes() };
    my @special_clusters = @{ $this->get_special_nodes() };

    # cluster chunks based on surface cues
    my $basic_clusters = $this->_cluster('cluster_basic', \@regular_clusters, 'single-link', \&_cluster_basic_similarity, 0);

    if ( $check_integrity && ! $this->check_integrity() ) {
	die "Gist graph is invalid after basic clustering ...";
    } 

    # at this point the genericity of all the nodes in the graph is set
    # i.e. genericity is directly derived from surface/semantic features (?)

    my @temp_clusters = values( %{ $this->nodes() } );
    my ( $generic_clusters , $specific_clusters ) = $this->_determine_generic_specific_split( \@temp_clusters );

    # add labels for both generic and specific nodes
    map { $_->add_flag( $FLAG_GENERIC ) } @{ $generic_clusters };
    map { $_->add_flag( $FLAG_SPECIFIC ) } @{ $specific_clusters };

    # cluster unique chunks based on context
    # cluster with low genericity should be more likely to get clustered
    my $contextual_clusters = $this->_cluster('cluster_contextual', $specific_clusters, 'single-link', sub { $this->_cluster_contextual_similarity(@_); }, 0.5);

    if ( $check_integrity && ! $this->check_integrity() ) {
	die "Gist graph is invalid after contextual clustering ...";
    } 

}

# similarity function for _cluster_basic
# incompatible nodes have a similarity of -1
sub _cluster_basic_similarity {

    my $cluster1 = shift;
    my $cluster2 = shift;

    # compute compatibility score between the two clusters
    my $match_score = NPMatcher::match($cluster1,$cluster2);
    
    if ( $match_score && ! _mergeable($cluster1,$cluster2) ) {
	# print STDERR "Clusters [" . join(" || ", $cluster1->surface_string(), $cluster2->surface_string()) . "] match but are also non mergeable ... skipping ...\n";
	return -1;
    }
   
    return $match_score;

}

# cluster sort function
sub _cluster_sort {

    my $cluster_a = shift;
    my $cluster_b = shift;

    my $head_length_a = $cluster_a->head_length();
    my $head_length_b = $cluster_b->head_length();

    if ( $head_length_a < $head_length_b ) {

	return -1;

    }
    elsif ( $head_length_a == $head_length_b ) {

	# TODO: use a semantic definition here instead

	my $modifiers_a = $cluster_a->modifiers();
	my $modifiers_b = $cluster_b->modifiers();

	my $first_modifier_a = scalar(@$modifiers_a) ? $modifiers_a->[0] : "";
	my $first_modifier_b = scalar(@$modifiers_b) ? $modifiers_b->[0] : "";

	return ( length($first_modifier_a) <=> length($first_modifier_b) );

    }
    else {

	return 1;

    }

}

# check for existence of match for a cluster in a summary
# TODO: move this function ot a Summary (Gist ?) class ? 
sub _cluster_match {

    my $cluster = shift;
    my $summary = shift;

    my $cluster_id = $cluster->id();
    foreach my $summary_chunk (@$summary) {
	if ( $summary_chunk eq $cluster_id ) {
	    return 1;
	}
    }

    return 0;

}

# similarity function for _cluster_basic
# incompatible nodes have a similarity of -1
# based on --> neighbors and verbalization to neighbors
sub _cluster_contextual_similarity {

    my $this = shift;
    my $cluster1 = shift;
    my $cluster2 = shift;

    # make sure we have generated contexts for both cluster1 and cluster2
    # TODO: maybe we can turn this into a closure ?
    if ( ! defined( $this->contexts()->{ $cluster1->id() } ) ) {
	$this->contexts()->{ $cluster1->id() } = $this->_build_context( $cluster1 );
    }
    if ( ! defined( $this->contexts()->{ $cluster2->id() } ) ) {
	$this->contexts()->{ $cluster2->id() } = $this->_build_context( $cluster2 );
    }

    # compute similarity between these two contexts
    my $contextual_similarity = GistGraph::Node::Context::similarity( $this->contexts()->{ $cluster1->id() } , $this->contexts()->{ $cluster2->id() } );

    return $contextual_similarity;

=pod
    # sort context by decreasing number of matching clusters, then by decreasing weight
    my @sorted_contexts = sort { $context2weight{$b} <=> $context2weight{$a} } sort { scalar( @{ $all_contexts{ $b } } ) <=> scalar( @{ $all_contexts{ $a } } ) } @selected_contexts;

    # 2 - merge clusters following context ordering
    my %cluster_mapping;
    my $cluster_mapped_sub = sub {

	my $original_cluster = shift;
	my $resolution_sub = shift;

	my $mapping = $cluster_mapping{$original_cluster};
	if ( defined($mapping) ) {
	    return $resolution_sub->( $mapping );
	}

	return $original_cluster;

    };

    my $cluster_mapped_sub_wrapper = sub {
	my $original_cluster = shift;
	return $cluster_mapped_sub->($original_cluster,$cluster_mapped_sub);
    };

    foreach my $context (@sorted_contexts) {
	
	my $mergeable_clusters = $all_contexts{ $context };

	my $target_cluster = $cluster_mapped_sub->( $mergeable_clusters->[0] );

	for (my $i=1; $i<scalar(@$mergeable_clusters); $i++) {
	
	    my $mergeable_cluster = $cluster_mapped_sub_wrapper->( $mergeable_clusters->[$i] );

	}
	
    }

    foreach my $cluster (@candidate_clusters) {

	if ( defined($cluster_mapping{$cluster}) ) {
	    next;
	}

	push @cluster_output, $cluster;

    }
=cut

}

no Moose;

1;

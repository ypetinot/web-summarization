package Web::Summarizer::Graph2::GistGraph;

# Models gist graph for a specific instance

use Moose;
#extends 'Web::Summarizer::Graph2';

use Web::Summarizer::Graph2::Definitions;

use Clone qw/clone/;
use JSON;
use List::MoreUtils qw/uniq each_array/;
use String::Similarity;

# fields
has 'url' => (is => 'ro', isa => 'Str', required => 1);
has 'controller' => (is => 'ro', isa => 'Web::Summarizer::Graph2');
has 'graph' => (is => 'ro', isa => 'Graph', required => 1);

has 'features' => (is => 'ro', isa => 'HashRef', required => 1);
has 'fillers' => (is => 'ro', isa => 'HashRef', default => sub { {} });
has 'fillers_cache' => (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'filler_features' => (is => 'rw', isa => 'HashRef', default => sub { {} });
has 'virtual2node' => (is => 'rw', isa => 'HashRef', default => sub { {} });


#has 'features_reference' => (is => 'ro', isa => 'HashRef', required => 1);
has 'edge2features' => (is => 'rw', isa => 'HashRef', default => sub { {} });

has '_edge2cost' => (is => 'rw', isa => 'HashRef', default => sub { {} } );
has '_edge2dirty' => (is => 'rw', isa => 'HashRef', default => sub { {} } );

my $DEBUG = 1;

=pod
# Compute cost of an edge given a set of features and associated weights
sub _compute_edge_cost {
    
    my $this = shift;
    my $weights = shift;
    my $edge = shift;
    my $params = shift;

    my $use_shortest_path = $params->{ 'use_shortest_path' };

    my $edge_cost = 0;

    my $edge_features = $this->_compute_edge_features( $edge , $params );

    my $has_non_zero_feature = 0;
    foreach my $feature_id (keys %{ $edge_features }) {

	my $weight = _feature_weight( $weights , $feature_id );
	my $feature_value = $edge_features->{ $feature_id };

	if ( $feature_value ) {
	    $has_non_zero_feature++;
	}

	my $cost_update = $weight * $feature_value;
	if ( $cost_update ) {
	    # Multiplicative costs seem to prevent the occurrence of negative cycles ?
	    # TODO: try multiplicative costs also ?
	    $edge_cost += $cost_update;
	}
	
    }
    
    if ( ($DEBUG > 2) && $has_non_zero_feature ) {
	print STDERR "\tEdge " . join("::", @{ $edge }) . " has active feature ...\n";
    }

    my $edge_weight;
    my $TINY = 0.00000000001;
    
    if ( $use_shortest_path ) {
	#$edge_weight = -log( $TINY + $edge_cost );
	$edge_weight = $edge_cost;
    }
    else {
	$edge_weight = $edge_cost;
    }

    # TODO: include study of the best cost function ?
    return $edge_weight;
    #return sigmoid( $edge_weight );
    #return $edge_cost;
    #return exp( $edge_cost );

}
=cut

# activate paths
sub activate_path {

    my $this = shift;
    my $path = shift;

    my @activated_path;

    foreach my $node (@{ $path }) {

	# By default we just keep the existing node (?)
	my $activated_node = $node;

	# Is this a slot ?
	if ( $this->graph()->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {

	    # do we have fillers for it ?
	    my $candidates = $this->fillers_cache()->{ $node };
	    if ( defined( $candidates ) && scalar( @{ $candidates } ) ) {
		
		my $true_filler = decode_json( $this->graph()->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_DATA ) )->{ $this->url() };
		my $true_filler_surface = join(" ", @{ $true_filler });

		# search for best match
		my @sorted_candidates = sort { similarity( $true_filler_surface , $b->[ 0 ] ) <=> similarity( $true_filler_surface , $a->[ 0 ] ) } @{ $candidates };
		##if ( lc( $true_filler ) eq lc( $sorted_candidates[0]->[ 0 ] ) ) {
		if ( similarity( lc( $true_filler_surface ) , lc( $sorted_candidates[0]->[ 0 ] ) ) > 0.5 ) {
		    $activated_node = $sorted_candidates[0]->[ 1 ];
		}
		##}
		
	    }
	    
            # by default we just add the node to preserve the path ?

	}

	push @activated_path , $activated_node;
	
    }

    return \@activated_path;

}

# activate all slot nodes in the gist graph
sub activate_nodes {

    my $this = shift;
    
    my @nodes = $this->graph()->vertices();
    
    # 1 - activate all the nodes
    # TODO: this could probably be optimized and moved into the next loop
    foreach my $node (@nodes) {
	$this->activate_node( $node );
    }

=pod
	# Is node a slot ?
	if ( $this->graph()->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {
	    my $node_fillers = $this->fillers_cache()->{ $node };
	    push @from_set , map { $_->[ 1 ]; } @{ $node_fillers };
	}

	# look at all the successors for this node
	my @successors = $this->graph()->successors();
	foreach my $successor (@successors) {
		
	    # TODO: add default node ?
	    my @to_set;

	    # Is successor a slot ?
	    if ( $this->graph()->get_vertex_attribute( $successor , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {	    
		my $successor_fillers = $this->fillers_cache()->{ $successor };
		push @to_set , map { $_->[ 1 ]; } @{ $successor_fillers };
	    }

	}
=cut

}

# activate node --> map node to set of virtual nodes and identify true candidate (if in train mode only ?)
sub activate_node {

    my $this = shift;
    my $node = shift;

    my $first_character = substr( $node , 0 , 1 );

    if ( $this->graph()->get_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {
	    
	# special processing for slot nodes	      

	my @_candidates;
	
	# This is potentially a slot node
	my $slot_node_type = $node;
	$slot_node_type =~ s/\/\d+$//sg;
	    
	my $slot_node_candidates = $this->fillers()->{ $slot_node_type };
	    
	# 1 - list all candidates for this slot
	if ( defined( $slot_node_candidates ) ) {
		
	    my @slot_candidate_fillers = keys( %{ $slot_node_candidates } );
	    foreach my $slot_candidate_filler (@slot_candidate_fillers) {	
		
		# Create a virtual node for this (slot,candidate) pair
		# ( the id of the slot node is unique )
		my $virtual_successor_node = join("::", $node, $slot_candidate_filler);
		$this->virtual2node()->{ $virtual_successor_node } = $node;
		
		# Assign features to this virtual node
		my $filler_features = $slot_node_candidates->{ $slot_candidate_filler };
		my %virtual_node_features;
		map { $virtual_node_features{ join("::", $node, $_) } = $filler_features->{ $_ }; } keys( %{ $filler_features } );
		$this->filler_features()->{ $virtual_successor_node } = \%virtual_node_features;

		# finally add virtual node to the list of candidate successors
		push @_candidates, [ $slot_candidate_filler , $virtual_successor_node , \%virtual_node_features ];
		
	    }
	    
	}
	
	# set cache
	$this->fillers_cache()->{ $node } = \@_candidates;

    }
    else {
	
	# this is a regular node, no activation required
	return $node;
	
    }

}

# get successors for the specified node
# TODO: out-going edge from a slot node should have constant/0 weight
sub successors {

    my $this = shift;
    my $node = shift;

    # 0 - make sure we're working with non-virtual nodes
    my $non_virtual_node = $this->virtual2node()->{ $node };
    if ( defined( $non_virtual_node ) ) {
	$node = $non_virtual_node;
    }

    # 1 - get successors from reference graph    
    my @reference_successors = $this->graph()->successors( $node );

    my @successors;

    # 2 - process each reference successor independently
    foreach my $reference_successor (@reference_successors) {

	# --> if the successor is a slot, actually return all the candidates
	if ( $this->graph()->get_vertex_attribute( $reference_successor , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT ) ) {
	    
	    # get all candidates for this slot
	    my $candidates = $this->fillers_cache()->{ $node };
	    if ( $candidates ) {
		push @successors, map { $_->[ 1 ] } @{ $candidates };
		next;
	    }

	}

	# --> otherwise return regular node
	push @successors, $reference_successor;

    }

    return @successors;

}

# "dynamically" determine cost of an edge in the gist graph
# Used to be compute_edge_cost
sub get_edge_cost {

    my $this = shift;
    my $from = shift;
    my $to = shift;
    my $weights = shift;
    my $params = shift;

    my $edge_key = $this->controller()->_edge_key( [ $from , $to ] );
    my $is_dirty = $this->_edge2dirty()->{ $edge_key };

    if ( defined( $is_dirty ) && !$is_dirty ) {
	return $this->_edge2cost()->{ $edge_key };
    }

    # 1 - retrieve features for the target edge
    my $edge_features = $this->_compute_edge_features( [ $from , $to ] , $params );

    my $edge_cost = 0;
    map { $edge_cost += $edge_features->{ $_ } * $weights->{ $_ } } grep { $weights->{ $_ } } keys( %{ $edge_features } );

    $this->_edge2dirty()->{ $edge_key } = 0;
    $this->_edge2cost()->{ $edge_key } = $edge_cost;

    return $edge_cost;

}

# Mark edge for cost recomputation
sub mark_edge_dirty {

    my $this = shift;
    my $edge = shift;

    my $edge_key = $this->controller()->_edge_key( $edge );

    $this->_edge2dirty()->{ $edge_key } = 1;
    $this->_edge2cost()->{ $edge_key } = undef;

}

sub _compute_edge_features {

    my $this = shift;
    my $edge = shift;
    my $params = shift;

    my $edge_source = $edge->[ 0 ];
    my $edge_sink = $edge->[ 1 ];

    # --> return edge features

    my $edge_source_non_virtual = $this->virtual2node()->{ $edge_source };
    my $edge_sink_non_virtual = $this->virtual2node()->{ $edge_sink };

    # --> if target of the edge is a slot, then return slot features
    if ( defined( $edge_sink_non_virtual ) ) {
	return $this->filler_features()->{ $edge_sink };
    }
    # --> if source of the edge is a slot, treat slot as original node
    if ( defined( $edge_source_non_virtual ) ) {
	$edge_source = $edge_source_non_virtual;
    }

    # redefine edge
    $edge = [ $edge_source , $edge_sink ];

    # we are now ready to compute the edge key
    my $edge_key = $this->controller()->_edge_key( $edge );

    if (  ! defined( $this->edge2features()->{ $edge_key } ) ) {

	my $features = {};
	
	# Get feature definitions (ids) from the controller
#	print STDERR "Getting edge features --> ";
	my ( $edge_feature_ids , $object_feature_ids ) = $this->controller()->_get_features( $edge , $params );
#	print STDERR "[ok]\n";

	my $raw_edge_features = $this->features()->{ $Web::Summarizer::Graph2::Definitions::FEATURES_KEY_EDGE };
	
	my $raw_object_features = $this->features()->{ $Web::Summarizer::Graph2::Definitions::FEATURES_KEY_OBJECT };
	my $mapped_object_features = $this->controller()->_map_object_features( $raw_object_features , $edge );

	foreach my $feature_entry ( [ $edge_feature_ids , $raw_edge_features ] , [ $object_feature_ids , $mapped_object_features ] ) {
	    
	    my $feature_ids = $feature_entry->[ 0 ];
	    my %_feature_mapping;
	    if ( $DEBUG && ( ref( $feature_ids ) ne 'ARRAY' ) ) {
		#print STDERR "Issue with feature ids for edge [" . join(",", @{ $edge }) . "]\n";
		use Data::Dumper;
		print STDERR "Issue with feature ids for edge: " . Dumper( $edge ) . "\n";
		# For now we just skip ?
		next;
	    }
	    map { $_feature_mapping{ $_ } = 1; } @{ $feature_ids };

	    my $raw_features = $feature_entry->[ 1 ];
	    
	    foreach my $feature_id (keys( %{ $raw_features } )) {
		
		if ( ! $_feature_mapping{ $feature_id } ) {
		    next;
		}

		#foreach my $feature_id (@{ $feature_ids }) {
		# TODO: try with non-binary edge penalties ?
		my $feature_value = ( ( $raw_features->{ $feature_id } || $Web::Summarizer::Graph2::Definitions::FEATURE_DEFAULT ) ? 1 : 0 ) * 1;
		if ( $feature_value != 0 ) {
		    $features->{ $feature_id } = $feature_value;
		}
		
=pod
		# keep track of feature to edge mapping
		if ( $DEBUG > 2 && defined( $this->feature2edge()->{ $feature_id } ) ) {
		    my $cached_edge = $this->feature2edge()->{ $feature_id };
		    my $cached_edge_surface = join("::", @{ $cached_edge });
		    my $edge_surface = join("::", @{ $edge });
		    if ( $cached_edge_surface ne $edge_surface ) {
			die "Feature/Edge mapping mismatch: $feature_id / $cached_edge_surface / $edge_surface";
		    }
		}
		$this->feature2edge()->{ $feature_id } = $edge;
=cut
		
	    }
	    
	}

	$this->edge2features()->{ $edge_key } = $features;

    }
    else {
#	print STDERR "Got edge features from cache !\n";
    }

    return $this->edge2features()->{ $edge_key };
##    return $features;

}

# find optimal path for the current set of weights
sub _optimal_path {

    my $this = shift;
    my $weights = shift;
    my $label = shift;
    my $params = shift;

    print STDERR "Searching optimal path for $label ...\n";

=pod
    # 1 - produce weighted graph for the current object (features)
    my $weighted_graph = $this->_compute_weighted_graph( $weights , $params );

    if ( $DEBUG > 2 ) {
	# dump weighted graph
	print STDERR "Weighted graph: $weighted_graph\n";
	foreach my $edge ($weighted_graph->edges()) {
	    print STDERR "Edge: (" . join(",", @{$edge}) . ") : " .$weighted_graph->get_edge_weight( @{$edge} ) . "\n";
	}
    }
=cut

    # 2 - find optimal  path in weighted graph

=pod
    if ( $use_shortest_path ) {
	# shortest path
	#@optimal_path = $weighted_graph->SP_Dijkstra( $NODE_BOG , $NODE_EOG );
	#@optimal_path = $weighted_graph->SP_Bellman_Ford( $NODE_BOG , $NODE_EOG );
	#@optimal_path = _lp_solve_shortest_path( $weighted_graph , $NODE_BOG , $NODE_EOG );
	#@optimal_path = _optimal_path_beam_search( $weighted_graph , $NODE_BOG , $NODE_EOG , 10 , $use_shortest_path );
    }
    else {
	# longest path
	@optimal_path = _optimal_path_beam_search( $weighted_graph , $NODE_BOG , $NODE_EOG , 10 , $use_shortest_path );
    }
=cut

    #@optimal_path = _optimal_path_beam_search( $weighted_graph , $NODE_BOG , $NODE_EOG , $params );
#    my ( $path_optimal , $optimal_path_stats ) = $this->_optimal_path_limited_beam_search( $Web::Summarizer::Graph2::Definitions::NODE_BOG , $Web::Summarizer::Graph2::Definitions::NODE_EOG , $weights , $params );
    my ( $path_optimal , $optimal_path_stats ) = $this->_optimal_path_acceptance_beam_search( $Web::Summarizer::Graph2::Definitions::NODE_BOG , $Web::Summarizer::Graph2::Definitions::NODE_EOG , $weights , $params );

    #@optimal_path = $weighted_graph->SP_Bellman_Ford( $NODE_BOG , $NODE_EOG );

#    if ( $DEBUG ) {
	#print STDERR ">> optimal path stats : " . join(" ", map { join(":", $_, $optimal_path_stats->{ $_ }) } keys(%{ $optimal_path_stats } ) ) . "\n";
	#print STDERR ">> computing optimal path for $label ...\n";
	print STDERR join("\t", $label, join(" ", @{ $path_optimal }), join(" ", @{ $params->{ 'current_target' } }), join(" ", map { join(":", $_, $optimal_path_stats->{ $_ }) } keys(%{ $optimal_path_stats } ) ) ) . "\n\n"; 
#    }
    
    return $path_optimal;

}

# Acceptance-based Beam Search
sub _optimal_path_acceptance_beam_search {

    my $this = shift;
    my $from = shift;
    my $to = shift;
    my $weights = shift;
    my $params = shift || {};

    my $length_distribution = $params->{ 'length_distribution' };
    my $bucket_size = $params->{ 'length_distribution_bucket_size' };
    
    my %distribution;
    map {

	my $bucket = int( $_ / $bucket_size );
	$distribution{ $bucket }++;

    } @{ $length_distribution };
    
    # normalize distribution
    my $n_events = scalar( @{ $length_distribution } );
    map { $distribution{ $_ } /= $n_events; } keys( %distribution );

    my $acceptance_filter = sub {
	    
	my $candidate_path = shift;
	
	my $candidate_length = scalar(@{ $candidate_path });
	my $candidate_length_probability = $distribution{ int( $candidate_length / $bucket_size ) } || 0;
	my $random_value = rand(1);

	if ( $random_value < $candidate_length_probability ) {
	    return 1;
	}
	
	return 0;
	
    };

    return $this->_optimal_path_beam_search( $from , $to , $weights , $params , $acceptance_filter , undef );

}

# limited Beam Search
sub _optimal_path_limited_beam_search {

    my $this = shift;
    my $from = shift;
    my $to = shift;
    my $weights = shift;
    my $params = shift || {};

    my $min_length = $params->{ 'acceptance_min_length' };
    my $max_length = $params->{ 'acceptance_max_length' };

    my $acceptance_filter_lower = sub {

	my $candidate_path = shift;
   
	my $candidate_length = scalar(@{ $candidate_path });
	if (
	    ( $min_length && $candidate_length >= $min_length )
	    )
	{
	    return 1;
	}
	
	return 0;

    };

    my $acceptance_filter_upper = sub {

	my $candidate_path = shift;
   
	my $candidate_length = scalar(@{ $candidate_path });
	if (
	    ( $max_length && $candidate_length <= $max_length )
	    )
	{
	    return 1;
	}
	
	return 0;

    };

    return $this->_optimal_path_beam_search( $from , $to , $weights , $params , $acceptance_filter_lower , $acceptance_filter_upper );

}

# Approximate optimal path using Beam Search
sub _optimal_path_beam_search {

    my $this = shift;
    my $from = shift;
    my $to = shift;
    my $weights = shift;
    my $params = shift;
    my $acceptance_filter_lower = shift;
    my $acceptance_filter_upper = shift;

    my $beam_size = $params->{ 'beam_size' };
    my $use_shortest_path = $params->{ 'use_shortest_path' };
    my $use_early_update = $params->{ 'use_early_update' };

    my $target_path = $params->{ 'current_target' };
    my $early_update_ok = 1;

    # TODO: turn path into Path class
    my @paths = ( [ [ $from ] , 0 , 0 , 1 , 1 , { $from => 1 } ] );
    my @paths_final;
    my $early_update_count = scalar(@paths);
    my $early_update_last_violation = undef;

    my $found = 0;
    my $stats = {};

    # TODO: make these params
#   my $FOUND_EXTRA = 10;
    my $FOUND_EXTRA = -1;
    my $found_extra = $FOUND_EXTRA;

    my $n_iterations = 0;
    
    while ( (!$found) || ($found_extra > 0) ) {

	if ( $found ) {
	    $found_extra--;
	}
       
	$n_iterations++;
	if ( ! $n_iterations % 1000 ) {
	    print STDERR ">> beam search iteration: $n_iterations\n";
	}

	# TODO: add test for empty path list ? empty list of successors if not eog node ?
	if ( $n_iterations > 1000 ) {
	    print STDERR ">> Reached set limit to obtain optimal path --> $n_iterations / $found\n";
	    # TODO: is having a default path empty acceptable ?
	    return ( $paths[0] || [] , $stats );
	}

	# iterate over current candidate paths
	my $n_candidates = scalar(@paths);
	for (my $i=0; $i<$n_candidates; $i++) {
	    
	    my $current_entry = shift @paths;
	    my $current_path = $current_entry->[ 0 ];
	    my $current_score = $current_entry->[ 1 ];
	    my $current_found = $current_entry->[ 2 ];
	    my $current_early = $current_entry->[ 3 ];
	    my $current_length = $current_entry->[ 4 ];
	    my $current_seen = $current_entry->[ 5 ];

	    $early_update_count -= $current_early;

	    my $current_node = $current_path->[ $#{ $current_path } ];

	    # expand current path
	    my @neighbors = $this->successors( $current_node );
	    if ( $DEBUG && ($current_node ne $to) && ! scalar(@neighbors) ) {
		die "Structural problem !";
	    }
	    foreach my $neighbor (@neighbors) {
		
		if ( $DEBUG && ($neighbor eq $from) ) {
		    die "Structural problem: ran into $from !";
		}

		if ( defined( $current_seen->{ $neighbor } ) ) {
		    next;
		}

		$stats->{ 'candidates' }++;
		if ( ! $stats->{ 'candidates' } % 100 ) {
		    print STDERR "\t" . $stats->{ 'candidates' } . "\n";
		}

		my $local_found = 0;
		
		my $new_path = clone( $current_path );
		push @{ $new_path }, $neighbor;

		# TODO: clone the whole entry instead ?
		my $new_seen = clone( $current_seen );
		$new_seen->{ $neighbor }++;

		if ( $neighbor eq $to ) {
		    
		    # Ignore a path if it breaks the "lower" acceptance criteria
		    if ( defined( $acceptance_filter_lower ) ) {
			if ( ! $acceptance_filter_lower->( $new_path ) ) {
			    next;
			}
		    }

		    $found = 1;
		    $local_found = 1;
		    
		    # reset found extra
		    $found_extra = $FOUND_EXTRA;
		    
		}

		# Ignore a path right away if it breaks the "upper" acceptance criteria
		if ( defined( $acceptance_filter_upper ) ) {
		    if ( ! $acceptance_filter_upper->( $new_path ) ) {
			next;
		    }
		}
				
		my $local_early_update_ok = $current_early;
		if ( $local_early_update_ok ) {

		    if ( scalar( @{ $new_path } ) <= scalar( @{ $target_path } ) ) {
			if ( $new_path->[ $#{ $new_path } ] ne $target_path->[ $#{ $new_path } ] ) {
			    $local_early_update_ok = 0;
			}
		    }
		    else {
			$local_early_update_ok = 0;
		    }

		    if ( ! $local_early_update_ok ) {
			$early_update_last_violation = $new_path;
		    }
		    else {
			$early_update_count++;
		    }
	    
		}

		# TODO: weight cache ?
		my $new_path_score = $current_score + $this->get_edge_cost( $current_node , $neighbor , $weights , $params );
		my $path_entry = [ $new_path , $new_path_score , $local_found , $local_early_update_ok , $current_length + 1 , $new_seen ];

		if ( $local_found ) {
		    push @paths_final, $path_entry;
		}
		else {
		    push @paths, $path_entry;
		}
		
	    }
	    
	}

	if ( $use_early_update && ( ! $early_update_count ) ) {
	    return ( $early_update_last_violation , $stats );
	}

	# sort candidates by decreasing score
	my @sorted_paths;
	if ( $use_shortest_path ) {
	    @sorted_paths = sort { $a->[ 1 ] <=> $b->[ 1 ] } @paths;
	}
	else {
	    @sorted_paths = sort { $b->[ 1 ] <=> $a->[ 1 ] } @paths;
	}
	@paths = @sorted_paths;

	if ( $DEBUG ) {

	    my @broken_paths = grep { scalar( @{ $_->[ 0 ] } ) != $_->[ 4 ] } @sorted_paths;
	    if ( scalar( @broken_paths ) ) {
		die "Found corrupted paths !";
	    }

	}

	# truncate candidate set to beam size if necessary
	if ( scalar(@paths) > $beam_size ) {
	    splice @paths, $beam_size;
	}
	    
    }	
    
    my @candidate_paths;
    if ( $use_shortest_path ) {
	@candidate_paths = sort { $a->[ 1 ] <=> $b->[ 1 ] } @paths_final;
    }
    else {
	@candidate_paths = sort { $b->[ 1 ] <=> $a->[ 1 ] } @paths_final;
    }
    
    return ( $candidate_paths[0]->[0] , $stats );
    
}

# combine/intersect full input features with current path
sub _compute_path_features {

    my $this = shift;
    my $path = shift;
    my $params = shift;

    my $features = {};

    # Loop over edges that are present in $path --> all other edge features are therefore/implicitly forced to be 0
    for (my $i=0; $i<scalar(@{ $path }) - 1; $i++) {
	
	my $from = $path->[ $i ];
	my $to = $path->[ $i + 1 ];

	my $current_edge = [ $from , $to ];
	my $edge_features = $this->_compute_edge_features( $current_edge , $params );

	map { $features->{ $_ } = $edge_features->{ $_ }; } keys( %{ $edge_features } );

    }

    return $features;
    
}

=pod
# TODO: make this about edge cost ?
sub update_feature_weights {

    my $this = shift;
    my $updated_weights = shift;
    
    foreach my $updated_weight_id (keys(%{ $updated_weights })) {

	my $updated_weight_value = $updated_weights->{ $updated_weight_id };

	# update feature weight
	$this->feature_weights()->{ $updated_weight_id } = $updated_weights->{ $updated_weight_id };

	# mark corresponding edge as dirty
	# TODO - for now we recompute everything ?
	# my $edge = _map_feature_to_edge

    }
       
}
=cut

# Compute weighted graph
sub _compute_weighted_graph {

    my $this = shift;
    my $weights = shift;
    my $params = shift;

    foreach my $edge ($this->graph()->edges()) {
	$this->_update_edge_cost( $weights , $edge , $params );
    }

}

# Identify set of features that are candidates for update, also return the corresponding feature values for the object under consideration
# Can we identity which edges are concerned by the update ?
sub _update_feature_ids {
    
    my $this = shift;
    my $features_reference = shift;
    my $path_optimal = shift;
    my $params = shift;

    my @affected_edges;
    my @feature_ids;
    my $features_optimal = {};

    my $node_b = $path_optimal->[ $#{ $path_optimal } ];
    if ( ! defined( $node_b ) ) {
	if ( $DEBUG ) {
	    print STDERR "Problem, optimal path has invalid terminal node ...";
	}
    }
    elsif ( $params->{ 'use_early_update' } && ( $node_b ne $Web::Summarizer::Graph2::Definitions::NODE_EOG ) ) {

	# optimal path is the one following the target path that was also the last one to fall off the search beam 
	# list features based on last node of optimal path
	my $node_a = $path_optimal->[ $#{ $path_optimal } - 1 ];
	my $last_edge = [ $node_a , $node_b ];

	$features_optimal = $this->_compute_path_features( $last_edge , $params );
	
	# Correct ?
	@feature_ids = keys( %{ $features_optimal } );
	@affected_edges = ( $last_edge );

    }
    else {

	# compute features (energy) for the current optimal path
	$features_optimal = $this->_compute_path_features( $path_optimal , $params );

	# TODO: can be cached
	@feature_ids = (uniq( keys( %{ $features_reference } ) , keys( %{ $features_optimal } ) ));

	for (my $i=0; $i<scalar(@{ $path_optimal })-1; $i++) {
	    push @affected_edges, [ $path_optimal->[ $i ] , $path_optimal->[ $i + 1 ] ];
	}

    }

    return ( \@feature_ids , $features_optimal , \@affected_edges);

}

no Moose;

1;

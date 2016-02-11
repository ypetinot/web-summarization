package WordGraph::Decoder::BeamSearchDecoder;

# Models gist graph for a specific instance

#use Moose;
#use Moose::Role;
use MooseX::Role::Parameterized;

parameter use_early_update => (
    isa => 'Bool',
    required => 0,
    default => 0
    );

parameter beam_size => (
    isa => 'Num',
    required => 1
    );

# TODO : this has to go, but how ?
parameter reference_construction_limit => (
    isa => 'Num',
    required => 1
    );

parameter edge_model => (
    isa => 'Str',
    required => 1
    );

parameter word_graph_transformations => (
    isa => 'ArrayRef',
    default => sub { [] }
    );

role {

    my $p = shift;
    my $_use_early_update = $p->use_early_update;
    my $_beam_size = $p->beam_size;

    my %params;
    my $slots = $p->meta->{_meta_instance}->{slots};
    map { $params{ $_ } = $p->{ $_ } } @{ $slots };
    with( 'WordGraph::Decoder' => \%params );

    # use early update
    has 'use_early_update' => ( is => 'ro' , isa => 'Bool' , default => $_use_early_update );
    
    # use shortest path
    has 'use_shortest_path' => ( is => 'ro' , isa => 'Bool' , default => 1 );

    # length distribution bucket size
    has 'length_distribution_bucket_size' => ( is => 'ro' , isa => 'Num' , default => 5 );

    # beam size
    has 'beam_size' => ( is => 'ro' , isa => 'Num' , default => $_beam_size );

    use Web::Summarizer::Graph2::Definitions;
    
    use Clone qw/clone/;
    use JSON;
    use List::MoreUtils qw/uniq each_array/;
    use String::Similarity;
    
    my $DEBUG = 0;
    
    # TODO: what we really need to do is make sure the reference data is clean UTF-8
    use bytes;
    
=pod
    method "_compute_edge_features" => sub {
	
	my $this = shift;
	my $edge = shift;
	
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
	    $this->debug( "Getting edge features --> " );
	    my ( $edge_feature_ids , $object_feature_ids ) = $this->controller()->_get_features( $edge );
	    $this->debug( "[ok]" );

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
		    
		}
		
	    }
	    
	    $this->edge2features()->{ $edge_key } = $features;
	    
	}
	else {
	    $this->debug( "Got edge features from cache !" );
	}
	
	return $this->edge2features()->{ $edge_key };
	
    };
=cut
    
    # find optimal path for the current set of weights
    method "_decode" => sub {
	
	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	
	my ( $path_optimal , $optimal_path_stats ) = $this->_optimal_path_acceptance_beam_search(
	    $graph , $instance ,
	    $graph->source_node(), # $Web::Summarizer::Graph2::Definitions::NODE_BOG ,
	    $graph->sink_node(), # $Web::Summarizer::Graph2::Definitions::NODE_EOG
	    );
	
	return ( $path_optimal , $optimal_path_stats );
	
    };
    
    # Acceptance-based Beam Search
    method _optimal_path_acceptance_beam_search => sub {

	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	my $from = shift;
	my $to = shift;
	
	# TODO : make sure we only use training paths
	my @length_distribution = map { $_->length() } values(%{ $graph->paths });
	my $bucket_size = $this->length_distribution_bucket_size();
	
	my %distribution;
	map {
	    
	    my $bucket = int( $_ / $bucket_size );
	    $distribution{ $bucket }++;
	    
	} @length_distribution;
	
	# normalize distribution
	my $n_events = scalar( @length_distribution );
	map { $distribution{ $_ } /= $n_events; } keys( %distribution );
	
	my $acceptance_filter_lower = sub {
	    
	    my $candidate_path = shift;
	    
	    my $candidate_length = scalar(@{ $candidate_path });
	    my $candidate_length_probability = $distribution{ int( $candidate_length / $bucket_size ) } || 0;
	    my $random_value = rand(1);
	    
	    if ( $random_value < $candidate_length_probability ) {
		return 1;
	    }
	    
	    return 0;
	    
	};
	
	my $acceptance_filter_upper = undef;
	
	return $this->_optimal_path_beam_search( $graph , $instance , $from , $to , $acceptance_filter_lower , $acceptance_filter_upper );
	
    };
    
    # limited Beam Search
    method "_optimal_path_limited_beam_search" => sub {
	
	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	my $from = shift;
	my $to = shift;
	my $min_length = shift;
	my $max_length = shift;
	
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
	
	return $this->_optimal_path_beam_search( $from , $to , $acceptance_filter_lower , $acceptance_filter_upper );
	
    };
    
    # Approximate optimal path using Beam Search
    method "_optimal_path_beam_search" => sub {
	
	my $this = shift;
	my $graph = shift;
	my $instance = shift;
	my $from = shift;
	my $to = shift;
	my $acceptance_filter_lower = shift;
	my $acceptance_filter_upper = shift;
	
	my $beam_size = $this->beam_size();
	my $use_shortest_path = $this->use_shortest_path();
	my $use_early_update = ( ! $this->test_mode() ) && ( $this->use_early_update() || 0 );
	
	my $target_path = $graph->paths()->{ $instance->[ 0 ]->id };
	
	# TODO: turn path into Path class
	my @paths = ( [ [ $from ] , 0 , 0 , 1 , 1 , { $from => 1 } ] );
	my @paths_final;
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
	    if ( ! $n_candidates ) {
		print STDERR "Empty beam ... will stop ...\n";
		last;
	    }
	    
	    print STDERR "[Beam Search] iteration : $n_iterations | beam size : $n_candidates\n";
	    
	    if ( $DEBUG ) {
		
		print STDERR "Current beam // target : " . join( " " , map { $_->realize_debug( $instance ) } @{ $target_path } ) . "\n";
		map { print STDERR join( " / " , join( " " , map { $_->realize_debug( $instance ) } @{ $_->[ 0 ] } ) ) . "\n"; } @paths;
		print STDERR "\n\n";
		
	    }
	    
	    for (my $i=0; $i<$n_candidates; $i++) {
		
		my $current_entry = shift @paths;
		my $current_path = $current_entry->[ 0 ];
		my $current_score = $current_entry->[ 1 ];
		my $current_found = $current_entry->[ 2 ];
		
		# indicates whether the current path is compatible with the target path
		my $current_early = $current_entry->[ 3 ];
		
		my $current_length = $current_entry->[ 4 ];
		my $current_seen = $current_entry->[ 5 ];
		
		my $current_node = $current_path->[ $#{ $current_path } ];
		
		# expand current path
		my @neighbors = $graph->successors( $current_node , $instance , 1 );
		
                # This is actually ok since slot locations may not be fillable (hence not traversable)
                #	    if ( $DEBUG && ($current_node ne $to) && ! scalar(@neighbors) ) {
                #		die "Structural problem !";
                #	    }
		
		foreach my $neighbor (@neighbors) {
		    
		    if ( $DEBUG && ! $graph->get_edge_attribute( $current_node , $neighbor , $Web::Summarizer::Graph2::Definitions::EDGE_ATTRIBUTE_WIDTH ) ) {
			die "Structural problem: edge ( $current_node --> $neighbor ) does not exist !";
		    }
		    elsif ( $DEBUG && ($neighbor eq $from) ) {
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
		
		    my $new_path = clone_path( $current_path );
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
		    
		    my $local_early_update_ok = $use_early_update && $current_early;
		    if ( $local_early_update_ok ) {
			
			if ( scalar( @{ $new_path } ) <= scalar( @{ $target_path } ) ) {
			    # TODO : refine comparison to account for case, potential noise, etc.
			    if ( $new_path->[ $#{ $new_path } ]->realize( $instance ) ne
				 $target_path->[ $#{ $new_path } ]->realize( $instance ) ) {
				$local_early_update_ok = 0;
			    }
			}
			else {
			    $local_early_update_ok = 0;
			}
			
			if ( ! $local_early_update_ok ) {
			    if ( $DEBUG ) {
				print STDERR "Added violating path ...\n";
			    }
			    $early_update_last_violation = $new_path;
			}
			
		    }
		    
		    #my $neighbor_edge_cost = $graph->edge_cost->compute( $instance , [ $current_node , $neighbor ] );
		    my $neighbor_edge_cost = $this->model->compute( $graph , [ $current_node , $neighbor ] , $instance );
		    my $new_path_score = $current_score + $neighbor_edge_cost;
		    my $path_entry = [ $new_path , $new_path_score , $local_found , $local_early_update_ok , $current_length + 1 , $new_seen ];
		    
		    if ( $local_found ) {
			push @paths_final, $path_entry;
		    }
		    else {
			push @paths, $path_entry;
		    }
		    
		}
		
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
	    # TODO: extend beam size to include tail entries having the same score as the last entry in the beam ?
	    if ( scalar(@paths) > $beam_size ) {
		splice @paths, $beam_size;
	    }
	    
	    # since we rerank and truncate, this is the only safe way to determine whether the target has already fallen off the beam ...
	    my $early_update_ok = grep { $_->[ 3 ] } @paths;
	    if ( $use_early_update && ( ! $early_update_ok ) ) {
		if ( $DEBUG ) {
		    print STDERR "Early update !\n";
		}
		return ( $early_update_last_violation , $stats );
	    }
	    
	}	
	
	my @candidate_paths;
	if ( $use_shortest_path ) {
	    @candidate_paths = sort { $a->[ 1 ] <=> $b->[ 1 ] } @paths_final;
	}
	else {
	    @candidate_paths = sort { $b->[ 1 ] <=> $a->[ 1 ] } @paths_final;
	}
	
	# TODO: modify method to directly work with Path instances ?
	# TODO: is it even possible to end up with no candidate path ? bug ?
	my $candidate_path_object = scalar( @candidate_paths ) ?
	    new WordGraph::Path( graph => $graph , node_sequence => $candidate_paths[ 0 ]->[ 0 ] , object => $instance->[ 0 ] ) : undef;
	
	return ( $candidate_path_object , $stats );
	
    };

    # Identify set of features that are candidates for update, also return the corresponding feature values for the object under consideration
    # Can we identity which edges are concerned by the update ?
    # my ($update_feature_ids , $features_optimal , $affected_edges) = $this->graph() ... ->_update_feature_ids( $this->features()->{ $url } , $path_optimal );
    method "_update_feature_ids" => sub {
	
	my $this = shift;
	my $features_reference = shift;
	my $path_optimal = shift;
	
	my @affected_edges;
	my @feature_ids;
	my $features_optimal = {};
	
	my $node_b = $path_optimal->[ $#{ $path_optimal } ];
	if ( ! defined( $node_b ) ) {
	    if ( $DEBUG ) {
		print STDERR "Problem, optimal path has invalid terminal node ...";
	    }
	}
	
	elsif ( $this->use_early_update() && ( $node_b ne $Web::Summarizer::Graph2::Definitions::NODE_EOG ) ) {
	    
	    # optimal path is the one following the target path that was also the last one to fall off the search beam 
	    # list features based on last node of optimal path
	    my $node_a = $path_optimal->[ $#{ $path_optimal } - 1 ];
	    my $last_edge = [ $node_a , $node_b ];
	    
	    $features_optimal = $this->_compute_path_features( $last_edge );
	    
	    # Correct ?
	    @feature_ids = keys( %{ $features_optimal } );
	    @affected_edges = ( $last_edge );
	    
	}
	else {
	    
	    # compute features (energy) for the current optimal path
	    $features_optimal = $this->_compute_path_features( $path_optimal );
	    
	    # TODO: can be cached
	    @feature_ids = (uniq( keys( %{ $features_reference } ) , keys( %{ $features_optimal } ) ));
	    
	    for (my $i=0; $i<scalar(@{ $path_optimal })-1; $i++) {
		push @affected_edges, [ $path_optimal->[ $i ] , $path_optimal->[ $i + 1 ] ];
	    }
	    
	}
	
	return ( \@feature_ids , $features_optimal , \@affected_edges);
	
    };

};

sub clone_path {
	
    my $path = shift;
    
    my @cloned_path;
    foreach my $path_node (@{ $path }) {
	push @cloned_path, $path_node->clone();
    }
    
    return \@cloned_path;
	
}

#__PACKAGE__->meta->make_immutable;

1;

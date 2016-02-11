package WordGraph::EdgeWeighter::StructuredPerceptronEdgeWeighter;

use Statistics::Basic qw(:all);

use Moose;

extends 'WordGraph::EdgeWeighter';

my $DEBUG = 1;

# compute weights
sub compute_weights {
    
    my $this = shift;
    my $params = shift;

    my $iterations = $params->{ 'iterations' };
    my $use_shortest_path = $params->{ 'use_shortest_path' };
    

    my %w;
    my $y_activated = $this->paths();

# 2 - iterate
    my $ALPHA = 1;
    print STDERR "Structured perceptron now learning ...\n";
    for (my $i=0; $i<$iterations; $i++) {
	
	my %optimal_paths;
	my $updated = 0;
	
	my %w_copy = %w;
	
	# 2 - 1 - iterate over training samples
	foreach my $url (keys( %{ $y_activated } )) {
	    
	    my $updated_url = 0;
	    
	    # \phi(x,y)
	    # $features_reference{ $url };
	    $params->{ 'current_target_url' } = $url;
	    $params->{ 'current_target' } = $y_activated->{ $url };
	    
	    # 2 - 1 - 1 - find optimal path for the current training sample
	    # Identify optimal path given current w
	    # We don't need to update the graph, the weights can be absorbed dynamically (beam search !)
	    my $path_optimal = $this->graphs()->{ $url }->_optimal_path( \%w , $url , $params);
	    $optimal_paths{ $url } = $path_optimal;
	    
	    # 2 - 1 - 2 - update weights based on features (energy) error
	    # w is in feature space
	    my ($update_feature_ids , $features_optimal , $affected_edges) = $this->graphs()->{ $url }->_update_feature_ids( $this->features()->{ $url } , $path_optimal , $params );
	    my @update_feature_ids_actual;
	    foreach my $feature_id (@{ $update_feature_ids }) {
		
		my $feature_reference = ( $this->features()->{ $url }->{ $feature_id } || $Web::Summarizer::Graph2::Definitions::FEATURE_DEFAULT );
		my $feature_current = ( $features_optimal->{ $feature_id } || $Web::Summarizer::Graph2::Definitions::FEATURE_DEFAULT );
		
		my $feature_delta = $feature_reference - $feature_current;
		if ( $feature_delta ) {
		    
		    $updated++;
		    $updated_url++;
		    
		    if ( $DEBUG > 2 ) {
			print STDERR "\tUpdating feature $feature_id --> $feature_delta\n";
		    }
		    
		    my $feature_updated_value = undef;
		    if ( $use_shortest_path ) {
			# shortest path formulation
			$feature_updated_value = Web::Summarizer::Graph2::_feature_weight( \%w , $feature_id ) - $ALPHA * $feature_delta;
		    }
		    else {
			# longest path formulation
			$feature_updated_value = Web::Summarizer::Graph2::_feature_weight( \%w , $feature_id ) + $ALPHA * $feature_delta;
		    }
		    
		    $w{ $feature_id } = $feature_updated_value;
		    push @update_feature_ids_actual, $feature_id;
		    
		}
		
	    }
	    
	    if ( $updated_url ) {
		# Mark all (can we optimize that ?) along the optimal path as dirty
		foreach my $url2 (keys( %{ $y_activated } )) {
		    map { $this->graphs()->{ $url2 }->mark_edge_dirty( $_ ); } @{ $affected_edges };
		}
	    }
	    
	    # 2 - 1 - 3 - --> if in shared mode we average (?) connected weights
	    # --> effective number of model parameters depends on mode: shared/non-shared
	    # TODO
	    
	    print STDERR "\n";
	    
	}
	
	# 2 - 2 - compute current error level ~ loop on all paths for which the ground-truth is available
	# Measure ? --> Edge P/R ? Node P/R ?
	my @node_jaccards;
	my @edge_jaccards;
	foreach my $url (keys(%{ $y_activated })) {
	    
	    my $current_path = $optimal_paths{ $url };
	    my $true_path = $y_activated->{ $url };
	    
	    my ($node_jaccard, $edge_jaccard) = $this->_node_edge_jaccard( $true_path , $current_path );
	    push @node_jaccards, $node_jaccard;
	    push @edge_jaccards, $edge_jaccard;
	    
	}
	my $average_node_jaccard = mean( @node_jaccards );
	my $average_edge_jaccard = mean( @edge_jaccards );
	
	my $norm_w = $this->_norm( \%w );
	
#    if ( $DEBUG ) {
	my @change_set = map { join(":", $_, $w{ $_ }); } grep { !defined( $w_copy{ $_ } ) || ( $w_copy{ $_ } != $w{ $_ } ); } keys(%w);
	my $change_set_size = scalar(@change_set);
	print STDERR "Iteration \#$i / Average Node Jaccard: $average_node_jaccard / Average Edge Jaccard: $average_edge_jaccard / $updated / $norm_w / $change_set_size\n";
	if ( $DEBUG > 2 ) {
	    print STDERR "w: " . join(" ", @change_set) . "\n";
	}
	print STDERR "\n";
#    }
	
	#$ALPHA /= 5;
	
    }

    # TODO: should we try averaging the weights ?
    return \%w;

}

no Moose;

1;

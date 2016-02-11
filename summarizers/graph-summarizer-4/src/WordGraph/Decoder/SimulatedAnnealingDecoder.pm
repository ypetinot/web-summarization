package WordGraph::Decoder::SimulatedAnnealingDecoder;

use SentenceEnergy;

use Moose;

extends 'WordGraph::Decoder';

# sentence energy model
has 'sentence_energy_model' => ( is => 'ro' , isa => 'SentenceEnergy' , init_arg => undef , lazy => 1 , builder => '_sentence_energy_model_builder' );
sub _sentence_energy_model_builder {
   
    my $this = shift;

    my $sentence_energy_model = new SentenceEnergy( 'server_address' => $this->params()->{ $Web::Summarizer::Graph2::Definitions::WORDGRAPH_PARAMS_FEATURE_SERVICE } );
  
    return $sentence_energy_model;
    
}

sub path_energy {

    my $this = shift;
    my $graph = shift;
    my $instance = shift;
    my $path = shift;

    return $this->sentence_energy_model()->compute_energy( $graph->data_extractor() , $instance , $path );

}

# find optimal path for the current set of weights
sub _decode {

    my $this = shift;
    my $graph = shift;
    my $instance = shift;

    # TODO: we should start with the most relevant summary/path
    my $graph_paths = $graph->paths();
    my @base_path = @{ ( values( %{ $graph_paths } ) )[ 0 ] };

    # simulated annealing
    my $k = 0;
    my $k_max = 10000;

    # we need shortest paths for all node pairs in the graph
    my $replicated_graph = $this->replicate_graph( $graph );
    my $apsp = $replicated_graph->APSP_Floyd_Warshall();

    my @energy_min_sentence = @base_path;
    my $energy_min = $this->path_energy( $graph , $instance , \@energy_min_sentence );
    my $energy  = $energy_min;

    my @current_path = @base_path;

    while ( $k < $k_max ) {
	
	#my $t = 1 - ( $k / $k_max );
	my $t = exp( $k_max - $k );

	my @updated_path;

	# maintain current path information
	my %in_current_path;
	map { $in_current_path{ $_ } = 1; } @current_path;
	
	# iterate over all nodes in the current path
	while ( my $path_node = shift @current_path ) {
	    
	    #my $path_node = $current_path[ $i ];
	    push @updated_path, $path_node;
	    
	    # once we've reach the penultimate node in the path, nothing can change
	    if ( ! $#current_path ) {
		next;
	    }

	    my $next_node = shift @current_path;
	    my $join_node = shift @current_path;

	    # generate possible transitions from the current node
	    # we only want to make local changes
	    my @node_neighbors = $graph->neighbors();
	    foreach my $node_neighbor (@node_neighbors) {

		my @sp = $apsp->path_vertices( $node_neighbor , $join_node );
		my $has_visited_node = grep { $in_current_path{ $_ } } @sp;

		# the candidate paths cannot contain cycles
		if ( $has_visited_node ) {
		    next;
		}

		my @candidate_path = ( @updated_path , @sp , @current_path);
		
		# compute energy of candidate path
		my $candidate_path_energy = $this->path_energy( $graph , $instance , \@candidate_path );

		# compute energy difference (is there a way to do this as a delta instead of recomputing everything ?)
		my $energy_diff = $candidate_path_energy - $energy;

		# transition with probability ...
		my $toss = rand(1);
		my $transitional_probability = exp( -1 * $energy_diff / $t );
		if ( ( $energy_diff < 0 ) || ( $toss < $transitional_probability ) ) {

		    @current_path = @candidate_path;
		    $energy += $energy_diff;

		    my $current_path_string = join( " " , @current_path );
		    print STDERR ">> $t / $energy / $energy_diff / $transitional_probability / $toss ==> $current_path_string\n";

		    # keep track of lowest configuration energy found
		    if ( ! defined( $energy_min ) || $energy < $energy_min ) {
			@energy_min_sentence = @current_path;
			$energy_min = $energy;
		    }

		}
	    
		# Can encode current configuration with a binary vector / hash ?
		# Energy delta from transition ?
		
	    }

	}

	$k++;

    }

    my $path_optimal = \@energy_min_sentence;
    my $optimal_path_stats = {
	'energy' => $energy_min,
	'n_iteration' => $energy
    };

    my $path_optimal_object = new WordGraph::Path( graph => $graph , node_sequence => $path_optimal , object => $instance->raw_input_object );

    return ( $path_optimal_object , $optimal_path_stats );

}

no Moose;

1;

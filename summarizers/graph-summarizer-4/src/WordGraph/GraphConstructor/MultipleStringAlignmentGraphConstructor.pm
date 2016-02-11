package WordGraph::GraphConstructor::MultipleStringAlignmentGraphConstructor;

use strict;
use warnings;

use JSON;
use Memoize;
use POSIX;
use WordNet::QueryData;
use WordNet::Similarity;

use WordNetLoader;

use Moose;

# TODO
extends 'WordGraph::GraphConstructor';

# element key 2 node mapping
has '_key_2_nodes' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# node 2 element key mapping
has '_node_2_key' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# node data
has '_node_data' => ( is => 'rw' , isa => 'HashRef' , default => sub { {} } );

# clustering graph
has '_state_graph_clustering' => ( is => 'rw' , isa => 'Graph::Undirected' );

# word graph sample
has '_state_graph_sample' => ( is => 'rw' , isa => 'Graph::Directed' );

### # word graph sample / edge history
### has '_state_graph_sample_edge_history' => ( is => 'rw' , isa => 'HashRef' );

# wordnet loaded
# TODO: change name ?
has '_wordnet_loader' => ( is => 'ro' , isa => 'WordNetLoader' , lazy => 1 , builder => '_wordnet_loader_builder' );

my $DEBUG = 1;
my $infinity = LONG_MAX;

my $ANNOTATION_KEY_AMBIGUITY = 'ambiguity';
my $ANNOTATION_KEY_INDEX = 'index';
my $ANNOTATION_KEY_KEY = 'key';
my $ANNOTATION_KEY_PATH_LABEL = 'path_label';
my $ANNOTATION_KEY_IS_SLOT = 'is_slot';

sub _wordnet_loader_builder {

    my $this = shift;

    my $wordnet_loader = new WordNetLoader();

    return $wordnet_loader;

}

sub constraints {

    # There can only be one filler per slot or, put differently, each cluster non-homogeneous tokens (semantic distance > 1) can contain at most one candidate from each instance.

}

# check node cooccurrence
# Note: cannot be memoized / can it be optimized ?
sub cooccur {

    my $this = shift;
    my $a = shift;
    my $b = shift;
    my $path_strict = shift || 0;
    
    my $b_data = $this->_node_data()->{ $b };

    # Note: we take into account current clustering status
    my $cluster_a = $path_strict ? [ $a ] : $this->get_cluster( $a );
    my $cluster_b = $path_strict ? [ $b ] : $this->get_cluster( $b );

    my %seen_path;
    foreach my $run ( [ $cluster_a , 1 ] , [ $cluster_b , 0 ] ) {

	my $cluster = $run->[ 0 ];
	my $mode = $run->[ 1 ];

	foreach my $cluster_node (@{ $cluster }) {

	    my $cluster_node_data = $this->_node_data()->{ $cluster_node };
	    my $path_id = $cluster_node_data->[ 1 ];

	    if ( $mode ) {
		$seen_path{ $path_id }++;
		if ( $DEBUG && $seen_path{ $path_id } > 1 ) {
		    print STDERR "Problem !";
		}
	    }
	    elsif ( $seen_path{ $path_id } ) {
		return 1;
	    }

	}

    }
    
    return 0;

}

sub do_switch {

    my $this = shift;
    my $edge = shift;
    my $target_state = shift;

    if ( $target_state ) {
	$this->_state_graph_clustering()->add_edge( @{ $edge } );
    }
    else {
	$this->_state_graph_clustering()->delete_edge( @{ $edge } );
    }

}

# 1 - potential energy is created by grouping nodes together
# 2 - potential energy of a regular edge ? --> 1 (could be adjusted based on frequence of nodes, revisit this idea later)

# --> incentive to merger as many nodes as possibe to reduce the number of edges in the graph
# --> importance of edge being merged (ratio) * the semantic cost of merging the two nodes ( 0 for identical terms (unambiguous only ?) / infinite for 

sub _same_surface {

    my $this = shift;
    my $a = shift;
    my $b = shift;

    my $surface_a = $this->_node_data()->{ $a }->[ 2 ]->surface();
    my $surface_b = $this->_node_data()->{ $b }->[ 2 ]->surface();
    
    return ( $surface_a eq $surface_b );

}

# undirected edge energy potential
# attraction: token context + relative position ?
# rejection: lack of semantic compatibility
# attraction * rejection
# --> soft slotting ? --> means node is potentially 

sub potential {

    my $this = shift;
    my $a = shift;
    my $b = shift;

    # Nodes sharing the same surface and not occurring with the same path
    if ( $this->cooccur( $a , $b , 1 ) ) {

	# Path cooccurrence is causing repulsion between nodes

	# Always infinite energy ?
	return $infinity;

    }
    elsif ( $this->_same_surface( $a , $b ) ) {
	return 0.5;
    }
    else {

	my $semantic_distance_a_b = $this->_semantic_distance( $a , $b );
	#return exp( 1 + $semantic_distance_a_b );
	#return ( 1 + $semantic_distance_a_b );
	# TODO: refine this using a sigmoid function
	return ( $semantic_distance_a_b <= 0.5 ) ? ( 0.5 + $semantic_distance_a_b ) : $infinity;

=pod
	# Nodes in the same synset can be merged ?
	if ( $semantic_distance_a_b <= 1 ) {
	    return 1;
	}
	# How do we handle potential slot locations ?
	else {
	    return $semantic_distance_a_b;
	}
=cut

    }

}

memoize('_semantic_distance');
sub _semantic_distance {

    my $this = shift;
    my $a = shift;
    my $b = shift;

    my $word_a = $this->_node_data()->{ $a }->[ 2 ]->surface();
    my $word_b = $this->_node_data()->{ $b }->[ 2 ]->surface();;

    my $wordnet_query_data = $this->_wordnet_loader()->wordnet_query_data();
    my $wordnet_similarity = $this->_wordnet_loader()->wordnet_similarity();

    my @synsets_a = $wordnet_query_data->queryWord( $word_a );
    my @synsets_b = $wordnet_query_data->queryWord( $word_b );

    # by default we assume synsets to be incompatible
    my $semantic_distance = $infinity;

    if ( scalar( @synsets_a ) && scalar( @synsets_b ) ) {
	
	my $synset_a = $synsets_a[ 0 ] . "#1";
	my $synset_b = $synsets_b[ 0 ] . "#1";

	#my $value = $measure->getRelatedness("car#n#1", "bus#n#2");
	my $value = 1 - $wordnet_similarity->getRelatedness( $synset_a , $synset_b );
	if ( $DEBUG ) {
	    print STDERR ">> Semantic Distance [ $synset_a - $synset_b ] : $value\n";
	}

	my ($error, $errorString) = $wordnet_similarity->getError();
	if ( $error ) {
	    print STDERR ">> $errorString\n";
	}
	else {
	    $semantic_distance = $value;
	}
	
    }

    return $semantic_distance;

}

# get current cluster for a specific node
sub get_cluster {

    my $this = shift;
    my $node_id = shift;

    my @cluster = $this->_state_graph_clustering->all_reachable( $node_id );

    # the target node itself is part of the cluster
    push @cluster, $node_id;

    return \@cluster;

}

# Note: is that it ?
sub node_weight {

    my $this = shift;
    my $node = shift;

    return 1;

}

# compute energy difference if we were to switch node pair $raw_node_pair
sub energy_diff_if_switch {

    my $this = shift;
    my $node_pair = shift;
    
    my $node_a = $node_pair->[ 0 ];
    my $node_b = $node_pair->[ 1 ];

    my $potential_diff = 0;

    # are there optimizations possible ?

    # 1 - get current pair state
    my $is_pair_on = $this->_state_graph_clustering->has_edge( $node_a , $node_b );
    if ( $is_pair_on ) {
	# need to temporarily remove edge to get node clusters
	$this->do_switch( $node_pair , 0 );
    }

    # 2 - get cluster associated with each node
    my $cluster_a = $this->get_cluster( $node_a );
    my $cluster_b = $this->get_cluster( $node_b );

    if ( $is_pair_on ) {
	# reinstantiate edge
	$this->do_switch( $node_pair , 1 );
    }

    my $cluster_match = scalar( grep{ $_ eq $node_b } @{ $cluster_a } );

    if ( ! $is_pair_on && $cluster_match ) {
	    
	# both nodes are in the same cluster
	# switching the edge on/off will have no effect
	
    }
    else {

	my $energy_diff_sign;
    
	if ( $is_pair_on ) {
	    
	    # we evaluate the impact of removing the clustering edge
	    # evaluate potentials being removed between nodes in each cluster
	    $energy_diff_sign = -1;
	    
	}
	else {
	    
	    # we evaluate the impact of adding the clustering edge	    
	    # evalute potentials being created between nodes in each cluster
	    $energy_diff_sign = 1;
	    
	}
	
	my $absolute_potential_diff = 0;
	# compute local joint energy
	foreach my $cluster_a_member (@{ $cluster_a }) {
	    foreach my $cluster_b_member (@{ $cluster_b }) {
		my $node_weight_a = $this->node_weight( $cluster_a_member );
		my $node_weight_b = $this->node_weight( $cluster_b_member );
#		$absolute_potential_diff += $node_weight_a * $node_weight_b * $this->potential( $cluster_a_member , $cluster_b_member ) - ( $node_weight_a + $node_weight_b );
		$absolute_potential_diff += ( $node_weight_a + $node_weight_b ) * ( $this->potential( $cluster_a_member , $cluster_b_member ) - 1 );
	    }
	}
	
	$potential_diff = $energy_diff_sign * $absolute_potential_diff;

    }

    return ( $is_pair_on , $potential_diff );

}

sub construct_core {
    
    my $this = shift;
    my $graph = shift;
    my $token_sequences = shift;

    # 1 - build state graphs
    my $mapped_sequences = $this->_state_graphs_builder( $token_sequences );

    my @raw_nodes = $this->_state_graph_clustering()->vertices();
    my @raw_node_pairs;
    for (my $i=0; $i<scalar(@raw_nodes); $i++) {
	for (my $j=$i+1; $j<scalar(@raw_nodes); $j++) {
	    	    
	    my $node_i = $raw_nodes[ $i ];
	    my $node_j = $raw_nodes[ $j ];

	    # We cannot cluster nodes that cooccur
	    # Note: also applies to token extracted from the target object
	    # --> i.e. represent target object as single - potentially disconnected - sequence
	    if ( $this->cooccur( $node_i , $node_j ) ) {
		next;
	    }

	    my $node_i_data = $this->_node_data()->{ $node_i };
	    my $node_j_data = $this->_node_data()->{ $node_j };
	    if ( ! $node_i_data || ! $node_j_data ) {
		next;
	    }

	    my $node_i_token = $node_i_data->[ 2 ];
	    my $node_j_token = $node_j_data->[ 2 ];

	    if ( ( $node_i_token->sequence() && ( $node_i_token->sequence() ne $node_j_token->sequence() ) ) &&
		 ( $node_i_token->pos() && ( $node_i_token->pos() ne $node_j_token->pos() ) )
		) {
		next;
	    }

	    push @raw_node_pairs, [ $node_i , $node_j ];

	}
    }

    # 2 - simulated annealing
    my $k = 0;
    my $k_max = 10000;
    my $energy_system = 0;

    my $energy_system_min = undef;
    my @best_components;

    while ( $k < $k_max ) {
    
	#my $t = 1 - ( $k / $k_max );
	my $t = exp( $k_max - $k );

	my @components = $this->_state_graph_clustering()->connected_components();
	my $number_of_components = scalar( @components );
	#print STDERR ">> Temperature: $t / Components: $number_of_components\n";
	#print STDERR ">> Components: " . join( " / " , map { "[ " . join( " - " , ( map { $this->_node_data()->{ $_ }->[ 2 ]->surface() } @{ $_ } ) ) . " ]" } @components ) . "\n";

	# iterate over all nodes in the graph
	my @candidate_node_pairs;
	while (my $raw_node_pair = shift @raw_node_pairs ) {
	    
	    # TODO : keep track of lowest configuration energy found
	    # --> map of all the active clustering edges in the graph
	    
	    # Can encode current configuration with a binary vector / hash ?
	    # Energy delta from transition ?

	    # compute energy difference if we were to switch node pair $raw_node_pair
	    my ( $current_state , $potential_diff ) = $this->energy_diff_if_switch( $raw_node_pair );
	    my $energy_diff = $potential_diff;

=pod
	    if ( ! $energy_diff ) {
		# we do not attempt to transition to a state with the same energy level
		next;
	    }
	    elsif ( $energy_diff < $infinity ) {
		print STDERR ">> diff : $energy_diff ...\n";
	    }	    
=cut
	    push @candidate_node_pairs, $raw_node_pair;

	    # transition with probability ...
	    my $toss = rand(1);
	    my $transitional_probability = exp( -1 * $energy_diff / $t );
	    if ( ( $energy_diff < 0 ) || ( $toss < $transitional_probability ) ) {

		my ( $a , $b ) = @{ $raw_node_pair };
		my ( $surface_a , $surface_b ) = map { $this->_node_data()->{ $_ }->[ 2 ]->surface(); } @{ $raw_node_pair };
		print STDERR ">> $t / $energy_system / $current_state / [ $surface_a ($a) -- $surface_b ($b) ] / $energy_diff / $transitional_probability / $toss\n";
		$this->do_switch( $raw_node_pair , ! $current_state );
		
		$energy_system += $energy_diff;
		#print STDERR "[Energy: $energy_system]\n";

		if ( ! defined( $energy_system_min ) || $energy_system < $energy_system_min ) {
		    $energy_system_min = $energy_system;
		    @best_components = @components;
		}

	    }
	    
	} 

	@raw_node_pairs = @candidate_node_pairs;
	@candidate_node_pairs = ();

	$k++;
	
    }

    print STDERR ">> Best Componnents: " . join( " / " , map { "[ " . join( " - " , ( map { $this->_node_data()->{ $_ }->[ 2 ]->surface() } @{ $_ } ) ) . " ]" } @best_components ) . "\n";

    # create word-graph nodes based on best components
    my %node_mapping;
    my %key2wgids;
    foreach my $best_component (@best_components) {
	
	my $master_node = $best_component->[ 0 ];
	my $master_token = $this->_node_data()->{ $master_node }->[ 2 ];
	my $master_token_shared_key = $master_token->shared_key();

	# 1 - create word-graph node for this component
	my $word_graph_node = $graph->add_vertex( $master_token , $key2wgids{ $master_token_shared_key }++ );

	# 2 - maintain mapping for all other nodes in this component
	my $n_nodes = scalar(@{ $best_component });
	for (my $i=0; $i<$n_nodes; $i++) {
	    my $current_node = $best_component->[ $i ];
	    $node_mapping{ $current_node } = $word_graph_node;
	}

    }

    # add paths to word-graph
    my %paths;
    foreach my $reference_url (keys( %{ $mapped_sequences })) {

	my $mapped_sequence = $mapped_sequences->{ $reference_url };

	my @path = map { $node_mapping{ $_ }; } @{ $mapped_sequence };
	$paths{ $reference_url } = \@path;

    }

    return \%paths;

}

sub _state_graphs_builder {
    
    my $this = shift;
    my $token_sequences = shift;

    my %mapped_sequences;

    # 0 - create local (clustering) graph
    my $graph_sample = new Graph::Directed;
    my $graph_clustering = new Graph::Undirected;

    # 1 - populate graph_sample with one node per token in the reference paths
    # (i.e. fully unclustered word-graph)
    my $count = 0;
    my $path_count = 0;
    foreach my $reference_url ( keys( %{ $token_sequences } ) ) {

	$path_count++;
	
	my $reference_gist_sequence = $token_sequences->{ $reference_url };
	my @mapped_sequence;

	my $reference_gist_sequence_length = scalar(@{ $reference_gist_sequence });
	my $reference_gist_sequence_previous_node_id = undef;
	for (my $i=0; $i<$reference_gist_sequence_length; $i++) {

	    my $reference_gist_sequence_token = $reference_gist_sequence->[ $i ];
	    my $is_shared_node = ( ! $i ) || ( $i == ( $reference_gist_sequence_length - 1 ) );

	    my $path_node_id = undef;
	    my $path_node_data = undef;

	    my $reference_gist_sequence_token_shared_key = $reference_gist_sequence_token->shared_key();

	    if ( ! $is_shared_node ) {

		#$path_node_id = join( "#" , $reference_url , $i , $reference_gist_sequence_token_shared_key );
		$path_node_id = $count++;
		$path_node_data = [ $path_node_id , $path_count , $reference_gist_sequence_token , $i ];

		# update vertex mapping
		$this->_node_data()->{ $path_node_id } = $path_node_data;

	    }
	    else {

		#$path_node_id = $reference_gist_sequence_token_shared_key;
		$path_node_id = ( ! $i ) ? -1 : -2;
		$this->_node_data()->{ $path_node_id } = [ $path_node_id , -1 , $reference_gist_sequence_token , -1 ];

	    }
	    
	    if ( ( ! $is_shared_node ) ||
		 ( $is_shared_node && ! $graph_sample->has_vertex( $path_node_id ) )
		) {
	
		#my $path_node_surface = $reference_gist_sequence_token->surface();
		#print STDERR "/// $path_node_id --> $path_node_surface\n";

		$graph_sample->add_vertex( $path_node_id );
		$graph_clustering->add_vertex( $path_node_id );

		if ( $i ) {

		    # Add edge to sample graph
		    $graph_sample->add_edge( $reference_gist_sequence_previous_node_id , $path_node_id );
		    
		    # Initially all edges have a weight of 1
		    $graph_sample->set_edge_weight( $reference_gist_sequence_previous_node_id , $path_node_id , 1 );

		}

	    }

	    # update mapped sequence
	    push @mapped_sequence, $path_node_id;

	    # keep id of the current (node previous) node
	    $reference_gist_sequence_previous_node_id = $path_node_id;

	}

	# store mapped sequence
	$mapped_sequences{ $reference_url } = \@mapped_sequence;

    }

    $this->_state_graph_clustering( $graph_clustering );
    $this->_state_graph_sample( $graph_sample );

    return \%mapped_sequences;

}

# Insert complete path into a word graph
sub _insert_path {

    my $this = shift;
    my $graph = shift;
    my $path_label = shift;
    my $path_sequence = shift;

    # Just as \cite{Filippova} we allow for cycles --> linear similarity not sufficient w/in category
    # 1 - align unambiguous terms (single occurrence in graph and path)
    
    # 1 - filter path
    my @filtered_path_sequence = grep {
	
	my $keep = 1;

	# we do not include punctuation in the graph
	if ( $_->surface() =~ m/^\p{Punct}$/ ) {
	    $keep = 0;
	}

	$keep;

    } @{ $path_sequence };

    # 2 - map nodes to their alignment key (also include context ?)
    my @annotated_path_sequence;
    my %frequencies;
    for (my $i=0; $i<scalar(@filtered_path_sequence); $i++) { 

	my $path_element = $filtered_path_sequence[ $i ];

	my %annotations;
	$annotations{ $ANNOTATION_KEY_INDEX } = $i;
	$annotations{ $ANNOTATION_KEY_PATH_LABEL } = $path_label;

	# Use POS-lc(SURFACE) as node key ?
	my $path_element_key = $path_element->shared_key();
	$annotations{ $ANNOTATION_KEY_KEY } = $path_element_key;

	# Is this element associated with a slot location ?
	$annotations{ $ANNOTATION_KEY_IS_SLOT } = ( $path_element->abstract_type() =~ m/^SLOT_/ ) ? 1 : 0;
	
	# update frequency data (will be used towards the "soft" identification of stopwords)
	$frequencies{ $path_element_key }++;

	push @annotated_path_sequence , [ \%annotations , $path_element ];

    }

    # 3 - compute ambiguity levels
    map { $_->[0]->{ $ANNOTATION_KEY_AMBIGUITY } = $this->_ambiguity_level( \%frequencies , $_ ); } @annotated_path_sequence;

    # 4 - sort elements by increasing level of ambiguity
    my @sorted_path_sequence = sort { $a->[0]->{ $ANNOTATION_KEY_AMBIGUITY } <=> $b->[0]->{ $ANNOTATION_KEY_AMBIGUITY } } @annotated_path_sequence;

    # 4 - align nodes
    my %path_status;
    my @node_sequence = map { $_->[ 1 ]; } sort { $a->[0]->{ $ANNOTATION_KEY_INDEX } <=> $b->[ 0 ]->{ $ANNOTATION_KEY_INDEX } } map { $this->_insert_node( $graph , $path_sequence , $_ , \%path_status ); } @sorted_path_sequence;

    # TODO: this could be moved to the parent class
    $this->_create_path( $graph , $path_label , \@node_sequence );

    return \@node_sequence;

}

# 1 - non-stopwords (~600 ?) for which no candidate exists in the graph or for which an unambiguous mapping is possible
# 2 - non-stopwords for which there are either several possible candidates in the graph or which occur more than once in the sentence
# 3 - stopwords

# An equivalent implementation is to sort path elements according to their ambiguity level given the current status of the graph being constructed
# stopwords --> get frequency count from reference cluster

sub _ambiguity_level {

    my $this = shift;
    my $frequencies = shift;
    my $source_element = shift;
    
    my $source_element_key = $source_element->[ 0 ]->{ ${ANNOTATION_KEY_KEY} };
    my $base_ambiguity = $frequencies->{ $source_element_key };

    # means we must maintain a key --> [ nodes ] index
    my $vertices = $this->_key_2_nodes()->{ $source_element_key } || [];
    my $vertex_count = scalar( @{ $vertices } );

    my $ambiguity = $base_ambiguity * ( 1 + $vertex_count );

    return $ambiguity;
    
}

# map nodes according to greater context overlap (preceding and succeeding words), or if same overlap, frequency of the node (i.e. number of paths in which it has been included so far)
sub _insert_node {

    my $this = shift;
    my $graph = shift;
    my $path_sequence = shift;
    my $annotated_element = shift;
    my $path_status = shift;

    my $annotations = $annotated_element->[ 0 ];
    my $source_element = $annotated_element->[ 1 ];

    my $path_label = $annotations->{ $ANNOTATION_KEY_PATH_LABEL };

    # 1 - determine node key
    my $source_element_key = $source_element->shared_key();

    # 2 - retrieve matching graph nodes
    my $candidate_vertices = $this->_key_2_nodes()->{ $source_element_key } || [];

    # 3 - determine whether a new node should be created
    my $ambiguity_level = $annotations->{ $ANNOTATION_KEY_AMBIGUITY };
    
    my $create_new = 1;
    my $node = undef;

    if ( scalar( @{ $candidate_vertices } ) && $ambiguity_level ) {
	
	# find best potential candidate
	# need to decide if one of the existing nodes can be used as a host
	
	my $best_candidate = undef;
	my $best_candidate_score = -1;
	my $best_candidate_frequency = 0;

	foreach my $candidate_node ( grep { ! $path_status->{ $_ } } @{ $candidate_vertices } ) {
	    
	    if ( defined( $path_status->{ $candidate_node } ) ) {
		# This node already appears in the current path
		next;
	    }
	    
	    # Default so that a candidate is found only if there is some level of filter match overall
	    # TO CHECK !
	    my $candidate_score = 0;
	    my $candidate_frequency = $graph->get_vertex_weight( $candidate_node );
	  
	    my $current_index = $annotations->{ $ANNOTATION_KEY_INDEX };

	    # 1 - predecessors data
	    my $path_predecessor = _get_path_element( $path_sequence , $current_index - 1 );
	    my @candidate_predecessors = $graph->predecessors( $candidate_node );
	    
	    # 2 - successors data
	    my $path_successor = _get_path_element( $path_sequence , $current_index + 1 );
	    my @candidate_successors = $graph->successors( $candidate_node );

	    # 3 - compute overlap match for candidate node
	    my $match_count = 0;
	    foreach my $entry ( ( [ $path_predecessor , \@candidate_predecessors ] , [ $path_successor , \@candidate_successors ] ) ) {

		my $path_neighbor = $entry->[ 0 ];
		my $graph_neighbors = $entry->[ 1 ];
		
		if ( $path_neighbor ) {
		    
		    my $path_neighbor_key = $path_neighbor->shared_key();
		    
		    foreach my $candidate_neighbor (@{ $graph_neighbors }) {
			# HERE: candidate_neighbor is not an "element"
			# --> mapping from node to elements ? --> pos and surface match (ok), what else ?
			if ( $this->_node_2_key()->{ $candidate_neighbor } eq $path_neighbor_key ) {
			    $match_count++;
			    last;
			}
		    }

		}

	    }
  	    
	    if ( $candidate_score >= $best_candidate_score ) {
		
		if (
		    ( $candidate_score > $best_candidate_score ) ||
		    ( $candidate_frequency > $best_candidate_frequency )
		    ) {
		    $best_candidate = $candidate_node;
		    $best_candidate_score = $candidate_score;
		    $best_candidate_frequency = $candidate_frequency;
		}
	    
	    }

	}
	
	if ( defined( $best_candidate ) ) {
	    $node = $best_candidate;
	    $create_new = 0;
	}
	
    }

    # Create a new vertex
    if ( $create_new ) {

	# get new node instance
	$node = $graph->add_vertex( $source_element , scalar(@{ $candidate_vertices }) );
	
	# update candidate map
	push @{ $candidate_vertices } , $node;
	if ( ! scalar( @{ $candidate_vertices } ) ) {
	    $this->_key_2_nodes()->{ $source_element_key } = [];
	}
	push @{ $this->_key_2_nodes()->{ $source_element_key } } , $node;

	# update node 2 key mapping
	$this->_node_2_key()->{ $node } = $source_element_key;

    }
    
    # TODO: this is a good place to update vertex importance ?
    $graph->set_vertex_weight( $node , ( $graph->get_vertex_weight( $node ) || 0 ) + 1 );

    # If the current chunk is of a slot type, we populate the data associated with this node
    if ( $annotations->{ $ANNOTATION_KEY_IS_SLOT } ) {
	$node->set_slot_filler( $path_label , $source_element->surface() );
    }
    else {
	$graph->set_vertex_attribute( $node , $Web::Summarizer::Graph2::Definitions::NODE_ATTRIBUTE_IS_SLOT , 0 );
    }
    
    # Register this node for the current gist
    if ( defined( $path_status->{ $node } ) ) {
	die "This should never happen - we have selected a node that is already part of the current path - $node";
    }
    $path_status->{ $node } = 1;

    # return the selected/created node
    return [ $annotations , $node ];

}

# get path element
sub _get_path_element {

    my $path_sequence = shift;
    my $index = shift;
    
    # 1 - make sure we are dealing with a valid index
    if ( $index < 0 || $index >= scalar(@{ $path_sequence }) ) {
	return undef; 
    }

    return $path_sequence->[ $index ];

}

1;

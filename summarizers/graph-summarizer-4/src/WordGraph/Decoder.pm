package WordGraph::Decoder;

# Decoder operating on a WordGraph space and returning a WordGraph::Path instance within that space

#use Moose::Role;
use MooseX::Role::Parameterized;
###use namespace::autoclean;

parameter reference_construction_limit => (
    isa => 'Num',
    required => 0,
    default => 0
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
    my $_reference_construction_limit = $p->reference_construction_limit;
    my $_edge_model_class = $p->edge_model;
    my $_word_graph_transformations = $p->word_graph_transformations;

    has 'model' => ( is => 'ro' , isa => $_edge_model_class , init_arg => undef , lazy => 1 , builder => '_model_builder' );
    method "_model_builder" => sub {
	my $this = shift;
	return Web::Summarizer::Utils::load_class( $_edge_model_class )->new;
    };

    # construction reference limit (for word-graph construction)
    has 'reference_construction_limit' => ( is => 'ro' , isa => 'Num' , default => $_reference_construction_limit );

=pod
    # edge cost class
    has 'edge_cost_class' => ( is => 'ro' , isa => 'Str' , default => $default_edge_cost_class );
=cut

    # graph constructor (must be stateless)
    has 'graph_constructor' => ( is => 'ro' , isa => 'WordGraph::GraphConstructor' , required => 1 );

    # word-graph cache
    has 'graph_cache' => ( is => 'ro' , isa => 'HashRef[WordGraph]' , default => sub { {} } );

    # graph constructor class
    has 'graph_constructor_class' => ( is => 'ro' , isa => 'Str' , default => 'WordGraph::GraphConstructor::FilippovaGraphConstructor' );

    # graph constructor
    # TODO : proper overload ?
    has 'graph_constructor' => ( is => 'ro' , isa => 'WordGraph::GraphConstructor' , init_arg => undef, lazy => 1 , builder => '_graph_constructor_builder' );
    method "_graph_constructor_builder" => sub {
	
	my $this = shift;
	
	# instantiate word graph constructor
	#my $graph_constructor = new WordGraph::GraphConstructor::SummaryGraphConstructor();
	# TODO : avoid passing the transformations param if the parameter is an empty array - probably need to fix parameterization first
	my $graph_constructor = ( Web::Summarizer::Utils::load_class( $this->graph_constructor_class ) )->new( transformations => $_word_graph_transformations );
	
	return $graph_constructor;
	
    };
    
    # serialization directory for model
    has 'serialization_directory_model' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_serialization_directory_model_builder' );
    method "_serialization_directory_model_builder" => sub {
	my $this = shift;
	return $this->get_output_directory( $this->system );
    };
    
    # find optimal path for the current set of weights
    method "decode" => sub {

	my $this = shift;
	my $instance_in = shift;
	my $return_features = shift;
	my $gold_out = shift;

	my $target_object = $instance_in->[ 0 ];
	my $references = $instance_in->[ 1 ];

	# TODO : is this accurate ?
	my $label = $target_object->id;
	
	# 1 - derive word-graph topology from instance
	if ( ! defined( $this->graph_cache->{ $label } ) ) {
	    
	    # *******************************************************************************************************************
	    # 5 - prepare/build search space ?
	    # *******************************************************************************************************************
	    # TODO : not very clean ==> in the test phase there shoulnd't be any notion of "training" set/portion
	    # TODO : will probably need improvement or a 3-way split of the reference set
	    # TODO : add constraint to ensure that $instance is an instance of ReferenceTargetInstance

	    # Note : if we are training and edge model, then the first call (right now coming from Trainable) for every (training) instance will contain the expected output
	    # In order to be able to apply structured learning, we use the expected output in the construction of the word graph

	    my @reference_sentences_construction;
	    if ( defined( $gold_out ) ) {
		push @reference_sentences_construction, [ $target_object , $gold_out ];
	    }
	    else {
		$this->warn( "Now in test mode for : " . $target_object->url );
	    }

	    my $include_references = 1;
	    if ( $this->does( 'Web::Extractor::SentenceExtractor' ) ) {

		# TODO : fix Web::Extractor::MetaSentenceExtractor
		# CURRENT : create a meta-role that exclude the main method from each sub role but calls them explicitly
		push @reference_sentences_construction, map { [ $target_object , $_ ] } @{ $this->extract_sentences( $target_object , $references ) };

		# TODO : clean this up (in fact should probably be removed)
		$include_references = $include_references && ( $this->sentence_source eq 'all' || $this->sentence_source eq 'reference' );

	    }
	    
	    if ( $include_references ) {
		push @reference_sentences_construction, @{ $references };
	    }

	    if ( ! scalar( @reference_sentences_construction ) ) {
		$this->warn("ReferenceTargetSummarizer must have at least one reference (object,summary) pair for space construction ...");
	    }
	    $this->graph_cache->{ $label } = $this->prepare_space( \@reference_sentences_construction , $target_object , $references );

	}
	my $graph = $this->graph_cache->{ $label };

	# 2 - the cost of the individual edges in the word-graph is controlled by the model
	# This means the features are extracted by the model and the weights are stored in the model
	# The assumption is that each edge is in fact an elementary featurized object
	# CURRENT : make sure each edge in the graph is associated to its features (values) (the weights are shared)
	# ==> ok ==> WordGraph::EdgeModel::compute_edge_features

	# TODO : is it really ok to pass the graph here ?
#	my $model_instance = $this->model->create_instance( $graph , [ $target_object , undef ] , $references );
###	my $model_instance = $this->model->create_instance( [ $target_object , undef ] , $references );
	
	# for debugging purposes
	# TODO : only during debugging
#	$this->analyze_space( $graph , $model_instance->raw_input_object );
	$this->analyze_space( $graph , $target_object );
	
	my $decoded_path = undef;
	my $decoded_path_features = {};
	my $decoded_path_stats = {};
	
	# in case we have an empty space (this can happen)
	if ( $graph->is_empty ) {
	    
	    print STDERR "@@ Word-graph has no registered path ...\n";
	    
	}
	elsif ( defined( $gold_out ) ) {
	    
	    # we return the gold truth path in the word-graph
	    # TODO : add get_path method to WordGraph
	    $decoded_path = $graph->paths->{ $this->graph_constructor->get_path_key( $target_object , 0 ) };
	    if ( ! defined( $decoded_path ) ) {
		$this->error( "Gold path not found in word-graph : $label");
	    }
	    
###	    print STDERR "Initial call ... using gold path !\n";

	}
	else {
	    
           # TODO : can this be reintroduced at some point ?
           ###	my $expected = $instance->get_field('summary');
           ###	print STDERR "Searching optimal path for $label [expected: $expected]\n";
	    
	    ( $decoded_path , $decoded_path_stats ) = $this->_decode( $graph , $instance_in );
	    
	    if ( $decoded_path ) {
		
		if ( ! $this->test_mode() ) {
                    # TODO : can this be reintroduced at some point ?
                    ###		my $target_path = $graph->paths()->{ $label };
		    print STDERR join("\t", $label, $decoded_path->verbalize_debug(),
				      ###$target_path->verbalize_debug()
				      $target_object->get_field( 'summary' ),
				      , join(" ", map { join(":", $_, $decoded_path_stats->{ $_ }) } keys(%{ $decoded_path_stats } ) ) ) . "\n\n";
		}
		
	    }
	    else {
		
		print STDERR "@@ No path found for instance $label with decoder $this ...\n";
		
	    }
	    
	}
	
	# TODO: no way to avoid this ?
	if ( ! defined( $decoded_path ) ) {
#	    $decoded_path = new WordGraph::Path( graph => $graph , node_sequence => [] , object => $model_instance->object );
	    $decoded_path = new WordGraph::Path( graph => $graph , node_sequence => [] , object => $instance_in->[ 0 ] , source_id => __PACKAGE__ );
	}
	
	if ( $return_features ) {
	    # TODO : is this optimal ?
	    #return $this->compute_path_features( $decoded_path );
	    print STDERR "Featurizing : " . join( " / " , $instance_in->[ 0 ]->id , $decoded_path->verbalize ) . "\n";
	    return $this->model->featurize( $graph , $instance_in , $decoded_path );
	}

	return $decoded_path;
	
    };
      
    # combine/intersect full input features with current path
    method "compute_path_features" => sub {
	
	my $this = shift;
	my $path = shift;
	
	my $features = {};
	
	# Loop over edges that are present in $path --> all other edge features are therefore/implicitly forced to be 0
	for (my $i=0; $i<scalar(@{ $path }) - 1; $i++) {
	    
	    my $from = $path->[ $i ];
	    my $to = $path->[ $i + 1 ];
	    
	    my $current_edge = [ $from , $to ];
	    my $edge_features = $this->model->compute_edge_features( $path->graph , $current_edge , $path->object );
	    
	    map { $features->{ $_ } += $edge_features->{ $_ }; } keys( %{ $edge_features } );
	    
	}
	
	return $features;
	
    };

    method "prepare_space" => sub {
	
	my $this = shift;
	my $sentences_construction = shift;
	my $target_object = shift;
	my $references = shift;

	# TODO : construction sentences ranking should really happen here
	#my @construction_set = @{ $this->rank_references( $target_object , $sentences_construction ) };
	my @construction_set = @{ $sentences_construction };
	if ( $this->reference_construction_limit && $this->reference_construction_limit < scalar( @construction_set ) ) {
	    splice @construction_set , $this->reference_construction_limit;
	}
	
	$this->debug(">> generating gist graph ...");

	# TODO : should the target_object be passed to the graph constructor or should we instead perform the transformation here
	# (i.e. should the graph constructor only handle the construction of the raw (potentially cacheable) graph ?
	my $summary_graph = $this->graph_constructor->construct( \@construction_set , $target_object , $references );

	if ( ! $summary_graph->consistency ) {
	    die "Summary graph is not consistent ...";
	}

	$this->debug(">> done generating summary graph !");
	
	return $summary_graph;
	
    };
    
    method "analyze_space" => sub {
	
	my $this = shift;
	my $summary_graph = shift;
	my $target_data = shift;
	
	# ***********************************************************************************************************************
	# Word-graph analysis
	# ***********************************************************************************************************************
	
	# Experimental: detect nodes that have a weight of one (i.e. non-aligned) and that are not supported by the target object
	my @non_aligned_nodes = grep { $summary_graph->get_vertex_weight( $_ ) > 1 } $summary_graph->vertices;

    };
    
    method "cost" => sub {
	
	my $this = shift;
	my $component_costs = shift;
	
	my $cost = 0;
	map { $cost += $_; } @{ $component_costs };
	
	return $cost;
	
    };
    
    # Decoder works by considering incremental transitions (within the word-graph)
    with('ReferenceTargetDecoder');

};

###__PACKAGE__->meta->make_immutable;

1;

=pod

	    # TODO : set only once ?
	    $gold_outputs{ $training_set_instance_id } = $training_set_instance->output_object;

=cut

=pod

###=pod # we no longer make the assumption that the ground truth paths are in the graph, even during training
	    # 2 - 2 - compute current error level ~ loop on all paths for which the ground-truth is available
	    # Measure ? --> Edge P/R ? Node P/R ?
	    my @node_jaccards;
	    my @edge_jaccards;
	    foreach my $instance_id (keys(%optimal_outputs)) {
		
		my $current_output = $optimal_outputs{ $instance_id };
		my $true_output = $gold_outputs{ $instance_id };
		
		# TODO : directly return jaccard value ? (scalar context overload ?)
		my $node_jaccard = $sentence_analyzer->compute_ngram_jaccard( $true_output , $current_output , 1 )->{ 'jaccard' };
		my $edge_jaccard = $sentence_analyzer->compute_ngram_jaccard( $true_output , $current_output , 2 )->{ 'jaccard' };
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
	    $this->debug();
#    }

	}

###=cut	

=cut

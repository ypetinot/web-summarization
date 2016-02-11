package TargetAdapter::LocalMapping::TrainedTargetAdapter::TrainableSlot;

use strict;
use warnings;

# => only at training time ?
# => store this information in the slot objects -> instance id to [ filler , features ]
# TODO : pre-compute pairwise summary similarities for all pairs of mappings

use Model::FactorGraphModel;
use Similarity;

use JSON;
use Memoize;
use Text::Levenshtein::XS qw/distance/;

#use Moose::Role;
use Moose;
use namespace::autoclean;

# CURRENT : where should _filler_candidates_builder come from ? => two types of trainable slots ?
# OR : we can also learn the salience factor => fully generic
#extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Slot' );
extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::TypedSlot' );

# TODO : this should really be an ArrayRef ?
has 'instance_features' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_instance_features_builder' );
sub _instance_features_builder {

    my $this = shift;
    my $neighborhood = $this->neighborhood;

    # TODO : make sure the slot/neighborhood are associated with the main neighbor/reference
    
    my %instance_features;
    my @neighbors = @{ $neighborhood->get_neighbors( $this->parent->original_sequence->object ) };

    # Note : since the mode is slot model is trained in an unsupervised fashion, we include the target object
    # Note : this might become probablematic if we introduce constraints between fillers based on summary data => omit these constraints for factor involving a target variable
    ###push @neighbors , $this->parent->target;

    foreach my $neighbor (@neighbors) {

	my $neighbor_slot_options = $this->generate_options( $neighbor , weights => {} );
	my $neighbor_summary_string = $neighbor->summary_modality->utterance->raw_string;

	my @slot_instances = map {

	    my $neighbor_slot_option = $_->[ 0 ];

	    # Note : cost of replacing the original slot filler with this option, wrt to the neighbor instance
	    my $substituted_summary = $this->substitute_slot( $neighbor_slot_option );
	    my $substitution_cost = $this->string_energy( $neighbor_summary_string , $substituted_summary );

	    [ $neighbor_slot_option->surface , $neighbor_slot_option->features , $substitution_cost ];

	} @{ $neighbor_slot_options };

	$instance_features{ $neighbor->id } = \@slot_instances;

    }

    return \%instance_features;

}

has '_feature_set' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_feature_set_builder' );
sub _feature_set_builder {

    my $this = shift;

    my %_feature_set;
    
    # Note : to compute empirical feature expectations, we compute the sum of all features across all instances 
    foreach my $instance_features_entry ( values( %{ $this->instance_features } ) ) {
	foreach my $instance_filler_entry ( @{ $instance_features_entry } ) {
	    my $slot_option_features = $instance_filler_entry->[ 1 ];
	    foreach my $feature_key ( keys( %{ $slot_option_features } ) ) {
		$_feature_set{ $feature_key }++;
	    }
	} 
    }

    my @feature_set = keys( %_feature_set );
    return \@feature_set;

}

# TODO : create factor objects ? => wrapper for OpemGM2 ? => how did they generate the Python wrapper ? can this be replicated for Perl ?
has 'instance_pairwise_costs' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_instance_pairwise_costs_builder' );
sub _instance_pairwise_costs_builder {

    my $this = shift;
    my $instance_features = $this->instance_features;

    my @instance_ids = keys( %{ $instance_features } );

    my @costs;
    for ( my $i = 0 ; $i <= $#instance_ids ; $i++ ) {
	
	my $instance_id_i = $instance_ids[ $i ];
	my $instance_i_options = $instance_features->{ $instance_id_i };
	my @instance_i_states = map { $_->[ 0 ] } @{ $instance_i_options };

	for ( my $j = 0 ; $j < $i ; $j++ ) {

	    my $instance_id_j = $instance_ids[ $j ];
	    my $instance_j_options = $instance_features->{ $instance_id_j };
	    my @instance_j_states = map { $_->[ 0 ] } @{ $instance_j_options };

	    # consider all the value pairings
	    foreach my $state_i (@instance_i_states) {
		
		foreach my $state_j (@instance_j_states) {
	
		    my $pairwise_cost_ij = $this->summary_substitution_similarity( $instance_id_i , $state_i ,
										   $instance_id_j , $state_j );
		    
		    if ( $pairwise_cost_ij ) {
			push @costs , [ $instance_id_i , $state_i ,
					$instance_id_j , $state_j ,
					$pairwise_cost_ij ];
		    }

		}

	    }

	}

    }

    return \@costs;

}

memoize( 'cached_similarity' );
sub cached_similarity {

    my $this = shift;

    my $instance_i_id = shift;
    my $instance_j_id = shift;

    # TODO : rely on summary_substitution instead to get the original summary (without any substitution) ?
    my @summaries = map {
	lc( $this->neighborhood->get_instance( $_)->summary_modality->utterance->raw_string );
    } ( $instance_i_id , $instance_j_id );

    return $this->string_energy( @summaries );

}

sub string_energy {

    my $this = shift;
   
    # Note : might be better from a semantic standpoint ?
    # TODO : LCS ?
    
    return ( 1 - Similarity::_compute_cosine_similarity( @_ ) );
    #return distance( @_ );

} 

sub substitute_slot {

    my $this = shift;
    my $substitution_token = shift;

    my $slot_from = $this->from;
    my $slot_to = $this->to;

    my @original_sequence_objects = @{ $this->parent->original_sequence->object_sequence };
    my @substituted_summary_components;
    for ( my $i = 0 ; $i <= $#original_sequence_objects ; $i++ ) {
	if ( $i == $slot_from ) {
	    push @substituted_summary_components , $substitution_token->surface;
	    $i = $slot_to;
	}
	else {
	    push @substituted_summary_components , $original_sequence_objects[ $i ]->surface;
	}
    }

    my $substituted_summary = join( ' ' , @substituted_summary_components );
    return $substituted_summary;

}

# Note : we compute a delta compared to the original similarity of the summaries involved
sub summary_substitution_similarity {
    
    my $this = shift;
    my $i = shift;
    my $state_i = shift;
    my $j = shift;
    my $state_j = shift;

    # substitution similarity : the value of the selected state is mapped to the slot filler (shared by all instances) in the neighbor summary => compute the similarity between the resulting summaries

    my $summary_substitution_similarity = 0;

    my $has_substitution = 0;
    my @summaries_substituted = map {
	my ( $has_match , $summary_substituted ) = $this->summary_substitution( $_->[ 0 ] , $_->[ 1 ] );
	$has_substitution += $has_match;
	lc( $summary_substituted );
    } ( [ $i , $state_i ] , [ $j , $state_j ] );

    if ( $has_substitution ) {
	#$summary_substitution_similarity = Similarity::_compute_cosine_similarity( @summaries_substituted ) - $this->cached_similarity( @summaries_substituted );
	# Note : this is better since we would care about word ordering in the join learning case (?)
	# Note : negative deltas are better => this is an energy
	# CURRENT : SLOT => empty replacement ? might be better to similute full removal
	$summary_substitution_similarity = $this->string_energy( @summaries_substituted ) - $this->cached_similarity( $i , $j );
    }

    return $summary_substitution_similarity;

}

# the neighborhood must be available
###requires ( 'neighborhood' );

# the slots original filler must be available
###requires ( 'as_string' );

sub summary_substitution {

    my $this = shift;
    my $instance_id = shift;
    my $map_from_string = shift;

    my $instance = $this->neighborhood->get_instance( $instance_id );
    my $instance_summary = $instance->summary_modality->utterance->raw_string;
    my $slot_original_filler = $this->as_string;

    my $has_match = 0;
    if ( ( $map_from_string ne $slot_original_filler ) && 
	 ( $instance_summary =~ s/(^|\W)\Q$map_from_string\E(\W|$)/$1${slot_original_filler}$2/sgi ) ) {
	$has_match = 1;
    }

    return ( $has_match , $instance_summary );

}

sub _weight_default_builder {
    my $this = shift;
    return 0;
}

# TODO : maybe this is the function that should be provided by this role ?
# TODO : is providing this as a role the best option ?
sub _weights_builder {
    
    my $this = shift;
    
    # 1 - generate all instances
    my $instance_features = $this->instance_features;

    # 2 - output data for external model construction
    my $temp_file_factor_graph = new File::Temp;
    map {

	my $instance_id = $_;
	my $instance_candidates = $instance_features->{ $instance_id };

	foreach my $instance_candidate (@{ $instance_candidates }) {
	    ###$unrolled_model->add_variable( $instance_id , $instance_features );
	    print $temp_file_factor_graph join( "\t" , $instance_id , $instance_candidate->[ 0 ] ,
						encode_json( $instance_candidate->[ 1 ] ) ,
						$instance_candidate->[ 2 ]
		) . "\n";
	}

    } keys( %{ $instance_features } );
    $temp_file_factor_graph->close;

    # 3 - output pairwise potentials
    my $temp_file_factor_graph_pairwise_potentials = new File::Temp;
    my $pairwise_costs = $this->instance_pairwise_costs;
    foreach my $cost_entry (@{ $pairwise_costs }) {
	print $temp_file_factor_graph_pairwise_potentials join ( "\t" , @{ $cost_entry } ) . "\n";
    }
    $temp_file_factor_graph_pairwise_potentials->close;

    # TODO : transparent library to construct factor graphs ? => the idea would be to construct factor graphs by simply stating the energy between two states => whether energy components are shared is automatically inferred => this would be a bottom up approach to construct the graph => functional/logic languages should be good at this ? => basically data oriented ?

    my $optimized_weights = $this->generate_optimized_weights( $temp_file_factor_graph , $temp_file_factor_graph_pairwise_potentials );
    return $optimized_weights;

}

sub generate_optimized_weights {

    my $this = shift;
    my $file_factor_graph = shift;
    my $file_factor_graph_pairwise_potentials = shift;

    # Note : we use energy features
    # TODO : how do we handle SLOT fillers ? => should they even be present ?
    $this->logger->info( "Learning optimal slot weights ..." );
    my @optimizer_output = map { chomp; $_ } `/bin/bash -c "/proj/fluke/users/ypetinot/ocelot-working-copy/svn-research/trunk/experimental/opengm/sample_graph <( cat $file_factor_graph ) <( cat $file_factor_graph_pairwise_potentials ) 2> /dev/null"`;

    my %optimized_weights;
    map {
	my ( $weight_key , $weight_value ) = split /\t/ , $_;
	$optimized_weights{ $weight_key } = $weight_value;
    } @optimizer_output;

    return \%optimized_weights;

}

# Note : would have to be readjusted if I want to make use of it
sub em {
    
    my $this = shift;

    # 2 - run EM optimization
    my $average_log_likelihood_previous;
    my $average_log_likelihood_best = -1;
    my $epsilon = 0.001;
    my $max_iterations = 20;
    # 1000;
    my $iteration = 0;
    my $weights = {};
    
    my $weights_best;
    while ( ++$iteration <= $max_iterations ) {
	
	# CURRENT : should we be able to compute the likelihood function independently ?
	
	# m-step
	my ( $current_fillers , $average_log_likelihood ) = $this->m_step( $weights );
	
	if ( defined( $average_log_likelihood_previous ) ) {
	    
	    if ( $average_log_likelihood > $average_log_likelihood_best ) {
		$average_log_likelihood_best = $average_log_likelihood;
		$weights_best = $weights;
	    }
	    
=pod
        my $log_likelihood_delta = abs( $average_log_likelihood - $average_log_likelihood_previous );
	    if ( $log_likelihood_delta < $epsilon ) {
	    last;
	    }
=cut
	}

	# e-step
	my $weights_updated = $this->e_step( $weights , $current_fillers );
	$weights = $weights_updated;

	$this->logger->info( "[" . $this->key . "/$iteration] log likelihood: $average_log_likelihood | " . join( " | " , join( " / " , map { join( ':' , $_->[ 0 ] , $_->[ 3 ] ) } values( %{ $current_fillers } ) ) , encode_json( $weights ) ) );

	$average_log_likelihood_previous = $average_log_likelihood;

    }

    #return $weights;
    return $weights_best;

}

# optimize weights
# TODO : this is the M step
sub e_step {
    
    my $this = shift;
    my $weights_current = shift;
    my $fillers_current = shift;

    my %weights_current;
    my @instance_ids = keys( %{ $this->instance_features } );

    # update each feature weight independently based on current discrepancy between feature expected values
    my $features = $this->_feature_set;

    # update based on individual instance discrepancies => CRF training
    my %weights_gradients;
    foreach my $instance (@instance_ids) {

	# compute instance probabilities based on current set of weights
	my $model_instance_probabilities = $this->compute_model_probabilities( $instance , \%weights_current );

	my $instance_filler_current = $fillers_current->{ $instance };
	my $instance_filler_current_features = $instance_filler_current->[ 2 ];

	foreach my $feature ( @{ $features } ) {
	    
	    # current feature weight
	    my $feature_weight_current = $weights_current->{ $feature } || 0;
	    
	    # get feature value for the (assumed) current filler
	    my $instance_filler_feature_value = $instance_filler_current_features->{ $feature } || 0;
	    
	    # compute model expectation for this feature and this instance
	    my $feature_model_expectation_instance = 0;
	    foreach my $filler_candidate_entry (values( %{ $model_instance_probabilities } )) {
		my $filler_candidate_probability = $filler_candidate_entry->[ 0 ];
		my $filler_candidate_feature_value = $filler_candidate_entry->[ 1 ]->{ $feature } || 0;
		if ( $filler_candidate_feature_value && $filler_candidate_probability ) {
		    $feature_model_expectation_instance += $filler_candidate_feature_value * $filler_candidate_probability;
		}
	    }

	    $weights_gradients{ $feature } += ( $instance_filler_feature_value - $feature_model_expectation_instance );

	}
     
    }

    # compute updated weights
    my %weights_updated;
    my $n_instances = scalar( @instance_ids );
    my $sigma = 1;
    map {
	my $feature_key = $_;
	my $feature_weight_current = $weights_updated{ $feature_key } || 0;
	my $feature_weight_gradient = $weights_gradients{ $feature_key };

	# Note : this is equivalent to performing MAP estimation
	my $feature_weight_gradient_regularized = $feature_weight_gradient - ( ( $feature_weight_current ** 2 ) / ( 2 * $sigma ** 2 ) );

	if ( $feature_weight_gradient_regularized ) {
	    my $direction = -1;
	    ##my $direction = 1;
	    # TODO : confirm the sign of the update => maximization => +1 ?
	    # TODO : would it make sense to update based on the likelihood delta => yields the corresponding parameter delta ?
	    $weights_updated{ $feature_key } = $feature_weight_current + $direction * $this->learning_rate * ( $feature_weight_gradient_regularized / $n_instances );
	}
    } keys( %weights_gradients );

    return \%weights_updated;
    
}

has 'learning_rate' => ( is => 'ro' , isa => 'Num' , default => 0.001 );

sub compute_model_probabilities {

    my $this = shift;
    my $instance_id = shift;
    my $weights = shift;

    my %model_probabilities;

    # 1 - get instance data
    my $instance_data = $this->instance_features->{ $instance_id };

    # 2 - compute probability of each candidate filler for this instance
    my $instance_partition = 0;
    foreach my $candidate_filler_entry (@{ $instance_data }) {
	my $candidate_filler = $candidate_filler_entry->[ 0 ];
	my $candidate_filler_features = $candidate_filler_entry->[ 1 ];
	my $candidate_filler_score = $this->compute_score( $candidate_filler_features , weights => $weights );
	$model_probabilities{ $candidate_filler } = [ $candidate_filler_score , $candidate_filler_features ];
	$instance_partition += $candidate_filler_score;
    }

    # 3 - normalize
    if ( $instance_partition ) {
	map { $model_probabilities{ $_ }->[ 0 ] /= $instance_partition } keys( %model_probabilities );
    }

    return \%model_probabilities;

}

###requires( 'compute_score' );

# CURRENT : library to implement factor graphs ? => OpenGM2 ?
# update weights based on current set of optimal fillers
# TODO : this is really the E step => "Expected" state of each filler variable
sub m_step {

    my $this = shift;
    my $weights = shift;

    my %optimal_fillers;

    # for each instance identify best filler
    my $instances = $this->instance_features;
    my $average_likelihood = 0;
    foreach my $instance_id (keys( %{ $instances } )) {

	my $best_filler;
	my $best_filler_likelihood = -1;
	my $best_filler_features = undef;

	my $instance_candidates = $instances->{ $instance_id };
	my $instance_partition_function = 0;
	foreach my $instance_candidate_filler_entry ( @{ $instance_candidates } ) {

	    my $instance_candidate_filler = $instance_candidate_filler_entry->[ 0 ];
	    my $instance_candidate_filler_features = $instance_candidate_filler_entry->[ 1 ];

	    # compute likelihood of this filler
	    # P_{theta}( y_i | x_i ) => y_i is the filler , xi is the instance with which we are pairing up ?
	    # => in any case, x_i does not affect this computation ?
	    # TODO : compute score computes the unnormalized probability or the energy of the configuration ?
	    my $instance_candidate_filler_likelihood = $this->compute_score( $instance_candidate_filler_features , weights => $weights );

	    # update best filler information
	    if ( $instance_candidate_filler_likelihood > $best_filler_likelihood ) {
		$best_filler_likelihood = $instance_candidate_filler_likelihood;
		$best_filler = $instance_candidate_filler;
		$best_filler_features = $instance_candidate_filler_features;
	    }

	    $instance_partition_function += $instance_candidate_filler_likelihood;

	}

	# set best filler for the current instance
	my $best_filler_probability = $best_filler_likelihood / $instance_partition_function;
	$optimal_fillers{ $instance_id } = [ $best_filler , $best_filler_likelihood , $best_filler_features ,
					     $best_filler_probability ];

	# accumulate likelihood
	$average_likelihood += $best_filler_likelihood;

    }

    # compute average likelihood
    if ( $average_likelihood ) {
	$average_likelihood /= scalar( keys( %optimal_fillers ) );
    }

    return ( \%optimal_fillers , $average_likelihood );

}

=pod
    ###my $unrolled_model = new Model::FactorGraphModel;

    $temp_file_factor_graph->close;
    my $weights = {};

    # 2 - build model - add pairwise potentials
    my $instance_pairwise_costs = $this->instance_pairwise_costs;
    map {
	$unrolled_model->add_pairwise_potential( $_->[ 0 ] , $_->[ 1 ] , $_->[ 2 ] );
    } @{ $instance_pairwise_costs };

    # 2 - learn optimal set of weights
    # TODO : make it possible to load precomputed weights
    my $weights = $unrolled_model->optimize_weights;
=cut

__PACKAGE__->meta->make_immutable;

1;

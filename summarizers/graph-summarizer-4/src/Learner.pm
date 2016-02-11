package Learner;

use strict;
use warnings;

use Web::Summarizer::Graph2::Definitions;

use Moose;
use namespace::autoclean;

with('Logger');

# iterations
# TODO : create IteratedLearner sub-class
has 'iterations' => ( is => 'ro' , isa => 'Num' , required => 1 );

# run learning algorithm / compute weights
# default behavior is to do nothing ?
# TODO : improve using extend keyword ?
sub run {
    
    my $this = shift;
    my $model = shift;
    my $decoder_method = shift;

    # Note : for now we assume supervised learning
    # * raw instances must be in the format expected by the decoder
    # * get input component of training instances ==> this data will be used by the decoder and composed with proposed (decoded) output to produce features
    # [ [ instance_in (raw) , instance_out (featurized) ] , ... ]
    my $training_instances = shift;

    # 2 - run core learning algorithm
    # Model must be passed : (1) to update weights iteratively (absolutely necessary ?) and (2) to allow featurization of each training instance combined with their decoded output
    my $weights = $this->_compute_weights( $model , $decoder_method , $training_instances );

    # Note this allows the sub-class to directly assign weights to the featurizable model (is this a good thing ?)
    if ( $weights ) {
	$model->feature_weights( $weights );
    }

    return $weights;

}

# default behavior
sub _compute_weights {

    my $this = shift;
    my $model = shift;
    my $space = shift;
    my $decoder = shift;
    my $instances_input = shift;
    my $instances_ground_truth_features = shift;

    # 1 - make sure instances_input and instances_ground_truth_features have the same size
    my $n_instances_input = scalar( @{ $instances_input } );
    my $n_instances_ground_truth_features = scalar( @{ $instances_ground_truth_features } );
    if ( $n_instances_input != $n_instances_ground_truth_features ) {
	die "Mismatch between input instances and input instances ground truth features ...";
    }

    # 2 - iterate for n-iterations
    for (my $i=0; $i<$this->iterations; $i++) {

	# 3 - iterate over individual training instances
	for (my $j=0; $j<$n_instances_input; $j++) {
	    
	    my $current_instance = $instances_input->[ $j ];
	    my $current_instance_ground_truth_features = $instances_ground_truth_features->[ $j ];

	    # 4 - run decoding for the current instance
	    # Note : we pass the ground truth features as well to support early-update learners
	    # TODO : add if/else statement to clearly acknowledge the existence of early-update learners
	    my $decoder_output = $decoder->decode( $space , $current_instance , $current_instance_ground_truth_features );

	    # 5 - map decoded output to feature space
	    my $decoder_output_features = $model->featurize( $decoder_output );
	    
	    # 6 - update model
	    $this->update_model( $model , $current_instance_ground_truth_features , $decoder_output_features );

	}

    }

    # return the (updated) model
    # TODO : return a cloned version of the original model instead ?
    return $model;

}

# compute (gold) feature vector for a reference object
sub compute_gold_features {

    my $this = shift;
    my $model = shift;
    my $instance = shift;

    # 1 - get reference path
    my $reference_path = $model->paths()->{ $instance->url() };
    
    # 2 - generate feature vector for reference path
    my $reference_vector = $this->compute_path_features( $reference_path , $instance );

    return $reference_vector;

}

# compute feature vector for a given path
# path features factor into the feature of the path component and (for now) we simply sum these features together
sub compute_path_features {

    my $this = shift;    
    my $path = shift;
    my $instance = shift;

    my %path_features;

    my $path_length = $path->length();
    if ( $path->length() ) {

	# For now we work on edges only
	for ( my $i = 0 ; $i < $path_length - 1 ; $i++ ) {
	    
	    my $edge_features = $this->graph()->compute_edge_features( [ $path->get_element( $i ) , $path->get_element( $i + 1 ) ] , $instance );
	    map { $path_features{ $_ } = ( $path_features{ $_ } || 0 ) + $edge_features->{ $_ }; } keys( %{ $edge_features } );
	    
	}

	# normalize features (can we turn this into a configuration parameter ?)
	map { $path_features{ $_ } /= $path_length } keys( %path_features );

    }

    return \%path_features;

}

sub _norm {

    my $this = shift;
    my $vector = shift;

    my $temp_norm = 0;
    map { $temp_norm += $_^2; } values(%{ $vector });
    
    return sqrt( $temp_norm );

}

sub _feature_value {

    my $this = shift;
    my $featurized_object = shift;
    my $feature_id = shift;

    return $featurized_object->{ $feature_id } || $Web::Summarizer::Graph2::Definitions::FEATURE_DEFAULT;

}

sub _feature_weight {

    my $this = shift;
    my $weights = shift;
    my $feature_id = shift;

    return ( defined( $weights->{ $feature_id } ) ? $weights->{ $feature_id } : $Web::Summarizer::Graph2::Definitions::WEIGHT_DEFAULT );

}

__PACKAGE__->meta->make_immutable;

1;

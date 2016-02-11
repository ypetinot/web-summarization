package NPModel::SingleLayerPerceptron;

use strict;
use warnings;

use Moose;

use NPModel::Base;
extends 'NPModel::Base';

use Digest::MD5 qw(md5 md5_hex md5_base64);
use Encode qw(encode_utf8);
use Text::Trim;

# initial weight value
has 'initial_weight_value' => (is => 'ro', isa => 'Num', default => 0);

# learning rate
has 'learning_rate' => (is => 'ro', isa => 'Num', default => 0.1);

# bias for this perceptron
has 'bias' => (is => 'rw', isa => 'Num', default => 0);

# weights for this perceptron
has 'weights' => (is => 'rw', isa => 'HashRef', default => sub { {} });

# decision threshold
has 'threshold' => (is => 'ro', isa => 'Num', default => 0.5);

# train model
sub train {

    my $this = shift;
    my $ground_truths = shift;
    
    # process training instances in an online fashion
    my $training_set = $this->contents();
    for (my $i=0; $i<scalar(@{ $training_set }); $i++) { 

	my $instance = $training_set->[ $i ];
	my $ground_truth = $ground_truths->[ $i ];

	# update perceptron
	$this->update( $instance , $ground_truth );

    }

}

# update perceptron for a single instance
sub update {

    my $this = shift;
    my $instance = shift;
    my $ground_truth = shift;

    print STDERR "[SingleLayerPerceptron] updating model with instance: " . $instance->url() . "\n";

    # TODO: should the featurization be performed at the super-class level ?
    my $featurized_instance = $instance->featurize( $this->features() );

    # compute current output
    my $current_output = $this->classify( $instance );
    
    # compute error
    my $error = $ground_truth - $current_output;

    my $doing_update = 1;
    
    # check error threshold ?
    # TODO

    # adapt weights
    foreach my $feature ( keys( %{ $featurized_instance } ) ) {

	my $instance_feature_value = $featurized_instance->{ $feature };
	my $current_feature_weight = $this->_feature_weight( $feature );;

	my $new_feature_weight = $current_feature_weight + $this->learning_rate() * $error * $instance_feature_value;
	
	if ( $new_feature_weight ) {
	    $this->_feature_weight( $feature , $new_feature_weight );
	}

    }

    return $doing_update;

}

sub classify {

    my $this = shift;
    my $instance = shift;

    my $featurized_instance = $instance->featurize( $this->features() );

    my $weighted_sum = $this->bias();
    foreach my $feature ( keys( %{ $featurized_instance } ) ) {
	
	my $instance_feature_value = $featurized_instance->{ $feature } || 0;
	my $current_feature_weight = $this->_feature_weight( $feature );
	
	$weighted_sum += $current_feature_weight * $instance_feature_value;
	
    }
    my $classification = ( $weighted_sum > $this->threshold() )?1:0;

    return $classification;

}

sub _feature_weight {

    my $this = shift;
    my $feature_name = shift;
    my $feature_weight = shift;

    if ( $feature_weight ) {
	$this->weights()->{ $feature_name } = $feature_weight;
    }

    my $current_feature_weight = $this->weights()->{ $feature_name };
    return defined($current_feature_weight)?$current_feature_weight:$this->initial_weight_value();

}

no Moose;

1;

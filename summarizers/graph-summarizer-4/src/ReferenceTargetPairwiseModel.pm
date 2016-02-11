package ReferenceTargetPairwiseModel;

# Base class for all models that leverage several input objects (references) to generate a new output object (target)
# Note : the reference set can be (theoretically) extended to the entire reference corpus and should therefore be thought of as such.

# Note : possible feature sets
# 1 - one set of features for each reference object , akin to a (soft) NN model ==> do not require a Factor Graph formulation, simply generate the features and learn (easy) but learning limited to single instance unless we use the full training set as reference (future work ?)

# 2 spaces:
# 1 --> gist space where we try to produce a gist that is consistent with known gists --> translates into "gist feature" weights
# 2 --> document space where the document features should ...

# TODO : create Model:: namespace ?

use strict;
use warnings;

# Base class for all (statistical/energy-based) models

use ObjectSummaryEnergyModel;
use ObjectObjectFactorType;
use ObjectSentenceFactorType;
use ReferenceTargetPairwiseFactorGraph;
use ReferenceTargetPairwiseInstance;
use SentenceSentenceFactorType;

use Moose;
use namespace::autoclean;

# factor type
has 'factor_types' => ( is => 'ro' , isa => 'ArrayRef[FactorType]' , init_arg => undef , lazy => 1 , builder => '_factor_types_builder' );
sub _factor_types_builder {
    my $this = shift;
    my @factor_types;
    push @factor_types , $this->sentence_sentence_factor_type;
    push @factor_types , $this->object_sentence_factor_type;
    push @factor_types , $this->object_object_factor_type;
    return \@factor_types;
}

with('Model::FactorGraphModel','ReferenceTargetModel');

# object <-> sentence factor
has 'object_sentence_factor_type' => ( is => 'ro' , isa => 'ObjectSentenceFactorType' , init_arg => undef , lazy => 1 , builder => '_object_sentence_factor_type_builder' );
sub _object_sentence_factor_type_builder {
    my $this = shift;
    return new ObjectSentenceFactorType( model => $this , modalities => $this->object_modalities );
    #return new ObjectSentenceFactorType( model => $this );
}

# object <-> object factor
has 'object_object_factor_type' => ( is => 'ro' , isa => 'ObjectObjectFactorType' , init_arg => undef , lazy => 1 , builder => '_object_object_factor_type_builder' );
sub _object_object_factor_type_builder {
    my $this = shift;
    return new ObjectObjectFactorType( model => $this , modalities => $this->object_modalities );
    #return new ObjectObjectFactorType( model => $this );
}

# sentence <-> sentence factor
has 'sentence_sentence_factor_type' => ( is => 'ro' , isa => 'SentenceSentenceFactorType' , init_arg => undef , lazy => 1 , builder => '_sentence_sentence_factor_type_builder' );
sub _sentence_sentence_factor_type_builder {
    my $this = shift;
    return new SentenceSentenceFactorType( model => $this );
}

# TODO : how can we make this method more generic ?
# TODO : return an object (ReferenceTargetInstance) instead of an ARRAY ref
sub create_instance {

    my $this = shift;
    my $instance_training = shift;
    my $instances_dev = shift;

    return $this->transform_instance( [ [ $instance_training->[ 0 ] , $instances_dev ] , $instance_training->[ 1 ] ] );

}

# transform instance
sub transform_instance {

    my $this = shift;
    my $raw_instance = shift;

    # raw instances format : [ [ target_object , reference_entries ] , target_summary ]
    my $raw_instance_target_object = $raw_instance->[ 0 ]->[ 0 ];
    my $raw_instance_reference_entries = $raw_instance->[ 0 ]->[ 1 ];
    my $raw_instance_target_sentence = $raw_instance->[ 1 ];

    # generate all pairwise configurations (factor graphs) of training-reference objects
    my @pairwise_configurations;
    foreach my $reference_entry (@{ $raw_instance_reference_entries }) {

	my $reference_entry_object = $reference_entry->[ 0 ];
	my $reference_entry_sentence = $reference_entry->[ 1 ];
	
	push @pairwise_configurations , new ReferenceTargetPairwiseFactorGraph(
	    model => $this ,
	    target_object => $raw_instance_target_object ,
	    target_summary => $raw_instance_target_sentence ,
	    reference => $reference_entry_sentence );
	
    }

    # TODO : add some sort of copy constructor ?
    my $transformed_instance = new ReferenceTargetPairwiseInstance( target_object => $raw_instance_target_object ,
								    raw_output_object => $raw_instance_target_sentence ,
								    references => $raw_instance_reference_entries ,
								    configurations => \@pairwise_configurations
	);

}

sub featurize {

    my $this = shift;
    my $instance_in = shift;
    my $instance_out = shift;

    my $instance = $this->transform_instance( [ $instance_in , $instance_out ] );
    
    return $instance->featurize;

}

sub cost {

    my $this = shift;
    my $input_object = shift;
    my $output_object = shift;

    # map (input,output) to local instance type
    my $instance = $this->transform_instance( [ $input_object , $output_object ] );

    # score local instance
    my $unnormalized_probability = $instance->compute_unnormalized_probability;

    # TODO : can we do better ?
    return ( 1 / ( 0.00000001 + $unnormalized_probability ) ); 

}

__PACKAGE__->meta->make_immutable;

1;

package TargetAdapter::LocalMapping::TrainedTargetAdapter;

# Approach: adapt by sequentially scanning the reference sentence and attempting to transform extractive locations

use strict;
use warnings;

use TargetAdapter::LocalMapping::TrainedTargetAdapter::TrainedAdaptedSequence;
use Web::Summarizer::GeneratedSentence;

use Function::Parameters qw/:strict/;
use List::Util qw/min/;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter' );

# TODO : move to a role ?
# model base
has 'model_base' => ( is => 'ro' , isa => 'Str' , required => 1 );

# probability threshold appearance
has 'probability_threshold_appearance' => ( is => 'ro' , isa => 'Num' , required => 1 );

# TODO : simply specify the AdaptedSequence class as a custom builder
sub _adapted_sequence_builder {

    my $this = shift;
    my $component_id = shift;

    # CURRENT : adapt a specific component of the original
    my $adapted_sequence = new TargetAdapter::LocalMapping::TrainedTargetAdapter::TrainedAdaptedSequence (
	component_id => $component_id,
	from => $this->reference_sentence->get_component_from( $component_id ),
	to => $this->reference_sentence->get_component_to( $component_id ),
	original_sequence => $this->reference_sentence,
	target => $this->target,
	neighborhood => $this->neighborhood,
	support_threshold_target => $this->support_threshold_target,
	do_abstractive_replacements => $this->do_abstractive_replacements,
	do_compression => $this->do_compression,
	do_slot_optimization => $this->do_slot_optimization,
	output_learning_data => $this->output_learning_data,
	model_base => $this->model_base,
	probability_threshold_appearance => $this->probability_threshold_appearance,
	);

    # TODO : remove ? => the model, if there is one, is now implicitly built at construction time
    # train model
    #$adapted_sequence->train;

    return $adapted_sequence;

}

# TODO : to be removed
=pod
# extractive adaptation feature generator
has 'extractive_adaptation_feature_generator' => ( is => 'ro' , isa => 'TargetAdapter::Extractive::FeatureGenerator' , init_arg => undef , lazy => 1 , builder => '_extractive_adaptation_feature_generator_builder' );
sub _extractive_adaptation_feature_generator_builder {
    my $this = shift;
    return new TargetAdapter::Extractive::FeatureGenerator( binarize => 1 , feature_mapping_file => $this->features_mapping_file );
}
=cut

# TODO : to be removed
=pod

my $extractive_alternatives = $this->extractive_analyzer->analyze( $this->target , $sentence_object , $sentence->verbalize , threshold => $appearance_threshold , max => 20 );

=cut

__PACKAGE__->meta->make_immutable;

1;

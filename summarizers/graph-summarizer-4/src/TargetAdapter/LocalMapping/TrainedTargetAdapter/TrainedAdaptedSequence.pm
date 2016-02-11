package TargetAdapter::LocalMapping::TrainedTargetAdapter::TrainedAdaptedSequence;

use strict;
use warnings;

use Carp::Assert;
use Graph::Writer::Dot;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptedSequence' );

with( 'Trainable::LibLinearModel' => { model_file => 'appearance.model' , map_features => 1 , feature_mapping => 'appearance.features.mapping' } );

# probability threshold appearance
has 'probability_threshold_appearance' => ( is => 'ro' , isa => 'Num' , required => 1 );

sub _slot_class_abstractive_builder {
    my $this = shift;
    return $this->_slot_class;
}

sub _slot_class_extractive_regular_builder {
    my $this = shift;
    return $this->_slot_class;
}

sub _slot_class_extractive_typed_builder {
    my $this = shift;
    return $this->_slot_class;
}

# TODO : re-enable ?
#sub _slot_class_noop_builder {
#    my $this = shift;
#    return $this->_slot_class;
#}

sub _slot_class {
    return 'TargetAdapter::LocalMapping::TrainedTargetAdapter::TrainableSlot';
}

sub appearance_function {

    my $this = shift;
    my $appearance_features = shift;

    # TODO : no longer relevant ?
    # generate adaptation model
    ###my $adaptation_model = $this->adaptation_model;

    # run appearance prediction
    my ( $probability_appearance , $probability_non_appearance ) = @{ $this->predict_probability( features => $appearance_features ) };

    # in order to appear, the probability of appearance should be greater than specified threshold
    my $appearance = ( $probability_appearance >= $this->probability_threshold_appearance ) ? 1 : 0;

    return $appearance;

}

has 'adaptation_model' => ( is => 'ro' , isa => 'Graph' , init_arg => undef , lazy => 1 , builder => '_adaptation_model_builder' );
sub _adaptation_model_builder {
    
    # Note that the assumption is that there is a SINGLE mapping for any string (i.e. no local considerations if the string appears multiple time in the original summary)
    
    my $this = shift;
    
    my ( $_costs , $_optimal_assignment , $_original_holder_numerical_ids , $_numerical2token ) = @{ $this->_raw_finalization_hungarian_assignments_builder };
    my @costs = @{ $_costs };
    my @optimal_assignment = @{ $_optimal_assignment };
    my @original_holder_numerical_ids = @{ $_original_holder_numerical_ids };
    my %numerical2token = %{ $_numerical2token };
    
    # produce model state using optimal set of assignments
    # CURRENT : this should be driven by the dependency graph
    # PROBLEM : do we need to encode pairwise potentials ? if so how ?
    my $segment_graph = new Graph::Directed;
    for ( my $i = 0 ; $i <= $#original_holder_numerical_ids ; $i++ ) {
	
	my $original_holder_numerical_id = $original_holder_numerical_ids[ $i ];
	
	my $optimal_j = $optimal_assignment[ $original_holder_numerical_id ];
	my $segment_option = $numerical2token{ $optimal_j };
	my $segment_option_probability = 1 - $costs[ $original_holder_numerical_id ][ $optimal_j ];
	affirm { $segment_option_probability >= 0 && $segment_option_probability <= 1 } 'Segment probabilities must be in the [0,1] range' if DEBUG;
	
	my $segment = $this->get_segment( $i );
	my $segment_features = $this->segment_features( $i , $segment_option , $segment_option_probability );
	
	# store node features as attributes
	map {
	    my $segment_feature_key = $_;
	    my $segment_feature_value = $segment_features->{ $segment_feature_key };
	    $segment_graph->set_vertex_attribute( $i , $segment_feature_key , $segment_feature_value );
	}
	keys( %{ $segment_features } );
	
	# add edges
	# TODO : do we need edge attributes ?
	my @segment_dependents = @{ $segment->get_segment_successors_ids };
	foreach my $segment_dependent (@segment_dependents) {
	    $segment_graph->add_edge( $i , $segment_dependent );
	}
	
    }
    
    return $segment_graph;
    
}

sub run_inference {

    my $this = shift;
    my $segment_graph = $this->adaptation_model;

    # write out segment graph
    # CURRENT : generate unique instance id
    my $graph_writer = new Graph::Writer::Dot;
    my $segment_graph_file = 'instance.dot';
    $graph_writer->write_graph( $segment_graph , $segment_graph_file );
	
    # TODO : is_pinned as feature ?
    # $this->_segments->[ $i ]->is_pinned

    # TODO : is_punctuation as feature ?
    # $segment_option->is_punctuation
    
}

__PACKAGE__->meta->make_immutable;

1;

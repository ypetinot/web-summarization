package ReferenceTargetEnergyModel;

use strict;
use warnings;

use ObjectSummaryEnergyModel;
use ObjectObjectPotential;
use ObjectSentencePotential;
use SentenceSentencePotential;

use Moose;
use namespace::autoclean;

with('ReferenceTargetModel');

# target summary
# Note : in theory the target summary node really has many potential values
has 'target_summary' => ( is => 'rw' , isa => 'Web::Summarizer::Sentence' , required => 0 );

# reference object node
# TODO : create DiscreteRandomVariable class to model this node
# Note : this is inaccurate since the reference_summary and reference_object are (currently) tied
has 'reference_object' => ( is => 'ro' , isa => 'ArrayRef[Category::UrlData]' , init_arg => undef , lazy => 1 , builder => '_reference_object_builder' );
sub _reference_object_builder {

    my $this = shift;
    my @reference_objects = map { $_->object; } @{ $this->reference };

    return \@reference_objects;

}

# f-roto : reference object / target object factor
has 'f_roto' => ( is => 'rw' , isa => 'ObjectObjectPotential' , init_arg => undef , lazy => 1 , builder => '_f_roto_builder' );
sub _f_roto_builder {

    my $this = shift;
    return new ObjectObjectPotential( id => 'roto' , model => $this , modalities => $this->object_modalities , object1 => $this->target_object , object2 => $this->reference_object );

}

# f-rsts : reference summary / target summary factor
has 'f_rsts' => ( is => 'rw' , isa => 'SentenceSentencePotential' , init_arg => undef , lazy => 1 , builder => '_f_rsts_builder' );
sub _f_rsts_builder {

    my $this = shift;
    return new SentenceSentencePotential( id => 'rsts' , model => $this , object1 => $this->target_summary , object2 => $this->reference );

}

# f-tots : target object / target summary factor
has 'f_tots' => ( is => 'rw' , isa => 'ObjectSentencePotential' , init_arg => undef , lazy => 1 , builder => '_f_tots_builder' );
sub _f_tots_builder {

    my $this = shift;
    return new ObjectSentencePotential( id => 'tots' , model => $this , modalities => $this->object_modalities , object1 => $this->target_object , object2 => $this->target_summary );

}

# TODO: f_rors ==> for now we only consider reference sentences that are exact summaries for the reference objects , what about sentences loosely associated with the target object (the target object would also be a reference object in this case) ?

# object-summary energy model
has 'object_summary_energy_model' => ( is => 'ro' , isa => 'ObjectSummaryEnergyModel' , default => sub { return new ObjectSummaryEnergyModel(); } );

# TODO : reimplement as a true/generic message passing algorithm
sub compute_configuration_unnormalized_probability {

    my $this = shift;
    
    # Make sure the reference summaries and objects are properly tied
    # TODO : this shouldn't be necessary
    my $reference_object_domain_cardinality = scalar( @{ $this->reference_object } );
    my $reference_summary_domain_cardinality = scalar( @{ $this->reference } );
    if ( $reference_object_domain_cardinality != $reference_summary_domain_cardinality ) {
	die "Mismatch between reference object and reference summary nodes ...";
    }
    
    # 1 - impact of tots factor
    my $tots_compatibility = $this->f_tots->value( $this->target_object , $this->target_summary );

    # 2 - factor in impact of rsts factor
    my $rsts_roto_compatibility = 0;
    for ( my $i = 0 ; $i < $reference_object_domain_cardinality ; $i++ ) {

	my $current_reference_object_value = $this->reference_object->[ $i ];
	my $current_reference_summary_value = $this->reference->[ $i ];

	# TODO : add caching of factor values (somewhere)
	$rsts_roto_compatibility += $this->f_roto->value( $current_reference_object_value , $this->target_object ) *
	    $this->f_rsts->value( $current_reference_summary_value , $this->target_summary );

    }

    my $unnormalized_probability = $tots_compatibility * $rsts_roto_compatibility;

    return $unnormalized_probability;

}

# features builder
sub _features_builder {

    my $this = shift;

    my %features;

    foreach my $factor ( $this->f_tots , $this->f_roto , $this->f_rsts ) {
	
	my $factor_id = $factor->id;
	my $factor_features = $factor->feature_definitions;

	map {

	    my $factor_feature = $_;

	    # TODO : should we avoid feature repetition ? (i'm thinking that no)
	    my $factor_feature_key = join( "::" , $factor_id , $factor_feature->id );

	    $features{ $factor_feature_key } = $factor_feature;

	} @{ $factor_features };

    }

    return \%features;

}

__PACKAGE__->meta->make_immutable;

1;

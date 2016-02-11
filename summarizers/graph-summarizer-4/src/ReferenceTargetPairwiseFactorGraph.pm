package ReferenceTargetPairwiseFactorGraph;

# TODO : turn into anonymous/inner class returned by ReferenceTargetPairwiseModel ?

# Simplest version of the reference-target energy model : only consider individual pairings of target/reference pairs.
# Model intuition : I would like to use this (object,summary) pair as a reference for generation, what is the most likely target summary in this context ?

use strict;
use warnings;

use Factor;
use FactorGraph;
use ReferenceTargetPairwiseModel;

use Moose;
use MooseX::Aliases;
# TODO : bug in MooseX::UndefTolerant::Attribute ?
use MooseX::UndefTolerant;
use MooseX::UndefTolerant::Attribute;
use namespace::autoclean;

with('FactorGraph');

# underlying model
# TODO : move this up to a FactorGraph class
#has 'model' => ( is => 'ro' , isa => 'ReferenceTargetPairwiseModel' , required => 1 );
has 'model' => ( is => 'ro' , isa => 'ReferenceTargetPairwiseModel' , default => sub { return new ReferenceTargetPairwiseModel(); } );

# target object
# TODO : ultimately no random variable should be required (i.e. any random variable can be unobserved in the factor graph)
#has 'target_object' => ( is => 'rw' , isa => 'Category::UrlData' , required => 1 );
has 'raw_input_object' => ( is => 'ro' , isa => 'Category::UrlData' , alias => 'target_object' , required => 1);

# target summary
#has 'target_summary' => ( is => 'rw' , isa => 'Web::Summarizer::Sentence' , required =>1 );
has 'raw_output_object' => ( is => 'rw' , isa => 'Web::Summarizer::Sequence' , alias => 'target_summary' ,
			      traits => [ qw(MooseX::UndefTolerant::Attribute) ] );

# reference node
# TODO : create DiscreteRandomVariable class to model this node ?
has 'reference' => ( is => 'ro' , isa => 'Web::Summarizer::Sentence' , required => 1 );

# reference object node
# TODO : create DiscreteRandomVariable class to model this node
has 'reference_object' => ( is => 'ro' , isa => 'Category::UrlData' , init_arg => undef , lazy => 1 , builder => '_reference_object_builder' );
sub _reference_object_builder {

    my $this = shift;
    my $reference_object = $this->reference->object;

    return $reference_object;

}

# create random variables
sub create_random_variables {

    my $this = shift;

    my %random_variables;
    $random_variables{ 'target_object' } = $this->target_object;
    $random_variables{ 'target_summary' } = $this->target_summary;
    $random_variables{ 'reference_object' } = $this->reference_object;
    $random_variables{ 'reference_summary' } = $this->reference_summary;

    return \%random_variables;

}

# create factors
sub create_factors {

    my $this = shift;
    
    my %factors;
    $factors{ 'roto' } = $this->f_roto;
    $factors{ 'rsts' } = $this->f_rsts;
    $factors{ 'tots' } = $this->f_tots;

    return \%factors;

}

# f-roto : reference object / target object factor
has 'f_roto' => ( is => 'rw' , isa => 'Factor' , init_arg => undef , lazy => 1 , builder => '_f_roto_builder' );
sub _f_roto_builder {

    my $this = shift;
    #return new ObjectObjectPotential( id => 'roto' , model => $this , modalities => $this->object_modalities , object1 => 'target_object' , object2 => 'reference_object' );
    #return new Factor( id => 'roto' , type => $this->model->object_object_factor_type , instance => $this , object1 => 'target_object' , object2 => 'reference_object' );
    return new Factor( id => 'roto' , type => $this->model->object_object_factor_type , instance => $this , object1 => $this->target_object , object2 => $this->reference_object );

}

# f-rsts : reference summary / target summary factor
has 'f_rsts' => ( is => 'rw' , isa => 'Factor' , init_arg => undef , lazy => 1 , builder => '_f_rsts_builder' );
sub _f_rsts_builder {

    my $this = shift;
    #return new SentenceSentencePotential( id => 'rsts' , model => $this , object1 => 'target_summary' , object2 => 'reference' );
    #return new Factor( id => 'rsts' , type => $this->model->sentence_sentence_factor_type , instance => $this , object1 => 'target_summary' , object2 => 'reference' );
    return new Factor( id => 'rsts' , type => $this->model->sentence_sentence_factor_type , instance => $this , object1 => $this->target_summary , object2 => $this->reference );

}

# f-tots : target object / target summary factor
has 'f_tots' => ( is => 'rw' , isa => 'Factor' , init_arg => undef , lazy => 1 , builder => '_f_tots_builder' );
sub _f_tots_builder {

    my $this = shift;
    #return new ObjectSentenceFactor( id => 'tots' , type => $this->model->object_sentence_factor_type , instance => $this , object1 => 'target_object' , object2 => 'target_summary' );
    #return new Factor( id => 'tots' , type => $this->model->object_sentence_factor_type , instance => $this , object1 => 'target_object' , object2 => 'target_summary' );
    return new Factor( id => 'tots' , type => $this->model->object_sentence_factor_type , instance => $this , object1 => $this->target_object , object2 => $this->target_summary );

}

# TODO: f_rors ==> for now we only consider reference sentences that are exact summaries for the reference objects , what about sentences loosely associated with the target object (the target object would also be a reference object in this case) ?

# object-summary energy model
has 'object_summary_energy_model' => ( is => 'ro' , isa => 'ObjectSummaryEnergyModel' , default => sub { return new ObjectSummaryEnergyModel(); } );

sub id {
    my $this = shift;
    return join( "::" , $this->model->id , $this->target_object->url , $this->reference_object->url );
}

# TODO : reimplement as a true/generic message passing algorithm
sub compute_unnormalized_probability {

    my $this = shift;

    my $reference_object = $this->reference_object;
    my $reference_summary = $this->reference;
    my $binary_relevance = 

    # TODO : add caching of factor values (somewhere)
    my $_tots = $this->f_tots->value( $this->target_object , $this->target_summary );
    my $_roto = $this->f_roto->value( $reference_object , $this->target_object );
    my $_rsts = $this->f_rsts->value( $reference_summary , $this->target_summary );

    # CURRENT : the factors don't take into account the binary relevance variable
    my $unnormalized_probability = $_tots * $_roto * $_rsts;

    print STDERR join( " / " , $this->id , $this->raw_output_object->verbalize , $_tots , $_roto , $_rsts , $unnormalized_probability ) . "\n";

    return $unnormalized_probability;

}

__PACKAGE__->meta->make_immutable;

1;

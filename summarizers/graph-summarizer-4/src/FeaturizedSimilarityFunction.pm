package FeaturizedSimilarityFunction;

# TODO : implement as role so we can have both symmetric and asymmetric similarity functions

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# Note : operates in vector/feature space defined by the entry_featurizer
has 'entry_similarity_function' => ( is => 'ro' , isa => 'SimilarityFunction' , init_args => undef , lazy => 1 , builder => '_entry_similarity_function_builder' );

# CURRENT : do this potentially support a kernel-based ranker, i.e. a ranker leveraging the full reference list (does this even make sense ?) ?
has 'target_object_featurizer_class' => ( is => 'ro' , isa => 'Str' , required => 1 );
has 'target_object_featurizer' => ( is => 'ro' , isa => 'Category::UrlData::Featurizer' , init_args => undef , lazy => 1 , builder => '_target_object_featurizer_builder' );
sub _target_object_featurizer_builder {
    my $this = shift;
    return Web::Summarizer::Utils::load_class( $this->target_object_featurizer_class );
}

has 'reference_entry_featurizer_class' => ( is => 'ro' , isa => 'Str' , required => 1 );
has 'reference_entry_featurizer' => ( is => 'ro' , isa => 'Web::Summarizer::Featurizer' , init_args => undef , lazy => 1 , builder => '_entry_featurizer_builder' );
# => summary is part of the object ... how does this apply to the target object/summary ?
sub _reference_entry_featurizer_builder {
    my $this = shift;
    return Web::Summarizer::Utils::load_class( $this->reference_entry_featurizer_class );
}

1;

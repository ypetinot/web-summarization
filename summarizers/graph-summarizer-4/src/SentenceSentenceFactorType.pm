package SentenceSentenceFactorType;

use strict;
use warnings;

use Feature::CosineSimilarity;

use Moose;
use namespace::autoclean;

# feature definitions
has 'feature_definitions' => ( is => 'rw' , isa => 'ArrayRef' , lazy => 1 , builder => '_sentence_sentence_feature_definitions_builder' );
sub _sentence_sentence_feature_definitions_builder {

    my $this = shift;

    my @sentence_sentence_features;

    # We instantiate object-object features
    # TODO: provide list of features through system configuration

    #push @sentence_sentence_features , new Feature::CosineSimilarity( object1 => $this->object1 , object2 => $this->object2 );
    push @sentence_sentence_features , new Feature::CosineSimilarity();

    # 2 - KL divergence between word distributions
    # TODO

    return \@sentence_sentence_features;

}

with('PairwiseFactorType');

__PACKAGE__->meta->make_immutable;

1;

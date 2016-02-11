package Feature::CosineSimilarity;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# TODO : how can we reduce redundancy with Feature::ModalitySimilarity ?

# To be removed once I've confirmed that this feature is indeed properly covered here
### # (Non-Native) Target frequency
### push @edge_features, new WordGraph::EdgeFeature::NodeFrequency( id => $Web::Summarizer::Graph2::Definitions::FEATURE_FREQUENCY , modalities => $this->modalities_fluent );

# id
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
sub _id_builder {
    my $this = shift;
    return 'cosine-similarity';
}

with 'Feature::ReferenceTargetFeature' => { type => 'Web::Summarizer::Sentence' };

# compute
# TODO: how can we define required abstract methods uing Moose ? ==> parent class
# TODO: add triggers on objects to recompute only when needed
sub compute {

    my $this = shift;
    my $sequence1 = shift;
    my $sequence2 = shift;

    # TODO : turn this into an attribute
    my $order = 1;

    # 1 - get vector for object 1
    my $vector_1 = $sequence1->get_ngrams( $order , 1 );

    # 2 - get vector for object 2
    my $vector_2 = $sequence2->get_ngrams( $order , 1 );

    # 3 - compute similarity
    # TODO: make similarity function a parameterizable attribute
    my $similarity = Vector::cosine( $vector_1 , $vector_2 );

    my $feature_key = $this->id ;

    return { $feature_key => $similarity };

}

__PACKAGE__->meta->make_immutable;

1;

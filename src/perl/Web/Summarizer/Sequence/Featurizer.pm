package Web::Summarizer::Sequence::Featurizer;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# TODO : see parent class, is there a way to effectively recurse over all _id methods to build to the final id ?
sub _id {
    my $this = shift;
    return join( '::' , __PACKAGE__ );
}

sub run {

    my $this = shift;
    my $object = shift;
    
    # 2 - vectorize sentence
    # CURRENT : we need to be able to produce representations that are more than just unigrams
    # TODO : should correspond to weight_callback ? , coordinate_weighter => $this->coordinate_weighter
    my $sentence_vectorized = $object->get_ngrams( 1 , return_vector => 1 , surface_only => 1 );

    return $sentence_vectorized;

}

with( 'Featurizer' );

__PACKAGE__->meta->make_immutable;

1;

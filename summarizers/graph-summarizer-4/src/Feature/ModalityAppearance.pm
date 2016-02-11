package Feature::ModalityAppearance;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# TODO : create super role for all modality-based features ?

# id
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
sub _id_builder {
    my $this = shift;
    return join( "::" , 'modality-appearance' , $this->modality->id() );
}

with('Feature::ModalityFeature','Feature::ObjectSentenceFeature');

# compute
# TODO: how can we define required abstract methods uing Moose ? ==> parent class
# TODO: add triggers on objects to recompute only when needed
# TODO: can we check argument types ?
sub compute {

    my $this = shift;
    my $object = shift;
    my $sentence = shift;

    # 1 - get vector for object
    my $object_vector = $this->_object_vector_builder( $object );

    # TODO : could this be implemened as a generic vector operation ?

    # TODO : add support for higher-order n-grams
    my $appearance_count = 0;
    my $sequence_ngrams = $sentence->get_ngrams( 1 );
    my $sequence_ngrams_count = scalar( @{ $sequence_ngrams } );
    
    for (my $i=0; $i<$sequence_ngrams_count; $i++) {

	# TODO : turn n-grams into a class ? Web::Summarizer::TokenNgram ?
	if ( defined( $object_vector->get( join( " " , map { $_->surface } @{ $sequence_ngrams->[ $i ] } ) ) ) ) {
	    $appearance_count++;
	}

    }

    my $appearance = $appearance_count / $sequence_ngrams_count;
    #my $feature_key = join( "::" , $this->id , $this->modality->id );
    my $feature_key = $this->id;

    return { $feature_key => $appearance };
    
}

__PACKAGE__->meta->make_immutable;

1;

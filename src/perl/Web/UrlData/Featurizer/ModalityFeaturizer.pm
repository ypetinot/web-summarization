package Web::UrlData::Featurizer::ModalityFeaturizer;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# Note : should modality be a Modality instance instead ?
has 'modality' => ( is => 'ro' , isa => 'Str' , required => 1 );

# TODO : see parent class, is there a way to effectively recurse over all _id methods to build to the final id ?
sub _id {
    my $this = shift;
    return join( '::' , __PACKAGE__ , $this->modality );
}

sub run {

    my $this = shift;
    my $object = shift;

    # 1 - extract field
    # TODO : can we do better than dynamically computing a field name ?
    my $modality_object_name = $this->modality . '_modality' ;
    my $modality_object = $object->$modality_object_name;
    my $field_value = $modality_object->content;

    # TODO : is this optimal ? => the format of field_value could be controlled by passing a parameter to get_field !
    if ( ref( $field_value ) ) {
	$field_value = join( ' ' , @{ $field_value } );
    }

    # 2 - vectorize field value
    # CURRENT : we need to be able to produce representations that are more than just unigrams
    my $field_value_vectorized = String::Tokenizer->vectorize( $field_value , coordinate_weighter => $this->coordinate_weighter );

    return $field_value_vectorized;

}

with( 'Featurizer' );

__PACKAGE__->meta->make_immutable;

1;

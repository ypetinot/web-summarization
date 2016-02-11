package Feature::ModalityFeature;

use strict;
use warnings;

# base for all modality features - implies that instance is a Category::UrlData object ?

use Moose::Role;
use namespace::autoclean;

with ('Feature');

# modality
has 'modality' => ( is => 'ro' , isa => 'Modality::NgrammableModality' , required => 1 );

sub _object_vector_builder {

    my $this = shift;
    my $object = shift;

    my $content = $object->get_modality_data( $this->modality );
    my $vector = new StringVector( $content );

    return $vector;

}

1;

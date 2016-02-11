package Feature::ReferenceTarget::ModalitySimilarity;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

# id
has 'id' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_id_builder' );
sub _id_builder {
    my $this = shift;
    return join( "::" , 'modality-similarity' , $this->modality->id );
}

with 'Feature::ModalityFeature',
    'Feature::ReferenceTargetFeature' => { type => 'Category::UrlData' };

# compute
# TODO: how can we define required abstract methods uing Moose ? ==> parent class
# TODO: add triggers on objects to recompute only when needed
sub compute {

    my $this = shift;
    my $object1 = shift;
    my $object2 = shift;

    my %features;

    # 1 - get vector for object 1
    my $vector_1 = $this->_object_vector_builder( $object1 );

    # 2 - get vector for object 2
    my $vector_2 = $this->_object_vector_builder( $object2 );

    # 3 - compute similarity
    # TODO: make similarity function a parameterizable attribute
    my $similarity = Vector::cosine( $vector_1 , $vector_2 );

    my $feature_key = join( "::" , $this->id , $this->modality->id );

    $features{ $feature_key } = $similarity;

    return \%features;

}

=pod
sub _object_vector_builder {

    my $this = shift;
    my $object = shift;

    my $content = $object->get_modality_data( $this->modality );
    my $vector = new StringVector( $content );

    return $vector;

}
=cut

__PACKAGE__->meta->make_immutable;

1;

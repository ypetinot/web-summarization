package ObjectObjectFactorType;

use strict;
use warnings;

use Feature::ReferenceTarget::ModalitySimilarity;

use Moose;
use namespace::autoclean;

# feature definitions
has 'feature_definitions' => ( is => 'rw' , isa => 'ArrayRef' , lazy => 1 , builder => '_object_object_feature_definitions_builder' );
sub _object_object_feature_definitions_builder {

    my $this = shift;

    my @object_object_features;

    # We instantiate object-object features
    # TODO: provide list of features through system configuration

    # 1 - cosine similarity for each textual modality
    foreach my $modality (@{ $this->modalities }) {

	if ( $modality->id ne 'content.rendered' ) {
	    next;
	}

=pod
	# 0 - has modality feature
	# TODO : note that here both objects must have the current modality
	my $has_modality_feature = new Feature::HasModality( modality => $modality );
=cut

	#my $modality_similarity_feature = new Feature::ReferenceTarget::ModalitySimilarity( modality => $modality , object1 => $this->object1 , object2 => $this->object2 );
	my $modality_similarity_feature = new Feature::ReferenceTarget::ModalitySimilarity( modality => $modality );
	push @object_object_features , $modality_similarity_feature;

    }

    # 2 - KL divergence between word distribution for each textual modality
    # TODO

    return \@object_object_features;

}

with('MultiModalityPairwiseFactorType');

__PACKAGE__->meta->make_immutable;

1;

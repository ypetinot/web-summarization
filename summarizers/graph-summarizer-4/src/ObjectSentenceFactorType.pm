package ObjectSentenceFactorType;

use strict;
use warnings;

use Feature::ModalityAppearance;
use Feature::ModalityConditional;

use Moose;
use namespace::autoclean;

# feature definitions
has 'feature_definitions' => ( is => 'rw' , isa => 'ArrayRef' , lazy => 1 , builder => '_object_sentence_feature_definitions_builder' );
sub _object_sentence_feature_definitions_builder {

    my $this = shift;

    my @object_sentence_features;

    # We instantiate object-object features
    # TODO: provide list of features through system configuration

    foreach my $modality (@{ $this->modalities }) {

=pod
	# 0 - has modality feature
	# TODO
	my $has_modality_feature = new Feature::HasModality( modality => $modality );
=cut

	# 1 - cosine similarity for each textual modality
	# TODO : create object adaptor so a modality can be turned into a vector
	my $modality_similarity_feature = new Feature::CosineSimilarity( modality => $modality );

	# 2 - summary coverage
	my $modality_coverage_feature = new Feature::ModalityAppearance( modality => $modality );
	push @object_sentence_features , $modality_coverage_feature;
	 
=pod TODO: activate
        # 3 - semantic compatibility for each textual modality
        #my $modality_semantics_feature = new Feature::ModalitySemantics( modality => $modality , object => $this->object1 , sentence => $this->object2 );
        my $modality_semantics_feature = new Feature::ModalitySemantics( modality => $modality );
        push @object_sentence_features , $modality_semantics_feature;
=cut

=pod TODO: activate
        # 4 - conditional compatibility for each textual modality
        for (my $ngram_order=1; $ngram_order<=3; $ngram_order++) {
		foreach my $modality_conditional_mode ( 'average' , 'max' , 'min' ) {
		    #my $modality_conditional_feature = new Feature::ModalityConditional( modality => $modality , mode => $modality_conditional_mode , ngram_order => $ngram_order , object => $this->object1 , sentence => $this->object2 );
		    my $modality_conditional_feature = new Feature::ModalityConditional( modality => $modality , mode => $modality_conditional_mode , ngram_order => $ngram_order );
		    push @object_sentence_features , $modality_conditional_feature;
		}
	    }
=cut

	}

    return \@object_sentence_features;

}

with('MultiModalityPairwiseFactorType');

__PACKAGE__->meta->make_immutable;

1;

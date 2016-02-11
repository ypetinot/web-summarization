package WordGraph::ReferenceRanker::SymmetricTargetSimilarity;

use Similarity;
use String::Tokenizer;
use Vector;
use Web::Summarizer::Sequence::Featurizer;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceRanker::FieldBasedRanker' );

# Use LCS to compute similarity between modalities ? Only applies to single-utterance modalities.
has 'use_lcs_similarity' => ( is => 'ro' , isa => 'Bool' , default => 0 );

=pod
our $REFERENCE_RANKING_MODE_RELEVANCE = "relevance";
sub _id {
    my $this = shift;
    return join( "::" , $REFERENCE_RANKING_MODE_RELEVANCE , $this->similarity_field );
}
=cut

# TODO : if the target field is a single utterance, we should use a similarity function based on the LCS between the two strings
sub object_similarity {
    my $this = shift;
    return ( $this->similarity_field eq 'summary' ) ? return $this->lcs_similarity( @_ ) : $this->SUPER::object_similarity( @_ );
}

sub lcs_similarity {

    my $this = shift;
    my $target_object = shift;
    my $reference_sentence = shift;

    return $this->summary_lcs_similarity( $target_object->summary_modality->utterance , $reference_sentence );
    
}

sub _symmetric_builder {
    return 1;
}

__PACKAGE__->meta->make_immutable;

1;

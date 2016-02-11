package WordGraph::ReferenceRanker::TargetSimilarity;

use Similarity;
use String::Tokenizer;
use Vector;
use Web::Summarizer::Sequence::Featurizer;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceRanker::FieldBasedRanker' );

our $REFERENCE_RANKING_MODE_RELEVANCE = "relevance";
sub _id {
    my $this = shift;
    return join( "::" , $REFERENCE_RANKING_MODE_RELEVANCE , $this->similarity_field );
}

# TODO : rename package to WordGraph::ReferenceRanker::AsymmetricTargetSimilarity ?
sub _symmetric_builder {
    return 0;
}

__PACKAGE__->meta->make_immutable;

1;

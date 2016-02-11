package WordGraph::ReferenceRanker::FieldBasedRanker;

use strict;
use warnings;

use Web::Summarizer::Sequence::Featurizer;
use Web::UrlData::Featurizer::ModalityFeaturizer;

use Moose;
use namespace::autoclean;

extends( 'WordGraph::ReferenceRanker' );

# similarity field
has 'similarity_field' => ( is => 'rw' , isa => 'Str' , required => 1 );

sub _run_implementation {

    my $this = shift;
    my $target_object = shift;
    my $reference_sentences = shift;
    my $full_serialization_path = shift;

    my %url2sentence;
    my %url2score;

    # relevance computing
    my @sentence_entries;
    foreach my $reference_sentence (@{ $reference_sentences }) {

	my $reference_sentence_score = $this->object_similarity( $target_object , $reference_sentence );

	# TODO / Note : there might be value in returning reference sentences with a 0 score
	if ( $reference_sentence_score > 0 ) {
	    push @sentence_entries, [ $reference_sentence , $reference_sentence_score ];
	}

    }

    return \@sentence_entries;

}

__PACKAGE__->meta->make_immutable;

1;

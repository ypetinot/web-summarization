package WordGraph::ReferenceRanker::FieldBasedSupportRanker;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

with( 'DMOZ' );
with( 'WordGraph::ReferenceRanker' );

# similarity field
has 'similarity_field' => ( is => 'rw' , isa => 'Str' , default => 'content' );

sub support_score {

    my $this = shift;
    my $target_object = shift;
    my $sentence = shift;

    # CURRENT : ranking strategy : #supported / #non_supported => instead of length (would favor shorter summaries, which is not a bad thing actually => experiment)

    my $sentence_support = 0;
    my $sentence_support_binary = 0;
    map {
	$sentence_support += $_->object_support( $target_object );
	$sentence_support_binary += ( $_->object_support( $target_object ) > 0 );
	      # Note : seems like a bad idea as it would promote specific terms => we actually prefer generic terms
	      #/ ( $this->global_data->global_count( 'summary' , 1 , $_->id ) || 1 );
    } @{ $sentence->object_sequence };

    my $sentence_length = $sentence->length;

    # Note : binary support should be suffient ?
    my $support_score = $sentence_length ? $sentence_support_binary / $sentence_length : $sentence_length;
    return $support_score;

}

sub _run {

    my $this = shift;
    my $target_object = shift;
    my $reference_sentences = shift;
    my $full_serialization_path = shift;

    my %url2sentence;
    my %url2score;

    # relevance computing
    my @sentence_entries;
    foreach my $reference_sentence (@{ $reference_sentences }) {

	my $reference_sentence_score = $this->support_score( $target_object , $reference_sentence );

	# TODO / Note : there might be value in returning reference sentences with a 0 score
	if ( $reference_sentence_score > 0 ) {
	    push @sentence_entries, [ $reference_sentence , $reference_sentence_score ];
	}

    }

    return \@sentence_entries;

}

__PACKAGE__->meta->make_immutable;

1;

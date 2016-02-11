package TargetAdapter::LocalMapping::GlobalScoreTargetAdapter;

use strict;
use warnings;

use Algorithm::Loops qw(
Filter
MapCar MapCarU MapCarE MapCarMin
NextPermute NextPermuteNum
NestedLoops
);

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter' );

# encapsulates sequence vectorization for this class
sub _vectorize_sequence {
    my $this = shift;
    my $sequence = shift;
    my $weighted = shift || 0;
    my $weighter = $weighted ? sub { } : undef;
    return $sequence->get_ngrams( [1,2,3] , return_vector => 1 , surface_only => 1 );
}

# brute-force search for decoding having the maximum global score
sub _adapt {

    my $this = shift;
    # TODO : pass in a more integrated object (i.e. more integrated with the alignment data => Alignment object ?)
    my $original_sentence = shift;
    my $aligned_sequence = shift;

    my $n_tokens = $original_sentence->length;

    my @original_sequence;
    my $adapted_sequence;

    # 1 - identify target utterance to guide the adaptation process
    # Note : this is the utterance from the target object that is the most similar to the reference sentence
    my $original_sentence_vectorized = $this->_vectorize_sequence( $original_sentence );
    my @target_object_utterances = map { @{ $_ } } values( %{ $this->target->utterances } );
    my @target_object_utterances_vectorized = map { $this->_vectorize_sequence( $_ ) } @target_object_utterances;
    my $best_target_object_utterance = undef;
    my $best_target_object_utterance_cosine_similarity = -1;
    my $best_target_object_utterance_vectorized = undef;
    for ( my $i=0; $i<=$#target_object_utterances; $i++ ) {

	my $target_object_utterance = $target_object_utterances[ $i ];
	my $target_object_utterance_vectorized = $target_object_utterances_vectorized[ $i ];

	# compute similarity between reference sentence and current target object utterance
	my $cosine_similarity = Vector::cosine( $original_sentence_vectorized , $target_object_utterance_vectorized );
	if ( $cosine_similarity > $best_target_object_utterance_cosine_similarity ) {
	    $best_target_object_utterance = $target_object_utterance;
	    $best_target_object_utterance_cosine_similarity = $cosine_similarity;
	    $best_target_object_utterance_vectorized = $target_object_utterance_vectorized;
	}

    }

    # 2 - iterate over all possible adaptations of the reference sentence
    # CURRENT : generate (nested list) all variations and return the one that is most similar to the target object, this time using tf-idf weighting for the vectorized representation
    my $original_sentence_vectorized_weighted = $this->_vectorize_sequence( $original_sentence , 1 );
    # TODO : make sure epsilon is part of the alternatives
    my @tokens_alternatives = map {
	
	my $original_token = $_;
	my $original_token_id = $original_token->id;

	my @token_alternatives = ( $original_token->surface );

	my $token_alignments = $aligned_sequence->{ $original_token_id };
	if ( $token_alignments ) {
	    push @token_alternatives , $token_alignments->[ 0 ];
	}

	\@token_alternatives;

    } @{ $original_sentence->object_sequence };

    my @variations = NestedLoops(
	\@tokens_alternatives,
	sub { \@_; },
	);

    my $best_variation = undef;
    my $best_variation_target_cosine_similarity = -1;
    foreach my $variation (@variations) {
	
	my $variation_length = scalar( @{ $variation } );
	if ( $variation_length != $n_tokens ) {
	    die "We have a problem ...";
	}

	# TODO : we should be able to do much better than this
	my @variation_tokens = map { ref( $_ ) ? $_ : new Web::Summarizer::Token( string => $_ ) } @{ $variation };
	my $variation_sequence = new Web::Summarizer::Sentence( object_sequence => \@variation_tokens , object => $this->target ,
								source_id => join( '.' , $original_sentence->source_id , 'adaptated' , __PACKAGE__ ) );

	# TODO : should we apply weighting ?
	my $variation_vectorized = $this->_vectorize_sequence( $variation_sequence );

	# evaluate proximity between variation_string and the best target utterance
	my $variation_target_cosine_similarity = Vector::cosine( $variation_vectorized , $best_target_object_utterance_vectorized );
	if ( $variation_target_cosine_similarity > $best_variation_target_cosine_similarity ) {
	    $best_variation = $variation_sequence;
	    $best_variation_target_cosine_similarity = $variation_target_cosine_similarity;
	}

    }

    return $best_variation;

}

__PACKAGE__->meta->make_immutable;

1;

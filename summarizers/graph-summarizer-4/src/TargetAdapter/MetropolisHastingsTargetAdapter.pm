package TargetAdapter::MetropolisHastingsTargetAdapter::State;

use strict;
use warnings;

use Moose;
use namespace::autoclean;

with( 'DMOZ' );
with( 'TargetAdapter::RelevanceModel' );

# original sentence
has 'original_sentence' => ( is => 'ro' , isa => 'Web::Summarizer::Sentence' , required => 1 );

# original sequence (will not be modified)
has 'original_sequence' => ( is => 'ro' , isa => 'ArrayRef' , required => 1 );

# current sequence
has '_current_sequence' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_current_sequence_builder' );
sub _current_sequence_builder {
    my $this = shift;
    my @current_sequence = @{ $this->original_sequence };
    return \@current_sequence;
}

sub length {
    my $this = shift;
    return scalar( @{ $this->original_sequence } );
}

sub get_sequence {

    my $this = shift;
    
    my @tokens = grep { defined( $_ ) } @{ $this->_current_sequence };
    return \@tokens;

}

sub configuration_energy {

    my $this = shift;

    my $energy = 0;

    # we assume the energy factors over 3-grams
    my @window;
    my $ngram_order = 3;
    my $length_effective = 0;
    for ( my $i = 0 ; $i < $this->length ; $i++ ) {

	my $current_sequence_token = $this->_current_sequence->[ $i ];
	my $original_sequence_token = $this->original_sequence->[ $i ];

	if ( ! defined( $current_sequence_token ) ) {
	    # this original token is currently deleted
	    # TODO : we should score the deletion
	    next;
	}

	$length_effective++;

	push @window , $current_sequence_token;
	if ( $#window >= $ngram_order ) {
	    splice @window , $ngram_order;
	}

	# TODO : store surface information
	my $ngram_surface = join( " " , map { $_->surface } @window );
	my $relevance_probability = $this->relevance_probability ( $this->original_sentence , $original_sequence_token , $current_sequence_token );
	$energy += $relevance_probability * $this->global_data->global_count( 'summary' , $ngram_order , $ngram_surface );

    }

    return $length_effective ? $energy / $length_effective : $energy ;

}

__PACKAGE__->meta->make_immutable;

1;

package TargetAdapter::MetropolisHastingsTargetAdapter;

use strict;
use warnings;

use Web::Summarizer::GeneratedSentence;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::TrainedTargetAdapter' );

sub _adapt {

    my $this = shift;
    my $original_sentence = shift;
    my $alignment = shift;

    my $original_sentence_object = $original_sentence->object;

    # TODO : include sentence start and end symbols
    my @original_sentence_tokens_filtered = grep { ! $_->is_punctuation } @{ $original_sentence->object_sequence };
    my $n_original_sentence_tokens_filtered = scalar( @original_sentence_tokens_filtered );

    my $n_iterations = 100;
    my $iteration_count = 0;
    my $appearance_threshold = 2;

    my $_extractive_alternatives = $this->extractive_analyzer->analyze( $this->target , $original_sentence->object , $original_sentence->raw_string , threshold => $appearance_threshold , max => 20 );

    # TODO : should we use the full original sentence's sequence of tokens ?
    my $current_state = new TargetAdapter::MetropolisHastingsTargetAdapter::State(
	original_sentence => $original_sentence,
	original_sequence => \@original_sentence_tokens_filtered
	);
    my $current_state_energy = $current_state->configuration_energy;

    while ( $iteration_count++ < $n_iterations ) {

	# proposals - for each position in the original sequence we consider possible extractive alternatives (for now - next we can consider syntactic transformations, inversions, etc.) and compute their probability according to our relevance model.
	my @proposals;
	for ( my $i = 0 ; $i <= $#original_sentence_tokens_filtered ; $i++ ) {
	    
	    my $original_sentence_token = $original_sentence_tokens_filtered[ $i ];

	    # Note : only focus on unsupported tokens ( performance reasons - for now )
	    if ( $this->target->supports( $original_sentence_token ) ) {
		next;
	    }
	    
	    # Note this computation should be stored
	    foreach my $_extractive_alternative (@{ $_extractive_alternatives }) {

		my $extractive_alternative_token = $_extractive_alternative->[ 0 ];
		my $extractive_alternative_token_frequence = $_extractive_alternative->[ 1 ];

		# Note : all transformations are equiprobable
		push @proposals , [ $i , 'substitution' , $extractive_alternative_token ];
		
	    }

	}

	# randomly select a transformation
	my $transformation_index = int( rand( scalar( @proposals ) ) );
	my $transformation = $proposals[ $transformation_index ];
	
	# compute energy of new transformation
	my $candidate_state = $current_state->transition( $transformation );
	my $candidate_state_energy = $candidate_state->configuration_energy;

	# decide on whether to perform transformation
	if ( $candidate_state_energy > $current_state_energy ) {

	}
	
    }

    my $adapted_sentence_raw_string = join( " " , map { $_->surface } @{ $current_state->get_sequence } );
    return Web::Summarizer::GeneratedSentence->new( raw_string => $adapted_sentence_raw_string , object => $this->target , source_id => __PACKAGE__ , score => $current_state_energy );

}

__PACKAGE__->meta->make_immutable;

1;

package TargetAdapter::LocalMapping::SimpleTargetAdapter;

use strict;
use warnings;

use TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptedSequence;
use TargetAdapter::LocalMapping::SimpleTargetAdapter::GraphBasedAdaptedSequence;
use Web::Summarizer::GeneratedSentence;

use Algorithm::Loops qw(
Filter
MapCar MapCarU MapCarE MapCarMin
NextPermute NextPermuteNum
NestedLoops
);

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter' );
with( 'TargetAdapter::RelevanceModel' );

has '_adapted_sequences' => ( is => 'ro' , isa => 'ArrayRef[TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptedSequence]' , init_arg => undef , lazy => 1 , builder => '_adapted_sequences_builder' );
sub _adapted_sequences_builder {
    my $this = shift;

    my @adapted_sequences;
    
    my $original_sentence_component_count = $this->reference_sentence->component_count;
    for ( my $component_id = 0 ; $component_id < $original_sentence_component_count ; $component_id++ ) {
	my $adapted_sequence = $this->_adapted_sequence_builder( $component_id );
	push @adapted_sequences , $adapted_sequence;	
    }
    
    return \@adapted_sequences;

}

# TODO : local model => so that we don't have to perform any form of global training (which may not even be meaningful in the first place => local model comes first in levels of complexity)
# TODO : select a single neighbor/reference but fit slots so that the set of replacements for each slot are maximally coherent ?
# TODO => how ?

sub _adapted_sequence_builder {

    my $this = shift;
    my $component_id = shift;

    # CURRENT : adapt a specific component of the original 
##    my $adapted_sequence = new TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptedSequence (
    my $adapted_sequence = new TargetAdapter::LocalMapping::SimpleTargetAdapter::GraphBasedAdaptedSequence (
	component_id => $component_id,
	from => $this->reference_sentence->get_component_from( $component_id ),
	to => $this->reference_sentence->get_component_to( $component_id ),
	original_sequence => $this->reference_sentence,
	target => $this->target,
	neighborhood => $this->neighborhood,
# TODO : to be removed once the Neighborhood class can handle the pairwise/mirrorred analysis of instances
##	reference_specific => $this->_mirrored_analysis->[ 1 ],
##	target_specific => $this->_mirrored_analysis->[ 0 ],
	support_threshold_target => $this->support_threshold_target,
	do_abstractive_replacements => $this->do_abstractive_replacements,
	do_compression => $this->do_compression,
	do_slot_optimization => $this->do_slot_optimization,
	output_learning_data => $this->output_learning_data,
	);

    return $adapted_sequence;

}

has 'support_threshold_target' => ( is => 'ro' , isa => 'Num' , default => 2 );

has 'do_compression' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# do replacements only ? => i.e. no compression ?
has 'do_abstractive_replacements' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# do slot optimization
has 'do_slot_optimization' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# output learning data ?
has 'output_learning_data' => ( is => 'ro' , isa => 'Bool' , default => 0 );

has 'decoding_mode' => ( is => 'ro' , isa => 'Str' , default => 'hungarian' );

# adapt by looking up predicted replacement for each token
sub _adapt {

    my $this = shift;
    my $compressed = shift || 0;
    my $neighbors = shift || [];

    # TODO : negative factors for non appearance ?

    # CURRENT : optimize replacement model => features : appear in title, appear in url, etc.
    # TODO    : for each type create a distribution of candidates
    # TODO    : minimum threshold to consider supported => 2;

    # => for all locations, estimate probability of replacement based on neighborhood => frequent in neiborhood mean no replacement => this gives prior for the slots as well
    # => what is the corresponding stochastic model ?

    my $number_adapted = 0;
    my $number_supported = 0;
    my $number_unfillable = 0;
    my $last_output_token = undef;

    my @tokens_surface;

    my $score = 1;

    # CURRENT :
    # 1 - make initial parse available so that within slot dependies are available to the slot itself
    # 2 - generate new sequence ...

    foreach my $adapted_sequence (@{ $this->_adapted_sequences }) {
	
	# Note : finalize is responsible for both adapting the slots and computing the probability of the final summary
	my ( $adapted_sequence_finalized , $adapted_sequence_finalized_probability ) = $adapted_sequence->finalize( decoding_mode => $this->decoding_mode , compressed => $compressed , neighbors => $neighbors );
	my @adapted_sentence_tokens = @{ $adapted_sequence_finalized };

	# find optimal path through adapted sequence
	# TODO => note that we still need to take into account the do_replacement flag
	my $token_position = 0;
	my $previous_token_is_punctuation = 0;
	foreach my $adapted_sentence_token (@adapted_sentence_tokens) {

	    my $adapted_sentence_token_is_punctuation = $adapted_sentence_token->is_punctuation;

	    # Note : we skip any leading puncutation
	    if ( $adapted_sentence_token_is_punctuation && ! $token_position ) {
		next;
	    }
	    # Note : we never include quotes (should we be more careful here ?)
	    elsif ( $adapted_sentence_token_is_punctuation && $adapted_sentence_token->is_quote ) {
		next;
	    }

	    my $adapted_sentence_token_surface = $token_position++ ?
		( $adapted_sentence_token->abstract_type ? $adapted_sentence_token->surface : $adapted_sentence_token->surface_regular )
		: $adapted_sentence_token->surface_capitalized;

	    if ( $previous_token_is_punctuation && $adapted_sentence_token_is_punctuation ) {
		pop @tokens_surface;
	    }

	    push @tokens_surface , $adapted_sentence_token_surface;
	    $previous_token_is_punctuation = $adapted_sentence_token_is_punctuation;

	}

	# update score
	# Note : an empty sequence (should/will) have a probability of 1, but this is fine
	$score *= $adapted_sequence_finalized_probability;
	
    }

    # TODO : normalize by sentence length ? => the expectation is that longer summaries will have a lower probability anyways
    my $adapted_sentence = new Web::Summarizer::GeneratedSentence( raw_string => join( " " , @tokens_surface ) , object => $this->target , source_id => __PACKAGE__ , score => $score );

    return $adapted_sentence;

}

# TODO : to be removed - no longer relevant since we are using a probabilistic model now
=pod
    my $lm_score = $this->_lm_score( \@tokens_surface );
    my $support_score = $this->_support_score( \@adapted_sentence_tokens );
    my $score_final = $lm_score * $support_score;
=cut

sub _support_score {

    my $this = shift;
    my $tokens = shift;

    my $score = 0;
    my $n_tokens = scalar( @{ $tokens } );

    if ( $n_tokens ) {
	
	for ( my $i = 0 ; $i < $n_tokens ; $i++ ) {

	    # TODO : check whether phrase tokens (i.e. slot fillers) are handled properly
	    $score += $this->target->supports( $tokens->[ $i ] ) ? 1 : 0;
	    
	}

	$score /= $n_tokens;

    }

    return $score;

}

sub _lm_score {

    my $this = shift;
    my $tokens_surface = shift;

    my $score = 0;

    my $order = 3;
    my $n_tokens = scalar( @{ $tokens_surface } );

    if ( $n_tokens ) {

	for ( my $i = 0 ; $i < ( $n_tokens - $order - 1 ) ; $i++ ) {
	    
	    my $ngram_surface = join ( " " , map { $tokens_surface->[ $_ ] } ( $i .. ( $i + $order - 1 ) ) );
	    my $ngram_count = $this->global_data->global_count( 'summary' , $order , $ngram_surface );
	    $score += $ngram_count;
	    
	}

	$score /= $n_tokens;

    }

    return $score;

}

sub _pos_factor {
    
    my $this = shift;
    my $predicted_pos = shift;
    my $type_candidate = shift;

    my $factor = 1;

    my $pos_string = join( ' ' , @{ $predicted_pos } );

    if ( $type_candidate =~ m/\#n#/ && $predicted_pos !~ /(?:^|\s)N/ ) {
	$factor /= 2;
    }

    return $factor;

}

sub _corpus_factor {
    
    my $this = shift;
    my $original_span = shift;
    my $previous_token = shift;
    my $type_candidate = shift;
    my $next_token = shift;

#    my $incoming_bigram_count = $this->global_data->global_count( 'summary' , 2 , join( ' ' , $previous_token , $type_candidate ) );
#    my $outgoing_bigram_count = $this->global_data->global_count( 'summary' , 2 , join( ' ' , $type_candidate , $next_token ) );

    my $trigram = join( ' ' , $previous_token , $type_candidate , $next_token );

=pod
    my $original_trigram_count = $this->global_data->global_count( 'summary' , 3 , $original_span );
    my $trigram_count = $this->global_data->global_count( 'summary' , 3 , $trigram );

    # TODO : avoid mixing bigram and trigram counts ? => e.g. favor trigrams but backoff to bigrams
#    return $incoming_bigram_count + $outgoing_bigram_count + $trigram_count;
=cut

    return ( 1 - $this->semantic_distance( $original_span , $trigram ) );
#    return ( $trigram_count + 1 ) / ( $original_trigram_count + 1 );

}

=pod
sub _best_adaptable_type {

    my $this = shift;
    my $reference_specific = shift;
    my $original_extractive_span = shift;

    my $best_type = undef;

    my %target_type_members;
    map {
	my $type = $_;
	my $type_members = $target_specific->get_type_members( $_ );
	if ( $type_members ) {
	    $target_type_members{ $type } = $type_members;
	}
    } @{ $original_span_types };

    if ( scalar( keys( %target_type_members ) ) ) {
	my @sorted_types = sort {
	    scalar( @{ $target_type_members{ $b } } ) <=> scalar( @{ $target_type_members{ $a } } )
	} keys( %target_type_members );
	$best_type = $sorted_types[ 0 ];
    }

    # CURRENT : might not be necessary anymore => consider all the types

    # TODO : clean this up
    return ( $original_span_types , $best_type , $target_type_members{ $best_type } );

}
=cut

has '_pos_function_regex' => ( is => 'ro' , isa => 'Regexp' , init_arg => undef , lazy => 1 , builder => '_pos_function_regex_builder' );
sub _pos_function_regex_builder {
    my $this = shift;

# TODO : fix
    my @function_poses = ( 'IN' );
    my $function_poses_regex_string = join( '|' , map {
	my $pos_regex_string = '^' . $_ . '$';
	qr/$pos_regex_string/;
					    } @function_poses );
    
    my $regex = qr/${function_poses_regex_string}/;

    return $regex;
}

sub _is_function_token {

    my $this = shift;
    my $token = shift;

    my $pos_function_regex = $this->_pos_function_regex;
    if ( $token->pos =~ m/$pos_function_regex/sgi ) {
	return 1;
    }

    return 0;

}

# TODO : to be removed
=pod
# TODO : ultimately this should become _adapted_compressed_builder ?
sub compress {

    my $this = shift;
    my $uncompressed_sentence = shift;

    

}
=cut

__PACKAGE__->meta->make_immutable;

1;

# original code
=pod
    for ( my $i=0; $i<$n_tokens; $i++ ) {

	# TODO : we shouldn't have to double check here ! => improve this ?
	my $original_token_target_supported = $target_supported[ $i ];
	if ( $original_token_target_supported ) {
	    # we don't attempt to transform supported tokens
	    $number_supported++;
	    @adapted_tokens = ( $original_token );
	}
	elsif ( $this->_is_function_token( $original_token ) ) {
	    $this->logger->debug( "[" . __PACKAGE__ . "] Keeping function word : " . $original_token->surface );
	    @adapted_tokens = ( $original_token );
	}
	else {

	    # Perform extractive analysis
	    my ( $is_extractive , $object_support_target , $object_support_reference ) = $this->_token_analysis( $original_sentence_object , $original_token , $reference_specific );

	    # CURRENT : is the notion of extractive important ? => maybe not, there might not be a needed to differentiate betwee abstractive and extractive given the way I am adapting terms => go up and find replacement
	    # CURRENT : simple algorithm could be : go up and check for existence of replacement and generated n-gram exists
	    # CURRENT : if not supported by object and not abstractable and replaceable => skip

	    # Note : here we are looking for conditions where we think we have an option to adap
	    # => note that if there is no reference object support we assume that we are dealing with a function word
	    # => TODO : refine by checking for synset support in reference object
	    if ( ! $object_support_target && $object_support_reference ) {

		# TODO : keep moving forward until either phrase is known or token is supported
		my $original_extractive_span_to = $i;
		my $original_extractive_span;
		my $original_extractive_span_current;
		while ( 1 ) {

		    my $ok = 0;

		    if ( $original_extractive_span_to < $n_tokens ) {

			$original_extractive_span_current = join( ' ' ,
								  map {
								      my $token = $original_sentence->object_sequence->[ $_ ];
								      $token->surface;
								  } ( $i .. $original_extractive_span_to ) );

			# TODO : is this the right thing to do ?
			# => include reference summary in set of utterances instead ?
			# => would yield contiguous slots but how do we detect the type then ?
			if ( ( $original_extractive_span_to == $i ) || $reference_specific->has_sequence( $original_extractive_span_current ) ) {
			    $original_extractive_span = $original_extractive_span_current;
			    $ok = 1;
			    $original_extractive_span_to++;
			}
		    
		    }

		    if ( ! $ok ) {
			$original_extractive_span_to--;
			last;
		    }

		}

		# attempt to map original_extractive_span to a slot type and consider target members of the same type
		# TODO : if a token is unsupported by the reference, at least attempt to look it up as an entity
		my $original_span_types = $reference_specific->get_types( $original_extractive_span ) || $this->extractive_analyzer->get_types( $original_extractive_span );
		my $adapted = 0;		

		# CURRENT : how do handle Bandera, Texas ?

		if ( $original_span_types ) {
		    
		    my %candidate2score;
		    my $original_span_type_prior = 1 / scalar( @{ $original_span_types } );

		    # CURRENT : only consider types that are compatible with the POS information ?
		    my @predicted_pos;
		    map {
			my $token = $original_sentence->object_sequence->[ $_ ];
			push @predicted_pos , $token->pos;
		    } ( $i .. $original_extractive_span_to );
		    
		    # consider all the possible types and for each type the possible target candidates
		    foreach my $original_span_type (@{ $original_span_types }) {

			my $type_candidates = $target_specific->get_type_members( $original_span_type );
			
			# probability of a type for a string is based on the number of types this string is assigned to => uniform prior
			
			foreach my $type_candidate (@{ $type_candidates }) {

			    # TODO : if the type is a wn synset, check if one a compatible word appears in the target
			    # p $this->wordnet_query_data->querySense( 'give#v#8' , 'hypo' )
			    # ==> TODO : implement as a generic function that 'goes down' from type

			    my $type_candidate_type_prior = 1 /
				scalar( @{ $target_specific->get_types( $type_candidate , normalize => 0 ) } );
			    
			    
			    my $previous_token = $i ? $original_sentence->object_sequence->[ $i - 1 ]->surface : undef;
			    my $next_token = ( $original_extractive_span_to < $n_tokens - 1 ) ? $original_sentence->object_sequence->[ $original_extractive_span_to + 1 ]->surface : undef;
			    $candidate2score{ $type_candidate } +=
				#$original_span_type_prior * $type_candidate_type_prior *
				( 1 - $this->semantic_distance( $original_extractive_span , $type_candidate ) ) *
				$this->_pos_factor( \@predicted_pos , $type_candidate ) *
				$this->_corpus_factor( $original_extractive_span , $previous_token , $type_candidate , $next_token );

			}
			
		    }

		    if ( scalar( keys( %candidate2score ) ) ) {

			# identify most likely candidate
			my @sorted_candidates = sort {
			    $candidate2score{ $b } <=> $candidate2score{ $a }
			} keys( %candidate2score );
			my $best_candidate = $sorted_candidates[ 0 ];
			my $best_candidate_score = $candidate2score{ $best_candidate };
			
			# normalize best_candidate_score (allows to work with a scoring function that's not normalized)
			my $candidates_partition = 0;
			map { $candidates_partition += $_; } values( %candidate2score );
			my $best_candidate_score_normalized = $best_candidate_score / $candidates_partition;
			
			my $adaptation_confidence = $best_candidate_score_normalized;
			$number_adapted += $adaptation_confidence;
			$this->logger->debug( "[" . __PACKAGE__ . "] Attempting to adapt $original_extractive_span\n" );
			
			@adapted_tokens = ( new Web::Summarizer::Token( surface => $best_candidate ) );
			
			# we adapted the sequence of tokens
			$adapted = 1;

		    }

		}
		else {

		    # we don't have a type for the unsupported/extractive span
		    # we will drop this sequence of tokens
		    $this->logger->debug( "[" . __PACKAGE__ . "] Dropping : $original_extractive_span" );

		}

		# For cases where we were not able to adapt the sequence of tokens
		if ( ! $adapted ) {
		    # we do nothing but count this slot location at dubious
		    $number_unfillable++;
		    $this->logger->debug( "[" . __PACKAGE__ . "] Unfillable : $original_extractive_span" );
		}
		
		# update cursor
		$i = $original_extractive_span_to;

	    }
	    else {
		
		# TODO : add check for synsets
		# TODO : add semantic prediction because these words may not be relevant at all
		$this->logger->debug( "Function word : " . $original_token->surface );
		@adapted_tokens = ( $original_token );

	    }

	    # Note: in a future iteration, original_token_alignment could turn into a structure that is more complex

	}

	if ( scalar( @adapted_tokens ) ) {
	    push @adapted_sentence_tokens, @adapted_tokens;
	    $last_output_token = $adapted_tokens[ $#adapted_tokens ];
	}
	else {

	    # TODO : this is where a full-fledged sentence-compressor could be used => viterbi decoder to find optimal path according to language model
	    # => not I could simply mark the words that should be deleted (with a cost for inclusion) and run a global decoder to find the best sentence that can be made out of the raw sequence of tokens.

	    # move forward until we reach the first target supported token
	    # TODO : find next supported word that has highest probability according to corpus
	    my $stop_ok = 0;
	    while ( ! $stop_ok && $i < $n_tokens ) {

		my $current_token_surface = $original_sentence->object_sequence->[ $i ]->surface;
		$this->logger->debug( "[" . __PACKAGE__ . "] Skipping : $current_token_surface" );
		$i++;

		# test current n-gram
		my $current_final_ngram = join( ' ' , ( $last_output_token ? $last_output_token->surface : '<s>' ) , $current_token_surface );
		my $current_final_ngram_count = $this->global_data->global_count( 'summary' , 3 , $current_final_ngram );
		if ( ! $current_final_ngram_count ) {
		    $stop_ok = 0;
		}
		else {
		    $stop_ok = 1;
		}

	    }

	    if ( defined( $last_output_token ) ) {
		
		my $last_output_token_is_punctuation = $last_output_token->is_punctuation;
		if ( $last_output_token_is_punctuation ) {
		    while ( scalar( @adapted_sentence_tokens ) && $adapted_sentence_tokens[ $#adapted_sentence_tokens ]->is_punctuation ) {
			my $token_surface = $adapted_sentence_tokens[ $#adapted_sentence_tokens ]->surface;
			$this->logger->debug( "[" . __PACKAGE__ . "] Popping : $token_surface" );
			pop @adapted_sentence_tokens;
		    }
		}
		
	    }

	}
	
    }

    my $score = $lm_score * ( $number_supported + $number_adapted ) / ( 1 + $number_unfillable );
=cut

package TargetAdapter::LocalMapping::SimpleTargetAdapter::WordEmbeddingSlot;

use strict;
use warnings;

use Vector;

use Function::Parameters qw/:strict/;
use List::MoreUtils qw/uniq/;
use Memoize;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Slot' );
with( 'TypeSignature' );
with( 'WordNetLoader' );

# TODO : to be removed ?
# => we now handle types using a scoring/feature-based approach => no hard filtering (filtering is on frequency only ?)
sub type_compatible {
    
    my $this = shift;
    my $candidate_type = shift;

# Note: specific type detection by NER component is dubious
##
##    # if we have a type, the candidate type must match ?
##    if ( $this->has_abstract_types ) {
##	# TODO : reprocess / post-process named entities to determine specific types ?
##	return defined( $this->abstract_types->{ $candidate_type } ) || ( $candidate_type eq 'MISC' );
##    }

    return 1;

}

sub slot_compatible {

    my $this = shift;
    my $candidate_filler = shift;

    return 1;

}

# TODO : can we avoid creating a new intermediate method to handle this ?
sub _modality_appearance_count {

    my $this = shift;
    my $target_instance = shift;
    my $string = shift;

    # TODO : how to avoid having to reinstantiate a Token object ?
    my $token = new Web::Summarizer::Token( surface => $string );

    # TODO : is there a better way to get this information ?
    # TODO : regex_match absolutely necessary ?
    my $appearance_vector = $token->_appearance_vector( $target_instance , regex_match => 1 );

    return $appearance_vector->dimensionality;

}

=pod

###	my $is_this_regular = $this->is_regular;
###	my $is_candidate_regular = $this->is_regular( $_ );

###	# CURRENT : separate indicator for the regular nature of a word => method => is_regular
###	if ( ( $is_this_regular && ! $is_candidate_regular )
###	     || ( ! $is_this_regular && $is_candidate_regular ) ) {
###	    $keep = 0;
###	}

# TODO : provide abstract candidates by simply listing the ontological types associated with the slot => could do this for all slots and use these as abstract candidates ?

=cut

# Note : type filtering takes place at candidate generation-time
sub _filler_candidates_builder {

    my $this = shift;
    my $target_instance = shift;

    my %filler_candidates;

    # TODO : remove code redundancy between the collection of incoming and outgpoing dependencies
    # TODO : acquire dependency type to that we can better filter the candidates
    my $dependency_graph = $this->parent->original_sequence->dependencies_graphs->[ $this->parent->component_id ]->[ 0 ];

    # incoming dependencies
    my %incoming;
    my %outgoing;

    foreach my $entry ( [ \%incoming , 0 ] , [ \%outgoing , 1 ] ) {
    
	my $entry_hash = $entry->[ 0 ];
	my $entry_direction = $entry->[ 1 ];

	map {
	    my $token_id = $_;
	    my @token_neighbors = uniq ( $entry_direction ? $dependency_graph->successors( $token_id ) : $dependency_graph->predecessors( $token_id ) );
	    # TODO : we might still be losing information here if we have multiple dependencies to multiple instances of the same word
	    foreach my $token_neighbor (@token_neighbors) {
		my $token_neighbor_key = $this->parent->original_sequence->object_sequence->[ $token_neighbor ]->id;
		my $token_neighbor_dependency_type = $dependency_graph->get_edge_attribute(
		    ( $entry_direction ? $token_id : $token_neighbor ) ,
		    ( $entry_direction ? $token_neighbor : $token_id ) , 'dependency-type' );
		if ( defined( $entry_hash->{ $token_neighbor_key } ) && ( $entry_hash->{ $token_neighbor_key } ne $token_neighbor_dependency_type ) ) {
		    # TODO : handle multiple incoming types for the same word ?
		    $this->logger->warn( "Conflicting dependency type found : $token_id / $token_neighbor" );
		}
		$entry_hash->{ $token_neighbor_key } = $token_neighbor_dependency_type;
	    }
	} @{ $this->_range_sequence };

    }

    # TODO : switch loops so we abort early => i.e. only focus on unsupported dependencies in the reference summary
    # Note : we are looking for target candidates that have at least one dependency in common with the current filler
    my $target_dependencies = $target_instance->dependencies;
    foreach my $target_dependency_entry (@{ $target_dependencies }) {

	my $target_dependency_entry_from = $target_dependency_entry->[ 0 ];
	my $target_dependency_entry_to = $target_dependency_entry->[ 1 ];
	my $target_dependency_entry_dependencies = $target_dependency_entry->[ 3 ];

	my @dependency_candidates;

	# TODO : handle multiple incoming/outgoing dependency types
	my $incoming_type = $incoming{ $target_dependency_entry_from };
	if ( $incoming_type ) {
	    push @dependency_candidates, [ $incoming_type , 0 ];
	}

	my $outgoing_type = $outgoing{ $target_dependency_entry_to };
	if ( $outgoing_type ) {
	    push @dependency_candidates, [ $outgoing_type , 1 ];
	}	
	
	foreach my $dependency_candidate (@dependency_candidates) {

	    my $dependency_candidate_type = $dependency_candidate->[ 0 ];

	    foreach my $target_dependency_entry_dependency (@{ $target_dependency_entry_dependencies }) {

		my $target_dependency_entry_type = $target_dependency_entry_dependency->type;

		# Note: dependency types must match
		if ( $target_dependency_entry_type eq $dependency_candidate_type ) {
		    my $dependency_candidate_direction = $dependency_candidate->[ 1 ];
		    my $filler_candidate = $dependency_candidate_direction ? $target_dependency_entry_from : $target_dependency_entry_to;
		    if ( $this->slot_compatible( $filler_candidate ) ) {
			$filler_candidates{ lc( $filler_candidate ) }++;
		    }
		}

	    }

	}

    }

    # type-based target candidates
    # TODO : create dependency-based features
    my $target_candidates = $this->target_candidates( $target_instance );
    map {
	# TODO : avoid override in case this candidate has already been found ?
	$filler_candidates{ lc( $_ ) } = $target_candidates->{ $_ };
    }
    keys( %{ $target_candidates });
    
    return \%filler_candidates;

}

# TODO : this factor is probably a salience factor
sub previous_token_factor {

    my $this = shift;
    my $target_instance = shift;
    my $candidate = shift;

    # Approach return 1 if bi-gram exists in target, else backoff to corpus's bigram frequency

    # 1 - get previous token
    my $previous_token = $this->previous_token;

    return $this->context_factor( $target_instance , $previous_token , $candidate );

}

# TODO : this factor is probably a salience factor
sub next_token_factor {

    my $this = shift;
    my $target_instance = shift;
    my $candidate = shift;
    
    # 1 - get next token
    my $next_token = $this->next_token;
    
    return $this->context_factor( $target_instance, $candidate , $next_token );

}

sub context_factor {

    my $this = shift;
    my $target_instance = shift;
    my $token_1 = shift;
    my $token_2 = shift;

    my @_tokens = map {
	ref( $_ ) ? $_->surface : $_;
    } ( $token_1 , $token_2 );

    # generate bigram
    my $bigram = join( ' ' , @_tokens );
    if ( $target_instance->supports( $bigram , regex_match => 1 ) ) {
	return 1;
    }
    
    return $this->parent->_transition_probability( $token_1 , $token_2 );

}

# TODO : use appearance pattern as an indicator of semantic similarity ? => should work

sub appearance_factors {

    my $this = shift;
    my $target_instance = shift;
    my $object_1 = shift;
    my $string_1 = shift;
    my $object_2 = shift;
    my $string_2 = shift;
    
    my %appearance_factors;

    # TODO : is there a better way to get this information
    my @appearance_vectors = map {	
	my $token = new Web::Summarizer::Token( surface => $_->[ 1 ] );
	# Note : regex match is necessary since I don't have phrases handled for fluent modalities
	# TODO : avoid using regex match
	my $object_appearance = $token->_appearance_vector( $_->[ 0 ] , regex_match => 1 );
    } ( [ $object_1 , $string_1 ] , [ $object_2 , $string_2 ] );

    # TODO : only consider modalities available from both objects

    # similultaneous appearance in respective modalities
    my $modalities = $target_instance->modalities;
    my $n = scalar( keys( %{ $modalities } ) );
    if ( $n ) {

	foreach my $modality_id (keys( %{ $modalities } )) {
	    my $factor_value = 1;
	    map { $factor_value *= ( $_->coordinates->{ $modality_id } ? 1 : 0 ) } @appearance_vectors;
	    $appearance_factors{ join( '::' , $modality_id , 'simultaneous' ) } = $factor_value;
	}

	# aggregate appearance similarity
	# TODO

    }

    return \%appearance_factors;

}

sub type_factor {

    my $this = shift;
    my $target_instance = shift;
    my $string_2 = shift;

    # CURRENT : add basic type in case no advanced type is available ?

    if ( $this->has_abstract_types ) {
	return $this->type_factor_entity( $target_instance , $string_2 );
    }

    return $this->type_factor_regular( $target_instance , $string_2 );

}

sub type_factor_entity {

    my $this = shift;
    my $target_instance = shift;
    my $string_1 = $this->as_string;
    my $string_2 = shift;

    # 1 - lookup types using best/comprehensive resource => Freebase
    my @type_signatures = map { $this->type_signature_freebase( $_ ) } ( $string_1 , $string_2 );

    # TODO : shouldn't the two be merged instead ? => or separate factors ?
    if ( ! $type_signatures[ 0 ]->norm ) {
	return $this->type_factor_ner( $target_instance , $string_2 );
    }

# cosine similarity, via normalization is probably not the best way to measure type compatibility
# renormalization might be ok though
    # 2 - compute similarity between signatures
    # TODO : should we use a Jaccard coefficient instead ?
    my $type_factor = Vector::cosine( @type_signatures );

    return ( $type_factor , @type_signatures );

}

has '_slot_type_signature_ner' => ( is => 'ro' , isa => 'Vector' , init_arg => undef , lazy => 1 , builder => '_slot_type_signature_ner_builder' );
sub _slot_type_signature_ner_builder {

    my $this = shift;

    my %slot_types = %{ $this->abstract_types };

    # update the (neighbor) type signature with the detected type (if any) for the current slot
    my $slot_types_object = $this->parent->original_sequence->object->string_to_types( $this->as_string )->coordinates;

    map { $slot_types{ $_ } += $slot_types_object->{ $_ } } keys( %{ $slot_types_object } );
    
    return new Vector( coordinates => \%slot_types );
    
}

sub type_factor_ner {

    my $this = shift;
    my $target_instance = shift;
    my $string_2 = shift;

    my @type_signatures = ( $this->_slot_type_signature_ner ,
			    $target_instance->string_to_types( $string_2 ) );

    my $type_factor = Vector::cosine( @type_signatures );

    return ( $type_factor , @type_signatures );

}

# type signature
has 'type_signature' => ( is => 'ro' , isa => 'Vector' , init_arg => undef , lazy => 1 , builder => '_type_signature_builder' );
sub _type_signature_builder {
    my $this = shift;
    my $signature = $this->type_signature_freebase( $this->as_string );
    return $signature;
}

sub type_factor_regular {

    my $this = shift;
    my $target_instance = shift;
    my $string_1 = $this->as_string;
    my $string_2 = shift;

    # generate type signatures (vectors)
    my @type_signatures = map { $this->parent->type_signature( $_ ) } ( $string_1 , $string_2 );

    # compute overlap
    my $type_overlap = 0;
    my $n = 0;
    foreach my $type ( keys( %{ $type_signatures[ 0 ]->coordinates } ) ) {
	if ( $type_signatures[ 1 ]->coordinates->{ $type } ) {
	    $type_overlap++;
	}
	$n++;
    }
    my $type_factor = $type_overlap / ( $n ? $n : 1 );

    return ( $type_factor , @type_signatures );

}

memoize( 'candidate_features' );
sub candidate_features {

    my $this = shift;
    my $target_instance = shift;
    my $target_candidate = shift;

    my $score = 0;
    my $surface = $target_candidate;
    
    # TODO : add factor regarding predicted type

    my $is_self_replacement = ( lc( $this->as_string ) eq lc( $target_candidate ) ) ? 1 : 0;
    
    # TODO : add prior for candidate given type => avoid selecting irrelevant instances of the type
    # TODO : one way to approximate this would be to compare neighboring terms in a word embedding ?
    my $factor_morphology = $this->morphological_factor( $this->as_string , $target_candidate );

    # Note : this test is an optimization / constraint (must have some overlapping type)
    # no hard filtering on inactive factors => prevents learning downstream => however having constraints like this would make it equivalent to an ILP decoder
    # Note : the coocurrence constraint guarantees that we consider candidates that are plausible given the text segments observed in the target, the candidates are then prioritized based on their respective value
    # Note : the coocurrence constraint no longer seems necessary if we use dependencies and strong type information ? (ok for dependencies, but maybe additional control will be needed for type-based replacements)
  
    my %factors;

# Note : turned off for now
=pod
    my $factor_cooccurrence = $this->cooccurrence_factor( $target_instance , $target_candidate );
    $factors{ 'cooccurrence' } = $factor_cooccurrence;
=cut

    # TODO : add feature indicating whether the current candidate already appears somewhere else (not this slot) in the summary

    my ( $factor_type , $sequence_type_signature , $target_candidate_type_signature ) = $this->type_factor( $target_instance ,
													    $target_candidate );
    $factor_type = $is_self_replacement ? 1 : $factor_type;
    $factors{ 'type' } = $this->_energy_features ? 1 - $factor_type : $factor_type;
    $factors{ 'morphology' } = $this->_energy_features ? 1 - $factor_morphology : $factor_morphology;
    
    my $target_candidate_surface = $target_instance->most_likely_surface_form( $target_candidate );
    if ( defined( $target_candidate_surface ) ) {
	$surface = $target_candidate_surface;
    }
    else {
	# Note : we now potentially consider replacement that are not originating from the target object
	#$this->logger->debug( "Unable to obtain surface form for : $target_candidate" );
	$target_candidate_surface = $target_candidate;
    }
    # CURRENT : use capitalization of the source word
    my $sequence_surface = $this->as_string;
    # TODO : once freebase is in place, type-entity should become a check for the presence of a freebase id
    my $factor_similarity = $is_self_replacement ? 1 : $this->similarity_factor( $sequence_surface , $target_candidate_surface );

    $factors{ 'word_embedding' } = $this->_energy_features ? 1 - $factor_similarity : $factor_similarity;
    
    # TODO : should this be part of factor_type ?
    my $factor_type_conditional_probability = $this->parent->analyzer->type_conditional_probability( $target_instance , $target_candidate , $target_candidate_type_signature , $sequence_type_signature );
###    $factors{ 'type_conditional' } = $factor_type_conditional_probability;

    # TODO : replace previous/next features with dependency-based features    
    # Note : previous/next token are type indicators but must be combined with a strong semantic/type signal in order to have a positive effect
    my $factor_previous_token = $is_self_replacement ? 1 : $this->previous_token_factor( $target_instance , $target_candidate_surface );
###    $factors{ 'previous-token' } = $factor_previous_token;
    
    my $factor_next_token = $is_self_replacement ? 1 : $this->next_token_factor( $target_instance , $target_candidate_surface );
###    $factors{ 'next-token' } = $factor_next_token;

    # TODO : use ?
    my $factor_slot_compatible = $this->slot_compatible_factor( $target_candidate );

# Note : turned off for now    
=pod
    my $appearance_factors = $this->appearance_factors( $this->parent->original_sequence->object , $this->as_string ,
							$target_instance , $target_candidate );
    map { 
	$factors{ $_ } = $appearance_factors->{ $_ };
    } keys( %{ $appearance_factors } );
=cut
    
    # CURRENT : fully factorized model ? => this will lead to higher likelihood n-grams => no good
    # => weighted approach instead : 0.5 for lm 0.5 for mapping , then mapping as product
    my $filler_candidates = $this->filler_candidates( $target_instance ); 
    my $candidate_weight = $filler_candidates->{ $target_candidate } || 0;
    my $candidates_total_weight = 0;
    map { $candidates_total_weight += $_ } values( $filler_candidates );
    # TODO : in which cases can candidates_total_weight be 0 ?
    my $factor_weight = $candidates_total_weight ? $candidate_weight / $candidates_total_weight : 0;
###    $factors{ 'candidate-weight' } = $factor_weight;
    
    # CURRENT : replace modality_weight and candidate_weight with coocurrence factor
    # NEXT: implement decoding as a graph alignment task

    # TODO : word appears in similar context in the target and reference ? => similar to cooccurence ?
    
    # => candidate_weight is a representation of the term conditional probability given the current object (importance)
    # => score is a representation of the term conditional probability given the current filler (semantic match)
    # => are there cases where these two factors are not sufficient ? (note: in case of ties, these should be solved first inside the score computation)

    # generate all feature combinations
    # TODO : deep learning to achieve this automatically / in a more principled way ?
    $this->combine_features( \%factors );
    
    # TODO : enable trainable/loadable feature weights
    # Note : as much as possible, features (joint features) should be of the *same type* (but maybe orthogonal) => to combine features of different types I should probably separate things into multiple factors (stages for relative importance)
    # Note : we combine factor_type and factor_similarity to avoid a loss of information in cases where no type information is available for the current filler (and the filler type score would default to 1)
    ###$score = 1 * exp( $factor_type + $factor_similarity + $factor_type * $factor_similarity );

    return ( \%factors , $surface );
  
}

sub combine_features {

    my $this = shift;
    my $features = shift;

    # TODO : go beyond ?
    # + $factor_type * $factor_similarity * $factor_previous_token + $factor_type * $factor_similarity * $factor_next_token );

    my @feature_ids = keys( %{ $features } );
    for ( my $i = 0 ; $i <=$#feature_ids ; $i++ ) {
	my $feature_id_i = $feature_ids[ $i ];
	my $feature_id_i_value = $features->{ $feature_id_i };
	for ( my $j = $i + 1 ; $j <= $#feature_ids ; $j++ ) {
	    my $feature_id_j = $feature_ids[ $j ];
	    my $feature_id_j_value = $features->{ $feature_id_j };
	    my $combined_feature_key = join( ':::' , 'combined' , $feature_id_i , $feature_id_j );
	    my $combined_feature_value = $feature_id_i_value * $feature_id_j_value;
	    if ( $combined_feature_value ) {
		$features->{ $combined_feature_key } = $combined_feature_value;
	    }
	}
    }

}

sub similarity_factor {
    my $this = shift;
    my $sequence_surface = shift;
    my $target_candidate_surface = shift;
    my $identical = ( lc( $sequence_surface ) eq lc( $target_candidate_surface ) ) ? 1 : 0;
    my $cosine_similarity = $identical ? 1 : $this->semantic_distance( $sequence_surface , $target_candidate_surface , rescale => 0 );
    my $similarity_factor = ( $cosine_similarity > 0 ) ? $cosine_similarity : 0 ;
    return $similarity_factor;
}

# TODO : coocurrence across multiple slots will lead to a new decoding method
sub cooccurrence_factor {

    my $this = shift;
    my $target_instance = shift;
    my $candidate = shift;

    my $cooccurrence_factor = 0;

    # TODO : create more generic function in UrlData to get term coocurrences ?
    my $candidate_support = $target_instance->supports( $candidate , regex_match => 1 , return_utterances => 1 );
    # TODO : to be removed once this bug has been fixed
    if ( ! defined( $candidate_support ) ) {
	# Note : error message no longer relevant since we are now generating features for candidates that potentially do not appear anywhere in the target data
	#$this->logger->error( "No support for a term that should be supported => to be fixed ..." );
	return 0;
    }
    my @candidate_utterances = @{ $candidate_support->[ 2 ] };
    my $candidate_word_length = scalar( split /\s+/ , $candidate );

    # current slot id
    my $slot_id = $this->id;

# Note : not a good idea for isolated slots
    # determine pre/post portions
    # => find preceding slot
    my $lower = $this->from;
    my $lower_has_supported = 0;
    while ( $lower > $this->parent->from ) {
	if ( $this->parent->is_in_slot( $lower - 1 ) && $lower_has_supported ) {
	    last;
	}
	elsif ( $this->parent->get_status( $lower ) eq $this->parent->status_supported ) {
	    $lower_has_supported++;
	}
	$lower--;
    }

    # => find following slot
    my $upper = $this->to;
    my $upper_has_supported = 0;
    while ( $upper < $this->parent->to ) {
	if ( $this->parent->is_in_slot( $upper + 1 ) && $upper_has_supported ) {
	    last;
	}
	elsif ( $this->parent->get_status( $upper ) eq $this->parent->status_supported ) {
	    $upper_has_supported++;
	}
	$upper++;
    }

    # iterate over reference summary
    for ( my $i = $lower - 1 ; $i <= $upper ; $i++ ) {

	my $current_token;
	if ( $i == $lower - 1 ) {

	    # TODO : clean this up => may be need to abstract out part of the loop into a separate method
	    # Note : we artificially introduce the main entity as the first token in our sequence
	    $current_token = $this->parent->main_entity;

	}
	else {

	    # do not consider the slot fillers
	    #if ( $i >= $this->from && $i <= $this->to ) {
	    if ( $this->parent->is_in_slot( $i ) ) {
		next;
	    }
	    
	    $current_token = $this->parent->original_sequence->object_sequence->[ $i ];
	    if ( $current_token->is_punctuation ||
		 ( ( $this->parent->get_status( $i ) ne $this->parent->status_function ) &&
		   ( $this->parent->get_status( $i ) ne $this->parent->status_supported ) ) ){
		next;
	    }

	}

	my $local_cooccurrence = 0;

	# consider cooccurence between candidate and template token
	my $current_token_support = $target_instance->supports( $current_token , regex_match => 1 , return_utterances => 1 );
	# TODO : to be removed once this bug has been fixed
	if ( ! defined( $current_token_support ) ) {
	    # Note : error message no longer relevant since we are now generating features for candidates that potentially do not appear anywhere in the target data
	    #$this->logger->error( "No support for a term that should be supported => to be fixed ..." );
	    next;
	}
	my @current_token_utterances = @{ $current_token_support->[ 2 ] };
	foreach my $candidate_utterance (@candidate_utterances) {
	    foreach my $current_token_utterance (@current_token_utterances) {
		if ( $candidate_utterance == $current_token_utterance ) {
		    #$local_cooccurrence++;
		    # TODO : weight based on modality weight => remove modality weight above
		    # TODO : how do I get the modality information ?
		    $local_cooccurrence += $candidate_utterance->weight / $candidate_utterance->length;
		}
	    }
	}
	
	# Design principal: feature should be 0 if characteristic of a poor match
#	$cooccurrence_factor += $candidate_word_length * ( 1 + $local_cooccurrence ) / scalar( @current_token_utterances );
	$cooccurrence_factor += $candidate_word_length * $local_cooccurrence / scalar( @current_token_utterances );
	

    }

    return $cooccurrence_factor;

}

# TODO : use this as feature instead ( taken jointly with is_regular ) ? => this is just another characterization of semantic similarity/compatibility
sub slot_compatible_factor {

    my $this = shift;
    my $candidate_filler = shift;

    my @all_hypernyms;

    # Acceptable cases:
    # 1 - replacement is hypernym of current filler => TODO : get all hypernyms ? 1/2/3 levels ?
    foreach my $slot_token ( @{ $this->span_tokens } ) {
	my $slot_token_hypernyms = $slot_token->hypernyms;
	push @all_hypernyms , @{ $slot_token_hypernyms };
	map {
	    if ( $_->id eq lc( $candidate_filler ) ) {
		return 1;
	    }
	} @{ $slot_token_hypernyms };
    }

    # 2 - replacement is hyponym of current filler
    foreach my $slot_token ( @{ $this->span_tokens } ) {
	my $slot_token_hyponyms = $slot_token->hyponyms;
	map {
	    if ( $_->id eq lc( $candidate_filler ) ) {
		return 1;
	    }
	} @{ $slot_token_hyponyms };
    }

    # 3 - replacement is synonym of current filler
    # => note in this case, we may just keep the original filler
    # TODO - improve support

    # 4 - replacement is sibling of current filler (common hypernym)
    my @sibling_tokens;
    foreach my $hypernym (@all_hypernyms) {
	my $hyponyms = $hypernym->hyponyms;
	map {
	    if ( $_->id eq lc( $candidate_filler ) ) {
		return 1;
	    }
	} @{ $hyponyms };
    }

    return 0;

}

__PACKAGE__->meta->make_immutable;

1;

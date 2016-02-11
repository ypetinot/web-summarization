package TargetAdapter::RelevanceModel;

use strict;
use warnings;

use Function::Parameters qw/:strict/;
use List::Util qw/min/;
use Memoize;

use Moose::Role;

# TODO : should we move this functionality to a generic sub-class ?
sub _token_analysis {

    my $this = shift;
    my $reference_object = shift;
    my $token = shift;
    my $reference_specific = shift;

    my $object_support_target = $this->target->supports( $token );
    my $object_support_reference = $reference_object->supports( $token );

    # extractive terms are supported by the reference and not by the target
    # Note : a token can meet the previous two conditions and not appear in reference specific if this token appears in different extractive contexts that individually do not meet the appearance threshold.
    my $is_extractive = ( ( $reference_specific->has_sequence( $token->surface ) ) &&
			  ( ! $object_support_target ) &&
			  ( $object_support_reference ) ) || 0;

    return ( $is_extractive , $object_support_target , $object_support_reference );

}

# encodes probabilistic model for term relevance
method relevance_probability ( $original_sentence , $original_sentence_token , $token = undef ) {

    my $original_sentence_object = $original_sentence->object;

    my ( $is_extractive , $object_support_target , $object_support_reference ) = $self->_token_analysis( $original_sentence_object , $original_sentence_token );

    my $current_supported = $object_support_target;
    my $current_extractive = $is_extractive;

    # P(relevance|input) = P(supported) + ( 1 - P(supported) ) * ( P(extractive) * P(relevant|existing_filler) + (1-P(extractive) * P(abstractive_relevance|object)))
    
    # Alternative model ? => no notion of supported, just extractive vs abstractive ?

    # TODO : is there a way to soften these ? maybe using a neighborhood-based prior ?
    my $_current_supported = min( 1 , $current_supported );
    my $_current_extractive = min( 1 , $current_extractive );
    my $probability_current_extractive = ( 1 - $_current_supported ) * $_current_extractive;

    my $probability_relevant_given_current_filler = ( $probability_current_extractive && defined( $token ) ) ?
	$self->replacement_probability( $original_sentence , $original_sentence_token , $token )
	: 0;

    # We only focus on extraction here => for now (P( abstractive_relevance | object ) = 0 => i.e. we limit ourselves to what's in the original sentence.
    my $probability_abstractive_relevance_given_target = $self->target_relevance( $token );

    # Note : this is a mixture model I believe
    my $relevance_probability = $probability_current_extractive * $probability_relevant_given_current_filler +
	( 1 - $probability_current_extractive ) * $probability_abstractive_relevance_given_target ;
    $self->logger->debug( "relevance probability (" . 
			  $original_sentence_token->surface .
			  ( defined( $token ) ? ( " / " . $token->surface ) : '' ) .
			  ") : $relevance_probability" );

    return $relevance_probability;

 }

sub extractive_probability {

    my $this = shift;
    my $token = shift;

    return ( 1 - $this->term_prior( $token ) );

}

sub replacement_probability {

    # CURRENT : probabilistic factorization ?
    # P(replacement) = P(replacement_supported_target) * P(compatible) 
    # P(replacement_supported_target) is obvious for unigrams, but it also accounts for larger-ngrams => would end up prefering n-grams that appear in the target

    my $this = shift;
    # Note : even though the term-to-term replacement probability may consider the original sentence context, this is distinct from modeling the context in the ILP.
    my $original_sentence = shift;
    my $original_sentence_token = shift;
    my $replacement_token = shift;
    
    my $original_sentence_object = $original_sentence->object;
    
    # 2.1 - generate features for extractive alternative
    my $extractive_alternative_features = $this->extractive_adaptation_feature_generator->generate_features( $original_sentence_object , $original_sentence->raw_string , $original_sentence_token , $replacement_token );
    
# 2.2 - compute cost for each extractive alternative
    # TODO : is there any need to renormalize across all alternative scores for a given original token
    # CURRENT : confirm that substitution probability for Barcelona / [still|costs|either|selling] is wrong
    #           1 => TODO => enforce that n-grams should appear somewhere in the neighborhood (i think Kapils constraints are equivalent to this although there is no notion of fixed position)
    #           2 => yes => model improvements ? => add 'matching_capitalization' feature / other same-ness feature as opposed to just context and hoping for the model to catch up on combinations ?
    #           3 => add dependency labels ? => should be useful to at least prune non-supported sub-trees
    my ( $probability_keep , $probability_substitution ) = @{ $this->_model->predict_probability( feature => $extractive_alternative_features ) };
    
    # 2.2 - set cost associated to pairing => this is a fixed weight
    # Note : the indicators imply substitution
    # Note : the prior of the original sentence token could be applied here as well
    my $replacement_probability = $probability_substitution * ( 1 - $this->term_prior( $replacement_token ) );
    $this->logger->debug( "replacement probability (" . join( " / " , map { $_->surface } ( $original_sentence_token , $replacement_token ) ) . ") : $replacement_probability" );
    
    return $replacement_probability;
    
}

sub target_relevance {

    my $this = shift;
    my $token = shift;

    my $probability_abstractive_relevance_given_target = 0;
    return $probability_abstractive_relevance_given_target;

}

sub term_prior {

    my $this = shift;
    my $token = shift;

    # TODO : the prior should certainly be defined in terms of the neighborhood / or maybe a weighted average between the full corpus and the neighborhood
    # TODO : add functionality to the Token package
    my $token_length = $token->word_length;
    my $token_appearance_count = $this->global_data->global_count( 'summary' , $token_length , $token->surface );

    # TODO : this is the number of training summaries => needs to be acquired properly
    my $global_reference_count = 1173510;
    
    my $term_prior = min( 1 , $token_appearance_count / $global_reference_count );
    
    return $term_prior;

}

1;

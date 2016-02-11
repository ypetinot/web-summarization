package TargetAligner::WordDistance;

use strict;
use warnings;

use Service::NLP::Word2Vec;

use Function::Parameters qw/:strict/;
use List::Util qw/max min/;
use Text::Levenshtein::XS qw/distance/;

use Moose::Role;

# TODO : move to a role ? that role could also handle caching of whatever underlying data service is used => parameter that enables caching
has '_word2vec_client' => ( is => 'ro' , isa => 'Service::NLP::Word2Vec' , init_arg => undef , lazy => 1 , builder => '_word2vec_client_builder' );
sub _word2vec_client_builder {
    my $this = shift;
    return new Service::NLP::Word2Vec;
}

method semantic_distance( $token_1 , $token_2 , :$rescale = 1 ) {

    #return $this->_word2vec_client->distance( $token_1 , $token_2 );

    my $cosine_similarity = $self->_word2vec_client->cosine_similarity( $token_1 , $token_2 );

    # Note : this implementation implies that non-correlated and anti-correlated terms are treated in the same way => right now I think this is ok, but might need to revisit this assumption
    my $cosine_similarity_rescale = 0.5;

    # TODO : clean this up ?
    #return $rescale ? 1 - max( 0 , $cosine_similarity_rescale * $cosine_similarity ) : $cosine_similarity ;
    return $rescale ? ( abs( $cosine_similarity - 1 ) / 2 ) : $cosine_similarity ;

}

# TODO : this really belongs in the token class
sub _is_number {
    my $this = shift;
    my $token = shift;
    return ( $token =~ m/^\d+(?:.*\d+)?/ ) || 0;
}

# morphological factor => close to 1 for probable replacement, close to 0 othewise
sub morphological_factor {

    my $this = shift;
    my $token_1 = shift;
    my $token_2 = shift;

    my $token_1_length = length( $token_1 );
    my $token_2_length = length( $token_2 );

    # TODO : would there be a way to still work with Token objects here ?
    my $token_1_is_number = $this->_is_number( $token_1 );
    my $token_2_is_number = $this->_is_number( $token_2 );

    my $morphological_factor = 1;
    my $max_length = max( $token_1_length , $token_2_length );

    if ( ! $token_1_length || ! $token_2_length ) {
	# default (maximum) edit distance
    }
    else {
	$morphological_factor *= min( $token_1_length , $token_2_length ) / $max_length;
    }

    if ( ( $token_1_is_number || $token_2_is_number ) && ( ! ( $token_1_is_number && $token_2_is_number ) ) ) {
	# Note : the edit distance between two numbers is 0 (are there other special cases we should address here ?)
	$morphological_factor = 0;
    }
    else {
	$morphological_factor *= exp( - distance( $token_1 , $token_2 ) );
    }

    return $morphological_factor;

}

# appearance factor
sub appearance_factor {
    my $this = shift;
    my $object_1 = shift;
    my $token_1 = shift;
    my $object_2 = shift;
    my $token_2 = shift;

    # 1 - appearance vector for target object
    my $target_object_appearance_vector = $this->_appearance_vector( $object_1 , $token_1 );

    # 2 - appearance vector for reference object
    my $reference_object_appearance_vector = $this->_appearance_vector( $object_2 , $token_2 );

    # 3 - compute cosine of appearance vectors
    my $appearance_factor = 1 - Vector::cosine( $reference_object_appearance_vector , $target_object_appearance_vector );

    return $appearance_factor;

}

# cost function
sub cost_function {

    my $this = shift;
    my $object_1 = shift;
    my $token_1 = shift;
    my $object_2 = shift;
    my $token_2 = shift;

    $this->logger->info( "Call to cost function for : $token_1 / $token_2" );
    
    my $morphology_factor = $this->morphological_factor( $token_1 , $token_2 );
    my $morphology_factor_weight = 0.1;
    
    my $contextual_factor = 1 - Vector::cosine( $object_1->vectorized_context( $token_1 ) , $object_2->vectorized_context( $token_2 ) );
    my $contextual_factor_weight = 0.1;
    
    # TODO : for each modality, the average position of the term in utterances ...
    # TODO : ... to the capitilization and punctuation pattern surrounding these terms => how can we implement this ?
    # TODO : should we only consider tokens that do not overlap ? -> i.e. cluster unsupported tokens that have a surface representation that is over 75% similar ?
    
    my $semantic_factor = $this->semantic_distance( $token_1 , $token_2 );
    my $semantic_factor_weight = 0.6;
    
    my $modality_appearance_factor = $this->appearance_factor( $object_1 , $token_1 , $object_2 , $token_2 );
    my $modality_appearance_factor_weight = 0.1;
    
    my $syntactic_factor = 1;
    my $syntactic_factor_weight = 0;
    
    my $token_1_global_count = $this->global_data->global_count( 'summary' , 1 , $token_1 );
    my $token_2_global_count = $this->global_data->global_count( 'summary' , 1 , $token_2 );
    my $frequency_factor = ( $token_1_global_count || $token_2_global_count ) ? abs( $token_1_global_count - $token_2_global_count ) / ( max( $token_1_global_count , $token_2_global_count ) ) : 1;
    my $frequency_factor_weight = 0.1;
    
    my $cost = ( $morphology_factor_weight * $morphology_factor ) +
	( $semantic_factor_weight * $semantic_factor ) +
	( $modality_appearance_factor_weight * $modality_appearance_factor ) +
	( $contextual_factor_weight * $contextual_factor ) +
	( $frequency_factor_weight * $frequency_factor ) +
	( $syntactic_factor_weight * $syntactic_factor ) ;

    $this->logger->info( "Done with cost function for : $token_1 / $token_2 / $cost" );
    
    return $cost;
    
}

1;

package TargetAdapter::Extractive::FeatureGenerator;

use strict;
use warnings;

use Category::UrlData;
use Web::Summarizer::Token;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::FeatureMapper' );
with( 'DMOZ' );
with( 'TargetAligner::WordDistance' );

# features should be binarized
has 'binarize' => ( is => 'ro' , isa => 'Bool' , default => '0' );

sub _reference_summary_context_features {

    my $this = shift;
    my $reference_summary = shift;
    my $from_token = shift;
    my $extractive_token = shift;

    my %features;

    my $previous_token = undef;
    if ( $reference_summary =~ m/(\w+)\s*$from_token/ ) {
	$previous_token = $1;
    }
    else {
	$previous_token = '<s>';
    }

    my $leading_bigram = join( " " , $previous_token , $extractive_token );
    $features{ 'reference-summary-leading-bigram-known' } = $this->global_data->global_count( 'summary' , 2 , $leading_bigram ); 

    my $next_token = undef;
    if ( $reference_summary =~ m/$from_token\s*(\w+)/ ) {
	$next_token = $1;
    }
    else {
	$next_token = '</s>';
    }

    my $trailing_bigram = join( " " , $extractive_token , $next_token );
    $features{ 'reference-summary-trailing-bigram-known' } = $this->global_data->global_count( 'summary' , 2 , $trailing_bigram );

    my $adapted_trigram = join( " " , $previous_token , $extractive_token , $next_token );
    $features{ 'reference-summary-adapted-trigram-known' } = $this->global_data->global_count( 'summary' , 3 , $adapted_trigram );

    # CURRENT : potential feature : 'does extractive term already appears in summary' => if this was the case the term would not be extractive => if this issue occurs, check token matching ?

    return \%features;

}

sub _source_replacement_features {

    my $this = shift;
    my $from_token = shift;
    my $to_token = shift;

    my $from_token_surface = $from_token->surface;
    my $to_token_surface = $to_token->surface;

    my %features;

    # token overlap features
    my $morphological_factor = $this->morphological_factor( $from_token_surface , $to_token_surface );
    _numeric_to_binary_features( \%features , 'morphological-similarity' , 0 , 1 , 0.1 , $morphological_factor );

    # semantic similarity
    # TODO : shouldn't the is_numeric tests be handled by WordDistance::semantic_distance ?
    my $semantic_similarity = ( $from_token->is_numeric || $to_token->is_numeric ) ? 0 : $this->semantic_distance( $from_token_surface , $to_token_surface , rescale => 0 );
    _numeric_to_binary_features( \%features , 'semantic-similarity' , -1 , 1 , 0.25 , $semantic_similarity );

    return \%features;

}

sub _numeric_to_binary_features {

    my $output_features = shift;
    my $feature_base = shift;
    my $numeric_from = shift;
    my $numeric_to = shift;
    my $step = shift;
    my $original_value = shift;

    my $n_steps = ( $numeric_to - $numeric_from ) / $step;

    my $step_low = $numeric_from;
    for ( my $i = 1 ; $i <= $n_steps ; $i++ ) {
	my $step_high = $i * $step;
	if ( $original_value >= $step_low && $original_value < $step_high  ) {
	    my $feature_key = join( '-' , $feature_base , $i );
	    $output_features->{ $feature_key } = 1;
	}
	$step_low = $step_high;
    }

}

sub _combine_features {

    my $features = shift;

    my %combined_features;
    my @feature_keys = keys( %{ $features } );

    for ( my $i=0; $i<=$#feature_keys; $i++ ) {
	my $feature_key_i = $feature_keys[ $i ];
	my $feature_value_i = $features->{ $feature_key_i };
	for ( my $j=0; $j<$i; $j++ ) {
	    my $feature_key_j = $feature_keys[ $j ];
	    my $feature_value_j = $features->{ $feature_key_j };
	    my $combined_feature_key = join( "::" , 'joint' , $feature_key_i , $feature_key_j );
	    $combined_features{ $combined_feature_key } = $feature_value_i * $feature_value_j;
	}
    }

    return \%combined_features;

}

sub _add_features {

    my $this = shift;
    my $output_features = shift;
    my $features = shift;

    my $binarize = $this->binarize;

    map {
	my $feature_key_raw = $_;
	if ( ! defined( $this->_feature2id->{ $feature_key_raw } ) ) {
	    $this->_feature2id->{ $feature_key_raw } = $this->inc_feature_counter;
	}
	my $feature_key_mapped = $this->_feature2id->{ $feature_key_raw };

	$output_features->{ $feature_key_mapped } = $binarize ? 1 : $features->{ $_ };
    }
    grep {
	$features->{ $_ };
    } keys( %{ $features } );

}

method generate_features ( $current_instance , $summary , $from_token , $extractive_token_object ) {

    my %features;
    
    # page/object features
    # generate token features => must be contextual only since this is an extraction task
    # => feature generation should be attached to Token object ? => yes
    my $contextual_features = $extractive_token_object->features( $current_instance , context => 1 , binary => 1 );
    $self->_add_features( \%features , $contextual_features );

    # reference summary context features
    my $reference_summary_context_features = $self->_reference_summary_context_features( $summary , $from_token , $extractive_token_object );
    $self->_add_features( \%features , $reference_summary_context_features );
    
    # source-replacement features
    my $source_replacement_features = $self->_source_replacement_features( $from_token , $extractive_token_object );
    $self->_add_features( \%features , $source_replacement_features );

# CURRENT : generate heavy contention on NFS mount ?
    # syntax features
    # TODO : add more , e.g. sub-tree appearance features
    my $pos_features = $extractive_token_object->features( $current_instance , syntax => 1 , binary => 1 );
    $self->_add_features( \%features , $pos_features );
    
    # corpus features
    # TODO : summary corpus position features    
    my $corpus_features = $extractive_token_object->features( $current_instance , corpus => 1 , binary => 1 );
    $self->_add_features( \%features , $corpus_features );
    
    # CURRENT : add feature for category of the reference object ? => only meaningfull if we also add the similarity with the target as another feature ?
    # TODO : add modality similarities as features
    
    # combine all available features
    $self->_add_features( \%features , _combine_features( \%features ) );
    
    return \%features;
   
}

__PACKAGE__->meta->make_immutable;

1;

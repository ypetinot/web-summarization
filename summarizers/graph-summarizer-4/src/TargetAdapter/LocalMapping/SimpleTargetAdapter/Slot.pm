package TargetAdapter::LocalMapping::SimpleTargetAdapter::Slot;

# TODO : allow recursive slots => treat as tree ?

use strict;
use warnings;

use Vector;
use Web::Summarizer::FeaturizedToken;

use Carp::Assert;
use Function::Parameters qw/:strict/;
use JSON;

use Moose;
use namespace::autoclean;

with( 'Logger' );
with( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::Span' );
with( 'TargetAligner::WordDistance' );
#with( 'TargetAdapter::LocalMapping::TrainedTargetAdapter::TrainableSlot' );

has '_energy_features' => ( is => 'ro' , isa => 'Num' , default => 1 );

# optimize computations (should not be one during training time ?)
has 'do_optimize' => ( is => 'ro' , isa => 'Bool' , default => 1 );

# replacement probability only ?
has 'replacement_probability_only' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# visualization mode
has 'visualization_mode' => ( is => 'ro' , isa => 'Bool' , default => 0 );

# parent adaptable sequence ( => i.e. no hierarchical structure )
has 'parent' => ( is => 'ro' , isa => 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptableSequence' , required => 1 );

# id
has 'id' => ( is => 'ro' , isa => 'Num' , required => 1 );

# key
# TODO : rename / obtain from a different source
has 'key' => ( is => 'ro' , isa => 'Str' , required => 1 );

# abstract types
has 'abstract_types' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_abstract_types_builder' );
sub _abstract_types_builder {
    my $this = shift;
    my %slot_types;
    map { $slot_types{ $_ }++ } grep { $_ } map { $_->abstract_type } grep { ! $_->is_punctuation } map { $this->parent->original_sequence->object_sequence->[ $_ ] } @{ $this->_range_sequence };
    return \%slot_types;
}

has 'slot_type' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_type_builder' );
sub _type_builder {
    my $this = shift;
    return join( '|' , keys( %{ $this->abstract_types } ) );
}

has 'has_abstract_types' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , lazy => 1 , builder => '_has_abstract_types_builder' );
sub _has_abstract_types_builder {
    my $this = shift;
    my $abstract_types_count = scalar( keys( %{ $this->abstract_types } ) );
    return ( $abstract_types_count > 0 );
}

# is slot expected to hold regular words ?
sub is_regular {

    my $this = shift;
    my $filler = shift;

    my $signature = defined( $filler ) ? $this->parent->type_signature( $filler ) : $this->type_signature;

    # check if one of the types is a wordnet hypernym => this is an approximation obviously
    my $is_regular = scalar( grep { m/\#/si } keys( %{ $signature->coordinates } ) );
    return $is_regular;

}

# TODO : require that is a token is filler, the previous token must be a regular token (i.e. not a slot) => ILP-like
has 'previous_token' => ( is => 'ro' , isa => 'Web::Summarizer::Token' , init_arg => undef , lazy => 1 , builder => '_previous_token_builder' );
sub _previous_token_builder {

    my $this = shift;
    my $from = $this->from;
    if ( $from ) {
	# Note : assumes we don't have neighboring slots, which should be enforced
	return $this->parent->original_sequence->object_sequence->[ $from - 1 ];
    }
    return new Web::Summarizer::Token( surface => $this->parent->start_node );
}

has 'next_token' => ( is => 'ro' , isa => 'Web::Summarizer::Token' , init_arg => undef , lazy => 1 , builder => '_next_token_builder' );
sub _next_token_builder {

    my $this = shift;
    my $to = $this->to;
    if ( $to < $this->parent->to ) {
	# Note : assumes we don't have neighboring slots, which should be enforced
	return $this->parent->original_sequence->object_sequence->[ $to + 1 ];
    }
    return new Web::Summarizer::Token( surface => $this->parent->end_node );
}

# TODO : find better field name ?
has 'span_tokens' => ( is => 'ro' , isa => 'ArrayRef' , init_arg => undef , lazy => 1 , builder => '_span_tokens_builder' );
sub _span_tokens_builder {
    my $this = shift;
    my @tokens = map { $this->parent->original_sequence->object_sequence->[ $_ ] } @{ $this->_range_sequence };
    return \@tokens;
}

# TODO : is storing instance-specific information in the slot the right thing to do ?
# Note : builder to be provided by sub-class
#has '_filler_candidates' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_filler_candidates_builder' );
has '_filler_candidates' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );
sub filler_candidates {
    my $this = shift;
    my $target_instance = shift;
    my $target_instance_id = $target_instance->id;
    if ( ! defined( $this->_filler_candidates->{ $target_instance_id } ) ) {
	$this->_filler_candidates->{ $target_instance_id } = $this->_filler_candidates_builder( $target_instance );
    }
    return $this->_filler_candidates->{ $target_instance_id };
}

# TODO : promote to a generic package => this is nothing more than a Jaccard coefficient
sub _compute_overlap {
    my $this = shift;
    my $set_1 = shift;
    my $set_2 = shift;

    my @vectors = map {
	
	my $set = $_;

	my %coordinates;
	foreach my $set_element (@{ $set }) {	
	    $coordinates{ $set_element }++;
	}
	
	new Vector( coordinates => \%coordinates );

    } ( $set_1 , $set_2 );

    return Vector::jaccard( @vectors );

}

has 'allow_compression' => ( is => 'ro' , isa => 'Bool' , init_arg => undef , lazy => 1 , builder => '_allow_compression_builder' );
sub _allow_compression_builder {
    return 1;
}

sub _compatible_with_type {

    my $this = shift;
    my $type = shift;

    return 1;

}

sub _component_id_builder {
    my $this = shift;
    return $this->parent->component_id;
}

# Note : its ok to have this piece of information as a field since the slot is tied to the original instance
has 'current_filler_prior' => ( is => 'ro' , isa => 'Num', init_arg => undef , lazy => 1 , builder => '_current_filler_prior_builder' );
sub _current_filler_prior_builder {
    my $this = shift;
    my $sequence = $this->key;
    return $this->neighborhood->neighborhood_density->{ $sequence } || 0;
}

# Note : the concept of weights probably belongs in a subclass => ParameterizedSlot ?
has 'weights' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_weights_builder' );
sub _weights_builder {
    return {};
}

has 'weight_default' => ( is => 'ro' , isa => 'Num' , init_arg => undef , lazy => 1 , builder => '_weight_default_builder' );
sub _weight_default_builder {
    my $this = shift;
    return 1;
}

# TODO : should be renamed to "compute_energy" ?
method compute_score ( $features , :$weights ) {

    my $score = 0;

    foreach my $feature_key ( keys( %{ $features } ) ) {
	my $feature_value = $features->{ $feature_key } || 0 ;
	my $feature_weight = $weights->{ $feature_key } || $self->weight_default ;
	if ( $feature_value && $feature_weight ) {
	    $score += $feature_weight * $feature_value ;
	}
    }

    # Note : score is really an energy => return unnormalized probability
    return exp ( - $score );

}

=pod
method compute_partition {

    

}

method compute_probability {


}
=cut

method generate_options ( $target_instance , :$weights = undef ) {

    my $use_weights = defined( $weights );

    # CURRENT : slot has a prior
    # TODO : write this equation in the thesis
    # 0 - where/when do I get the original filler ? => key
    # 1 - current filler is kept with probability equal to its prior
    # 2 - candidate replacements split the remaining probability mass based on their condition distribution given the current filler

    my @options;

    # CURRENT : put all the candidates in the same bag and normalize probabilities over this common bag => this might be too strong an assumption
    my $score_partition = 0;
    my $score_max = 0;

    # CURRENT : provide both the key and original surface form as needed
    my $sequence = $self->key;
    my $sequence_length = length( $sequence );

    my $has_ground_truth = $target_instance->has_field( 'summary' , namespace => 'dmoz' );

    my $slot_surface = undef;
    my $slot_surface_confidence = 0;
    
    ## Note : this is equivalent to a uniform kernel ?
    # CURRENT : is it fair to exclude the reference object ?
    my $current_filler_prior = $self->current_filler_prior;

    # probability of the current location being a slot
    # TODO : this should an object field
    my $slot_probability = 1 - $current_filler_prior;

    # CURRENT : set of candidates based on type compatibility. If no type then consider all candidates
    # TODO : learn mapping/correlation between signature and summary terms => reduced space, should be manageable

    # Note : if the prior is less than 1 (not really a slot then) we estimate P(replacement=w|replaceable) (conditional distribution over replacement candidates given that the location is replaceable)
    if ( $current_filler_prior < 1 ) {

	my %filler_candidates = %{ $self->filler_candidates( $target_instance ) };
	my @target_candidates = keys( %filler_candidates );

	# Note : always consider the current filler as a potential candidate ?
	if ( !defined( $filler_candidates{ $sequence } ) ) {
	    push @target_candidates , $sequence;
	}

	if ( ! $use_weights ) {
	    $weights = $self->weights;
	}

	my %candidate_2_score;
      candidate_scan: foreach my $target_candidate (@target_candidates) {
	  
	  # ignore candidate if it appears in the original sequence at a diffent location => isn't this a salient issue ?
	  # Note : at the very least, this only apply to alternate replacements, not to the original filler which could (and sometimes does) appear multiple times
	  if ( $target_candidate ne $sequence ) {

	      for ( my $i = 0 ; $i < $self->parent->original_sequence->length; $i++ ) {
		  
		  # Note : it is ok to consider the refilling of the slot by its current filler => Bayesian view on the template/slot structure
		  if ( $i >= $self->from && $i <= $self->to ) {
		      next;
		  }
		  
		  my $current_token = $self->parent->original_sequence->object_sequence->[ $i ];
		  if ( $current_token->id eq $target_candidate ) {
		      next candidate_scan;
		  }
	      }

	  }
	  
	  if ( defined( $candidate_2_score{ $target_candidate } ) ) {
	      next;
	  }
	  
	  my ( $score_salience , $stats_salience ) = $self->factor_salience( $target_instance , $target_candidate );
	  if ( $self->do_optimize && ! $score_salience ) {
	      next;
	  }

	  # Note : fitness scores are in general more expensive to compute
	  # Note : we're passing $target_instance only to get type information about the candidate => should this be avoided ?
	  # TODO : candidate_score should really take a set of features as input parameter ?
	  my ( $features , $target_candidate_surface ) = $self->candidate_features( $target_instance , $target_candidate );

	  # TODO : clean this up
	  # **** CURRENT **** : it doesn't seem legit to confound the salience score/feature with semantic-oriented features
#	  $features->{ 'salience' } = $self->_energy_features ? ( 1 / ( 1 + $score_salience ) ) : $score_salience;

	  my $score_fitness = $self->compute_score( $features , weights => $weights );
	  
	  # TODO : optimize computation => which one is the most expensive to compute generally ?
	  # TODO : the salience score should become a precomputed factor in the factor graph model
          my $score = $score_fitness * $score_salience;
#	  my $score = $score_fitness;
	  
	  if ( $score ) {
	      
	      $candidate_2_score{ $target_candidate } = $score;
	      $score_partition += $score;		
	      if ( $score > $score_max ) {
		  $score_max = $score;
	      }
	      push @options , [ new Web::Summarizer::FeaturizedToken( surface => $target_candidate_surface || $target_candidate , abstract_type => $self->slot_type , features => $features ) , $score , $features ];
	      
	  }

	  $self->logger->debug( join( "\t" , $target_instance->url , $self->parent->original_sequence->object->url , $sequence , $target_candidate , encode_json( $features || {} ) , $score_fitness , $score_salience , $score ) );

      }
	
	# TODO ? => No type available for <$sequence> => recursing ?
	# normalize scores/probabilities
	if ( $score_partition ) {
	    
	    map {
		
		# p_abst is the abstracitve prior => prior of appearance among abstractive terms
		# p( appear at position ) = p_abst + ( 1 - p_abst ) * p( replacement at position )
		
		# replacement candidate under consideration
		# TODO : can we do better than using the Token id ?
		my $replacement_candidate = $_->[ 0 ]->id;
		
		# CURRENT : make sure to combine replacement_factor and salience factor here and then normalize
		my $slot_replacement_probability = $_->[ 1 ] / $score_partition;
		
		# templatedness/abstractiveness of the term
		# => a term that appears in some cases in abstractive => appearance prior would be in a medium range
		# => a term that appears only in its associated object is extractive => appearance prior would be close to 0
		
		# TODO : should we go for something cleaner ?
		$_->[ 1 ] = ( 1 - $current_filler_prior ) * $slot_replacement_probability;;
		
	    } @options;
	    
	}
	
    }
    
    # Note : it is necessary to have the SLOT option for removal purposes in cases where multiple slot may be mapped to a single filler, in which case only one of them will be successfully filled.
    # TODO : can we preserve the original token information ?
    # CURRENT : set probability to 0 but maybe it should be set by the appearance model ? => can only be done a posteriori though
    # TODO : discount fraction of templatic probability ?
    if ( $self->allow_compression ) {
	push @options , [ new Web::Summarizer::FeaturizedToken( surface => join( '_' , 'SLOT' , $self->id ) , features => {} ) , 0 , {} ];
    }
    
    if ( $self->visualization_mode ) {
	my $max_options = 5;
	if ( scalar( @options ) > $max_options ) {
	    my @sorted_options = sort { $b->[ 1 ] <=> $a->[ 1 ] } @options;
	    splice @sorted_options , $max_options;
	    @options = @sorted_options;
	}
    }
    
    # CURRENT : combine conditional replacement probability with non-replacement probability
    if ( ! $self->allow_compression || $current_filler_prior ) {
	
	# TODO : get the actual surface form
	my $current_filler_surface = $self->key;
	
	my $current_filler_option = undef;
	foreach my $option (@options) {
	    if ( lc ( $option->[ 0 ]->surface ) eq lc ( $current_filler_surface ) ) {
		$current_filler_option = $option;
		last;
	    }
	}
	
	if ( ! defined( $current_filler_option ) ) {
	    $current_filler_option = [ new Web::Summarizer::FeaturizedToken( surface => $current_filler_surface , features => {} ) , 0 ];
	    push @options , $current_filler_option;
	}
	$current_filler_option->[ 1 ] += $current_filler_prior;
	
    }

    # CURRENT/TODO : fix segmentation , e.g. Horndon on the Hill
    
    affirm {
	my $probability_mass = 0;
	map { $probability_mass += $_->[ 1 ] } @options;
	( $probability_mass - 1 ) < 0.0000001;
    } "Total probability mass must be equal to 1" if DEBUG;

    my @sorted_options = sort { $b->[ 1 ] <=> $a->[ 1 ] } @options;
    if ( ! $use_weights ) {
	$self->logger->debug( "Best replacement option for $sequence: " . join( ' / ' , $sorted_options[ 0 ]->[ 0 ]->surface , $sorted_options[ 0 ]->[ 1 ] ) );
    }
    
    # CURRENT : soft application of type factor ?
    return \@sorted_options;

    # CURRENT/TODO : flag to force a specific capitalixation form ?
    # TODO : always prefer neighborhood capitalization form, then the form that is prevalent in the target object

}

=pod
# generate transformed forms of this slot based on available type information
# TODO : should this function recurse on itself => I would tend to think so (?)
sub process {

    # CURRENT : put all the candidates in the same bag and normalize probabilities over this common bag => this might be too strong an assumption

    # 1 - get predicted types for the current sequence
    # TODO : does it make sense to have to turn off the normalize flag ?
    my $sequence_types = $this->parent->reference_specific->get_types( $sequence , normalize => 0 );

    if ( $sequence_types ) {

	my %candidate_2_score;
	foreach my $sequence_type (@{ $sequence_types }) {

	    # make sure type is compatible with slot
	    if ( ! $this->_compatible_with_type( $sequence_type ) ) {
		next;
	    }
	    
	    # TODO : add prior for candidate given type => avoid selecting irrelevant instances of the type
	    
###		my $next_token = ( $original_extractive_span_to < $n_tokens - 1 ) ? $original_sentence->object_sequence->[ $original_extractive_span_to + 1 ]->surface : undef;
		    #$original_span_type_prior * $type_candidate_type_prior *
#		    $this->_pos_factor( \@predicted_pos , $type_candidate ) *
#		    $this->_corpus_factor( $original_extractive_span , $previous_token , $type_candidate , $next_token );

		$score_partition += $score;

	    }
	    
	}

# Note : this is no longer necessary since we rely on probabilistic decoding to make the selection
#=pod	
#	# sort candidates by decreasing type overlap
#	my @sorted_candidates = sort { $candidate_2_score{ $b } <=> $candidate_2_score{ $a } } keys( %candidate_2_score );
#
#	if ( $#sorted_candidates >= 0 ) {
#	    $slot_surface = $sorted_candidates[ 0 ];
#	    $slot_surface_confidence = $candidate_2_score{ $slot_surface } / ( $score_partition || 1 );
#	}
#	else {
#
#	    my $count_pre = $this->global_data->global_count( 'summary' , 2 , $string_pre );
#	    my $count_skipping = $this->global_data->global_count( 'summary' , 2 , $string_skipping );
#
#	    # Note : probability of relevant if the slot is not filled
#	    $slot_surface_confidence = $count_pre ? $count_skipping / $count_pre : 0;
#
#	}
#=cut

    }
    else {

	$this->logger->debug( "No type available for <$sequence> - recursing ..." );

	die "To be fixed";

	# identify sub-sequence that is reference specific
	$this->seek_and_adapt_wrapper;

    }

}
=cut

# TODO : this should probably rely on a core functionality in StringSequence
method as_string ( :$remove_punctuation = 0 ) {

    my @tokens = map { $_->surface } grep { !$remove_punctuation || !$_->is_puncutation } map {
	$self->parent->original_sequence->object_sequence->[ $_ ];
    } @{ $self->_range_sequence };

    my $string = join( " " , @tokens );
    return $string;

}

# TODO : should we be doing something more refined - e.g. return collection of original tokens ( "TokenCollection" class would extend Token ) ?
sub as_token {
    my $this = shift;
    return new Web::Summarizer::Token( surface => $this->as_string );
}

# CURRENT : abstractive prior used to weight the contribution of the replacement model
# p_abst is the abstracitve prior => prior of appearance among abstractive terms
# p( appear at position ) = p_abst + ( 1 - p_abst ) * p( replacement at position )
# if replacement of itself => 1 ? or 0 ?
method filler_probability ( $filler , :$slot_probability , :$slot_replacement_probability ) {

    if ( $self->replacement_probability_only ) {
	return $slot_replacement_probability;
    }

    my $option_probability = $slot_probability * $slot_replacement_probability;
    return $option_probability;

}

# TODO : do salience features belong here ? No if the slot is to be fully trained.
# determines salience of a candidate filler
# TODO : salience factor => is independent from the neighborhood / target-specific ~ proportion of modalities where candidate appears as initial estimate (refine probability mass allocation within a given level multi-modality appearance) => return score as a structure ?
sub factor_salience {

    # TODO : the minimum frequence requirements - which currently are implemented in the _target_candidates might belong here ?
    # => Still I don't think simply making salience proportional to raw frequency is a good idea

    # TODO : add style information ( bolded / h1 / linkified => number of times styled in content vs not-styled )

    my $this = shift;
    my $target_instance = shift;
    my $target_candidate = shift;

    my $total_appearances = 0;
    my $total_modality_appearances = 0;
    foreach my $modality ( $target_instance->url_modality , $target_instance->title_modality , $target_instance->content_modality , $target_instance->anchortext_modality ) {
	my $modality_appearance_count = $modality->supports( $target_candidate , regex_match => 1 ) || 0;
	$total_appearances += $modality_appearance_count;
	$total_modality_appearances += ( $total_appearances ? 1 : 0 );
    }

=pod
    my $factor_appears_in_url = $target_instance->url_modality->supports( $target_candidate , regex_match => 1 )? 1 : 0;
    push @factors , [ 'candidate-appears-in-url' , $factor_appears_in_url , 1 ];
    
    my $factor_appears_in_title = $target_instance->title_modality->supports( $target_candidate , regex_match => 1 ) ? 1 : 0;
    push @factors , [ 'candidate-appears-in-title' , $factor_appears_in_title , 1 ];
    
    my $factor_appears_in_content = $target_instance->content_modality->supports( $target_candidate , regex_match => 1 ) ? 1 : 0;
    push @factors , [ 'candidate-appears-in-content' , $factor_appears_in_content , 1 ];
    
    my $factor_appears_in_anchortext = $target_instance->anchortext_modality->supports( $target_candidate , regex_match => 1 ) ? 1 : 0;
    push @factors , [ 'candidate-appears-in-anchortext' , $factor_appears_in_anchortext , 1 ];
    
    my $modality_weight = $factor_appears_in_title + $factor_appears_in_url + $factor_appears_in_content + $factor_appears_in_anchortext;

    # Note : another option would be to stratify weights: produce salience scores at different levels of modality appearance
    # CURRENT : raw frequency boost can only work if types are strongly compatible => how do we capture this ?
    my $factor_salience = $target_instance->supports( $target_candidate , regex_match => 1 ) ** $modality_weight;
=cut

    #my $factor_salience = $modality_weight / 4;
    #my $factor_salience = $total_appearances ** $total_modality_appearances;
    # TODO : should we break this score into individual features ?
    # Note : for adaptation we are promoting target-specific attributes : frequent in target and infrequent in neighborhood
    # TODO : neighborhood frequency should take into account arbitrary support here to avoid terms that are frequent in objects but do not appear in summaries
    # TODO : include corpus salience factor ?
    # TODO : include factor for the appearance of the term in the original summary (this is not yet a joint optimization of slots, but close)
    # TODO : reintroduce co-occurrence factor

# CURRENT : not working
=pod
    # Note : back off to neighborhood for slots that are not originally supported by the associated object (abstractive terms)
    #my $slot_filler_support = $this->parent->original_sequence->object->supports( $this->key , regex_match => 1 );
    my $slot_filler_support = $this->parent->target->supports( $this->key );
    my $factor_salience = $slot_filler_support ? $total_modality_appearances / ( 1 + ( $this->neighborhood->prior( $target_candidate , all_modalities => 1 ) || 0 ) ) :
	( $this->neighborhood->neighborhood_density->{ $target_candidate } || 0 );
=cut

    my $factor_salience = $total_modality_appearances / ( 1 + ( $this->neighborhood->prior( $target_candidate , all_modalities => 1 ) || 0 ) );

    # TODO : visual salience ? give more weight to URL and Title modalities ?

    # TODO : turn this into a distributional similarity factor => move back to similarity factor
    #$factor_salience *= $this->cooccurrence_factor( $target_candidate );

    return $factor_salience;

    # Note : cooccurrence is a good filter but may not be a good indicator in terms of similarity

}

__PACKAGE__->meta->make_immutable;

# TODO : to be removed ?
=pod
	  if ( $has_ground_truth ) {
	      
	      # CURRENT : replace filler with target candidate and see if lcs increases ?
	      # => weak signal but valid if there is only one slot in the refeference summary
	      my @transformed_summary_sequence;
	      if ( $this->from > 0 ) {
		  push @transformed_summary_sequence , map { $this->parent->original_sequence->[ $_ ]->id } ( 0 .. ( $this->from - 1 ) );
	      }
	      push @transformed_summary_sequence , lc( $target_candidate );
	      if ( $this->to < $this->parent->to ) {
		  push @transformed_summary_sequence , map { $this->parent->original_sequence->[ $_ ]->id } ( $this->to .. $this->parent->to );
	      }
	      
	      my $ground_truth_modality = $target_instance->summary_modality;
	      my $ground_truth_summary = $ground_truth_modality->utterance;
	      my $transformed_lcs = $ground_truth_summary->lcs_similarity( \@transformed_summary_sequence , normalize => 1 , keep_punctuation => 0 ); 
	      my $reference_lcs = $ground_truth_summary->lcs_similarity( $this->parent->original_sequence , normalize => 1 , keep_punctuation => 0 );
	      my $ground_truth = ( $reference_lcs < $transformed_lcs ) ? 1 : 0;
	      
	      # determine appearance for the selected filler
	      # TODO : check if this would be any better ?
	      #my $ground_truth = $ground_truth_modality->supports( $target_candidate , regex_match => 1 ) ? 1 : 0;
	      
	  }
=cut

1;

package SentenceEnergy;

# Handles sentence construction ?

# Word-graph is only here to guide transitions now

use Moose;
with('ServiceClient');

# 1 - implement sentence energy
# Sentence energy: count n-grams (order: 1 ... 4) that appear in target data / vs / count n-grams that do not appear in target data  (all weighted by number of supporting modalities)
sub sentence_energy {

    my $this = shift;
    my $target_object = shift;
    my $sentence = shift;
    my $target_ngrams = shift;
    my $max_ngram_order = shift || 3;

    my @buffer;
    my $buffer_length = 0;

    my %ngrams;

    # TODO: can the energy diff be computed with recomputing everything ?
    my $sentence_length = scalar( @{ $sentence } );
    for (my $index=0; $index<$sentence_length; $index++) {

	# 1 - update n-gram window
	push @buffer, $sentence->[ $index ];
	$buffer_length++;
	if ( ( $buffer_length > $max_ngram_order) || ( $index + $buffer_length - 1 >= $sentence_length ) ) {
	    shift @buffer;
	    $buffer_length--;
	}

	# 2 - update n-gram counts
	my $ngram_string = '';
	for (my $i=0; $i<$buffer_length; $i++) {
	    $ngram_string .= $buffer[ $i ];
	    $ngrams{ $i }{ $ngram_string }++;
	}

    }

    # compute unnormalized sentence energy
    my $unnormalized_sentence_energy = 1;
    foreach my $ngram_order (keys( %ngrams )) {

	my $target_ngram_order_data = $target_ngrams->{ $ngram_order };

	foreach my $ngram (keys( %{ $ngrams{ $ngram_order} } )) {

	    # check for presence / absence of n-grams in target object (weighted by number of modalities in which they appear)

	    # 1 - modality appearance count
	    my $modality_appearance_count = $target_ngram_order_data->{ $ngram };

	    # 2 - update unnormalized energy
	    $unnormalized_sentence_energy *= pow( 2 , $modality_appearance_count - 1 ); 

	}

    }

    # compute normalized sentence energy
    my $normalized_sentence_energy = $unnormalized_sentence_energy / $sentence_length;

    return $normalized_sentence_energy;

}

sub compute_energy {

    my $this = shift;
    my $data_extractor = shift;
    my $target_object = shift;
    my $sequence = shift;

    my @sequence_tokens = map { $_->surface() } @{ $sequence };

    # 1 - compute energy given target object
    my $energy_given_target = $this->compute_energy_given_target( $data_extractor , $target_object , $sequence , \@sequence_tokens );

    # 2 - compute energy given corpus (and target)
    my $energy_given_corpus_and_target = $this->compute_energy_given_corpus( $sequence , \@sequence_tokens );

    # 3 - compute energy
    my $energy = $energy_given_target + $energy_given_corpus_and_target;

    return $energy;

}

sub compute_energy_given_target {

    my $this = shift;
    my $data_extractor = shift;
    my $target_object = shift;
    my $sequence = shift;
    my $sequence_tokens = shift;

    my $energy_given_target = 0;

    my $sequence_length = scalar( @{ $sequence } );

    my @modality_definitions = @{ $data_extractor->modalities()->modalities_ngrams() };

    # n-gram contributions
    foreach my $modality_definition (@modality_definitions) {

	my $modality = $modality_definition->[ 0 ];
	my $modality_preprocessing = $modality_definition->[ 2 ];
	my $modality_energy_given_target = 0;

	foreach my $n_gram_order (1,2,3) {
	    
	    my $modality_ngram_energy_given_target = 0;
	    my $modality_ngram_weight = 1;
	    
	    my ( $target_ngram_field , $target_ngram_field_mapping ) = $target_object->get_field( $modality , $modality_preprocessing , 1 );
	    
	    my @ngram_buffer;
	    for (my $i=0; $i<$sequence_length; $i++) {
		
		push @ngram_buffer, $sequence_tokens->[ $i ];

		if ( scalar( @ngram_buffer ) < $n_gram_order ) {
		    next;
		}

		my $raw_ngram = join( " " , @ngram_buffer );
		my $mapped_ngram = $target_ngram_field_mapping->{ $raw_ngram };
		if ( $mapped_ngram ) {
		    $modality_ngram_energy_given_target += $target_ngram_field->{ $mapped_ngram } || 0;
		}

	    }

	    $modality_energy_given_target += $modality_ngram_weight * $modality_ngram_energy_given_target;
	    
	}

	$energy_given_target += $modality_energy_given_target;

    }

    # additional contributions ?
    # syntax ?

    return $energy_given_target;

}

sub compute_energy_given_corpus {

    my $this = shift;
    my $sequence = shift;
    my $sequence_tokens = shift;

    my $energy_given_corpus_and_target = 0;
    
    # TODO: this is an approximation for now
    # we rank the sequence terms by decreasing genericity and discard the 20% most specific terms (to allow for the inclusion of specific terms, i.e. slot-like behavior)

    my $sequence_length = scalar( @{ $sequence } );

    my %sequence_terms_2_data;
    map { $sequence_terms_2_data{ $_ } = $this->request( 'get_word_entry' , [ $_ ] ) } @{ $sequence_tokens };

    my @sorted_sequence_terms = sort {
	$sequence_terms_2_data{ $b }->{ 'tf' } <=> $sequence_terms_2_data{ $a }->{ 'tf' }
    } keys( %sequence_terms_2_data );

    my $sequence_reference_length = int( 0.2 * $sequence_length );
    splice( @sorted_sequence_terms , $sequence_reference_length );

    foreach my $sequence_term (@sorted_sequence_terms) {

	my $sequence_term_genericity = $sequence_terms_2_data{ $sequence_term }->{ 'tf' };
	$energy_given_corpus_and_target += 1 / $sequence_term_genericity;

    }

    return $energy_given_corpus_and_target;

}

no Moose;

1;

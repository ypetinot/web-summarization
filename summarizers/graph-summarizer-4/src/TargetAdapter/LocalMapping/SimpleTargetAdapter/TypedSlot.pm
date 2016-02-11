package TargetAdapter::LocalMapping::SimpleTargetAdapter::TypedSlot;

use strict;
use warnings;

use Vector;

use Function::Parameters qw/:strict/;
use List::MoreUtils qw/uniq/;

use Moose;
use namespace::autoclean;

# TODO : what would it take to inherit from Slot instead ?
extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::WordEmbeddingSlot' );

# CURRENT : Entity slot ?

# Note : the problem with hard filtering is that this may lead to the absence of refilling candidates => would hurt the performance of non-compressive systems => deactivated until I get compression to work consistently.
# Note : better to work on improving the set of refilling candidates
=pod
# TODO : to be removed ? => reintroducing for typed slots as we seem to still have a lot noi
# => we now handle types using a scoring/feature-based approach => no hard filtering (filtering is on frequency only ?)
sub type_compatible {
    
    my $this = shift;
    my $candidate_type = shift;

    # Note: specific type detection by NER component is dubious
    # if we have a type, the candidate type must match ?
    if ( defined( $candidate_type ) && $this->has_abstract_types ) {
	# TODO : reprocess / post-process named entities to determine specific types ?
	return defined( $this->abstract_types->{ $candidate_type } ) || ( $candidate_type eq 'MISC' );
    }

    return 1;

}
=cut

=pod
sub _filler_candidates_builder {
    
    # 1 - determine slot type
    my @slot_types = grep { defined( $_ ) && length( $_ ) } map {
	$this->parent->original_sequence->object_sequence->[ $_ ]->abstract_type
    } @{ $this->_range_sequence };

    my %filler_candidates;
    foreach my $slot_type (@slot_types) {
	my $type_candidates = $target_instance->named_entities->{ $slot_type };
	map {
	    $filler_candidates{ $_ } = $type_candidates->{ $_ };
	} grep { $type_candidates->{ $_ } > 0 } keys( %{ $type_candidates } );
    }

}
=cut

=pod
sub type_factor {

    my $this = shift;
    my $string_1 = shift;
    my $string_2 = shift;

    my $target_named_entities = $target_instance->named_entities;

    # TODO : remove duplication with ScanningAdaptableSequence
    my %_slot_signature;
    my @slot_types = keys( %{ $this->abstract_types } );
    my $target_has_compatible_instance = 0;
    foreach my $slot_type (@slot_types) {
	$_slot_signature{ $slot_type }++;
	if ( defined( $target_named_entities->{ $slot_type } ) ) {
	    $target_has_compatible_instance++;
	}
    }

    my $string_1_signature = new Vector( coordinates => \%_slot_signature );

    my %_candidate_signature;
    foreach my $named_entity_type (keys( %{ $target_named_entities } )) {
	if ( defined( $target_named_entities->{ $named_entity_type }->{ $string_2 } ) ) {
	    $_candidate_signature{ $named_entity_type }++;
	}
    }
    my $string_2_signature = new Vector( coordinates => \%_candidate_signature );

    my $type_factor = Vector::cosine( $string_1_signature , $string_2_signature );

    return ( $type_factor , $string_1_signature , $string_2_signature );

}
=cut

# TODO : minimize noise => only high quality candidates should be preserved
# TODO : activate different processing depending on whether slot can be associated with a type
# The raw set of candidates is based on the pairwise comparison between the reference and the target (filtering ?)
# To this we add type compatible entities extracted from the target
# TODO : minimum_modality_appearance is to be used only for compression purposes, not to identify potential candidates
method target_candidates ( $target_instance , :$length_frequence_filtering = 0 , :$minimum_modality_appearance = 0 ) {

    # TODO : entity entailment => if I know this entity appears => transfer weight to associated entities ? => required strong entity identification (or maybe search ?)

# Note : this seems too restrictive => reintroduce later if needed
    my @filter_terms;
=pod
    my @filter_terms = grep { ! $_->is_punctuation }
    map { $self->parent->original_sequence->object_sequence->[ $_ ] }
    grep {
	$self->parent->get_status( $_ ) eq $self->parent->status_supported;
    } ( $self->parent->from .. $self->parent->to );
=cut

    my @target_entities;

    # CURRENT : define per-type appearance prior entire neighborhood => use as non-smoothed prior to filter out type outliers

    # marking extractive slot =>
    # 1 => named entity => lookup predicted cluster and get list of candidates
    # 2 => not named entity => lookup type and search for equivalent type in target
    # these are fundamentally the same approach, the question is how much confidence to we need to assign a type ?

    # neighborhood type signature
    my $neighborhood_type_signature = $self->parent->neighborhood->type_priors;

    # 1 - collect candidates using the result of mirrored analysis
    # Note : if the slot type is not ambiguous then we can use the type signature to get a good estimate on replacement confidence
    # TODO : on the other hand, an ambiguous slot type will probably lead to more noise unless we can find a good solution to estimate the posterior type distribution
    my $is_slot_type_ambiguous = ( scalar( @{ $self->parent->original_sequence->object_sequence->[ $self->from ]->_entity_ids } ) > 1 ) ? 1 : 0;
    if ( ! $is_slot_type_ambiguous ) {

	my $_target_specific_sequences = $self->parent->target_specific->raw_sequences;
	foreach my $target_specific_sequence (keys( %{ $_target_specific_sequences } )) {
	    
=pod
	    # 1 - make sure there is some type overlap with th current slot
	    my $target_specific_sequence_signature = $self->type_signature_freebase( $target_specific_sequence );
=cut
	    
# Note : too aggressive, frequency-based filtering is a better idea - leave it up to the slot filling algorithm to handle type-based filtering
#	    my $overlap = Vector::cosine( $self->type_signature , $target_specific_sequence_signature );
	    my $overlap = ( $_target_specific_sequences->{ $target_specific_sequence } > 1 );
	    if ( $overlap ) {
		push @target_entities , $target_specific_sequence;
	    }
	    
	}

    }

    # 2 - collect candidates using the raw predicted type for this slot
    my $_target_named_entities = $target_instance->named_entities;
    foreach my $named_entity_type (keys( %{ $_target_named_entities } )) {
	
	# Note : check if type is compatible with this slot
	if ( ! $self->type_compatible( $named_entity_type ) ) {
	    next;
	}

	push @target_entities , keys( %{ $_target_named_entities->{ $named_entity_type } } );

    }

    # 3 - URL string segmentation
    # TODO : url regexes can be stored ( in UrlModality ? )
    my @url_tokens = grep { length( $_ ) } map { split /[:.\/]/ } ( $target_instance->uri->host , $target_instance->uri->path );
    foreach my $url_token (@url_tokens) {
	# => resegment each URL token => how => then treat resegmented token as single entity => (only if entity lookup is a match ?)
	# OR : custom named entities builder ?
	my $url_token_regex_string = join( '\W*' , split // , $url_token );
	my $url_token_regex = qr/(?:^|\W)($url_token_regex_string)(?:\W|$)/asi;
	my $content = $target_instance->content_modality->content; 
	# TODO : apply to segments instead
	while ( $content =~ m/$url_token_regex/g ) {
	    # TODO : check whether this corresponds to a known entity => only if this introduces too much noise
	    push @target_entities , $1;
	}
    }
    
    # Note : segment as little as possible and instead try to combine while maximizing overlap (how ?)
    my %target_candidates;
    map {

	# TODO : turn threshold into parameter
	# TODO : make frequency available as candidate prior
	my $_candidate = $_;
	# TODO : is there a better way ?
	my @_candidate_tokens = grep { length( $_ ) && ( $_ !~ m/\p{PosixPunct}+/ ) } split /\s+/ , $_candidate;
	my $_candidate_word_length = scalar( @_candidate_tokens );

	if ( $_candidate_word_length ) {
	    
	    my $ok = 1;

	    foreach my $filter_term (@filter_terms) {
		my $term_regex = $filter_term->create_regex( plurals => 1 );
		if ( $_candidate =~ $term_regex ) {
		    $ok = 0;
		    last;
		}
	    }

            # Note : for performance reasons it is probably preferable to have this here - also takes care of basic noise filtering
	    my $target_appearance_count = ( $_candidate_word_length > 1 ) ? $target_instance->supports( $_candidate , regex_match => 1 ) : $target_instance->supports( $_candidate ) ;

	    # Note : the purpose here to is to filter out noise early on - this seems reasonable but is this too aggressive ? Filtering on modality frequency would definitely be too aggressive.
	    if ( $target_appearance_count < 2 ) {
		$ok = 0;
	    }

=pod
	    # length/frequency filtering => necessary unless we have a very strong type/semantic compability model
	    # otherwise long/infrequent strings tend to score high (issue with compositionality ?)
	    elsif ( $length_frequence_filtering && ( $target_appearance_count <= $_candidate_word_length ) ) {
		$ok = 0;
	    }
	    elsif ( $target_instance->supports( $_candidate ) && $self->parent->original_sequence->object->supports( $_candidate ) ) {
		# TODO : maybe this is a bit too harsh, check for support and significance instead
		$ok = 0;
	    }
=cut
	    
	    # CURRENT : name of the site/host should the first thing I check
	    
	    if ( $ok ) {
		
		# count of the full sequence
		# TODO : is it absolutely necessary given that we are not going to us this to compute features ?
		my $target_appearance_count = ( $_candidate_word_length > 1 ) ? $target_instance->supports( $_candidate , regex_match => 1 ) : $target_instance->supports( $_candidate ) ;
		$target_candidates{ $_candidate } += $target_appearance_count;

# Note : this probably introduces too much noise and potentially segments set phrases
=pod
		# also consider count of unigrams (any reason to also do all variations ?)
		if ( $_candidate_word_length > 1 ) {
		    map {
			# we only consider terms that tend to appear on their own / in different settings
			# Note : a lower threshold might be useful for abstractive slot filling, but one possibility would be to obtain candidates by going in the opposite direction (how ?)
			#if ( $target_instance->supports( $_ ) > 2 * $target_appearance_count ) {
			if ( $target_instance->supports( $_ ) > $target_appearance_count ) {
			    $target_candidates{ $_->surface } += $target_appearance_count
			}
		    } grep { ! $_->is_punctuation } map { ref( $_ ) ? $_ : new Web::Summarizer::Token( surface => $_ ) } @_candidate_tokens;
		}
=cut
		
	    }
	    
	}

    }
    grep {
 	( ! $minimum_modality_appearance ) || ( $self->_modality_appearance_count( $_ ) >= $minimum_modality_appearance );
    }
    uniq
    @target_entities;

    return \%target_candidates;

}

__PACKAGE__->meta->make_immutable;

1;

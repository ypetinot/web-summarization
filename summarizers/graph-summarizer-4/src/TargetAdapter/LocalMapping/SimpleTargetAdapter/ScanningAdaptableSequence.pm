package TargetAdapter::LocalMapping::SimpleTargetAdapter::ScanningAdaptableSequence;

use strict;
use warnings;

use Carp::Assert;
use List::MoreUtils qw/uniq/;
use List::Util qw/max min/;
use Memoize;

use Moose;
use namespace::autoclean;

extends( 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AdaptableSequence' );
with( 'Freebase' );

has 'slot_class_abstractive' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_slot_class_abstractive_builder' );
sub _slot_class_abstractive_builder {
    return 'TargetAdapter::LocalMapping::SimpleTargetAdapter::AbstractiveSlot';
}

has 'slot_class_extractive_regular' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_slot_class_extractive_regular_builder' );
sub _slot_class_extractive_regular_builder {
    return 'TargetAdapter::LocalMapping::SimpleTargetAdapter::RegularSlot';
}

has 'slot_class_extractive_typed' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_slot_class_extractive_typed_builder' );
sub _slot_class_extractive_typed_builder {
    return 'TargetAdapter::LocalMapping::SimpleTargetAdapter::TypedSlot';
}

has 'slot_class_noop' => ( is => 'ro' , isa => 'Str' , init_arg => undef , lazy => 1 , builder => '_slot_class_noop_builder' );
sub _slot_class_noop_builder {
    return 'TargetAdapter::LocalMapping::SimpleTargetAdapter::NoopSlot';
}

# perform slot optimization ?
has 'do_slot_optimization' => ( is => 'ro' , isa => 'Bool' , default => 0 );

memoize( 'type_signature' );
sub type_signature {

    my $this = shift;
    my $string = shift;

    my @types;

    my $string_types = $this->analyzer->detect_types( $string );
    if ( ! scalar( @{ $string_types } ) ) {

	my @string_components = split /\s+/ , $string;
	if ( $#string_components > 0 ) {
	    foreach my $string_component (@string_components) {
		my $component_types = $this->analyzer->detect_types( $string_component );
		if ( scalar( @{ $component_types } ) ) {
		    push @types , @{ $component_types };
		}
	    }
	}

    }
    else {
	@types = @{ $string_types };
    }

    my %signature_coordinates;

    # Note : not using uniq here would favor multi-word strings with repeated types
    map { $signature_coordinates{ $_ }++; } uniq @types;

    return new Vector( coordinates => \%signature_coordinates );

}

sub has_types {
    my $this = shift;
    my $string = shift;
    my $type_signature = $this->type_signature( $string );
    return $type_signature->norm ? 1 : 0;
}

sub get_original_token {
    my $this = shift;
    my $index = shift;
    my $index_status = $this->get_status( $index );
    my $slot_object = $this->_slots->{ $index_status };
    return $slot_object ? $slot_object->as_token : $this->original_sequence->object_sequence->[ $index ];
}

# CURRENT : generate all possible n-grams FROM reference summary and look for longest matches IN reference specific tokens
my $SLOT_MARKER_EXTRACTIVE="__EXTR__";
my $SLOT_MARKER_ABSTRACTIVE="__ABST__";
sub seek_and_adapt_wrapper {

    my $this = shift;

    # CURRENT : how to better identify slots in the reference summary => rely exclusively on prior ?
    # TODO => once these n-grams have been identified => treat as slot and adapt recursively

    my $from = $this->from;
    my $to = $this->to;

    # preliminary pass on tokens
    for ( my $i = $from ; $i <= $to ; $i++ ) {

	my $current_token = $this->original_sequence->object_sequence->[ $i ];

	if ( $current_token->is_punctuation ) {
	    # Note : punctuation allows to limit the potential for extention of slots
	    $this->mark_function( $i , $i );
	}
	# Note : connectors are part of the backbone => they *cannot* be slots
	elsif ( $this->original_sequence->is_connector( $i ) ||
		$current_token->pos eq 'DT' ||
		$current_token->pos eq 'MD' ||
		$current_token->pos =~ m/^VB/ ||
		$current_token->pos eq 'IN' # prevents tokens like 'from' from becoming slots
	    ) {
	    $this->mark_function( $i , $i );
	}
	else {

	    # TODO : allow functions terms to be dropped why supported terms cannot be dropped ?
	    my $target_utterances = $this->target->supports( $current_token , regex_match => ( $current_token->word_length > 1 ) );
	    my $reference_support = $this->original_sequence->object->supports( $current_token , regex_match => 1 );
	    # CURRENT : accuracy of anchortext extraction ? => restrict to basic anchortext ?
	    # CURRENT : should set an (modality)  occurrence threshold on the target side
	    
	    # CURRENT : supported == at least two distinct modality occurrences ? => alternatively we could use "templatic" terms as our basis for extension ? The goal is to have "something" persistent to get template dependencies from
	    # Golden:0 Tornado:1 men:s 's:s official:2 site:3 .:f => should naturally lead to men being replaced by women

	    # => this probably isn't something we need to pay attention
	    #if ( $target_utterances && $reference_support ) {
	    
	    # TODO : remove redundancy with determine_status
	    my $token_prior = $this->span_prior( $this->component_index( $i , -1 ) , $this->component_index( $i , -1 ) );

	    # TODO : create a "templatic" status ?
	    
	}
	
    }
    
    $this->logger->info( "Initial template: " . $this->status_as_string );
    
    # Note : current n-gram order
    # Note : we start with the full sequence => if it's a match, perfect !

    # TODO : reintroduce in order to detect the presence of (untyped) set phrases ?
    #my $current_order = 1;
    my $current_order = $this->length;

    while ( $current_order > 0 ) {
	
	my $current_order_bound = ( $to - ( $current_order - 1 ) );
	for ( my $i = $from ; $i <= $current_order_bound ; $i++ ) {
	    
	    my $current_token = $this->original_sequence->object_sequence->[ $i ];

	    # skip if the current location is controlled already
	    if ( $this->is_controlled( $i ) ) {
		next;
	    }

	    my $ngram_from = $i;
	    my $ngram_to = $ngram_from;
	    while ( ( $ngram_to < ( $i + ( $current_order - 1 ) ) ) && ! $this->is_controlled( $ngram_to + 1 ) ) {
		$ngram_to++;
	    }

	    affirm { $ngram_to <= $to } "n-gram end must be within bounds: $ngram_from / $ngram_to / $current_order_bound /// [ $from , $to ]" if DEBUG;
	    
	    # generate current reference summary n-gram
	    my @reference_summary_ngram = map { $this->original_sequence->object_sequence->[ $_ ] }
	    ( $ngram_from .. $ngram_to );
	    
	    # determine n-gram status
	    my $reference_summary_ngram_status = $this->determine_status(
		$ngram_from,
		$ngram_to,
		$this->target ,
		$this->original_sequence->object ,
		\@reference_summary_ngram );

	    if ( $reference_summary_ngram_status eq $this->status_function ) {
		$this->mark_status( $ngram_from , $ngram_to , $reference_summary_ngram_status );
		next;
	    }
	    elsif ( $reference_summary_ngram_status eq $this->status_abstractive ) {
		$this->mark_status( $ngram_from , $ngram_to , $reference_summary_ngram_status );
		next;
	    }
	    elsif ( $reference_summary_ngram_status eq $this->status_supported ) {
		# mark status as supported
		$this->mark_supported( $ngram_from , $ngram_to );
		next;
	    }
	    elsif ( $reference_summary_ngram_status eq $this->status_reference_specific ) {
		# this will become a slot ..
	    }
	    else {
		# TODO : should we be doing something here ?
		# we move forward
		next;
	    }

	    # CURRENT : isn't the preliminary pass removing the possibility of of detecting longer target-specific sequences ? in particular if we were to include function words ?

	    my $sequence = join( " " , map { $_->surface } @reference_summary_ngram );
	    # Note : at this point we are dealing with a reference-specific summary n-gram	
	    $this->logger->debug( "Found match for <$current_order/$sequence> : $ngram_from -- $ngram_to" );
	    my $slot = $this->mark_slot( $ngram_from , $ngram_to , $SLOT_MARKER_EXTRACTIVE );
	    
	}

	# moving to lower order
	$current_order--;
	
    }

    my %surface2regular;
    for ( my $i = $from ; $i <= $to ; $i++ ) {
	
	my $current_token = $this->original_sequence->object_sequence->[ $i ];
	
	if ( !$this->is_controlled( $i ) ) {
	    
	    if ( $current_token->abstract_type ) {
		# default to an extractive slot if a type has been assigned to this token
		$this->mark_slot( $i , $i , $SLOT_MARKER_EXTRACTIVE );
	    }
	    else {
		# TODO : this should be a soft assignment (or at least handled in a stochastic way)
		#$this->mark_status( $i , $i , $this->status_abstractive );
		$this->mark_slot( $i , $i , $SLOT_MARKER_ABSTRACTIVE );
	    }
	    
	}
	
	# Note : keep track of the surface form of regular nodes
	if ( ! $this->is_in_slot( $i ) ) {
	    $surface2regular{ $current_token->id } = $this->get_status( $i );
	}
	
    }
	
    $this->logger->info( "Raw template: " . $this->status_as_string );
    
    # post-scan to create slots
    for ( my $i = $from ; $i <= $to ; $i++ ) {

	my $current_token = $this->original_sequence->object_sequence->[ $i ];
	my $current_status = $this->get_status( $i );

	# skip if the current location is not assigned to a slot location
	if ( ! $this->is_in_slot( $i ) ) {
	    next;

	}
	elsif ( defined( $surface2regular{ $current_token->id } ) ) {

	    # Note: there exists at least one other location with the same surface that is not in a slot

	    # 1 - unregister this location
	    $this->mark_status( $i , $i , $surface2regular{ $current_token->id } );

	    # 2 - move on
	    next;

	}

	my $current_slot_id = $current_status;
	my $current_slot_type = $this->get_slot_at( $i );
	my $current_slot_entity = undef;

	# keep going until ...
	# TODO : only merge slots if their fillers have the same abstract type ?
	my $start = $i;
	while ( $this->is_in_slot( $i ) && ( $this->get_status( $i ) == $current_slot_id ) ) {
	    $i++;
	}
	my $end = $i;

	# Note : this could belong in a lower level component but since we rely on function tokens to allow extensions, this seems to fit here
	# Note : this allows recursive processing of the slot, e.g. in cases where we can't find a good candidate for the longer version of the entity ?
	# TODO : find most specific type
	if ( $this->do_slot_optimization ) {

	    # TODO : increment right away
	    my $optimized_end = $end;

	    # CURRENT : start from base and consider all extensions ?
	    # allow matches that include function tokens => if so this goes in scanning adaptable sequence

	    # Note : no longer seems pertinent if using dependencies
	    # => even for adjacent slots, e.g. : mapping "green panda" to "red dog" is probably easier when considering green/red and panda/dog separately

	    while ( ( $optimized_end <= $to ) && (
			( $this->is_in_slot( $optimized_end ) || $this->_status->[ $optimized_end ] eq $this->status_function ) ) ) {
		# TODO : check if we are on a different slot, if so reassign
		
		if ( $optimized_end == $to || 
		     ( $this->is_in_slot( $optimized_end + 1 ) && ( $this->get_slot_at( $optimized_end + 1 ) ne $current_slot_type ) ) ) {
		    last;
		}

		# CURRENT/TODO : require knowledge-base confirmation
		my $optimized_slot_entities = $this->map_string_to_entities( $this->original_substring( $start , $optimized_end ) );
		if ( $optimized_slot_entities ) {
		    # we have found a "built-in" entity => update slot
		    $current_slot_entity = $optimized_slot_entities;
		    $end = $optimized_end;
		}

		$optimized_end++;
		
	    }
	    
	    # go back as needed
	    # TODO : remove $end > $to
	    while ( ( $end > $to ) || ( ! $this->is_in_slot( $end ) ) ) {
		$end--;
	    }
	    $i = $end;

	    $this->logger->debug( "Optimized slot: $start <--> $end" );
	    
	}

	my @slot_tokens = grep { ! $_->is_punctuation } map { $this->original_sequence->object_sequence->[ $_ ] } uniq ( $start .. $end );
	my $key = join( " " , map { $_->id } @slot_tokens );

	# create slot
	# Note: ultimately there should not be slot types, since we are aiming that can be dynamically fitted to any kind of slot location and adjust to the location's characteristics (typed vs. abstractive, etc.)
	my $slot_id = $current_slot_id;
	# Note : using Freebase types here would mean that concepts are now treated as named entities => is this what we want ?
	##my $slot_typed = scalar( grep { $_->abstract_type } @slot_tokens ) || $current_slot_entity;
	my $slot_typed = scalar( grep { $_->abstract_type } @slot_tokens );
	my $slot_reference_supported = $this->original_sequence->object->supports( $key , regex_match => 1 );
	my $slot_target_supported = $this->target->supports( $key , regex_match => 1 );

	# Note : it's not typed vs. not-typed, it's entity vs. not-entity
	# CURRENT : entity vs. not-entity => how do I know that Warriors is a typed location ? => if it has types, this is different from being unambiguously typed 
	# TODO : learning paradigm/model that is stratified ? i.e. considers the semantic equivalency/compatibility of features and doesn't attempt to mix features that are incompatible ? => products as opposted to sums ?
	my $slot_class = undef;
	if ( $slot_target_supported ) {

	    # We will rely on object-based salience

	    if ( $slot_typed ) {		
		# Use entity candidates
		$slot_class = $this->slot_class_extractive_typed;
###		$slot_class = $this->slot_class_noop;
	    }
	    else {
		# Use regular candidates
		# target_supported => mirrored analysis (likely to be a regular word - if it isn't we are able to self refill)
##	    $slot_class = $this->slot_class_abstractive;
		# Note : the reason for this is that if the term is supported, we can use object salience as an indicator of its importance
		$slot_class = $this->slot_class_extractive_regular;
##		$slot_class = $this->slot_class_noop;
	    }

	}
	else {

	    # We will rely on neighborhood-based salience
	    my $neighborhood_prior = $this->neighborhood->neighborhood_density->{ $key } || 0;

	    if ( $slot_typed && !$neighborhood_prior ) {
		# this is most likely a named entity and we need to treat this as an extractive slot
		$slot_class = $this->slot_class_extractive_typed;
	    }
	    elsif ( $slot_typed && $neighborhood_prior ) {
		# TRICKY => what is the behavior *if* it is a named entity ?
		# unsupported without type => mirrored analysis (unlikely to be an entity)
		$slot_class = $this->slot_class_abstractive;
		# => salience of the current filler should not be 0
###		$slot_class = $this->slot_class_noop;
	    }
	    elsif ( !$slot_typed && !$neighborhood_prior ) {
		# regular ? => here we want to use candidates that are strictly siblings of the current filler
#		$slot_class = $this->slot_class_extractive_regular
		$slot_class = $this->slot_class_noop;
	    }
	    else { # !$slot_typed && $neighborhood_prior
#		$slot_class = $this->slot_class_abstractive;
		$slot_class = $this->slot_class_noop;
	    }

	}

	# CURRENT : when can the salience of the current filler be 0 ?

	# previous : ( $slot_typed || ( $current_slot_type eq $SLOT_MARKER_EXTRACTIVE ) ? $this->slot_class_extractive : $this->slot_class_abstractive ) ,
	# ( $current_slot_type eq $SLOT_MARKER_EXTRACTIVE ) ?
	# ( $slot_typed ? $this->slot_class_extractive_typed : $this->slot_class_extractive )
	# : $this->slot_class_abstractive ,
	# TODO : special slots for numbers / dates ?
	my $slot_object = $this->create_slot ( from => $start , to => $end , slot_class => $slot_class , key => $key , id => $slot_id );
	
    }

    # /2
    # CURRENT/TODO : adjacent slots that have projective dependencies (?) can be confounded into single slot ? => only if a filler cannot be found for the whole thing => recursive processing ?
    # => how would this work for "contact information" => "information" ?
 
    # /2
    # CURRENT/TODO : if the elements of a slot are fully supported by the target, but not next to each other, in which conditions can we consider the filler to be actually supported by the target ?
    # => how would this work for "A League" => "Area" ?

    # TODO:
    # 2 - proper way to combine word-embedding vectors for unknown multi-word phrases ?

    $this->logger->info( "Final template: " . $this->status_as_string );

    # Note : for cases where the set of candidates/replacement scoring is not optimal, use a Noop slot

    # CURRENT : learning model
    # => if we assume the current slot is valid for all members of the neighborhood => we can try to fit each slot function individually => supervision comes in the form of ...
    # ===> similarity between the slot fillers ? => how do we measure/validate similarity ?
    # ===> effect of substitution on summaries => energy of the cluster corresponds to the fully connected "network" energy that results from mapping filler_a with filler_b in summary_b => can be evluated easily, simply run the refilling process with the same reference but multiple targets
    # TODO : in order to produce the factor graph, I need to have all the slot features precomputed for all target instancess and all candidates (should not be a problem => make sure slot identification is *not* target specific

    # => fit model (how expensive would this be) ?
    # => test model

    return $this->status_as_string;

}

sub determine_status {

    my $this = shift;
    my $index_from = shift;
    my $index_to = shift;
    my $target_object = shift;
    my $reference_object = shift;
    my $ngram = shift;

    # 1 - map ngram to regex => we use the Token infrastructure
    my @selected_tokens = grep { ! $_->is_punctuation } @{ $ngram };
    my $ngram_string = join( " " , map { $_->surface } @selected_tokens );

    if ( length( $ngram_string ) ) {

	my $ngram_token = new Web::Summarizer::Token( surface => $ngram_string );       
	my $target_support = $this->_determine_object_support( $target_object , $ngram_token );
	my $reference_support = $this->_determine_object_support( $this->original_sequence->object , $ngram_token );

	# TODO : better encapsulation for component logic
	my $ngram_string_prior = $this->span_prior(
	    $this->component_index( $index_from , -1 ),
	    $this->component_index( $index_to , -1 ) );

	# TODO : clean up around here

	# TODO : this is probably redundant now
	if ( $target_support && $reference_support && $ngram_string_prior >= 0.5 ) {
	    # TODO : create new status for this case
	    return $this->status_supported;
	}

	# TODO : what is the meaning of this ?
	# 2 - check target support
	if ( $target_support && $ngram_string_prior >= 0.5 ) {
	    return $this->status_supported;
	}
	
	# CURRENT: does this belong here ?
	if ( $ngram_token->word_length == 1 ) {
	    
	    # Note: dependency connectors => status_function
	    if ( $this->original_sequence->is_connector( $index_from ) ) {
		return $this->status_function;
	    }

	    # TODO : we also need to introduce a probability over the templatic status of tokens
	    if ( $ngram_string_prior == 1 ) {
		return $this->status_function;
	    }

	}

	# CURRENT : prior => determines how likely the word is to be part of the template (i.e. not to be replaced)
	# What is the full matrix of cases we can consider for non-support terms ?
	# typed vs non-typed / extractive vs abstractive / what else ?

	# => extractive is not uniquely decided by the appearance on the reference page => whether the filler is typed is also an element of decision
	# => original filler has probability = prior (ok)
	# => supported => probability of appearance given appearance in target => this leads to a hard backbone ? how do we deal w/ aboutness issues ?
	# => abstracted => probability of appearance
	# => isn't appearance in target just a feature ?
	# => abstractive behavior is independent from neighborhood prior
	# => no notion of abstractive/extractive but instead types
	# => e.g. DET => find all determinants in target
	# => e.g. ADJ => find all determinants in target
	# ...
	# => in any case there must exist some minimal type indication otherwise we have no way to maintain a reasonable list of options
	# => binary decision for each location (random field ?) while maintaining dependency tree
	# compute confidence of replacement (affected by prior) => optimize decision function locally ?
	# => revisit abstraction later on if needed
	# TODO : jointly traing compression and scoring function to maximize target metric => training can be done locally

	# 3 - check reference support and neighborhood prior
	# TODO : these conditions could be further softened but should already be good indicators of reference specificity => Bayesian segementation based on prior
	# => reference support with no target support
	# => zero neighborhood prior
#	if ( $reference_support || ! $ngram_string_prior ) {
	if ( $reference_support && ( $ngram_string_prior < 0.2 ) ) {
	    return $this->status_reference_specific;
	}

    }

    # TODO : come up with more appropriate status codes / should be different from those provided by AdaptableSequence
    return $this->status_original;

}

sub status_as_string {

    my $this = shift;

    # TODO : need to clean things up for the priors => store priors for the entire sequence instead of per-component ?
    my $status_string = join( ' ' , map{ join( ':' ,
					       $this->original_sequence->object_sequence->[ $_ ]->surface ,
					       $this->_status->[ $_ ] ,
					       $this->priors->[ $this->component_index( $_ , -1 ) ] ) } @{ $this->_range_sequence } );

    return $status_string;

}

sub _determine_object_support {

    my $this = shift;
    my $object = shift;
    my $token = shift;

    my $supported = 0;
    
    #my $target_utterances = $target_object->supports( $ngram_token , regex_match => 1 , return_utterances => 1 );
    #my $reference_support = $reference_object->supports( $ngram_token , regex_match => 1 );

    # looking first at surface string
    my $utterances = $object->supports( $token , regex_match => 1 , return_utterances => 1 );
    if ( $utterances ) {
	$supported = 1;
    }
    # next look for hyponyms in the target
    # TODO : contrain on detected POS ?
    elsif ( $object->supports( $token , hyponyms_only => 1 ) ) {
	$supported = 1;
    }
    # finally look at hypernyms
    # TODO : is hypernym support always an indication of support ?
    elsif ( $object->supports( $token , hypernyms_only => 1 ) ) {
	$supported = 1;
    }

    return $supported;

}

__PACKAGE__->meta->make_immutable;

1;

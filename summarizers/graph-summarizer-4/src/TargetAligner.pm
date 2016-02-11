package TargetAligner;

use strict;
use warnings;

# CURRENT : how do we use as a standalone class ? => we still want to consume this role in TargetAdapter

use DMOZ::GlobalData;
#use Web::Summarizer::TokenRanker;
use Web::Summarizer::Utils;

use Function::Parameters qw(:strict);
use List::MoreUtils qw/uniq/;
use List::Util qw/max min/;
use Memoize;

use Moose;
use Moose::Util::TypeConstraints;
use namespace::autoclean;

with( 'Web::UrlData::Processor' );
with( 'DMOZ' );
with( 'Logger' );

# target object
has 'target' => ( is => 'ro' , isa => 'Category::UrlData' , required => 1 );

# Why ???
=pod
subtype 'TokenRankerRef' , as 'Web::Summarizer::TokenRanker';

#provide a coercion
coerce 'TokenRankerRef',
    from 'Str',
    via { Web::Summarizer::Utils::load_class( $_ )->new };

# token ranker
has 'token_ranker' => ( is => 'ro' , isa => 'TokenRankerRef' , predicate => 'has_token_ranker' );
=cut

has 'token_ranker_class' => ( is => 'ro' , isa => 'Str' , default => 'Web::Summarizer::TokenRanker::SimpleTokenRanker' );
has 'token_ranker' => ( is => 'ro' , isa => 'Web::Summarizer::TokenRanker' , init_arg => undef , lazy => 1 , builder => '_token_ranker_builder' );
sub _token_ranker_builder {
    my $this = shift;
    return Web::Summarizer::Utils::load_class( $this->token_ranker_class )->new;
}

# align for all utterances
# Purpose ? => align target to reference object, each "phrase" on the reference side should be aligned to a "phrase" on the target side
# CURRENT : Intuition ? => presuming we don't know anything about the reference and the target - in particular how similar they may be - what is the basis for alignment ? does it make sense ?
# CURRENT : How ? if we consider that corresponding utterances can be paired, then these pairings can be used to defined uniform alignment probabilities between terms
# CURRENT : Other solutions ?
sub align {
    
    my $this = shift;
    my $reference_object = shift;

    $this->error( "Aligning (" . $this->target->url . ") with (" . $reference_object->url . ")" );

    # 1 - get alignable terms for each object
    my $target_terms_alignable = $this->get_alignable_terms( $this->target , $reference_object );
    my $reference_terms_alignable = $this->get_alignable_terms( $reference_object , $this->target );

    # 2 - perform alignment
    # Note : we are producing a hard alignment here => a term can only be aligned to once => hungarian algorithm ? ILP ?
    # Note : lack of symmetry, should the target object be an attribute ?
    return $this->_align( $target_terms_alignable , $reference_object , $reference_terms_alignable );

}

sub get_alignable_terms {

    my $this = shift;
    my $main_object = shift;
    my $counterpart_object = shift;

    # 1 - get full list of terms (ranked by decreasing importance according to the selected TokenRanker)
    # CURRENT / TODO : should we be filtering single character tokens ?
    my $main_object_ranked_terms = $this->token_ranker->generate_ranking( $main_object , count_threshold => 2 );

    # TODO : generate list of alignable terms for each category of words/terms => nps / adjectives / adverbs

    # 2 - filter + truncate list of terms
    # TODO : make this optional/configurable
    my @main_object_selected_terms = grep { ! $counterpart_object->supports( $_ ) } @{ $main_object_ranked_terms };
    my $selected_terms_max = 10;
    if ( $#main_object_selected_terms >= $selected_terms_max ) {
	splice @main_object_selected_terms , $selected_terms_max;
    }

    return \@main_object_selected_terms;

}

memoize( '_get_object_tokens' );
sub _get_object_tokens {

    my $this = shift;
    my $object = shift;

    my $count_threshold = 2;

    my $object_tokens_full = $object->tokens;
    my @object_tokens = map { $_->[ 0 ] } grep { $_->[ 1 ] >= $count_threshold } values( %{ $object_tokens_full } );

    return \@object_tokens;

}

sub mutually_unsupported {

    my $this = shift;
    my $main_object = shift;
    my $counterpart_object = shift;

    # 1 - get list of unique tokens for the main object
    my $main_object_tokens = $this->_get_object_tokens( $main_object );

# TODO ?
=pod
    # compare target_object_token and reference_object_token
    # Note : the tokens must be objects so they can be compared in a flexible manner
    if ( $target_object_token->matches( $reference_object_token ) ) {
	# the two tokens are considered identical
	# TODO ...
    }
=cut

    # 3 - identify tokens from the main object that are not supported by the counterpart object
    my @unsupported;
    foreach my $token ( @{ $main_object_tokens } ) {

	if ( ! $token->object_support( $counterpart_object ) ) {
		# token is not supported by counterpart_object
		push @unsupported , $token;
	}
	else {
	    # token is supported by counterpart_object
	    # nothing
	}
	
    }

    return \@unsupported;

}

sub _align {
    
    my $this = shift;
    my $reference_object = shift;

    # we consider all pairings of utterances between the target and the reference objects
    # Note : it seems reasonable to assume that utterance pairings should be performed at a global level => the problem is how to detect unsupported tokens

    # get target/reference utterance sets
    my $target_utterances_sets = $this->target->utterances;
    my $reference_utterances_sets = $reference_object->utterances;

    my %alignment;
    foreach my $source_id (@{ $this->_alignment_sources }) {
	
	# 1 - get target/references utterance for the current source
	# TODO : can we avoid code duplication ?
	my @target_utterances = map { $this->_prepare_utterance( $_ , $this->target ); } @{ $target_utterances_sets->{ $source_id } };
	my @reference_utterances = map { $this->_prepare_utterance( $_ , $reference_object ); } @{ $reference_utterances_sets->{ $source_id } };
=pod
	# 2 - get utterances for reference object that contain the term to be replaced
	my @reference_utterances = map { $this->_prepare_utterance( $_ , $sentence->object ); } @{ $sentence->object->utterances( source => $source_id , pattern => $unsupported_sequence_pattern ) };
=cut

	if ( ! scalar( @target_utterances ) || ! scalar( @reference_utterances ) ) {
	    print STDERR "[" . __PACKAGE__ . "] nothing to align for $source_id ...\n";
	    next;
	}

=pod
	if ( ! scalar( @reference_utterances ) ) {
	    # this is most likely an indicative terms , this will be handled during the fusion phase
	    print STDERR ">> found no reference utterance in [$source_id] for pattern [$unsupported_sequence_pattern]\n";
	    next;
	}
=cut
	
	# TODO : focus on title and url for alignment (check individual words, identify words that are supported on either side )
	# TODO : use content modality only for validation (reason: content modality is too noisy, but could still use some very carefully selected utterances) ?
	
	# TODO : need to remove short strings ?
	# Option: identify short strings (that appear do not appear in reference ==> potential replacements)
	
	# CURRENT : align reference url to reference title
	# CURRENT : align target url target title
	# CURRENT : hosts align, then path is a specification of the host part ?
	
	# CURRENT : minimum context around any value that needs to be replaced => length of context gives confidence level
	# CURRENT : you must align with terms that are not supported by the target
	# CURRENT : then once we have an alignment assumption, attempts to further align (by bringing in replacements/abstractions ?)
	# 1 - for each reference summary that needs to be mapped
	# 2 - for each reference modality/utterance that contains this terms
	# 3 - find corresponding utterance in corresponding modality (trivial for url, title)
	# 4 - consider all the words in the target utterance
	# 4 - eliminating words/sequences that are supported by the target, what words/sequences remain that can be aligned to ?
	# TODO : should I consider bounded sequences (LCS) ? for acronyms/capitalized words ? => might get too specific ~
	# TODO : if alignment is impossible, lower confidence of reference page
	# Note : the more words are unsupported while summary terms cannot be aligned => lower confidence of reference => useful for ranking ?
	# TODO : perform reranking after adaptation !
	# TODO : only perform fusion on adaptable summaries (or those that don't require adaptation), otherwise simply return top ranked (unadulterated) summary.
	
	# 3 - pair up utterances for subsequence alignment
	my $utterance_pairs = $this->align_to_target_pairings( target_utterances => \@target_utterances , reference_utterances => \@reference_utterances ,
							       best => 1 , mode => 'hungarian' );

	# stop here if we cannot come up with a pairing for the current source
	my $utterance_pairs_count = scalar( @{ $utterance_pairs } );
	if ( ! $utterance_pairs_count ) {
	    print STDERR "Unable to obtain pairings for source : $source_id\n";
	    next;
	}

	# each pairing gets a fraction of the current source's vote
	my $utterance_vote = 1 / $utterance_pairs_count;
		
	# 4 - process each utterance pair
	foreach my $utterance_pair (@{ $utterance_pairs }) {
		    
	    # Note : should we perform our alignment globally (i.e. some form of unsupervised optimization ?)
	    # CURRENT ==> simple for now => giza++ spin-off => how long would it take ?
	    # 3.2 - align the two utterances
	    my $alignment = $this->align_utterances_coverage( $utterance_pair->[ 0 ]->[ 0 ] , $utterance_pair->[ 1 ]->[ 0 ] );
	    #my $alignment = $this->align_utterances( $utterance_pair->[ 0 ] , $utterance_pair->[ 1 ] );
	    
	    my $alignment_target_distribution = $alignment;
	    my @alignment_target_distribution_keys = keys( %{ $alignment_target_distribution } );
	    my $alignment_target_distribution_keys_count = scalar( @alignment_target_distribution_keys );
	    
	    if ( $alignment_target_distribution_keys_count ) {
		
		# Note: split vote between alignment candidates
		my $individual_alignment_vote = 1 / $alignment_target_distribution_keys_count;
		
		foreach my $alignment_target_key (keys( %{ $alignment_target_distribution } )) {
		    $alignment{ $alignment_target_key } +=
			$individual_alignment_vote * $alignment_target_distribution->{ $alignment_target_key };
		}
		
	    }
	    
	}
	
    }

    return \%alignment;

}

# CURRENT / TODO : how does this relate to the global align method ?
# reference/target alignment for a specific reference utterance
# Note : we only consider pair of utterances for which (1) the reference utterance contains one of the reference summary terms that is not target-supported; and (2) ... ?
sub align_utterance {

    my $this = shift;
    my $reference_object = shift;
    my $sentence = shift;

    my @reference_target_alignment;

    # 1 - perform global alignment between target and reference
    my $target_reference_global_alignment = $this->align( $reference_object );

    # identify unsupported sequences in reference sentence
    my $corrected_sequence = $this->generate_unsupported_sequences( $this->target , $sentence );

    # 2 - process each unsupported block
    my $corrected_sequence_length = scalar( @{ $corrected_sequence } );
    for (my $i=0; $i<$corrected_sequence_length; $i++) {

	my $current_token = $corrected_sequence->[ $i ];
	my $alignment_data = undef;

	# is this a regular token ?
	# TODO : should we be getting this information differently ?
	my $is_aligned_token = $current_token->is_slot_location;
	if ( ! $is_aligned_token ) {
	    # nothing to be done
	}
	else {

	    my $unsupported_sequence = $current_token->original_object_sequence;
	    my $unsupported_sequence_surface = $current_token->original_sequence_surface;
	    my $unsupported_sequence_pattern = $current_token->original_sequence_pattern_regex;

	    # CURRENT : devise experiments and top level parameters (i.e. what modalities to use for search, adaptation, etc)
	    #           => Then do my best ...
	    
	}

	push @reference_target_alignment , [ $current_token , $alignment_data ];

    }

    return \@reference_target_alignment;

}

sub _prepare_utterance {

    my $this = shift;
    my $raw_utterance = shift;
    my $object = shift;

    # 1 - turn raw utterance into Web::Summarizer::Sequence
    # Note : this should be the case already

    # 1 - segment
    my @segmented_utterance = @{ $raw_utterance->object_sequence };

    # 2 - index
    my %indexed_utterance;
    map { $indexed_utterance{ lc( $_->surface ) }++; } @segmented_utterance;

    return [ $raw_utterance , \@segmented_utterance , \%indexed_utterance , length( $raw_utterance->verbalize ) , $object ];

}

sub align_to_target_pairings_hungarian {

    my $self = shift;
    my $target_utterances = shift;
    my $reference_utterances = shift;

    my @costs;

    # 1 - compute cost matrix
    my $n_target_utterances = scalar( @{ $target_utterances } );
    my $n_reference_utterances = scalar( @{ $reference_utterances } );
    
    my $n = min( $n_target_utterances , $n_reference_utterances );

###    for ( my $i=0; $i<$n_reference_utterances; $i++ ) {
    for ( my $i=0; $i<$n; $i++ ) {
	
	my $reference_utterance = $reference_utterances->[ $i ]->[ 0 ];

#	my @cost_row;
###	for ( my $j=0; $j<$n_target_utterances; $j++ ) {
	for ( my $j=0; $j<$n; $j++ ) {
	    
	    my $target_utterance = $target_utterances->[ $j ]->[ 0 ];

	    my $cost_ij = multilevel_string_edit_cost( $reference_utterance , $target_utterance );
	    $costs[ $i ][ $j ] = $cost_ij;
#	    $cost_row[ $j ] = $cost_ij;
	    
	}

    }

    # 2 - find optimal assignment
    my @optimal_assignment;
    assign(\@costs,\@optimal_assignment);

#    if ( scalar( @optimal_assignment ) < $n_reference_utterances ) {
    if ( scalar( @optimal_assignment ) < $n ) {
	die "This should never happen : input-ouput size mismatch during pairing of reference and target utterances ...";
    }

    # 3 - map to utterance pairs
    my @utterances_pairs;
#    for (my $i=0; $i<min( $n_reference_utterances , $n_target_utterances ); $i++) {
    for (my $i=0; $i<=$#optimal_assignment; $i++) {

	my $optimal_j = $optimal_assignment[ $i ];

	my $reference_utterance = $reference_utterances->[ $i ];
	my $target_utterance = $target_utterances->[ $optimal_j ];
##	my $reference_utterance = $target_utterances->[ $i ];
##	my $target_utterance = $target_utterances->[ $optimal_j ];
 
	push @utterances_pairs , [ $reference_utterance , $target_utterance , $costs[ $i ][ $optimal_j ] ];

    }

    return \@utterances_pairs;

}

# Note : should not really be necessary (beyond a simple regex approach) if proper segmentation was in place
# CURRENT : where does this belong ?
method generate_unsupported_sequences ( $object , $utterance ) {

    my @unsupported_sequences;

    # Note : utterance must (at least) be a Web::Summarizer::Sequence
    my @tokens_regular = @{ $utterance->object_sequence };

    # 1 - annotate individual tokens in sentence
    # [target-supported] : target supported tokens
    # [reference-supported] : reference supported tokens
    # [reference-occurrences] : list of occurrences of token in reference
    # [target-occurrences] : needed ?

    my @target_supported;
    my @target_supported_count;

    my @reference_supported;
    my @reference_supported_count;
    my $reference_supported_count_max = 0;

    my @target_occurrences;
    my @reference_occurrences;

    # TODO : also create some form of "extractive appearance prior" and/or "abstractive appearance prior"
    my @corpus_count;
    my @appearance_prior;

    my $corpus_total = $self->global_data->global_count( 'summary' , 1 );
    for (my $i=0; $i <= $#tokens_regular; $i++) {

	my $token = $tokens_regular[ $i ];
	
	$target_supported[ $i ] = $token->object_support( $object , raw => 0 );
	$target_supported_count[ $i ] = scalar( @{ $target_supported[ $i ] });

	$reference_supported[ $i ] = $token->object_support( $utterance->object , raw => 0 );
	$reference_supported_count[ $i ] = scalar( @{ $reference_supported[ $i ] } );

	# TODO : add normalization code to token class ?
	$corpus_count[ $i ] = $self->global_data->global_count( 'summary' , 1 , lc( $token->surface ) );
	$appearance_prior[ $i ] = $corpus_count[ $i ] / $corpus_total;

	# Note : we only use reference supported terms that are not also target supported to avoid being affected by overly frequent terms, etc.
	#        => seems to yield a fairer estimate of the abstractive/extractive level
	#        => intuition : the more a terms appear on one side without appearing on the other indicates extractive behavior (as opposed to appearing at most a small amount of time, which would indicate abstractive behavior)
	if ( (!$target_supported_count[ $i ]) && ( $reference_supported_count_max < $reference_supported_count[ $i ] ) ) {
	    $reference_supported_count_max = $reference_supported_count[ $i ];
        }

	print STDERR join( "\t" , $token->surface , $token->pos , $target_supported_count[ $i ] , $reference_supported_count[ $i ] ) . "\n";

    }

    print STDERR "\n";

    # CURRENT : we need to segment the reference utterance optimally based on available reference data
    # CURRENT : define support score and maximize (using standard algorithm ?) => e.g. punctuation has no cost, can go either way, target-supported terms have a cost that ...
    # CURRENT : not this score is not the same as the extractability / extractive probability confidence
    # CURRENT :
    # 1 - consider all pairs of target unsupported + reference supported terms whose corresponding substring appears at least once in the reference, possibly going through target supported and/or punctuation tokens
    # 3 - for overlapping sequences, rank these pairs by decreasing amount of reference support => treat top sequence as a unit
    my @token2spans;
    my @token2max;
    my $utterance_object = $utterance->object;
    for (my $i=0; $i<=$#tokens_regular; $i++) {

	my $token_i_supported = $target_supported_count[ $i ];
	my $token_i_punctuation = $tokens_regular[ $i ]->is_punctuation;

	# TODO : can we do better ? maybe by encapsulating token meta-data in a class ?
	$token2max[ $i ] = 0;

	if ( $token_i_supported || $token_i_punctuation ) {
	    next;
	}

	my $previous_mode = undef;
	for (my $j=$i; $j<=$#tokens_regular; $j++) { 

	    my $token_j = $tokens_regular[ $j ];
	    print STDERR ">> " . $token_j->surface . "\n";

	    my $token_j_supported_reference = $reference_supported_count[ $j ];
	    my $token_j_supported_target = $target_supported_count[ $j ];
	    my $token_j_punctuation = $tokens_regular[ $j ]->is_punctuation;

	    # Note : force segmentation of ref-target supported transitions (00,01,10,11)
	    my $current_mode = $token_j_punctuation ? $previous_mode : join( "/" , ( $token_j_supported_reference ? 1:0 ) , ( $token_j_supported_target ? 1:0 ) );
	    if ( defined( $previous_mode ) && ( $current_mode ne $previous_mode ) ) {
		# we are reaching a chunking boundary
		last;
	    }	    

	    if ( $token_j_supported_target || $token_j_punctuation ) {
		next;
	    }

	    # is the substring (token_i,token_j) reference-supported ?
	    my $reference_supported = $self->check_supported( $utterance_object , \@tokens_regular , $i , $j , \@target_supported , \@reference_supported );
	    if ( $reference_supported ) {
		map {
	
		    my $token_index = $_;

		    if ( ! defined( $token2spans[ $token_index ] ) ) {
			$token2spans[ $token_index ] = [];
			$token2max[ $token_index ] = $reference_supported;
		    }
		    else {
			$token2max[ $token_index ] = max( $token2max[ $token_index ] , $reference_supported );
		    }

		    push @{ $token2spans[ $token_index ] } , [ $i , $j , $reference_supported ];

		} ($i .. $j);
	    }

	    $previous_mode = $current_mode;

	}

    }

    # 2 - how to detect overlapping sequences ? => scan tokens and keep track of containing sequences (ok)
    # Note : current option => left to right, selecting the longest possible subsequence given tokens that have not been seen already
    # Note : this might not always be optimal (?)
    my %token2assigned;
    my %token2sequence;
    # Note : process tokens that has strongest support overall
    my @sorted_token_indices = sort { $token2max[ $b ] <=> $token2max[ $a ] } ( 0 .. $#tokens_regular );

    foreach my $sorted_token_index (@sorted_token_indices) {
	
	my $token_entry = $token2spans[ $sorted_token_index ];

	if ( defined( $token_entry ) ) {

	    my @sorted_entries = sort { ( $b->[ 1 ] - $b->[ 0 ] ) <=> ( $a->[ 1 ] - $a->[ 0 ] ) } @{ $token_entry };

	    # TODO : select the sequence that has the strongest reference support, and for the same amount of support, favor shorter
	    #        => problem is that this leads to single token sequences being preferred
	    #        => this might be fixed by considering threshold-based decisions, i.e. if two tokens have respective frequencies that are
	    #        => sufficiently close we may conjoin them, otherwise we can assume the existence of a conceptual boundary between them ... 
	    #        => alternively we could attend to calibrate the thresholds by attempting to align pairs of references between themselves
	    # my @sorted_entries = sort { $b->[ 2 ] <=> ( $b->[ 2 ] ) } @{ $token_entry };

	    # TODO : a better segmentation may also be obtained by considering frequencies in the target neighborhood (i.e. references) or possibly
	    #        a n-gram language model of summaries of the appropriate order.

	    foreach my $sorted_entry (@sorted_entries) {

		my $sorted_entry_from = $sorted_entry->[ 0 ];
		my $sorted_entry_to = $sorted_entry->[ 1 ];

		# make sure no token in this entry has been seen already
		if ( scalar( grep { $token2assigned{ $_ } } ( $sorted_entry_from .. $sorted_entry_to ) ) ) {
		    next;
		}
		
		my $extractive_probability = 0;

		my @unsupported_sequence_tokens = map {
		    my $extractive_probability_token = ( $reference_supported_count[ $_ ] / $reference_supported_count_max );
		    $extractive_probability += $extractive_probability_token;
		    $token2assigned{ $_ }++;
		    $tokens_regular[ $_ ]
		} ( $sorted_entry_from .. $sorted_entry_to );
				
 		push @unsupported_sequences , \@unsupported_sequence_tokens;

		$token2sequence{ $sorted_entry_from } = [ \@unsupported_sequence_tokens , $extractive_probability ];
		last;

	    }

	}

    }

    # 2 - sequence re-segmentation
    # based on individual token annotations, knowing that we are mainly interested in sequences that are not target supported
    # segmentation should be done so as not to break n-grams prevalent in the reference object
    my @aligned_sequence;
    for (my $i=0; $i<=$#tokens_regular; $i++) {
	
	my $current_token_aligned = $token2sequence{ $i };
	
	if ( defined( $current_token_aligned ) ) {
	    
	    my $current_token_aligned_sequence        = $current_token_aligned->[ 0 ];
	    my $current_token_aligned_probability     = $current_token_aligned->[ 1 ];
	    my $current_token_aligned_sequence_length = scalar( @{ $current_token_aligned_sequence } );
	    
	    my $aligned_token = new Web::Summarizer::ExtractiveToken(
		original_object_sequence => $current_token_aligned_sequence,
		extractive_probability => $current_token_aligned_probability / $current_token_aligned_sequence_length
		);
	    
	    push @aligned_sequence , $aligned_token;
	    $i += $current_token_aligned_sequence_length - 1;
	    
	}
	else {
	    
	    my $current_token = $tokens_regular[ $i ];
	    push @aligned_sequence , $current_token;
	    
	}
	
    }
    
    return \@aligned_sequence;
    
}

# TODO : no longer needed ?
sub align_utterances_coverage {

    # CURRENT : segmentation is not helping => New York should be treated as a single token !

    my $this = shift;
    my $reference_utterance = shift;
    my $target_utterance = shift;

    my %alignment;

    # TODO : create a Utterance object
    # return [ $raw_utterance , \@segmented_utterance , \%indexed_utterance , length( $raw_utterance ) , $object ];
    my $reference_object = $reference_utterance->object;
    my $target_object = $target_utterance->object;

    # 1 - generate unsupported sequences
    # CURRENT : simply list out target sequences that are not supported by the reference object
    my $target_utterance_unsupported_sequences = $this->generate_unsupported_sequences( $reference_object , $target_utterance );

=pod
    my $reference_utterance_unsupported_sequences = $this->generate_unsupported_sequences( $target_object , $reference_utterance );
    # 2 - treat each target unsupported sequence as a pottential alignment for each reference unsupported sequence
    my $n_reference_utterance_unsupported_sequences = scalar( @{ $reference_utterance_unsupported_sequences } );
    my $n_target_utterance_unsupported_sequences = scalar( @{ $target_utterance_unsupported_sequences } );
    for ( my $i=0; $i<$n_reference_utterance_unsupported_sequences; $i++ ) {
	my $reference_utterance_unsupported_sequence = $reference_utterance_unsupported_sequences->[ $i ];
	my $reference_utterance_unsupported_sequence_surface = $reference_utterance_unsupported_sequence->[ 3 ];
	if ( $n_target_utterance_unsupported_sequences ) {
	    my $uniform_weight = 1 / $n_target_utterance_unsupported_sequences;
	    for( my $j=0; $j<$n_target_utterance_unsupported_sequences; $j++ ) {
		my $target_utterance_unsupported_sequence = $target_utterance_unsupported_sequences->[ $j ];
		my $target_utterance_unsupported_sequence_surface = $target_utterance_unsupported_sequence->[ 3 ];
		 $alignments{ $reference_utterance_unsupported_sequence_surface }->{ $target_utterance_unsupported_sequence_surface } = $uniform_weight;
	     }
	 }
	 else {
	     $alignments{ $reference_utterance_unsupported_sequence_surface }->{ '[[null]]' } = 1;
	 }
     }
=cut

    # 2 - treat each reference unsupported sequence as a potential alignment for our reference sequence
    my $n_target_utterance_unsupported_sequences = scalar( @{ $target_utterance_unsupported_sequences } );
    for (my $i=0; $i<$n_target_utterance_unsupported_sequences; $i++) {

	my $current_token = $target_utterance_unsupported_sequences->[ $i ];

	# Note : we only care about what has been identified as slot locations
	if ( $current_token->is_slot_location ) {    
	    my $uniform_weight = 1 / $n_target_utterance_unsupported_sequences;
	    for( my $j=0; $j<$n_target_utterance_unsupported_sequences; $j++ ) {
		my $target_utterance_unsupported_sequence_surface = $current_token->original_sequence_surface;
		$alignment{ $target_utterance_unsupported_sequence_surface } = $uniform_weight;
	    }
	    
	}

    }

    return \%alignment;

}

# TODO : should this be provided as a method in Web::Summarizer::Sequence ?
sub check_supported {

    my $this = shift;
    my $object = shift;
    my $tokens_sequence = shift;
    my $from = shift;
    my $to = shift;
    my $target_supported = shift;
    my $reference_supported = shift;

    my $supported = 0;

    # 1 - generate list of utterances that contain both from and to
    # TODO : implement intersection instead
    my @utterances = uniq ( @{ $reference_supported->[ $from ] } , @{ $reference_supported->[ $to ] } );

    if ( scalar( @utterances ) ) {

	# 1 - generate sequence regex
	my $sequence_regex_string = join( '\s*' , map {
	    
	    my $token_index = $_;
	    my $token = $tokens_sequence->[ $token_index ];
	    my $token_target_supported = scalar( @{ $target_supported->[ $token_index ] } );
	    my $token_reference_supported = scalar( @{ $reference_supported->[ $token_index ] } );

	    if ( $token->is_punctuation ) {
#		'(?:' . "\Q" . $token->surface . "\E" . ')?';
		'\p{Punct}*'; # Note : this is to say that punctuation does not effectively matter, which seems reasonable ...
	    }
	    elsif ( !$token_reference_supported && $token_target_supported ) {
		# Note : is this really useful ?
		'\w+';
	    }
	    else {
		$token->surface;
	    }
	    
					  } ($from .. $to) );

	print "regex >> $sequence_regex_string\n";

	my $sequence_regex = qr/$sequence_regex_string/;
	foreach my $utterance (@utterances) {
	    # check if current utterance matches sequence regex
	    if ( $utterance->[ 0 ]->verbalize =~ m/$sequence_regex/si ) {
		$supported++;
	    }   
	}

    }

    return $supported;

}

method align_to_target_pairings( :$target_utterances , :$reference_utterances , :$best = 0 , :$mode ) {

    # Note : process is controlled by the number of reference utterances

    if ( $mode eq 'hungarian' ) {
	return $self->align_to_target_pairings_hungarian( $target_utterances , $reference_utterances );
    }

    my @utterances_pairs;

    # 3 - consider all pairs of reference-target utterances
    # Note : this is a soft approach which might turn out to be expensive - a simplification would be to pair up utterances based on maxixum similarity
    # TODO : make sure to assign a weight to each pairing => Bayesian approach
    my $n_target_utterances = scalar( @{ $target_utterances } );
    my $n_reference_utterances = scalar( @{ $reference_utterances } );
    # CURRENT : if in best mode, an utterance can be used only once => what is the best matching algorithm for this ? Pigeon-hole algorithm , some sort of maximization ?
    for ( my $i=0; $i<$n_reference_utterances; $i++ ) {

	my $reference_utterance = $reference_utterances->[ $i ];
	
	my $reference_utterance_sequence = $reference_utterance->[ 0 ];
	print STDERR "Attempting to find alignment for reference utterance : " . $reference_utterance_sequence->verbalize . "\n";

	my $reference_utterance_index = $reference_utterance->[ 2 ];
	my $reference_utterance_length = $reference_utterance->[ 3 ];
	my $best_utterance_similarity = -1;
	my $best_utterance_index = -1;

	my $paired_count = 0;
	for ( my $j=0; $j<$n_target_utterances; $j++ ) {
	    
	    my $target_utterance = $target_utterances->[ $j ];
	    my $target_utterance_index = $target_utterance->[ 2 ];
	    my $target_utterance_length = $target_utterance->[ 3 ];

	    # compute character-level edit distance (i.e. Levhenstein distance)
###	    my $utterances_similarity = 1 / ( 1 + levenshtein( $reference_utterance , $target_utterance ) );

	    # Note : utterances must meet some basic conditions before we attempt to align them
	    # [1] - we do not perform alignment on utterances that are not in the same length range
	    # 3.1 - make sure the two utterances have at least one term in common (should we really be checking for this ?)
	    if ( ( $reference_utterance_length > 2 * $target_utterance_length ) || ( $reference_utterance_length > 2 * $target_utterance_length ) ||
		 ! scalar( grep { length( $_ ) >= 2 } keys( %{ $target_utterance_index } ) )
		 || ! Similarity::_compute_cosine_similarity( $reference_utterance_index , $target_utterance_index )
		) {
		# nothing
		next;
	    }

	    my $utterances_similarity = multilevel_string_edit_cost( $reference_utterance , $target_utterance );
	    my $utterance_pair = [ $reference_utterance , $target_utterance , $utterances_similarity ];

	    if ( $best && ( $utterances_similarity < $best_utterance_similarity ) ) {
		next;
	    }

	    if ( $utterances_similarity >= $best_utterance_similarity ) {
		$best_utterance_similarity = $utterances_similarity;
		if ( $best && ( $best_utterance_index >= 0 ) ) {		     
		    # nothing
		}
		else {
		    $best_utterance_index = $#utterances_pairs + 1;
		}
	    }
	    
	    $utterances_pairs[ $best_utterance_index ] = $utterance_pair;
	    $paired_count++;
	    
	}

	if ( ! $paired_count ) {
	    print STDERR "Unable to find pairing for reference utterance : " . $reference_utterance_sequence->verbalize . "\n";
	}

    }

    return \@utterances_pairs;

}

sub align_utterances_simple {

    my $this = shift;
    my $utterance_1 = shift;
    my $utterance_2 = shift;

    # 0 - all alignments focus on a specific reference term (independent of others ?)

    # 1 - each modality is given a vote - that vote is then distributed among the strings comprising that modality

    # 2 - utterances should be paired based on maximum character level similarity (i.e. Levenshtein distance)
    # TODO - in caller

    # 3 - for each pairing align reference(s) terms (character sequence) to character sequence that looks the most similar (character distance again ?)
    # TODO : automatically derive regexes by turning n-grams into regexes based on specificity between the target/reference.

}

sub align_utterances {

    my $this = shift;
    my $utterance_1 = shift;
    my $utterance_2 = shift;

    my $utterance_1_object = $utterance_1->[ 4 ];
    my $utterance_2_object = $utterance_2->[ 4 ];

    my $alignment = undef;

    # 1 - the ( similarity + word length difference ) between the two strings gives the alignment confidence
    # TODO
    
    print STDERR "Aligning [" . $utterance_1->[ 0 ] . "] with [" . $utterance_2->[ 0 ] . "]\n";
    
    # TODO : move to Token-based alignment algorithm => would allow this to become a object field
    # based on multilevel_string_edit_cost but with the added possibility of returning a low cost if both terms are unique to their object and are compatible (shape, semantic type, etc.)
    my $alignment_cost_sub = sub {
	
	my $term_1 = shift;
	my $term_2 = shift;
	
	# TODO : ultimately it would probably make sense to work with Tokens
	my $token_1 = new Web::Summarizer::Token( surface => $term_1 );
	my $token_2 = new Web::Summarizer::Token( surface => $term_2 );
	
	my $base_cost = multilevel_string_edit_cost( $term_1 , $term_2 );
	my $term_1_uniqueness = $token_1->object_support( $utterance_2_object );
	my $term_2_uniqueness = $token_2->object_support( $utterance_1_object );
	my $shape_cost = 1 - __PACKAGE__->word_shape_overlap( [ $term_1 ] , [ $term_2 ] );
	
	# if both terms are unique wrt to the other object
	my $cost = $base_cost * ( $term_1_uniqueness + $term_2_uniqueness + $shape_cost ); 
	
	return $cost;
	
    };
    
    $alignment = ( new String::Alignment( from => $utterance_1->[ 1 ] , to => $utterance_2->[ 1 ] ,
					  cost_alignment => $alignment_cost_sub,
					  cost_deletion  => $this->_corpus_cost,
					  cost_insertion => $this->_corpus_cost
		   ) )->align;

    return $alignment;

}

# CURRENT / TODO : apply only to Sequence objects ? or at least array of Token obect => allows to check support easily ...
sub multilevel_string_edit_cost {

    my $sequence_1 = shift;
    my $sequence_2 = shift;

# TODO : to be removed
=pod
    # TODO : abstract tokenization function
    my @string_1_tokens = ref( $string_1 ) ? @{ $string_1 } : ( split /\s+/ , $string_1 );
    my @string_2_tokens = ref( $string_2 ) ? @{ $string_2 } : ( split /\s+/ , $string_2 );
=cut

    # 1 - legnth difference cost
    my $cost_length_difference = abs( $sequence_1->length - $sequence_2->length );
    
    # 2 - shape cost
    # TODO : consider n-grams ?
    my $cost_word_shape_overlap = __PACKAGE__->word_shape_overlap( $sequence_1 , $sequence_2 );

    # 3 - counterpart non-supported
    # Note : we want to favor the alignment of strings that have a similar number of unsupported terms
    #        => i.e. we do not want to align two utterances based on terms that are supported somewhere in the counterpart object
    my $counterpart_diff = 0;
    for my $counterpart_entry ( [ $sequence_1 , $sequence_2->object , 1 ] , [ $sequence_2 , $sequence_1->object , -1 ] ) {
	my $sequence = $counterpart_entry->[ 0 ];
	my $counterpart = $counterpart_entry->[ 1 ];
	my $weight = $counterpart_entry->[ 2 ];
	foreach my $sequence_token (@{ $sequence }) {
	    if ( $sequence_token->object_support( $counterpart ) ) {
		$counterpart_diff += $weight;
	    }
	}
    }
    #my $cost_counterpart_non_supported = abs( $counterpart_string_1_non_supported - $counterpart_string_2_non_supported );
    my $cost_counterpart_non_supported = abs( $counterpart_diff );

    # 4 - word overlap
    # TODO : also consider n-grams ?
    my $cost_word_overlap = 1 - Similarity::_compute_cosine_similarity( $sequence_1 , $sequence_2 );
    # TODO: refine cost_word_overlap with corpus-wide idf : , $this->global_data->global_distribution( 'summary' , 1 ) );

    my $edit_cost = ( $cost_length_difference + $cost_word_shape_overlap + $cost_word_overlap ) ** ( 1 + $cost_counterpart_non_supported );

    return $edit_cost;

}

# TODO : instead use regular similarity, but based on different vectorization ?
sub word_shape_overlap {

    my $this = shift;
    my $string_1_tokens = shift;
    my $string_2_tokens = shift;

    my @strings = ( $string_1_tokens , $string_2_tokens );
    my @strings_vectorized = ( {} , {} );
    
    for ( my $i=0; $i<1; $i++ ) {
	my $string = $strings[ $i ];
	my $string_vectorized = $strings_vectorized[ $i ];
	map {  $string_vectorized->{ $this->surface_marker( $_ ) }++ } @{ $string };
    }

    # TODO : any point specifying dfs ?
    return Vector::cosine( new Vector( coordinates => $strings_vectorized[ 0 ] ) , new Vector( coordinates => $strings_vectorized[ 1 ] ) );

}

sub surface_marker {

    my $this = shift;
    my $token = shift;

    my $marker = 'unknown';

    if ( $token =~ m/^\p{Punct}+$/ ) {
	$marker = 'punctuation';
    }
    elsif ( $token =~ m/^\d+$/ ) {
	$marker = join( "-" , 'numeric' , length( $token ) );
    }
    elsif ( $token =~ m/^[A-Z]+$/ ) {
	$marker = 'alphanumeric-allcaps';
    }
    elsif ( $token =~ m/^[a-z]+$/ ) {
	$marker = 'alphanumeric-nocaps';
    }
    elsif ( $token =~ m/^[A-Z][a-z]+$/ ) {
	$marker = 'alphanumeric-capitalized';
    }
    elsif ( $token =~ m/^[a-z]+[A-Z]$/ ) {
	$marker = 'alphanumeric-capitalized-last';
    }
    elsif ( $token =~ m/^[a-z]+[A-Z][a-z]+$/ ) {
	$marker = 'alphanumeric-capitalized-middle';
    }

    return $marker;

}

#__PACKAGE__->meta->make_immutable;

1;

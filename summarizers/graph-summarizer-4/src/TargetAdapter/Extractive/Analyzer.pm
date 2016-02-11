package TargetAdapter::Extractive::Analyzer::Clusters;

# CURRENT : start by identify function words
# => segment using function words

use strict;
use warnings;

use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

# surface to string
has '_surface_2_string' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# string to surfaces
has '_string_2_surfaces' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# type to strings
has '_type_2_strings' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# string to types
has '_string_2_types' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# order to strings
has '_order_2_strings' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , default => sub { {} } );

# raw sequences
has 'raw_sequences' => ( is => 'rw' , isa => 'HashRef' );

sub get_orders {
    my $this = shift;
    my @orders = keys( %{ $this->_order_2_strings } );
    return \@orders;
}

sub get_order_sequences {
    my $this = shift;
    my $order = shift;
    my @sequences = keys %{ $this->_order_2_strings->{ $order } };
    return \@sequences;
}

sub add_surface_form {

    my $this = shift;
    my $string_normalized = shift;
    my $string_surface = shift;

    # update surface 2 string
    $this->_surface_2_string->{ $string_surface } = $string_normalized;

    # update string 2 surfaces
    if ( ! defined( $this->_string_2_surfaces->{ $string_normalized } ) ) {
	$this->_string_2_surfaces->{ $string_normalized } = {};
    }
    $this->_string_2_surfaces->{ $string_normalized }->{ $string_surface }++;
    
}

sub assign_cluster {

    my $this = shift;
    my $entry = shift;
    my $type = shift;
    my $order = shift;

    my $entry_normalized = $entry->[ 0 ];
    my $entry_surfaces = $entry->[ 1 ];

    # register types for the current sequence
    if ( ! defined( $this->_string_2_types->{ $entry_normalized } ) ) {
	$this->_string_2_types->{ $entry_normalized } = [];
    }
    push @{ $this->_string_2_types->{ $entry_normalized } } , $type;

    # update type to strings mapping
    if ( ! defined( $this->_type_2_strings->{ $type } ) ) {
	$this->_type_2_strings->{ $type } = [];
    }
    push @{ $this->_type_2_strings->{ $type } } , $entry_normalized;

    # update order to strings mapping
    if ( ! defined( $this->_order_2_strings->{ $order } ) ) {
	$this->_order_2_strings->{ $order } = {};
    }
    $this->_order_2_strings->{ $order }->{ $entry_normalized } = 1;

}

sub has_sequence {

    my $this = shift;
    my $string = shift;

    if ( defined( $this->_surface_2_string->{ $string } ) ) {
	return 1;
    }

    return 0;

}

method get_types ( $string , :$normalize = 1 ) {

    # 1 - map string to normalized string
    my $normalized_string = $normalize ? $self->_surface_2_string->{ $string } : $string;

    # 2 - map normalized string to types
    my $types = defined( $normalized_string ) ? $self->_string_2_types->{ $normalized_string } : undef;

    return $types;
    
}

# TODO : turn into a field
sub get_strings {

    my $this = shift;
    
    my @strings = keys( %{ $this->_string_2_types } );
    return \@strings;

}

sub get_type_members {
    
    my $this = shift;
    my $type = shift;

    return $this->_type_2_strings->{ $type };

}

sub type_count {
    my $this = shift;
    my $type = shift;
    return scalar( @{ $this->_type_2_strings->{ $type } } );
}

1;

package TargetAdapter::Extractive::Analyzer;

use strict;
use warnings;

use StringNormalizer;

use Carp::Assert;
use Function::Parameters qw/:strict/;
use List::MoreUtils qw/uniq/;
use List::Util qw/min/;
use Memoize;

use Moose;
use namespace::autoclean;

with( 'DBPedia' );
with( 'WordNetLoader' );

# Optimization for DBpedia role
memoize( 'get_types' );

method mutual ( $instance_target , $instance_reference , :$target_threshold = 0 , :$reference_threshold = 0 ) {

    # TODO : can we do better ?
    my ( $instance_1_unsupported_sequences , $instance_2_unsupported_sequences ) = map {
	$self->analyze_sequence( $_->[ 0 ] , $_->[ 1 ] , threshold => $_->[ 3 ] , use_summary => $_->[ 2 ] );
    } ( [ $instance_target , $instance_reference , 0 , $target_threshold || 2 ] , [ $instance_reference , $instance_target , 0 , $reference_threshold || 0 ] );

    return ( $instance_1_unsupported_sequences , $instance_2_unsupported_sequences );

}

method analyze_sequence ( $instance_target , $instance_reference , :$threshold = 0 , :$use_summary = 0 ) {

    $self->logger->debug( "Mirrored analysis : " . join( " <-> " , map { $_->url } ( $instance_target , $instance_reference ) ) );

    my %unsupported_sequences;
    my %raw_unsupported_sequences_surfaces;

    # for all utterances identify "sequences" of tokens that are unsupported by the other instance    
    my $target_utterances = $instance_target->utterances;

    # TODO : this should be promoted to UrlData::utterances with proper parameters
    if ( $use_summary ) {
	my %_target_utterances = %{ $target_utterances };
	$_target_utterances{ 'summary' } = $instance_target->summary_modality->utterances;
	$target_utterances = \%_target_utterances;
    }

    foreach my $target_utterance_source (keys( %{ $target_utterances })) {

	if ( $target_utterance_source eq 'anchortext' ) {
	    $self->logger->debug( "Ignoring anchortext modality for mirrored analysis => TODO: (1) only use anchortext basic; (2) use as frequency booster" );
	    next;
	}

	foreach my $target_utterance (@{ $target_utterances->{ $target_utterance_source } }) {
	    
	    my @utterance_sequence = grep { ! $_->is_punctuation } @{ $target_utterance->object_sequence };
	    my $max_considerable_length = min( 50 , $#utterance_sequence );
	    
	    for ( my $i = 0 ; $i <= $max_considerable_length ; $i++ ) {
		
		# keep moving forward until either phrase is known or token is supported
		my $span_to = $i;
		while ( ( $span_to <= $#utterance_sequence ) &&
# Note : not necessarily relevant here since we are trying to identify high-order n-grams (?)
#			( $instance_target->supports( $utterance_sequence[ $span_to ] ) > $threshold ) &&
			! $instance_reference->supports( $utterance_sequence[ $span_to ] ) ) {
		    # TODO : check wether we are reaching the end of an entity ?
		    $span_to++;
		}
		
		if ( $span_to > $i ) {
		    my @unsupported_sequence = map { $utterance_sequence[ $_ ] } ( $i .. ( $span_to - 1 ) );
		    my $unsupported_sequence_surface = join( " " , map { $_->surface } @unsupported_sequence ); 
		    my $unsupported_sequence_surface_normalized = StringNormalizer::_normalize( $unsupported_sequence_surface );

		    $unsupported_sequences{ $unsupported_sequence_surface_normalized }++;
		    $raw_unsupported_sequences_surfaces{ $unsupported_sequence_surface_normalized }{ $unsupported_sequence_surface }++;

		    $i = $span_to;
		}
		
	    }
	    
	}

    }

    # TODO : can we resegment sequences directly inside refine segmentation ?
    my $refined_segmentation = $self->_refine_segmentation( $instance_target , \%unsupported_sequences , $threshold );
    my @refined_segmentation_sorted = sort {
	my $a_order = $a->[ 1 ];
	my $b_order = $b->[ 1 ];
	if ( $a_order != $b_order ) {
	    $b->[ 1 ] <=> $a->[ 1 ];
	}
	else {
	    $b->[ 2 ] <=> $a->[ 2 ];
	}
    }
    map {
	my $ngram = $_;
	my $ngram_entry = $refined_segmentation->{ $ngram };
	[ $ngram , @{ $ngram_entry } , qr/(?:\W|^)$ngram(?:\W|$)/i ]
    } keys ( %{ $refined_segmentation } );

    # Resegmenting unsupported sequences based on the set of high-order n-grams that have been identified
    $self->logger->debug( "Post-processing segmentation for " . $instance_target->url . " [" . scalar(@refined_segmentation_sorted) . " target n-grams]" );
    my %unsupported_sequences_resegmented;
    my %unsupported_sequences_final;
    foreach my $unsupported_sequence ( keys( %unsupported_sequences ) ) {
	
	my $unsupported_sequence_weight = $unsupported_sequences{ $unsupported_sequence };
	my $unsupported_sequence_surfaces = $raw_unsupported_sequences_surfaces{ $unsupported_sequence };

	my @unsupported_segment_buffer = map {
	    [ $_ , $unsupported_sequence_surfaces->{ $_ } ]
	} keys( %{ $unsupported_sequence_surfaces } );

	foreach my $segment_regex_entry (@refined_segmentation_sorted) {
	    
	    my $segment = $segment_regex_entry->[ 0 ];
	    my $segment_regex = $segment_regex_entry->[ 3 ];

	    my @_remaining;
	    while ( scalar( @unsupported_segment_buffer ) ) {
		
		my $current_entry = shift @unsupported_segment_buffer;
		my $current = $current_entry->[ 0 ];
		my $current_weight = $current_entry->[ 1 ];

		my $has_match = 0;
		while ( $current =~ m/^(.*?)($segment_regex)(.*?)$/sgi ) {
		    $unsupported_sequences_resegmented{ StringNormalizer::_normalize( $2 ) } += $current_weight;
		    push @_remaining , map { [ $_ , $current_weight ] } grep { length( $_ ); }
		    map { StringNormalizer::_normalize( $_ ) }
		    ( $1 , $3 );
		    $has_match++;
		}
		
		if ( ! $has_match ) {
		    push @_remaining , $current_entry;
		}
		


=pod
		my @segments = split /($segment_regex)/ , $current;
		map {
		    # TODO : we should be able to derive this information in a less computationally-intensive way
		    if ( $_ =~ $segment_regex ) {
			$unsupported_sequences_resegmented{ $_ } += $current_weight;
		    }
		    else {
			push @_remaining , [ $_ , $current_weight ];
		    }
		}
=cut

	    }

	    @unsupported_segment_buffer = @_remaining;

	}

	# TODO : can we trim at an earlier stage ?
	map { $unsupported_sequences_resegmented{ StringNormalizer::_normalize( $_->[ 0 ] ) } = $_->[ 1 ] } @unsupported_segment_buffer;

    }

    # normalize
    $self->logger->debug( "Normalizing segmentation for " . $instance_target->url );
    my %unsupported_sequences_normalized;
    my %unsupported_sequences_surfaces;
    map {

	# TODO : is there a way to avoid recomputing this ?
	my $sequence_unnormalized = $_;
	my $sequence_normalized = StringNormalizer::_normalize( $sequence_unnormalized );

	$unsupported_sequences_normalized{ $sequence_normalized } += $unsupported_sequences_resegmented{ $sequence_unnormalized };

	if ( ! defined( $unsupported_sequences_surfaces{ $sequence_normalized } ) ) {
	    $unsupported_sequences_surfaces{ $sequence_normalized } = {};
	}
	$unsupported_sequences_surfaces{ $sequence_normalized }{ $sequence_unnormalized }++;

    } keys( %unsupported_sequences_resegmented );

    # filter sequences
    my @unsupported_sequences_filtered = map {
	# TODO : the surface forms are no longer being collected properly
	[ $_ , $unsupported_sequences_surfaces{ $_ } ]
    }
    # CURRENT : no thresholding, otherwise we're losing information => use type distribution instead (which I think is partially in place already)
    #grep { $unsupported_sequences_normalized{ $_ } >= $threshold }
    grep { length( $_ ) > 1 } # discard single characters => is this problematic ?
    keys( %unsupported_sequences_normalized );

    # cluster sequences
    my $clusters = $self->_cluster_by_type( $instance_target , \@unsupported_sequences_filtered , \%unsupported_sequences );

    return $clusters;

}

=pod
# Note : assumption is that multiple appearance of a given n-gram is not by chance for the mirrored target object
# => so we identify all ngrams (any length that appear more than once and treat these as undividable tokens
sub _refine_segmentation {

    my $this = shift;
    my $instance_target = shift;
    my $unsupported_sequences = shift;
    my $threshold = shift;

    $this->logger->debug( "Refining segmentation for " . $instance_target->url );

    my %refined_ngrams;

    my @_unsupported_sequences = map {

	my $sequence = $_;
	my @sequence_tokens = split /\s+/ , $sequence;
	my $sequence_length = scalar( @sequence_tokens );

	[ $sequence , $unsupported_sequences->{ $sequence } , \@sequence_tokens , $sequence_length ]
	  
    } keys( %{ $unsupported_sequences } );
    my @_unsupported_sequences_active = map { 1 } @_unsupported_sequences;

    my $n_unsupported_sequences = scalar( @_unsupported_sequences );

    my %final_ngrams;

    my $order = 0;
    while ( 1 ) {

	# moving on to higher order n-grams
	# Note : this seems like a reasonable limit
	if ( ++$order > 4 ) {
	    last;
	}

	# compute ngram counts for the current order
	my %ngram_counts;
	my %ngram_2_index;
	for ( my $i = 0 ; $i < $n_unsupported_sequences ; $i++ ) {

	    # we restrict the set of sequences to those that contain a significant ngram
	    # TODO : make sure this is ok
	    if ( ! $_unsupported_sequences_active[ $i ] ) {
		next;
	    }

	    my $sequence_entry = $_unsupported_sequences[ $i ];
	    my $sequence = $sequence_entry->[ 0 ];
	    my $sequence_weight = $sequence_entry->[ 1 ];
	    my $sequence_tokens = $sequence_entry->[ 2 ];
	    my $sequence_length = $sequence_entry->[ 3 ];

	    #print STDERR "Sequence length: $sequence_length / $order\n";
	    for ( my $j=0 ; $j<($sequence_length - ($order - 1)); $j++ ) {
		# TODO : come up with a more efficient implementation
		my $ngram = join( ' ' , ( map { $sequence_tokens->[ $_ ] } ( $j .. ( $j + ( $order - 1 ) ) ) ) );
		$ngram_counts{ $ngram } += $sequence_weight;
		$ngram_2_index{ $ngram }{ $i }++;
	    }
	    
	}

	# identify significant ngrams for the current order
	# Note : we use a heuristic for this => could use LR's instead ?
	# TODO : could use a mean average instead to adapt to more repetitive pages ?
	@_unsupported_sequences_active = map { 0 } @_unsupported_sequences;
	my @significant_order_ngrams = map {

	    my $ngram = $_;

	    if ( $ngram_counts{ $ngram } > $threshold ) {

		# activate all sequences containing the current ngram
		my @ngram_sequence_indices = keys( %{ $ngram_2_index{ $_ } } );
		foreach my $ngram_sequence_index (@ngram_sequence_indices) {
		    $_unsupported_sequences_active[ $ngram_sequence_index ]++;
		}
		
	    }

	    $ngram;

	}
	# TODO : use threshold parameter
	grep { $ngram_counts{ $_ } > $order }
	keys( %ngram_counts );

	# if no ngram is significant at the current order, we are done
	if ( ! scalar( @significant_order_ngrams ) ) {
	    # we are done
	    last;
	}

	# keep significant ngrams
	# CURRENT : generate tree from ngrams
	map { $refined_ngrams{ $_ } = [ $order , $ngram_counts{ $_ } ] } @significant_order_ngrams;

    }

    $this->logger->debug( "Done refining segmentation for " . $instance_target->url );

    return \%refined_ngrams;

}
=cut

# Note : assumption is that multiple appearance of a given n-gram is not by chance for the mirrored target object
# => so we identify all ngrams (any length that appear more than once and treat these as undividable tokens
sub _refine_segmentation {

    my $this = shift;
    my $instance_target = shift;
    my $unsupported_sequences = shift;
    my $threshold = shift;

    $this->logger->debug( "Refining segmentation for " . $instance_target->url );

    my %refined_ngrams;

    my @unsupported_sequences = keys( %{ $unsupported_sequences } );
    foreach my $unsupported_sequence (@unsupported_sequences) {

	# 1 - get accurate support for sequence
	my $unsupported_sequence_support = $instance_target->supports( $unsupported_sequence , regex_match => 1 );
	
	# 2 - filter as appropriate
	my $order = scalar( split /\s+/ , $unsupported_sequence );
	if ( $unsupported_sequence_support < $threshold ) {
	    next;
	}
	
	# 3 - register sequence
	$refined_ngrams{ $unsupported_sequence } = [ $order , $unsupported_sequence_support ];
	  
    }

    $this->logger->debug( "Done refining segmentation for " . $instance_target->url );

    return \%refined_ngrams;

}

sub _cluster_by_type {

    my $this = shift;
    my $instance = shift;
    my $sequences = shift;
    my $sequences_2 = shift;

    $this->logger->debug( "Clustering extractive content : " . $instance->url );

    my $clusters = new TargetAdapter::Extractive::Analyzer::Clusters;
    $clusters->raw_sequences( $sequences_2 );

    foreach my $sequence_entry ( @{ $sequences } ) {

	my $found_cluster = 0;

	my $sequence_normalized = $sequence_entry->[ 0 ];
	my $sequence_surfaces = $sequence_entry->[ 1 ];

	# TODO : this could have been preserved from the refine_segmentation step ?
	my @sequence_elements = split /\s+/ , $sequence_normalized;
	my $sequence_order = scalar( @sequence_elements );

	map {
	    $clusters->add_surface_form( $sequence_normalized , $_ );
	} keys( %{ $sequence_surfaces } );

	my $detected_types = $this->detect_types( $sequence_normalized , $instance );
	map {
	    $clusters->assign_cluster( $sequence_entry , $_ , $sequence_order );
	    $found_cluster++;
	} @{ $detected_types };

	if ( ! scalar( @{ $detected_types } ) && $sequence_order > 1 ) {
	    
	    # detect types for all possible orders until we reach an order that matches
	    # TODO : add upper limit for order ?
	    for ( my $order = $sequence_order - 1 ; $order >= 1 ; $order-- ) {
		
		# TODO : if order is 1 , check whether token has been seens before, if so ignore
		
		my $found_suborder_types = 0;
		
		# generate all possible ngrams for this order
		my $order_offset = $order - 1;
		for ( my $i = 0; $i < $sequence_order - $order_offset; $i++ ) {
		    
		    my @_elements = map { $sequence_elements[ $_ ] } ( $i .. ( $i + $order_offset ) );
		    my $_substring = join( ' ' , @_elements );

		    my $suborder_detected_types = $this->detect_types( $_substring );
		    map {

			# TODO : recover sub-string surface forms
			$clusters->assign_cluster( [ $_substring , { $_substring => 1 } ] , $_ , $order );
			$found_suborder_types++;

		    } @{ $suborder_detected_types };

		} 

		if ( $found_suborder_types ) {
		    last;
		}

	    }

	}

    }

    return $clusters;

}

sub detect_types {

    my $this = shift;
    my $sequence_normalized = shift;
    my $instance = shift;

    my @detected_types;

    if ( $sequence_normalized =~ m/^\p{Punct}$/ ) {
	$this->logger->debug( "Attempting to detect type for punctuation sequence: $sequence_normalized" );
    }
    elsif ( $sequence_normalized =~ m/^\d+[^ ]*$/ ) {
	push @detected_types , 'number';
    }
    else {
	
	# CURRENT : generate all hypernyms until root has been reached => verify that there is only one lineage
	# CURRENT : how can figure out that a word is a regular word ?

        my $sequence_token = new Web::Summarizer::Token( surface => $sequence_normalized );
	my $wordnet_hypes = $sequence_token->hypernyms;
	if ( scalar( @{ $wordnet_hypes } ) ) {

            my %hypes;
	    foreach my $_wordnet_hype (@{ $wordnet_hypes }) {

                my $wordnet_hype = $_wordnet_hype->abstract_type;
                affirm { $wordnet_hype } 'WordNet hype must be a non-empty string' if DEBUG;

                # mark the current hype
                $hypes{ $wordnet_hype }++;

                # get the full hierarchy of hypes
                my $all_hypes = $this->_get_hypes_hierarchy( $wordnet_hype );
                map { $hypes{ $_ }++; } @{ $all_hypes };

                push @detected_types , keys( %hypes );

                # Old version
		#push @detected_types , $wordnet_hype;

	    }
            # Note : this would lead to too many unwanted matches
	    #push @detected_types , 'type-regular';

	}

	if ( my $sequence_types = $this->get_types( $sequence_normalized ) ) {
	    
	    # Note : we consider all the returned types
	    map {
		push @detected_types , $_;
	    }
	    grep {
		# we filter out owl types
		$_ !~ m/^owl/;
	    }
	    @{ $sequence_types };
        push @detected_types , 'type-entity';

	}
	# If we cannot find a named entity for this sequence, test to see if it designates the site itself
	# TODO : should further restrict this test to cases where the word is not a common word ?
	# TODO : this might be better handled as some form of feature
	# Note: host/site detection is optional
	# TODO : I shouldn't have to escape the sequence here (?)
	#elsif ( $this->capitalized_sequence ) {
	#    push @detected_types , 'named-entity-unknown';
	#}
# Note : no unknown type otherwise we have to deal with a humongous amount of garbage
#	else {
#	    push @detected_types , 'type-unknown';
#	}

        # TODO : enable softer match (use Token class ?)
        if ( defined( $instance ) ) {
            if ( ! $sequence_token->is_punctuation ) {
	       if ( $instance->host =~ $sequence_token->as_regex_anywhere ) {
		   push @detected_types , 'site';
	       }
	    }
        }

    }

    return \@detected_types;

}

sub _get_hypes_hierarchy {
    
    my $this = shift;
    my $wordnet_sense = shift;

    my %hypes;
    my @hypes_buffer = ( $wordnet_sense );
    while ( scalar( @hypes_buffer ) ) {	
	my $current_hype = shift @hypes_buffer;
	my @next_hypes = $this->wordnet_query_data->querySense( $current_hype , "hype" );
	map {
	    my $next_hype = $_;
	    if ( ! defined( $hypes{ $next_hype } ) ) {
		push @hypes_buffer , $next_hype;
	    }
	    $hypes{ $next_hype }++;
	} @next_hypes;
    }

    my @hypes_list = keys( %hypes );
    return \@hypes_list;

}

# instance types
memoize( 'instance_types' );
sub instance_types {

    my $this = shift;
    my $instance = shift;

    # TODO : should we enforce a threshold here ? => yes if this method turns out to be too costly

    my %types;
    my %types_total_frequency;
    
    # for each token, determine its predicted types
    my $instance_tokens = $instance->tokens;
    foreach my $instance_token_id (keys( %{ $instance_tokens } )) {

	my $token_entry = $instance_tokens->{ $instance_token_id };
	my $token_frequency = $token_entry->[ 1 ];

	# Note : ignore sequences made up exclusively of punctuation
	if ( $instance_token_id =~ m/^\p{Punct}+$/ ) {
	    next;
	}

	# detect types for the current token
	my $token_types = $this->detect_types( $instance_token_id , $instance );

	# update type distribution
	map {
	    $types{ $_ }{ $instance_token_id } += $token_frequency;
	    $types_total_frequency{ $_ } += $token_frequency;
	} @{ $token_types };

    }

    # normalize
    foreach my $token_type (keys( %types )) {
	map {
	    # TODO : generate frequency normalizer here ?
	    $types{ $token_type }{ $_ } /= $types_total_frequency{ $token_type }
	} keys( %{ $types{ $token_type } } );
    }

    return \%types;

}

# compute probability of a string based on a target distribution of types
sub type_conditional_probability {

    my $this = shift;
    my $instance = shift;
    my $token = shift;
    my $token_types = shift;
    my $type_priors = shift;

    my $token_normalized = ref( $token ) ? $token->id : StringNormalizer::_normalize( $token );
    my $type_conditional_probability = 0;

    # 1 - generate types for instance
    my $instance_types = $this->instance_types( $instance );

    # CURRENT : if the instance does not contain any of the requested types, return conditional probability of 1
    # ==> would allow to use conditional probability as a factor
    # ==> if this doesn't work, fit the slot scoring function

    # 2 - for each predicted type, check the conditional probability of token in instance
    my @_token_types = keys( %{ $token_types->coordinates } );
    my $token_types_count = scalar( @_token_types );
    my $type_priors_count = scalar( keys( %{ $type_priors->coordinates } ) );
    if ( $token_types_count && $type_priors_count ) {
	# Note : the type prior is provided by the original filler (i.e. not by token)
	my $type_prior = 1 / $type_priors_count;
	foreach my $token_type (@_token_types) {
	    if ( $type_priors->coordinates->{ $token_type } ) {
		my $instance_conditional_distribution = $instance_types->{ $token_type };
		$type_conditional_probability += $type_prior * ( $instance_conditional_distribution->{ $token_normalized } || 0 );
	    }
	}
    }

    return $type_conditional_probability;

}

# TODO : should this be promoted to WordNetLoader ?
memoize( '_wordnet_pos' );
sub _wordnet_pos {
    my $this = shift;
    my $string = shift;

    my $string_token = new Web::Summarizer::Token( surface => $string );

    my %pos_data;
    map {
	my @pos_fields = split /\#/ , $_;
	$pos_data{ $pos_fields[ 1 ] }++;
    } @{ $string_token->_wordnet_senses };

    return \%pos_data;
}

sub _wordnet_synsets {

    my $this = shift;
    my $string = shift;
    
    my %synsets;

    my $senses = $this->_wordnet_senses( $string );
    
    foreach my $sense (@{ $senses }) {
	# TODO : replace with wordnet_querySense ?
	my $synset = $this->wordnet_query_data->querySense( $sense , 'synset' );
	$synsets{ $synset }++;
    }

    my @_synsets = keys( %synsets );
    return \@_synsets;

}

sub _wordnet_hypes {

    my $this = shift;
    my $string = shift;
    my $wordnet_senses = $this->_wordnet_senses( $string );

    # 1 - determine specific senses
    # CURRENT : need to validate $string
    my @string_specific_senses = map { $this->wordnet_querySense( $string ) } @{ $wordnet_senses };
    my @string_senses;
    foreach my $string_specific_sense (@string_specific_senses ) {
	my @specific_senses = $this->wordnet_querySense( $string_specific_sense , "hype" );
	push @string_senses , @specific_senses;
    }

    # 2 - determine hypernym for each sense
    my @wordnet_hypes = uniq map {
	# TODO : replace with wordnet_querySense ?
	$this->wordnet_query_data->querySense( $_ , "hype" );
    } @string_senses;

    return \@wordnet_hypes;

}

sub _pos_test {
    my $this = shift;
    my $string = shift;
    my $target_pos = shift;
    my $wordnet_pos_data = $this->_wordnet_pos( $string );
    return defined( $wordnet_pos_data->{ $target_pos } ) ? 1 : 0;
}

# adjective testing
sub _is_adjective {
    my $this = shift;
    my $string = shift;
    return $this->_pos_test( $string , 'a' );
}

# adverb testing
sub _is_adverb {
    my $this = shift;
    my $string = shift;
    return $this->_pos_test( $string , 'r' );
}

# noun testing
sub _is_noun {
    my $this = shift;
    my $string = shift;
    return $this->_pos_test( $string , 'n' );
}

# verb testing
sub _is_verb {
    my $this = shift;
    my $string = shift;
    return $this->_pos_test( $string , 'v' );
}

# Note : retrieve extractive tokens for the target instance, that is tokens that:
#        => (1) appear in the target beyond some threshold and (2) not in the reference
#        => (3) do not appear in the reference summary
method analyze ( $instance_target , $instance_reference , $instance_reference_summary , :$threshold = 0 , :$max = undef ) {

    # we identify tokens instance_target that are extractive given instance_reference
    
    my $instance_target_tokens = $instance_target->tokens;
    my @instance_target_tokens_sorted = sort {
	$b->[ 1 ] <=> $a->[ 1 ];
    }	
    grep {
	# condition (1)
	$_->[ 1 ] >= $threshold;
    }
    map {
	# TODO : what can i do to avoid code duplication here (while still being somewhat computationally efficient) ?
	my $token_regex = $_->as_regex;
	[ $_ , $instance_target->supports( $token_regex , regex_match => 1 ) ];
    }
    grep {
	my $token_regex = $_->as_regex;
	# condition (2) and (3)
	( ! $instance_reference->supports( $token_regex , regex_match => 1 ) ) &&
	    ( $instance_reference_summary !~ $token_regex )
    } map { new Web::Summarizer::Token( surface => $_ ) } keys( %{ $instance_target_tokens } );

    # TODO : ideally this should not be necessary but evaluating all extractive 
    if ( defined( $max ) ) {
	splice @instance_target_tokens_sorted , $max;
    }

=pod    
    my @instance_target_tokens_extractive = map {
	$_->[ 0 ];
    } @instance_target_tokens_sorted;

    return \@instance_target_tokens_extractive;
=cut

    return \@instance_target_tokens_sorted;

}

__PACKAGE__->meta->make_immutable;

1;

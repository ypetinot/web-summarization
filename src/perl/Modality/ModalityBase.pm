package Modality::ModalityBase;

# Base class for all modality classes
# CURRENT : should each modality be cached as a separate database ? => title / url / content / anchortext => and in turn each field is a collection within that database => would make it easier to regenerate a specific field
#           ==> only partially relevant => some of the fields are handled by Web::Object and its subclasses
#           ==> focus on serialization of (1) segments , (2) utterances and maybe (3) tokens

use strict;
use warnings;

use StringNormalizer;
use Web::Summarizer::Token;
use Web::Summarizer::Tokenizer;
use Web::Summarizer::Utils;

use Carp::Assert;
use HTML::Strip;
use Memoize;
use Function::Parameters qw/:strict/;

use Moose;
use namespace::autoclean;

with( 'Logger' );

# modality weight
has 'weight' => ( is => 'ro' , isa => 'Num' , default => 1 );

# TODO : should be moved to a subclass, unless we make the method name more generic ?
sub key_generator {
    my $this = shift;
    my $cache_key = $this->object->url;
    return $cache_key;
}

# whether this modality supports a specific token (passed either as an object or a plain string ?)
# TODO : all the logic should be moved down to the StringSequence/Sentence classes so that mathing can be better optimized
#memoize( 'supports' );
method supports( $token , :$regex_match = 0 , :$matches = 1 , :$return_utterances = 0 ,
		 :$hypernyms_only = 0 , :$hyponyms_only = 0 ) {

    my @tokens;

    my $token_object = ref( $token ) ? $token : new Web::Summarizer::Token( surface => $token );

    if ( $hypernyms_only || $hyponyms_only ) {
	
	# this is just a wrapper - list out hypernyms/hyponyms and call regular supports code

        # CURRENT : maintain list of supported wordnet senses
	# => the purpose is to remove individual senses attached multi-sense replacement candidates

	# 1 - determine list of hypo/hypernyms
	my $nyms = $hypernyms_only ? $token_object->hypernyms : $token_object->hyponyms;
	
	# 2 - add all hyper/hyponyms to the list of requested tokens
	push @tokens , ( map { [ $_ , 0 ] } @{ $nyms } );
       
    }
    else {

	my $token_is_regex = ( ref( $token_object ) eq 'Regexp' ) || 0;
	push @tokens , [ $token_object , $token_is_regex ];

    }

    # Note : results is just the list of supporting utterances
    my $results = undef;
    
    # Note : raw_results is a structure containing a complete view on the matches
    my $raw_results =undef;

    # Note : this should be equivalent to the number of supporting utterances
    my $matches_count = 0;

    foreach my $token_entry (@tokens) {

	my $token_entry_object = $token_entry->[ 0 ];
	my $token_entry_is_regex = $token_entry->[ 1 ];
	my $token_entry_results;
	my $token_entry_raw_results;
	my $token_entry_matches_count = 0;

	# TODO : should we use $token->as_regex_non_segmented in case nothing else matches ?
	if ( $self->fluent && ! $token_entry_is_regex && ! $regex_match ) {
	    $token_entry_results = $self->supports_token( $token_entry_object );
	    $token_entry_matches_count = scalar( @{ $token_entry_results || [] } );
	}
	else {
	    $token_entry_raw_results = $self->supports_regex( $token_entry_object , return_utterances => $return_utterances );
	    # TODO : need to review use of supports_regex so we can eventually harmonize the interface for supports methods
	    # TODO : harmonize the interface for supports methods
	    if ( defined( $token_entry_raw_results ) ) {
		$token_entry_matches_count += $token_entry_raw_results->[ 1 ];
	    }
	    $token_entry_results = $token_entry_matches_count ? $token_entry_raw_results->[ 2 ] : undef;
	}

	# merge results
	if ( defined( $token_entry_results ) ) {
	    if ( ! defined( $results ) ) {
		$results = [];
	    }
	    # TODO : only add unique utterances only ?
	    push @{ $results } , @{ $token_entry_results };
	}
	if ( defined( $token_entry_raw_results ) ) {

	    if ( ! defined( $raw_results ) ) {
		# [ token/regex , n_matches , utterances , matches ]
		$raw_results = [ $token_object , 0 , [] , [] , [] ];
	    }
	    
	    # TODO : reduce code redundancy with supports_token (synsets portion)
	    $raw_results->[ 1 ] += $token_entry_raw_results->[ 1 ];
	    push @{ $raw_results->[ 2 ] } , @{ $token_entry_raw_results->[ 2 ] };
	    push @{ $raw_results->[ 3 ] } , @{ $token_entry_raw_results->[ 3 ] };
	    push @{ $raw_results->[ 4 ] } , @{ $token_entry_raw_results->[ 4 ] };

	}
	$matches_count += $token_entry_matches_count;
	
    }

    # TODO : acceptable for now, but should removed eventually (through abstraction by Web::Summarizer::Token and updating all calls specifying the return_utterances flag)
    if ( $return_utterances ) {
	return $raw_results;
    }
    
    return $matches ? $results : $matches_count;

}

# TODO : utimately get rid of return_utterances
# TODO : create my own memoization here as well
#memoize( 'supports_regex' );
method supports_regex ( $regex , :$return_utterances = 0 , :$binary = 0 ) {

    my $regex_object = $regex;
    if ( ref( $regex ) ne 'Regexp' ) {
	# i.e. this is a Token object
	$regex_object = $self->fluent ? $regex->as_regex : $regex->as_regex_anywhere;
    }

    my @all_matches;

=pod
    foreach my $segment (@{ $segments }) {
	my $segment_copy = $segment;
	while ( my @matches = ( $segment_copy =~ m/$regex/s ) ){
	    push @all_segments , $segment;
	    push @all_matches , \@matches;
	    $segment_copy = substr $segment_copy , $+[ 0 ];
	}
    }
=cut

    my @all_utterances;
    my $utterances = $self->utterances;
    foreach my $utterance (@{ $utterances }) {
	my $utterance_matches = $utterance->supports_regex( $regex_object ) || [];
	foreach my $utterance_match (@{ $utterance_matches }) {
	    if ( $binary ) {
		return 1;
	    }
	    push @all_utterances , $return_utterances ? $utterance : $utterance->raw_string;
	    push @all_matches , $utterance_match;
	}
    }
    my $n_matches = scalar( @all_utterances );

    return $n_matches ? [ $regex , $n_matches , \@all_utterances , \@all_matches , [] ] : undef;

}

has 'synsets' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_synsets_builder' );
sub _synsets_builder {

    my $this = shift;

    my %synsets;
    
    # generate synsets for all tokens
    my @token_entries = values( %{ $this->tokens } );
    foreach my $token_entry (@token_entries) {

	# [ $utterance_token , 0 , [] ];

	my $synset = $token_entry->[ 0 ]->synset;
	
	if ( ! defined( $synsets{ $synset } ) ) {
	    # TODO : this is redundant with the tokens_builder code
	    $synsets{ $synset } = [ $synset , 0 , [] , [] , [] ];
	}

	my $synset_entry = $synsets{ $synset };
	
	# update total occurrence count
	$synset_entry->[ 1 ] += $token_entry->[ 1 ];

	# keep track of the utterances containing this token
	push @{ $synset_entry->[ 2 ] } , @{ $token_entry->[ 2 ] };

	# keep track of all the tokens detected under this synset
	push @{ $synset_entry->[ 4 ] } , $token_entry->[ 0 ];

    }

    return \%synsets;

}

# Check support by looking up token in modality index ?
method supports_token ( $token , :$consider_synonyms = 0 ) {

    my $token_entry = $self->tokens->{ ref( $token ) ? $token->id : $token };
    if ( $consider_synonyms && ! defined( $token_entry ) ) {

	# get token synset
	my $token_synset = $token->get_synset;

	# get modality synsets
	my $modality_synsets = $self->synsets;
	my $synset_entry = $modality_synsets->{ $token_synset };
	
	if ( defined( $synset_entry ) ) {
	    $token_entry = $synset_entry;
	}

    }

    # Note : return list of utterances
    # TODO : harmonize with supports_regex ? => i.e. return full entry ?
    return defined( $token_entry ) ? $token_entry->[ 2 ] : undef;

}

# list of tokens for this modality => all modalities are tokenizable, even if tokenization is achieved in a statistical way    
# TODO : create local class to handle Token occurrence record ?
has 'tokens' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_tokens_builder' );
sub _tokens_builder {

    my $this = shift;

    my %tokens;
    my $utterances = $this->utterances;

    foreach my $utterance ( @{ $utterances } ) {
	   
	my $utterance_tokens = $utterance->object_sequence;

	# how do we produce a truly unique set of tokens ?
	foreach my $utterance_token ( @{ $utterance_tokens } ) {
	    
	    my $token_key = $utterance_token->id;
	    if ( ! defined( $tokens{ $token_key } ) ) {
		$tokens{ $token_key } = [ $utterance_token , 0 , [] ];
	    }
	    my $token_entry = $tokens{ $token_key };

	    # update total occurrence count
	    $token_entry->[ 1 ]++;

	    # keep track of the utterances containing this token
	    push @{ $token_entry->[ 2 ] } , $utterance;
	    
	}
	
    }

    return \%tokens;

}

# CURRENT : serialization using CachedCollection => possible as trait ?
#           ==> for single string modalities => raw content == segment => avoid duplicate serialization ?
has 'segments' => (
    #traits => qw/CachedCollectionTrait/ ,
    is => 'ro' ,
    isa => 'ArrayRef[Str]' ,
    init_arg => undef ,
    lazy => 1 ,
    builder => '_segments_builder' );
# Note: segments_builder is based on get_data => we serialize raw segments
# Note: overload in order to provide custom segment construction and/or disable serialization
sub _segments_builder {

    my $this = shift;
    my $segments = $this->get_data;

    # TODO : to be removed
    if ( ! ref( $segments ) ) {
	$segments = [ $segments ];
    }

    my $hs = new HTML::Strip;
    my @filtered_segments = grep {
	
	defined( $_ ) &&
	    
	    # filter out segments that are exclusively made up of punctuation and spaces 
	    $_ !~ m/^(?:\p{PosixPunct}|\s)+$/si &&
	    
	    # TODO : move this to the data generator (will require flushing out the segments data stored in MongoDB
	    # Note : filtering out local URLs
	    # TODO : are there similar strings that should be filtered as well ?
	    $_ !~ m/^\/[^\s]+$/si &&
	    
	    # filter out script expressions
	    $_ !~ m/^\<\?/si &&

	    # filter out unrendered HTML content
	    # TODO : is this too aggressive ?
	    $_ !~ m/^\<[^\s]+\>/si &&
	    $_ !~ m/^<[^\s]+.*\>$/si &&
	    $_ !~ m/^<\!--/si &&
	    $_ !~ m/\=\"/si &&

	    # filter out Javascript content
	    $_ !~ m/string\(\d+\)/si &&
	    $_ !~ m/array\(\d+\)/si &&

	    # filter out JSON content
	    $_ !~ m/\}\}/si &&
	    $_ !~ m/\:\{/si

	    # TODO : add filter for full fledged URLs => how ?
	    ;
	
    }
    grep { defined( $_ ) && length( $_ ) }
    map {
	my $segment_raw = $_;
	my $segment_html_stripped = $hs->parse( $segment_raw );
	StringNormalizer::_clean( $segment_html_stripped );
    }
    grep { defined( $_ ) && length( $_ ) }
    @{ $segments };

    my @adjusted_segments;
    # Note : large segments ( > 1000 ) lead to a complete stall in some cases when calling the NER component => lack of RAM ?
    my $limit = 500;
    map {

	my $segment = $_;
	my $segment_length = length( $segment );
	if ( $segment_length > $limit ) {

	    # punctuation to space ratio
	    my @punctuation_characters = ( $segment =~ m/\p{PosixPunct}+/sgi );
	    my @space_characters = ( $segment =~ m/\s+/sgi );
	    my $punctuation_space_ratio = ( scalar( @punctuation_characters ) + 1 ) / ( scalar( @space_characters ) + 1 );

	    if ( $segment =~ m/^(?:\p{PosixPunct}|\d|\s)+$/ ) {
		# nothing - filter out large segments that consist exclusively of numbers, punctuation and spaces
	    }
	    elsif ( $punctuation_space_ratio < 5 ) {

		my @current_buffer;
		my $current_length = 0;
		my @segment_tokens = split /\s+/ , $segment;
		while ( scalar( @segment_tokens ) ) {
		    
		    my $next_token = shift @segment_tokens;
		    my $next_token_length = length( $next_token );
		    
		    push @current_buffer , $next_token;
		    $current_length += $next_token_length;
		    
		    if ( $current_length > $limit || ! scalar( @segment_tokens ) ) {
			my $adjusted_segment = join( ' ' , @current_buffer );
			push @adjusted_segments , $adjusted_segment;
			@current_buffer = ();
			$current_length = 0;
		    }
		    
		}

	    }

	}
	else {
	    push @adjusted_segments , $segment;
	}

    } @filtered_segments;

    my @final_segments = map {
	affirm { length( $_ ) <= 2 * $limit } "For performance reasons, we can only parse strings that have less than 2 * $limit characters." if DEBUG; 
	# TODO : can this be removed ?
	StringNormalizer::_clean( $_ );
    } @adjusted_segments;
    return \@final_segments;

}

# list of utterances for this modality (no option to filter)
# TODO : demote to a TextModality sub-class if we ever introduce image/video/audio modalities
has 'utterances' => ( is => 'ro' , isa => 'ArrayRef[Web::Summarizer::Sequence]' , init_arg => undef , lazy => 1 , builder => '_utterances_builder' );
sub _utterances_builder {
    
    my $this = shift;

    my $segments = $this->segments;

    my $url = $this->object->url;
    my $id = $this->id;
    
    my $n_segments = scalar( @{ $segments } );
    my $utterance_weight = $n_segments ? ( 1 / $n_segments ) : 0;

    # CURRENT :
    # 1 - call factory instead constructor to create multiple sentences
    # 2 - how are these handled down the line ?

    # CURRENT : how can we inform segmentation at this stage ?
    # TODO : is there a better way of filtering out utterances that have a length of 0 ?
    my @utterances = grep { $_->length } map {
	my $source_id = join( "." . $id , 'segmented' );
	# CURRENT : special treatment to get POS for fluent modalities
	# Note : in the future we may want to specify modality-specific parameters for the sequence instantiation
	Web::Summarizer::Utils::load_class( $this->sequence_class )->new(
	    raw_string => $_ ,
	    object => $this->object ,
	    source_id => $source_id ,
	    weight => $utterance_weight );
    }
    # TODO : this should be move to a factory method handling utterance construction
    grep { $_ !~ m/^(?:\p{PosixPunct}|\s)+$/ }
    @{ $segments };

    my $n_utterances = scalar( @utterances );

    print STDERR "[" . __PACKAGE__ . "] $url / $id / $n_utterances utterances\n"; 
    
    return \@utterances;
    
}

has 'sequence_class' => ( is => 'ro' , isa => 'Str', builder => '_sequence_class_builder' ); 
=pod
sub _string_sequence_builder_builder {

    my $this = shift;

    return Web::Summarizer::Utils::load_class( $this->sequence_builder_class )->new(

	# CURRENT : page-specific segmentation algorithm (should there be a hierarchy of backoffs ? web >> site >> page)
	tokenizer => new Web::Summarizer::Tokenizer( object => $this->object )

	);

}
=cut

# modality raw content as plain string
# CURRENT : dependency on UrlData::_raw_tokens
# Note: segments => content | utterances ( modality content is not the same a the HtmlDocument content )
has 'content' => ( is => 'ro' , isa => 'Maybe' , init_arg => undef , lazy => 1 , builder => '_content_builder' );
sub _content_builder {
    my $this = shift;
    return join( " " , @{ $this->segments } );
}

# named entities
has 'named_entities' => ( is => 'ro' , isa => 'HashRef' , init_arg => undef , lazy => 1 , builder => '_named_entities_builder' );
sub _named_entities_builder {

    my $this = shift;

# CURRENT/TODO => has_field for each modality object
# CURRENT => url::modality_id
###    if ( ! $this->has_field( 'named_entities' , namespace => 'nlp' ) ) {

    my %named_entities;
    
    # TODO : make available via a role ?
    my $parsing_service = Service::NLP::SentenceChunker->new;
    
    my %segment2seen;
    my $segments = $this->segments;
    foreach my $segment (@{ $segments }) {
	if ( $segment2seen{ $segment }++ ) {
	    next;
	}
	# TODO : this is a trick to get more named entities from non-well-formed segments - is there a way to avoid this ? better parsing service ?
	my $adapted_segment = ( $segment =~ m/\.$/ ) ? $segment : ( $segment . ' .' );
	map {
	    my $entity_surface = $_->entity;
	    my $entity_tag = $_->tag;
	    $named_entities{ $entity_tag }{ $entity_surface }++;
	}
	@{ $parsing_service->get_named_entities( $adapted_segment ) };
    }
    
###	$this->set_field( 'named_entities' , encode_json( \%named_entities ) , namespace => 'nlp' );

###    }

###    return decode_json( $this->get_field( 'named_entities' , namespace => 'nlp' ) );
    
    return \%named_entities;

}

__PACKAGE__->meta->make_immutable;

1;
